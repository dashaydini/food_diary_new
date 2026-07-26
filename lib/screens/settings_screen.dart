import 'package:flutter/material.dart';


class SettingsScreen extends StatelessWidget {

  const SettingsScreen({
    super.key,
  });



  @override
  Widget build(BuildContext context) {

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


        children: const [

          Card(

            child:
                ListTile(

              leading:
                  Icon(
                    Icons.info_outline,
                  ),

              title:
                  Text(
                    "Coffee Diary V2",
                  ),

              subtitle:
                  Text(
                    "יומן עגלות קפה",
                  ),

            ),

          ),


        ],

      ),

    );

  }

}