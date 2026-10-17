import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider phải được override trong bootstrap.dart',
  );
});

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final firebaseStorageProvider = Provider<FirebaseStorage?>((ref) {
  try {
    return FirebaseStorage.instance;
  } catch (_) {
    return null;
  }
});

final cloudFunctionsProvider = Provider<FirebaseFunctions?>((ref) {
  try {
    return FirebaseFunctions.instanceFor(region: 'asia-southeast1');
  } catch (_) {
    return null;
  }
});

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    scopes: <String>['email', 'profile'],
    serverClientId:
        '383448578264-g0u1cu53r4dg8tp8pp7oi9tm3ml8cm8r.apps.googleusercontent.com',
  );
});
