// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';

import '../services/auth_service.dart';


class LoginScreen extends StatelessWidget {

  const LoginScreen({
    super.key,
  });



  @override
  Widget build(BuildContext context) {


    final authService = AuthService();



    return Scaffold(


      appBar: AppBar(

        title: const Text(
          "התחברות",
        ),

      ),



      body: Center(


        child: Padding(


          padding: const EdgeInsets.all(24),



          child: Column(


            mainAxisAlignment:
                MainAxisAlignment.center,



            children: [



              const Text(

                "Coffee Diary",

                style: TextStyle(

                  fontSize: 32,

                  fontWeight: FontWeight.bold,

                ),

              ),



              const SizedBox(

                height: 40,

              ),





              FilledButton.icon(


                icon: const Icon(
                  Icons.login,
                ),



                label: const Text(
                  "כניסה עם Google",
                ),



                onPressed: () async {


                  try {


                    final result =
                        await authService.signInWithGoogle();



                    if(result == null){


                      ScaffoldMessenger.of(context)
                          .showSnackBar(

                        const SnackBar(

                          content:

                          Text(

                            "ההתחברות בוטלה",

                          ),

                        ),

                      );


                    }



                  } catch(e) {



                    debugPrint(

                      "GOOGLE LOGIN ERROR: $e",

                    );



                    ScaffoldMessenger.of(context)
                        .showSnackBar(


                      SnackBar(

                        content:

                        Text(

                          "שגיאת Google: $e",

                        ),

                      ),


                    );



                  }



                },


              ),





              const SizedBox(

                height: 15,

              ),





              OutlinedButton.icon(


                icon: const Icon(
                  Icons.email,
                ),



                label: const Text(
                  "כניסה עם מייל",
                ),



                onPressed: () {


                  ScaffoldMessenger.of(context)
                      .showSnackBar(

                    const SnackBar(

                      content:

                      Text(

                        "כניסה במייל תתווסף בשלב הבא",

                      ),

                    ),

                  );


                },


              ),





              const SizedBox(

                height: 15,

              ),





              TextButton(


                onPressed: () async {

                    final result =
                        await authService.signInAnonymously();

                    if (result == null) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                            const SnackBar(
                              content:
                                  Text("כניסת אורח נכשלה"),
                            ),
                          );
                    }

                  },


                child: const Text(

                  "כניסה כאורח",

                ),


              ),





            ],


          ),


        ),


      ),


    );


  }


}
