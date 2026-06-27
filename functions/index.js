// HoopScout — Cloud Functions
// Fan-out new chat messages as APNs/FCM pushes.

const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { logger } = require("firebase-functions");

initializeApp();

function computeInitials(name) {
  if (!name) return "?";
  const parts = name.trim().split(/\s+/);
  const first = parts[0] && parts[0][0] ? parts[0][0] : "";
  const last = parts.length > 1 && parts[1][0] ? parts[1][0] : "";
  const combined = (first + last).toUpperCase();
  return combined || "?";
}

// Triggered when a user tombstones their account (deletedAt first appears).
// Removes the followers/following/blocked subcollections that the client
// deletes best-effort — required for Apple App Store Guideline 5.1.1(v).
exports.cleanupDeletedUser = onDocumentUpdated(
  "users/{uid}",
  async (event) => {
    const before = event.data.before.data() || {};
    const after  = event.data.after.data()  || {};

    // Only run on the initial tombstone write; skip subsequent updates.
    if (before.deletedAt != null || after.deletedAt == null) return;

    const { uid } = event.params;
    const db = getFirestore();

    await Promise.all(
      ["followers", "following", "blocked"].map((sub) =>
        db.recursiveDelete(db.collection("users").doc(uid).collection(sub))
      )
    );

    logger.info("cleanupDeletedUser: subcollections removed", { uid });
  }
);

// Fan-out a follow: mirror to followers + update counters on both sides.
exports.onFollowChange = onDocumentWritten(
  "users/{followerUid}/following/{targetUid}",
  async (event) => {
    const { followerUid, targetUid } = event.params;
    if (followerUid === targetUid) return;

    const db = getFirestore();
    const before = event.data && event.data.before && event.data.before.exists;
    const after = event.data && event.data.after && event.data.after.exists;

    if (!before && after) {
      // New follow.
      const followerSnap = await db.doc(`users/${followerUid}`).get();
      const follower = followerSnap.data() || {};
      const name = follower.name || "Someone";
      const initials = computeInitials(name);

      const batch = db.batch();
      batch.set(db.doc(`users/${targetUid}/followers/${followerUid}`), {
        name,
        initials,
        since: FieldValue.serverTimestamp(),
      });
      batch.set(db.doc(`users/${followerUid}`),
        { followingCount: FieldValue.increment(1) }, { merge: true });
      batch.set(db.doc(`users/${targetUid}`),
        { followersCount: FieldValue.increment(1) }, { merge: true });
      await batch.commit();
    } else if (before && !after) {
      // Unfollow.
      const batch = db.batch();
      batch.delete(db.doc(`users/${targetUid}/followers/${followerUid}`));
      batch.set(db.doc(`users/${followerUid}`),
        { followingCount: FieldValue.increment(-1) }, { merge: true });
      batch.set(db.doc(`users/${targetUid}`),
        { followersCount: FieldValue.increment(-1) }, { merge: true });
      await batch.commit();
    }
  }
);

exports.sendMessageNotification = onDocumentCreated(
  "threads/{threadId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const message = snap.data() || {};
    const senderId = message.senderId;
    const text = message.text || "";
    const { threadId } = event.params;

    if (!senderId || !threadId) {
      logger.warn("Missing senderId or threadId", { senderId, threadId });
      return;
    }

    const db = getFirestore();

    // Load the parent thread.
    const threadSnap = await db.doc(`threads/${threadId}`).get();
    const thread = threadSnap.data();
    if (!thread) {
      logger.warn("Thread not found", threadId);
      return;
    }

    const participants = Array.isArray(thread.participants) ? thread.participants : [];
    const recipientIds = participants.filter((uid) => uid !== senderId);
    if (recipientIds.length === 0) return;

    const senderInfo = (thread.participantsInfo || {})[senderId] || {};
    const senderName = senderInfo.name || "Someone";

    // Fetch each recipient's FCM token in parallel.
    const tokenPromises = recipientIds.map(async (rid) => {
      const userSnap = await db.doc(`users/${rid}`).get();
      const token = userSnap.exists ? userSnap.data().fcmToken : null;
      return token || null;
    });
    const tokens = (await Promise.all(tokenPromises)).filter(Boolean);
    if (tokens.length === 0) {
      logger.info("No FCM tokens for recipients", recipientIds);
      return;
    }

    const truncated = text.length > 140 ? text.substring(0, 137) + "…" : text;

    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: senderName,
        body: truncated,
      },
      data: {
        threadId,
        type: "message",
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    // Clean up stale/invalid tokens.
    const stale = [];
    response.responses.forEach((res, idx) => {
      if (!res.success) {
        const code = res.error && res.error.code;
        if (
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/invalid-argument"
        ) {
          stale.push(tokens[idx]);
        } else {
          logger.warn("FCM send failure", { code, idx });
        }
      }
    });
    if (stale.length > 0) {
      // Best-effort: clear stale tokens from any user doc that referenced them.
      const usersSnap = await db.collection("users")
        .where("fcmToken", "in", stale.slice(0, 10))
        .get();
      const batch = db.batch();
      usersSnap.forEach((doc) => batch.update(doc.ref, { fcmToken: null }));
      await batch.commit().catch(() => {});
    }
  }
);
