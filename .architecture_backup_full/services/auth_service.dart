import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'user_service.dart';

String _generateNonce([int length = 32]) {
  const chars =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';

  final random = Random.secure();

  return List.generate(
    length,
    (_) => chars[random.nextInt(chars.length)],
  ).join();
}

String _sha256ofString(String input) {
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);

  return digest.toString();
}

class AuthService {
  Future<UserCredential?> signInWithApple() async {
    try {
      debugPrint("APPLE: START");

      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      if (credential.identityToken == null) {
        debugPrint("APPLE: NO ID TOKEN");
        return null;
      }

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: credential.identityToken,
        rawNonce: rawNonce,
      );

      final result = await _auth.signInWithCredential(
        oauthCredential,
      );

      if (result.user != null) {
        await _userService.createOrUpdateUser(
          result.user!,
        );
      }

      debugPrint("APPLE: COMPLETE");

      return result;
    } catch (e, stack) {
      debugPrint("APPLE LOGIN ERROR: $e");
      debugPrint(stack.toString());

      return null;
    }
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final UserService _userService = UserService();

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithEmail(
    String email,
    String password,
  ) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (result.user != null) {
      await _userService.createOrUpdateUser(
        result.user!,
      );
    }

    return result;
  }

  Future<UserCredential?> registerWithEmail(
    String email,
    String password,
  ) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    if (result.user != null) {
      await _userService.createOrUpdateUser(
        result.user!,
      );
    }

    return result;
  }

  Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint("GOOGLE: START");

      UserCredential? result;

      if (kIsWeb) {
        debugPrint("GOOGLE: WEB LOGIN");

        final provider = GoogleAuthProvider();

        result = await _auth.signInWithPopup(
          provider,
        );
      } else {
        debugPrint("GOOGLE: ANDROID/iOS LOGIN");

        final GoogleSignIn googleSignIn = GoogleSignIn(
          serverClientId:
              '188806948323-uabt3bsesl0l7l3j1ci8b1fkrlp0i3bu.apps.googleusercontent.com',
        );

        debugPrint("GOOGLE: SIGN IN");

        final GoogleSignInAccount? account = await googleSignIn.signIn();

        if (account == null) {
          debugPrint("GOOGLE: USER CANCELLED");
          return null;
        }

        debugPrint("GOOGLE: ACCOUNT RECEIVED");

        final GoogleSignInAuthentication authentication =
            await account.authentication;

        debugPrint(
          "GOOGLE: ID TOKEN = ${authentication.idToken != null}",
        );

        final credential = GoogleAuthProvider.credential(
          idToken: authentication.idToken,
        );

        debugPrint("GOOGLE: FIREBASE SIGN IN");

        result = await _auth.signInWithCredential(
          credential,
        );

        debugPrint(
          "GOOGLE: FIREBASE USER = ${result.user?.uid}",
        );
      }

      if (result.user != null) {
        debugPrint("GOOGLE: CREATE/UPDATE USER START");

        await _userService.createOrUpdateUser(
          result.user!,
        );

        debugPrint("GOOGLE: CREATE/UPDATE USER DONE");
      }

      debugPrint("GOOGLE: COMPLETE");

      return result;
    } catch (e, stack) {
      debugPrint(
        "GOOGLE LOGIN ERROR: $e",
      );

      debugPrint(
        stack.toString(),
      );

      return null;
    }
  }

  Future<UserCredential?> signInAnonymously() async {
    final result = await _auth.signInAnonymously();

    if (result.user != null) {
      await _userService.createOrUpdateUser(
        result.user!,
      );
    }

    return result;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
