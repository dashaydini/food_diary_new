import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';


class ProfileScreen extends StatelessWidget {

  ProfileScreen({
    super.key,
  });


  final AuthService authService =
      AuthService();



  @override
  Widget build(BuildContext context) {


    final user =
        FirebaseAuth.instance.currentUser;



    return Scaffold(

      appBar: AppBar(

        title: const Text(
          "פרופיל",
        ),

      ),


      body: Center(

        child: Column(

          mainAxisAlignment:
              MainAxisAlignment.center,


          children: [


            CircleAvatar(

              radius: 45,

              backgroundImage:
                  user?.photoURL != null
                      ? NetworkImage(
                          user!.photoURL!,
                        )
                      : null,


              child:
                  user?.photoURL == null
                      ? const Icon(
                          Icons.person,
                          size: 45,
                        )
                      : null,

            ),



            const SizedBox(
              height: 20,
            ),



            Text(

              user?.displayName ??
                  "משתמש",

              style:
                  const TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),

            ),



            const SizedBox(
              height: 8,
            ),



            Text(
              user?.email ?? "",
            ),



            const SizedBox(
              height: 40,
            ),




            FilledButton.icon(

              icon:
                  const Icon(
                    Icons.logout,
                  ),


              label:
                  const Text(
                    "התנתקות",
                  ),



              onPressed: () async {


                await authService.signOut();



              },


            ),



          ],

        ),

      ),

    );


  }

}