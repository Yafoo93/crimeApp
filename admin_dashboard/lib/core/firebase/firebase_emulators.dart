import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

Future<void> connectFirebaseEmulators() async {
  const useEmulators = bool.fromEnvironment('USE_FIREBASE_EMULATORS');

  if (!useEmulators) return;

  final host = kIsWeb || defaultTargetPlatform != TargetPlatform.android
      ? 'localhost'
      : '10.0.2.2';

  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseStorage.instance.useStorageEmulator(host, 9199);
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  FirebaseFunctions.instanceFor(region: 'europe-west1')
      .useFunctionsEmulator(host, 5001);
}
