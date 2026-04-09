import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseAuthDataSource {
  final FirebaseAuth _auth;
  final FirebaseDatabase _db;

  FirebaseAuthDataSource({FirebaseAuth? auth, FirebaseDatabase? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseDatabase.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> signUp(String email, String password, String displayName) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.updateDisplayName(displayName);
    // Initialize user profile in DB
    await _db.ref('users/${cred.user!.uid}').set({
      'displayName': displayName,
      'email': email,
      'vehicleNumber': '',
    });
    return cred;
  }

  Future<void> signOut() async => _auth.signOut();

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final snapshot = await _db.ref('users/$uid').get();
    if (!snapshot.exists || snapshot.value == null) return null;
    return Map<String, dynamic>.from(snapshot.value as Map);
  }

  Future<void> updateVehicleNumber(String uid, String vehicleNumber) async {
    await _db.ref('users/$uid/vehicleNumber').set(vehicleNumber);
  }
}
