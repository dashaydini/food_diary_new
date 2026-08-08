import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'user_service.dart';


class AuthService {


  final FirebaseAuth _auth =
      FirebaseAuth.instance;


  final UserService _userService =
      UserService();



  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();



  User? get currentUser =>
      _auth.currentUser;




  Future<UserCredential?> signInWithEmail(
      String email,
      String password,
      ) async {

    final result =
        await _auth.signInWithEmailAndPassword(
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

    final result =
        await _auth.createUserWithEmailAndPassword(
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


      UserCredential? result;



      if (kIsWeb) {


        final provider =
            GoogleAuthProvider();


        result =
            await _auth.signInWithPopup(
              provider,
            );


      } else {


        final GoogleSignIn googleSignIn =
            GoogleSignIn.instance;


        await googleSignIn.initialize();



        final account =
            await googleSignIn.authenticate();



        final authentication =
            account.authentication;



        final credential =
            GoogleAuthProvider.credential(
              idToken: authentication.idToken,
            );



        result =
            await _auth.signInWithCredential(
              credential,
            );

      }



      if (result.user != null) {

        await _userService.createOrUpdateUser(
          result.user!,
        );

      }



      return result;


    } catch (e) {


      debugPrint(
        "GOOGLE LOGIN ERROR: $e",
      );


      return null;

    }


  }






  Future<UserCredential?> signInAnonymously() async {


    final result =
        await _auth.signInAnonymously();



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