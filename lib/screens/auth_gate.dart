import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import 'main_navigation_screen.dart';
import 'login_screen.dart';



class AuthGate extends StatelessWidget {


  AuthGate({
    super.key,
  });



  final AuthService authService =
      AuthService();




  @override
  Widget build(BuildContext context) {


    return StreamBuilder<User?>(


      stream:
          authService.authStateChanges,



      builder:(context, snapshot){



        if(snapshot.connectionState ==
            ConnectionState.waiting){


          return const Scaffold(

            body:
            Center(

              child:
              CircularProgressIndicator(),

            ),

          );

        }




        if(snapshot.hasData){


          return const MainNavigationScreen();


        }




        return const LoginScreen();



      },

    );


  }


}