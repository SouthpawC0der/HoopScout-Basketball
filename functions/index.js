// HoopScout — Cloud Functions
// Fan-out new chat messages as APNs/FCM pushes.

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { logger } = require("firebase-functions");

initializeApp();

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
