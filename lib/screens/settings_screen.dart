import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';


class SettingsScreen extends StatelessWidget {


  const SettingsScreen({
    super.key,
  });



  @override
  Widget build(BuildContext context) {


    final user =
        FirebaseAuth.instance.currentUser;


    final authService =
        AuthService();



    return Scaffold(


      appBar:

          AppBar(

        title:

            const Text(

              "הגדרות",

            ),

      ),




      body:


          ListView(

        padding:

            const EdgeInsets.all(20),



        children: [




          Card(


            child:

                Padding(

              padding:

                  const EdgeInsets.all(16),



              child:

                  Column(

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

                    height: 15,

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



                ],

              ),

            ),


          ),





          const SizedBox(

            height: 20,

          ),






          Card(


            child:

                ListTile(

              leading:

                  const Icon(

                    Icons.info_outline,

                  ),



              title:

                  const Text(

                    "Coffee Diary V2",

                  ),



              subtitle:

                  const Text(

                    "יומן עגלות קפה",

                  ),


            ),


          ),





          const SizedBox(

            height: 20,

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


    );


  }


}