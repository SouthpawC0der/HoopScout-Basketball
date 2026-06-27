// HoopScout — Subscription Cloud Functions
//
// Closes the "client-trusted subscription" gap flagged in the security
// audit. The client must NEVER write subscriptionStatus / expiresAt /
// trialStartedAt directly — firestore.rules forbids it. Instead:
//
//   • On first gym profile creation, `stampGymTrialOnCreate` (Firestore
//     trigger) stamps a 7-day trial from the server clock.
//   • After a StoreKit purchase or restore, the client posts the signed
//     `transactionInfo` to `validateAppStoreTransaction` (callable). The
//     function verifies the JWS signature against Apple's root certs and,
//     if valid, writes the canonical entitlement to the user doc.
//   • Apple posts subscription lifecycle events (renewal, refund, billing
//     retry, etc.) to `appStoreServerNotificationsV2` (HTTPS). The handler
//     decodes the signed payload and updates the entitlement so off-session
//     changes are reflected without the client running.
//
// Setup checklist (NOT automated):
//   1. `npm install @apple/app-store-server-library` in `functions/`.
//   2. In App Store Connect → App Information → set the V2 Server URL to
//      the deployed URL of `appStoreServerNotificationsV2`.
//   3. Configure the function's runtime env vars:
//        BUNDLE_ID            — e.g. com.hoopscout.app
//        APP_APPLE_ID         — numeric App Store ID for the app
//        APPLE_ENV            — "Sandbox" or "Production"
//        APPLE_ISSUER_ID      — App Store Connect issuer
//        APPLE_KEY_ID         — In-App Purchase API key id
//        APPLE_PRIVATE_KEY    — PEM contents of the .p8 key
//   4. The runtime needs network egress to api.storekit.apple.com and
//      api.storekit-sandbox.apple.com.

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { logger } = require("firebase-functions");

const GYM_TRIAL_DAYS = 7;

// ─────────────────────────────────────────────────────────────────────
// 1. Trial stamping (with restart prevention)
// ─────────────────────────────────────────────────────────────────────
// Triggered the first time a gym user doc lands. Reads the Apple user
// identifier from the private subcollection and checks the
// `gymTrialClaims/{appleUserIdentifier}` registry: if a previous Firebase
// uid under the same Apple ID has already claimed a 7-day trial, this
// account gets `subscriptionStatus = "expired"` instead — they have to
// subscribe immediately, no second trial.
exports.stampGymTrialOnCreate = onDocumentCreated(
  "users/{uid}",
  async (event) => {
    const data = event.data?.data();
    if (!data || data.accountKind !== "gym") return;

    const db = getFirestore();
    const { uid } = event.params;

    // Apple's stable sub claim lives in users/{uid}/private/profile (PII).
    const privateSnap = await db
      .collection("users").doc(uid)
      .collection("private").doc("profile")
      .get();
    const appleUserId = privateSnap.exists
      ? privateSnap.data().appleUserIdentifier
      : null;

    // Honor an existing claim under the same Apple ID — no fresh trial.
    let alreadyClaimed = false;
    if (appleUserId) {
      const claimRef = db.collection("gymTrialClaims").doc(appleUserId);
      const claimSnap = await claimRef.get();
      if (claimSnap.exists && claimSnap.data().firstUid && claimSnap.data().firstUid !== uid) {
        alreadyClaimed = true;
      } else {
        await claimRef.set(
          {
            firstUid: uid,
            claimedAt: FieldValue.serverTimestamp(),
          },
          { merge: true }
        );
      }
    }

    if (alreadyClaimed) {
      await event.data.ref.set(
        {
          subscriptionStatus: "expired",
          subscriptionExpiresAt: Timestamp.fromMillis(Date.now()),
        },
        { merge: true }
      );
      logger.warn("stampGymTrialOnCreate: trial denied (already claimed)", {
        uid, appleUserId,
      });
      return;
    }

    const now = new Date();
    const expires = new Date(now.getTime() + GYM_TRIAL_DAYS * 24 * 60 * 60 * 1000);
    await event.data.ref.set(
      {
        subscriptionStatus: "trial",
        trialStartedAt: Timestamp.fromDate(now),
        subscriptionExpiresAt: Timestamp.fromDate(expires),
      },
      { merge: true }
    );

    logger.info("stampGymTrialOnCreate: trial granted", { uid, appleUserId });
  }
);

// ─────────────────────────────────────────────────────────────────────
// 2. Client-initiated transaction verification
// ─────────────────────────────────────────────────────────────────────
// Client (SubscriptionService.swift) calls this with the signed JWS
// `signedTransactionInfo` returned by StoreKit 2 after `Product.purchase()`
// or `Transaction.currentEntitlements`. Verified payload becomes the
// canonical entitlement on the user doc.
exports.validateAppStoreTransaction = onCall(
  { region: "us-central1" },
  async (req) => {
    if (!req.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in first.");
    }
    const signedTransaction = req.data?.signedTransactionInfo;
    if (typeof signedTransaction !== "string" || signedTransaction.length < 10) {
      throw new HttpsError("invalid-argument", "signedTransactionInfo missing.");
    }

    const transaction = await verifyAppleSignedTransaction(signedTransaction);
    if (!transaction) {
      throw new HttpsError("permission-denied", "Transaction failed verification.");
    }

    await applyTransactionToUser(req.auth.uid, transaction);
    return { ok: true, productId: transaction.productId };
  }
);

// ─────────────────────────────────────────────────────────────────────
// 3. App Store Server Notifications V2 webhook
// ─────────────────────────────────────────────────────────────────────
// Apple POSTs JSON with { signedPayload: "<JWS>" } whenever a subscription
// changes off-session. We decode, locate the originalTransactionId →
// uid mapping, and patch the user doc.
exports.appStoreServerNotificationsV2 = onRequest(
  { region: "us-central1" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("POST only");
      return;
    }
    const signedPayload = req.body?.signedPayload;
    if (typeof signedPayload !== "string") {
      res.status(400).send("Missing signedPayload");
      return;
    }

    try {
      const payload = await verifyAppleSignedNotification(signedPayload);
      if (!payload?.data?.signedTransactionInfo) {
        res.status(400).send("Missing signedTransactionInfo");
        return;
      }
      const transaction = await verifyAppleSignedTransaction(
        payload.data.signedTransactionInfo
      );
      if (!transaction) {
        res.status(400).send("Bad transaction signature");
        return;
      }

      const uid = await uidForOriginalTransaction(transaction.originalTransactionId);
      if (!uid) {
        // We don't know this transaction yet. Log and accept so Apple
        // doesn't retry forever.
        logger.warn("ASN V2: unknown originalTransactionId", {
          originalTransactionId: transaction.originalTransactionId,
        });
        res.status(200).send("ok");
        return;
      }
      await applyTransactionToUser(uid, transaction, payload.notificationType);
      res.status(200).send("ok");
    } catch (err) {
      logger.error("ASN V2 failed", { err: err.message });
      res.status(500).send("error");
    }
  }
);

// ─────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────

/// Map App Store originalTransactionId → Firebase uid.
/// Maintained at `appStoreLinks/{originalTransactionId}` with `{ uid }`.
/// The first successful validateAppStoreTransaction call writes this link.
async function uidForOriginalTransaction(originalTransactionId) {
  if (!originalTransactionId) return null;
  const doc = await getFirestore()
    .collection("appStoreLinks")
    .doc(originalTransactionId)
    .get();
  return doc.exists ? doc.data().uid : null;
}

/// Patch the user doc with the canonical entitlement and remember the
/// originalTransactionId↔uid link for future webhook events.
async function applyTransactionToUser(uid, transaction, notificationType) {
  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);

  let status = "expired";
  if (!transaction.revocationDate
      && transaction.expiresDate > Date.now()) {
    status = "active";
  }
  // Refunds, voluntary cancellations and grace-period termination all
  // collapse to "expired" once Apple stops entitling the user.

  const update = {
    subscriptionStatus: status,
    subscriptionExpiresAt: transaction.expiresDate
      ? Timestamp.fromMillis(transaction.expiresDate)
      : FieldValue.delete(),
    subscriptionUpdatedAt: FieldValue.serverTimestamp(),
    appStoreOriginalTransactionId: transaction.originalTransactionId,
    appStoreProductId: transaction.productId,
  };

  await Promise.all([
    userRef.set(update, { merge: true }),
    db.collection("appStoreLinks")
      .doc(transaction.originalTransactionId)
      .set({ uid, productId: transaction.productId }, { merge: true }),
  ]);

  logger.info("applyTransactionToUser", {
    uid,
    status,
    productId: transaction.productId,
    notificationType: notificationType ?? "client",
  });
}

// ─────────────────────────────────────────────────────────────────────
// Apple JWS verification
// ─────────────────────────────────────────────────────────────────────
// The blocks below are stubs — wire them to Apple's official library
// (`@apple/app-store-server-library`) once the dependency is installed.
// Until then the function returns null which short-circuits to a
// permission-denied response, so no spoofed transaction can land on the
// user doc.

/// Verify a signed transaction JWS. Returns a decoded payload with the
/// fields we care about, or null when verification fails.
async function verifyAppleSignedTransaction(signedTransactionInfo) {
  try {
    // const { SignedDataVerifier, Environment } = require("@apple/app-store-server-library");
    // const verifier = new SignedDataVerifier(
    //   appleRootCAs,
    //   true, // enable online checks
    //   Environment[process.env.APPLE_ENV ?? "Sandbox"],
    //   process.env.BUNDLE_ID,
    //   Number(process.env.APP_APPLE_ID)
    // );
    // const payload = await verifier.verifyAndDecodeTransaction(signedTransactionInfo);
    // return {
    //   productId: payload.productId,
    //   originalTransactionId: payload.originalTransactionId,
    //   expiresDate: payload.expiresDate,
    //   revocationDate: payload.revocationDate ?? null,
    // };
    logger.warn("verifyAppleSignedTransaction stub — install @apple/app-store-server-library");
    return null;
  } catch (err) {
    logger.error("verifyAppleSignedTransaction failed", { err: err.message });
    return null;
  }
}

/// Verify a signed notification (V2) JWS. Returns the decoded payload.
async function verifyAppleSignedNotification(signedPayload) {
  try {
    // const { SignedDataVerifier, Environment } = require("@apple/app-store-server-library");
    // const verifier = ... (same as above)
    // return await verifier.verifyAndDecodeNotification(signedPayload);
    logger.warn("verifyAppleSignedNotification stub — install @apple/app-store-server-library");
    return null;
  } catch (err) {
    logger.error("verifyAppleSignedNotification failed", { err: err.message });
    return null;
  }
}
