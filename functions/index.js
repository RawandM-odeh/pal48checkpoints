const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const STATUS_AR = Object.freeze({
  open: "مفتوح",
  closed: "مغلق",
  crowded: "أزمة",
  army_present: "جيش",
  settlers_present: "مستوطنون",
});

const ALLOWED_STATUSES = new Set([
  "open",
  "closed",
  "crowded",
  "army_present",
  "settlers_present",
]);

/** Normalize to an allowed status; otherwise [fallback] (default open). */
function normalizeStatus(raw, fallback = "open") {
  if (typeof raw !== "string") {
    return fallback;
  }
  const v = raw.trim().toLowerCase();
  if (ALLOWED_STATUSES.has(v)) {
    return v;
  }
  return fallback;
}

/** Read entrance/exit; snake_case first, then camelCase; legacy `status` fallback. */
function readDirections(data) {
  const legacyFallback = normalizeStatus(data.status);

  const entranceRaw =
    typeof data.entrance_status === "string" &&
        data.entrance_status.trim() !== "" ?
      data.entrance_status :
      typeof data.entranceStatus === "string" &&
          data.entranceStatus.trim() !== "" ?
        data.entranceStatus :
        null;

  const exitRaw =
    typeof data.exit_status === "string" &&
        data.exit_status.trim() !== "" ?
      data.exit_status :
      typeof data.exitStatus === "string" &&
          data.exitStatus.trim() !== "" ?
        data.exitStatus :
        null;

  const entrance = entranceRaw !== null ?
    normalizeStatus(entranceRaw, legacyFallback) :
    legacyFallback;
  const exit = exitRaw !== null ?
    normalizeStatus(exitRaw, legacyFallback) :
    legacyFallback;

  return {entrance, exit};
}

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
      try {
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

        const broadcastIdRaw = data.broadcastId;
        const broadcastId =
          typeof broadcastIdRaw === "string" ? broadcastIdRaw.trim() : "";
        /** @type {Record<string, string>} */
        const payload = {type: "broadcast"};
        if (broadcastId) {
          payload.broadcastId = broadcastId;
        }

        const result = await notifyAll(title, body, payload);
        return {ok: true, delivered: result.successCount, targets: result.total};
      } catch (err) {
        if (err instanceof functions.https.HttpsError) {
          throw err;
        }
        console.error("sendBroadcastNotification failed", err);
        const msg =
          err && typeof err.message === "string" ? err.message : String(err);
        throw new functions.https.HttpsError(
            "failed-precondition",
            msg ||
              "FCM failed (enable Blaze billing, FCM API, or check Functions logs).",
        );
      }
    });

exports.onCheckpointUpdated = functions.firestore
    .document("checkpoints/{checkpointId}")
    .onUpdate(async (change, context) => {
      const before = change.before.exists ? change.before.data() : null;
      const after = change.after.data();
      if (!before || !after) {
        return null;
      }

      const prev = readDirections(before);
      const next = readDirections(after);

      if (prev.entrance === next.entrance &&
          prev.exit === next.exit) {
        return null;
      }

      const name =
        typeof after.name === "string" && after.name.trim()
          ? after.name.trim()
          : "نقطة تفتيش";

      const entAr = STATUS_AR[next.entrance] || next.entrance;
      const exAr = STATUS_AR[next.exit] || next.exit;
      const title = `${name}`;
      const body = `الدخول: ${entAr}\nالخُروج: ${exAr}`;

      await notifyAll(title, body, {
        type: "checkpoint_update",
        checkpointId: String(context.params.checkpointId || ""),
      });
      return null;
    });
