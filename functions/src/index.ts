/* eslint-disable require-jsdoc */
import {initializeApp} from "firebase-admin/app";
import {
  FieldValue,
  Timestamp,
  getFirestore,
} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";
import {getStorage} from "firebase-admin/storage";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {
  onDocumentCreated,
  onDocumentUpdated,
} from "firebase-functions/v2/firestore";
import {onCall, onRequest, HttpsError} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";

initializeApp();

const db = getFirestore();
const auth = getAuth();
const storage = getStorage();
const region = "europe-west1";

const allowedRoles = ["user", "admin", "superAdmin"] as const;
const reportStatuses = [
  "pendingUpload",
  "uploading",
  "submitted",
  "failed",
  "investigating",
  "resolved",
  "closed",
] as const;
const mediaTypes = ["image", "video", "voice"] as const;
const maxReportsPerHour = 8;
const maxEvidenceBytes = 25 * 1024 * 1024;
const orphanGraceMs = 24 * 60 * 60 * 1000;

type UserRole = (typeof allowedRoles)[number];
type ReportStatus = (typeof reportStatuses)[number];
type MediaType = (typeof mediaTypes)[number];

type CallableRequest = {
  auth?: {uid: string; token: Record<string, unknown>};
  data?: Record<string, unknown>;
};

type AdminReportUpdate = {
  status?: ReportStatus;
  assignedTo?: string | null;
  spamFlagged?: boolean;
  adminNote?: string;
};

function isAllowedRole(role: unknown): role is UserRole {
  return typeof role === "string" && allowedRoles.includes(role as UserRole);
}

function isReportStatus(status: unknown): status is ReportStatus {
  return typeof status === "string" &&
    reportStatuses.includes(status as ReportStatus);
}

function isMediaType(type: unknown): type is MediaType {
  return typeof type === "string" && mediaTypes.includes(type as MediaType);
}

function isAdminClaim(token: Record<string, unknown>) {
  return token.role === "admin" || token.role === "superAdmin";
}

function assertSignedIn(request: CallableRequest) {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in is required.");
  }

  return request.auth;
}

function assertAdmin(request: CallableRequest) {
  const authContext = assertSignedIn(request);
  if (!isAdminClaim(authContext.token)) {
    throw new HttpsError("permission-denied", "Admin access is required.");
  }

  return authContext;
}

function assertSuperAdmin(request: CallableRequest) {
  const authContext = assertSignedIn(request);
  if (authContext.token.role !== "superAdmin") {
    throw new HttpsError(
      "permission-denied",
      "Only super admins can assign roles."
    );
  }

  return authContext;
}

function requiredString(
  value: unknown,
  field: string,
  maxLength = 5000
): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }

  const trimmed = value.trim();
  if (trimmed.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${field} must be ${maxLength} characters or less.`
    );
  }

  return trimmed;
}

function optionalString(value: unknown, field: string, maxLength = 2000) {
  if (value === undefined || value === null) {
    return undefined;
  }

  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} must be text.`);
  }

  const trimmed = value.trim();
  if (trimmed.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${field} must be ${maxLength} characters or less.`
    );
  }

  return trimmed;
}

function toAuditSnapshot(data: FirebaseFirestore.DocumentData | undefined) {
  if (!data) {
    return null;
  }

  return {
    status: data.status ?? null,
    assignedTo: data.assignedTo ?? null,
    spamFlagged: data.spamFlagged ?? null,
    adminNotesCount: data.adminNotesCount ?? null,
  };
}

function currentHourKey(date = new Date()) {
  const iso = date.toISOString();
  return iso.slice(0, 13).replace(/[-T:]/g, "");
}

function isAllowedEvidenceType(contentType: string) {
  return contentType.startsWith("image/") ||
    contentType.startsWith("video/") ||
    contentType.startsWith("audio/");
}

function validateReportPayload(
  reportId: string,
  data: FirebaseFirestore.DocumentData
) {
  const errors: string[] = [];

  if (data.id !== reportId) errors.push("id must match document id");
  if (typeof data.reporterId !== "string") {
    errors.push("reporterId is required");
  }
  if (typeof data.anonymous !== "boolean") {
    errors.push("anonymous must be boolean");
  }
  if (typeof data.categoryId !== "string") {
    errors.push("categoryId is required");
  }
  if (typeof data.categoryLabel !== "string") {
    errors.push("categoryLabel is required");
  }
  if (!["normal", "urgent", "critical"].includes(data.urgency)) {
    errors.push("urgency is invalid");
  }
  if (typeof data.description !== "string" ||
    data.description.trim().length < 5) {
    errors.push("description must be at least 5 characters");
  }
  if (!isReportStatus(data.status)) {
    errors.push("status is invalid");
  }
  if (!Array.isArray(data.media)) {
    errors.push("media must be an array");
  }
  if (data.spamFlagged !== false) {
    errors.push("spamFlagged must start false");
  }

  const location = data.location;
  if (typeof location !== "object" || location === null) {
    errors.push("location is required");
  } else {
    const hasGps = typeof location.latitude === "number" &&
      typeof location.longitude === "number";
    const hasGhanaPostGps = typeof location.ghanaPostGps === "string" &&
      location.ghanaPostGps.trim().length > 0;
    if (!hasGps && !hasGhanaPostGps) {
      errors.push("GPS coordinates or GhanaPostGPS is required");
    }
  }

  return errors;
}

function validateMediaPayload(data: FirebaseFirestore.DocumentData) {
  const errors: string[] = [];

  if (typeof data.ownerId !== "string") errors.push("ownerId is required");
  if (typeof data.reportId !== "string") errors.push("reportId is required");
  if (!isMediaType(data.type)) errors.push("type is invalid");
  if (typeof data.storagePath !== "string") {
    errors.push("storagePath is required");
  }
  if (typeof data.contentType !== "string" ||
    !isAllowedEvidenceType(data.contentType)) {
    errors.push("contentType is invalid");
  }
  if (typeof data.sizeBytes !== "number" ||
    data.sizeBytes <= 0 ||
    data.sizeBytes > maxEvidenceBytes) {
    errors.push("sizeBytes is invalid");
  }

  return errors;
}

async function writeAdminLog(input: {
  adminId: string;
  action: string;
  targetUserId?: string | null;
  reportId?: string | null;
  before?: Record<string, unknown> | null;
  after?: Record<string, unknown> | null;
}) {
  await db.collection("admin_logs").add({
    adminId: input.adminId,
    action: input.action,
    targetUserId: input.targetUserId ?? null,
    reportId: input.reportId ?? null,
    before: input.before ?? null,
    after: input.after ?? null,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function checkReportRateLimit(
  reporterId: string,
  reportId: string
) {
  const hourKey = currentHourKey();
  const limitRef = db.collection("rate_limits")
    .doc(`reportCreate_${reporterId}_${hourKey}`);
  const result = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(limitRef);
    const count = (snapshot.data()?.count as number | undefined) ?? 0;
    const nextCount = count + 1;
    transaction.set(
      limitRef,
      {
        id: limitRef.id,
        subjectId: reporterId,
        scope: "reportCreate",
        window: hourKey,
        count: nextCount,
        lastReportId: reportId,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: snapshot.exists ?
          snapshot.data()?.createdAt ?? FieldValue.serverTimestamp() :
          FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
    return nextCount;
  });

  return {
    count: result,
    limited: result > maxReportsPerHour,
    key: limitRef.id,
  };
}

export const healthCheck = onRequest(
  {region},
  (request, response) => {
    logger.info("crimeApp Firebase Functions is running.", {
      method: request.method,
    });
    response.send("crimeApp backend is running.");
  }
);

export const setUserRole = onCall(
  {region},
  async (request) => {
    const adminContext = assertSuperAdmin(request);
    const uid = requiredString(request.data?.uid, "uid", 128);
    const role = request.data?.role;

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

    await writeAdminLog({
      adminId: adminContext.uid,
      action: "setUserRole",
      targetUserId: uid,
      after: {role},
    });

    return {uid, role};
  }
);

export const bootstrapEmulatorSuperAdmin = onCall(
  {region},
  async (request) => {
    if (process.env.FUNCTIONS_EMULATOR !== "true") {
      throw new HttpsError(
        "permission-denied",
        "This bootstrap function only runs in the local emulator."
      );
    }

    const authContext = assertSignedIn(request);
    await auth.setCustomUserClaims(authContext.uid, {
      role: "superAdmin",
      admin: true,
      superAdmin: true,
    });

    await db.collection("users").doc(authContext.uid).set(
      {
        uid: authContext.uid,
        email: authContext.token.email ?? null,
        role: "superAdmin",
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true}
    );

    await writeAdminLog({
      adminId: authContext.uid,
      action: "bootstrapEmulatorSuperAdmin",
      targetUserId: authContext.uid,
      after: {role: "superAdmin"},
    });

    return {uid: authContext.uid, role: "superAdmin"};
  }
);

export const updateReportStatus = onCall(
  {region},
  async (request) => {
    const adminContext = assertAdmin(request);
    const reportId = requiredString(request.data?.reportId, "reportId", 128);
    const status = request.data?.status;

    if (!isReportStatus(status)) {
      throw new HttpsError("invalid-argument", "status is invalid.");
    }

    const assignedTo = request.data?.assignedTo === null ?
      null :
      optionalString(request.data?.assignedTo, "assignedTo", 128);
    const spamFlagged = request.data?.spamFlagged;
    const adminNote = optionalString(request.data?.adminNote, "adminNote");

    if (spamFlagged !== undefined && typeof spamFlagged !== "boolean") {
      throw new HttpsError(
        "invalid-argument",
        "spamFlagged must be boolean."
      );
    }

    const reportRef = db.collection("reports").doc(reportId);
    const reportSnapshot = await reportRef.get();
    if (!reportSnapshot.exists) {
      throw new HttpsError("not-found", "Report was not found.");
    }

    const before = toAuditSnapshot(reportSnapshot.data());
    const update: AdminReportUpdate & Record<string, unknown> = {
      status,
      updatedAt: FieldValue.serverTimestamp(),
      lastAdminUpdatedBy: adminContext.uid,
      lastAdminUpdatedAt: FieldValue.serverTimestamp(),
    };

    if (assignedTo !== undefined) update.assignedTo = assignedTo;
    if (spamFlagged !== undefined) update.spamFlagged = spamFlagged;
    if (adminNote && adminNote.length > 0) {
      update.adminNotesCount =
        FieldValue.increment(1) as unknown as number;
    }

    await reportRef.update(update);

    if (adminNote && adminNote.length > 0) {
      await db.collection("admin_notes").add({
        reportId,
        adminId: adminContext.uid,
        note: adminNote,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    await writeAdminLog({
      adminId: adminContext.uid,
      action: "updateReportStatus",
      reportId,
      before,
      after: {
        status,
        assignedTo: assignedTo ?? reportSnapshot.data()?.assignedTo ?? null,
        spamFlagged: spamFlagged ??
          reportSnapshot.data()?.spamFlagged ??
          null,
        adminNoteAdded: Boolean(adminNote),
      },
    });

    return {reportId, status};
  }
);

export const validateReportOnCreate = onDocumentCreated(
  {
    region,
    document: "reports/{reportId}",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const reportId = event.params.reportId;
    const data = snapshot.data();
    const errors = validateReportPayload(reportId, data);
    const reporterId = typeof data.reporterId === "string" ?
      data.reporterId :
      "unknown";
    const rateLimit = await checkReportRateLimit(reporterId, reportId);

    const validationStatus = errors.length === 0 && !rateLimit.limited ?
      "accepted" :
      "rejected";

    await snapshot.ref.set(
      {
        serverValidation: {
          status: validationStatus,
          errors,
          rateLimited: rateLimit.limited,
          rateLimitKey: rateLimit.key,
          checkedAt: FieldValue.serverTimestamp(),
        },
        spamFlagged: rateLimit.limited ? true : data.spamFlagged,
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true}
    );

    if (validationStatus === "rejected") {
      logger.warn("Report failed server validation.", {
        reportId,
        reporterId,
        errors,
        rateLimitCount: rateLimit.count,
      });
    }
  }
);

export const validateMediaMetadata = onDocumentCreated(
  {
    region,
    document: "report_media/{mediaId}",
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const errors = validateMediaPayload(data);
    const storagePath = data.storagePath as string | undefined;

    if (storagePath && errors.length === 0) {
      try {
        const [metadata] = await storage.bucket().file(storagePath)
          .getMetadata();
        const actualSize = Number(metadata.size ?? 0);
        const actualType = metadata.contentType ?? "";

        if (actualSize !== data.sizeBytes) {
          errors.push("sizeBytes does not match Storage metadata");
        }
        if (actualType !== data.contentType) {
          errors.push("contentType does not match Storage metadata");
        }
      } catch (error) {
        errors.push("Storage object was not found");
        logger.warn("Storage metadata lookup failed.", {
          mediaId: event.params.mediaId,
          storagePath,
          error,
        });
      }
    }

    await snapshot.ref.set(
      {
        serverValidation: {
          status: errors.length === 0 ? "accepted" : "rejected",
          errors,
          checkedAt: FieldValue.serverTimestamp(),
        },
        status: errors.length === 0 ? data.status : "rejected",
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
  }
);

export const auditReportOperationalChanges = onDocumentUpdated(
  {
    region,
    document: "reports/{reportId}",
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const beforeAudit = toAuditSnapshot(before);
    const afterAudit = toAuditSnapshot(after);
    if (JSON.stringify(beforeAudit) === JSON.stringify(afterAudit)) {
      return;
    }

    if (typeof after.lastAdminUpdatedBy === "string") {
      return;
    }

    const lastAdminUpdatedBy = typeof after.lastAdminUpdatedBy === "string" ?
      after.lastAdminUpdatedBy :
      "system";

    await writeAdminLog({
      adminId: lastAdminUpdatedBy,
      action: "reportOperationalFieldsChanged",
      reportId: event.params.reportId,
      before: beforeAudit,
      after: afterAudit,
    });
  }
);

export const cleanupOrphanedEvidence = onSchedule(
  {
    region,
    schedule: "every 24 hours",
    timeZone: "Africa/Accra",
  },
  async () => {
    const [files] = await storage.bucket().getFiles({prefix: "evidence/"});
    const cutoff = Date.now() - orphanGraceMs;
    let deleted = 0;
    let skipped = 0;

    for (const file of files) {
      const [, ownerId, reportId] = file.name.split("/");
      if (!ownerId || !reportId) {
        skipped++;
        continue;
      }

      const [metadata] = await file.getMetadata();
      const createdAt = metadata.timeCreated ?
        new Date(metadata.timeCreated).getTime() :
        Date.now();
      if (createdAt > cutoff) {
        skipped++;
        continue;
      }

      const reportSnapshot = await db.collection("reports").doc(reportId)
        .get();
      if (reportSnapshot.exists &&
        reportSnapshot.data()?.reporterId === ownerId) {
        skipped++;
        continue;
      }

      await file.delete({ignoreNotFound: true});
      deleted++;
    }

    await db.collection("system_jobs").add({
      job: "cleanupOrphanedEvidence",
      deleted,
      skipped,
      ranAt: Timestamp.now(),
    });

    logger.info("Orphaned evidence cleanup complete.", {deleted, skipped});
  }
);
