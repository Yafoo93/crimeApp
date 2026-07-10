import {initializeApp} from "firebase-admin/app";
import {FieldValue, getFirestore} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

initializeApp();

const db = getFirestore();
const auth = getAuth();
const region = "europe-west1";
const allowedRoles = ["user", "admin", "superAdmin"] as const;

type UserRole = (typeof allowedRoles)[number];

function isAllowedRole(role: unknown): role is UserRole {
  return typeof role === "string" && allowedRoles.includes(role as UserRole);
}

function assertSuperAdmin(request: {
  auth?: {uid: string; token: Record<string, unknown>};
}) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in is required.");
  }

  if (request.auth.token.role !== "superAdmin") {
    throw new HttpsError(
      "permission-denied",
      "Only super admins can assign roles."
    );
  }
}

export const healthCheck = onRequest(
  {
    region,
  },
  (request, response) => {
    logger.info("crimeApp Firebase Functions is running.", {
      method: request.method,
    });
    response.send("crimeApp backend is running.");
  }
);

export const setUserRole = onCall(
  {
    region,
  },
  async (request) => {
    assertSuperAdmin(request);

    const uid = request.data?.uid;
    const role = request.data?.role;

    if (typeof uid !== "string" || uid.trim().length === 0) {
      throw new HttpsError("invalid-argument", "A valid uid is required.");
    }

    if (!isAllowedRole(role)) {
      throw new HttpsError(
        "invalid-argument",
        "Role must be one of user, admin, or superAdmin."
      );
    }

    await auth.setCustomUserClaims(uid, {
      role,
      admin: role === "admin" || role === "superAdmin",
      superAdmin: role === "superAdmin",
    });

    await db.collection("users").doc(uid).set(
      {
        uid,
        role,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true}
    );

    await db.collection("admin_logs").add({
      adminId: request.auth!.uid,
      action: "setUserRole",
      targetUserId: uid,
      reportId: null,
      before: null,
      after: {role},
      createdAt: FieldValue.serverTimestamp(),
    });

    return {
      uid,
      role,
    };
  }
);
