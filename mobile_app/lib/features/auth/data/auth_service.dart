import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> registerWithEmail({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final user = credential.user;
    if (user == null) return;

    await user.updateDisplayName(fullName.trim());
    await _createUserProfile(
      uid: user.uid,
      displayName: fullName.trim(),
      email: email.trim(),
      phoneNumber: phoneNumber.trim(),
      isAnonymous: false,
    );
  }

  Future<void> continueProtectedReport() async {
    final credential = await _auth.signInAnonymously();
    final user = credential.user;
    if (user == null) return;

    await _createUserProfile(
      uid: user.uid,
      displayName: 'Protected Reporter',
      email: null,
      phoneNumber: null,
      isAnonymous: true,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> _createUserProfile({
    required String uid,
    required String displayName,
    required String? email,
    required String? phoneNumber,
    required bool isAnonymous,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': 'user',
      'status': 'active',
      'verifiedReporter': false,
      'anonymous': isAnonymous,
      'reportCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
