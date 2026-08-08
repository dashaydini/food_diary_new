// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';

import '../models/coffee_cart.dart';
import '../repositories/firebase_coffee_cart_repository.dart';


class FirebaseTestScreen extends StatelessWidget {

  const FirebaseTestScreen({
    super.key,
  });


  @override
  Widget build(BuildContext context) {

    final repository = FirebaseCoffeeCartRepository();


    return Scaffold(

      appBar: AppBar(
        title: const Text('Firebase Test'),
      ),


      body: Center(

        child: ElevatedButton(

          child: const Text(
            'Add Coffee Cart',
          ),


          onPressed: () async {


            final cart = CoffeeCart(

              name: 'עגלת הקפה הראשונה',

              location: 'באר שבע',

              visits: [],

            );


            await repository.addCoffeeCart(
              cart,
            );


            ScaffoldMessenger.of(context).showSnackBar(

              const SnackBar(

                content: Text(
                  'נשמר בהצלחה ב-Firebase',
                ),

              ),

            );


          },

        ),

      ),

    );

  }

}