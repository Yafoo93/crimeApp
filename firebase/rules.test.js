const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  serverTimestamp,
} = require("firebase/firestore");
const {ref, uploadString, getBytes} = require("firebase/storage");

const projectId = "crimeapp-40f21";

let testEnv;

function rootFile(filePath) {
  return path.join(__dirname, "..", filePath);
}

function reportData(id, reporterId) {
  return {
    id,
    reporterId,
    reporterDisplayName: "Emeka Okafor",
    anonymous: false,
    categoryId: "robbery",
    categoryLabel: "Robbery",
    urgency: "urgent",
    description: "Incident near the bank.",
    status: "submitted",
    syncStatus: "submitted",
    location: {
      latitude: 5.6037,
      longitude: -0.187,
      accuracyMeters: 15,
      ghanaPostGps: null,
      addressText: "Harbor Road",
    },
    media: {
      images: [],
      videos: [],
      voiceNotes: [],
    },
    spamFlagged: false,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    submittedAt: serverTimestamp(),
    assignedTo: null,
    adminNotesCount: 0,
  };
}

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(rootFile("firestore.rules"), "utf8"),
    },
    storage: {
      rules: fs.readFileSync(rootFile("firebase/storage.rules"), "utf8"),
    },
  });
});

test.after(async () => {
  await testEnv.cleanup();
});

test.afterEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.clearStorage();
});

test("unauthenticated users cannot read reports", async () => {
  const db = testEnv.unauthenticatedContext().firestore();

  await assertFails(getDoc(doc(db, "reports/report-1")));
});

test("citizens can create and read only their own reports", async () => {
  const aliceDb = testEnv.authenticatedContext("alice", {role: "user"})
    .firestore();
  const bobDb = testEnv.authenticatedContext("bob", {role: "user"})
    .firestore();

  const reportRef = doc(aliceDb, "reports/report-1");

  await assertSucceeds(setDoc(reportRef, reportData("report-1", "alice")));
  await assertSucceeds(getDoc(reportRef));
  await assertFails(getDoc(doc(bobDb, "reports/report-1")));
});

test("citizens cannot transfer report ownership", async () => {
  const aliceDb = testEnv.authenticatedContext("alice", {role: "user"})
    .firestore();

  const reportRef = doc(aliceDb, "reports/report-2");

  await assertSucceeds(setDoc(reportRef, reportData("report-2", "alice")));
  await assertFails(updateDoc(reportRef, {reporterId: "bob"}));
});

test("admins can read reports and update operational fields", async () => {
  const aliceDb = testEnv.authenticatedContext("alice", {role: "user"})
    .firestore();
  const adminDb = testEnv.authenticatedContext("admin-1", {role: "admin"})
    .firestore();

  await assertSucceeds(
    setDoc(doc(aliceDb, "reports/report-3"), reportData("report-3", "alice"))
  );

  const adminReportRef = doc(adminDb, "reports/report-3");

  await assertSucceeds(getDoc(adminReportRef));
  await assertSucceeds(
    updateDoc(adminReportRef, {
      status: "underReview",
      updatedAt: serverTimestamp(),
    })
  );
});

test("normal users cannot read all reports like admins", async () => {
  const aliceDb = testEnv.authenticatedContext("alice", {role: "user"})
    .firestore();
  const bobDb = testEnv.authenticatedContext("bob", {role: "user"})
    .firestore();

  await assertSucceeds(
    setDoc(doc(aliceDb, "reports/report-normal-denial"), reportData(
      "report-normal-denial",
      "alice"
    ))
  );

  await assertFails(getDoc(doc(bobDb, "reports/report-normal-denial")));
});

test("normal users cannot create admin logs or admin notes", async () => {
  const userDb = testEnv.authenticatedContext("alice", {role: "user"})
    .firestore();

  await assertFails(setDoc(doc(userDb, "admin_logs/log-denied"), {
    adminId: "alice",
    action: "updateReportStatus",
    targetUserId: null,
    reportId: "report-1",
    before: null,
    after: {status: "resolved"},
    createdAt: serverTimestamp(),
  }));

  await assertFails(setDoc(doc(userDb, "admin_notes/note-denied"), {
    reportId: "report-1",
    adminId: "alice",
    note: "Should not write.",
    createdAt: serverTimestamp(),
  }));
});

test("only admins can create audit logs", async () => {
  const userDb = testEnv.authenticatedContext("alice", {role: "user"})
    .firestore();
  const adminDb = testEnv.authenticatedContext("admin-1", {role: "admin"})
    .firestore();

  const logData = {
    adminId: "admin-1",
    action: "setUserRole",
    targetUserId: "alice",
    reportId: null,
    before: null,
    after: {role: "user"},
    createdAt: serverTimestamp(),
  };

  await assertFails(setDoc(doc(userDb, "admin_logs/log-1"), logData));
  await assertSucceeds(setDoc(doc(adminDb, "admin_logs/log-1"), logData));
});

test("only admins can read admin notes", async () => {
  const userDb = testEnv.authenticatedContext("alice", {role: "user"})
    .firestore();
  const adminDb = testEnv.authenticatedContext("admin-1", {role: "admin"})
    .firestore();

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), "admin_notes/note-1"), {
      reportId: "report-1",
      adminId: "admin-1",
      note: "Reviewed evidence.",
      createdAt: serverTimestamp(),
    });
  });

  await assertFails(getDoc(doc(userDb, "admin_notes/note-1")));
  await assertSucceeds(getDoc(doc(adminDb, "admin_notes/note-1")));
});

test("evidence files are private to owners and readable by admins", async () => {
  const aliceStorage = testEnv.authenticatedContext("alice", {role: "user"})
    .storage();
  const bobStorage = testEnv.authenticatedContext("bob", {role: "user"})
    .storage();
  const adminStorage = testEnv.authenticatedContext("admin-1", {role: "admin"})
    .storage();

  const filePath = "evidence/alice/report-1/photo.jpg";

  await assertSucceeds(
    uploadString(ref(aliceStorage, filePath), "image-bytes", "raw", {
      contentType: "image/jpeg",
    })
  );
  await assertFails(getBytes(ref(bobStorage, filePath)));
  await assertSucceeds(getBytes(ref(adminStorage, filePath)));
});
