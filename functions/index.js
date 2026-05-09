const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

async function notifyAll(title, body, data = {}) {
  const snapshot = await admin.firestore().collection("users").get();
  /** @type {string[]} */
  const tokens = [];
  snapshot.forEach((doc) => {
    const t = doc.data().fcmToken;
    if (typeof t === "string" && t.length > 16) {
      tokens.push(t);
    }
  });
  if (!tokens.length) {
    return {successCount: 0, total: 0};
  }

  const stringData = {};
  Object.keys(data).forEach((k) => {
    stringData[String(k)] = String(data[k]);
  });

  /** @type {string[][]} */
  const batches = [];
  for (let i = 0; i < tokens.length; i += 500) {
    batches.push(tokens.slice(i, i + 500));
  }

  let successCount = 0;
  for (const chunk of batches) {
    const res = await admin.messaging().sendEachForMulticast({
      tokens: chunk,
      notification: {title, body},
      data: stringData,
    });
    successCount += res.successCount;
  }

  return {successCount, total: tokens.length};
}

exports.sendBroadcastNotification = functions.https.onCall(
    async (data, context) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Login required.",
        );
      }

      const userDoc =
        await admin.firestore().collection("users").doc(context.auth.uid).get();
      const role = userDoc.exists ? userDoc.data().role : null;
      if (role !== "admin") {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Admin role required.",
        );
      }

      const title =
        typeof data.title === "string" ? data.title.trim() : "";
      const body = typeof data.body === "string" ? data.body.trim() : "";
      if (!title || !body) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "Title and body are required.",
        );
      }

      const result =
        await notifyAll(title, body, {type: "broadcast"});
      return {ok: true, delivered: result.successCount, targets: result.total};
    });

exports.onCheckpointUpdated = functions.firestore
    .document("checkpoints/{checkpointId}")
    .onUpdate(async (change, context) => {
      const before = change.before.exists ? change.before.data() : null;
      const after = change.after.data();
      if (!after) {
        return null;
      }
      const prevStatus =
        before && typeof before.status === "string" ? before.status : null;
      const nextStatus =
        typeof after.status === "string" ? after.status : "unknown";

      // Only ping users when status actually changes from the previous revision.
      if (prevStatus === nextStatus) {
        return null;
      }

      const name =
        typeof after.name === "string" && after.name.trim()
          ? after.name.trim()
          : "نقطة تفتيش";
      const title = `${name}`;
      const body = `الحالة الجديدة: ${nextStatus}`;

      await notifyAll(title, body, {
        type: "checkpoint_update",
        checkpointId: String(context.params.checkpointId || ""),
      });
      return null;
    });
