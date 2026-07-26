import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/coffee_cart.dart';


class FirebaseCoffeeCartRepository {


  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;



  Future<void> addCoffeeCart(
    CoffeeCart cart,
  ) async {

    await _firestore
        .collection('coffee_carts')
        .add(
          cart.toMap(),
        );

  }





  Future<List<CoffeeCart>> getCoffeeCartsOnce() async {


    final snapshot =
        await _firestore
            .collection('coffee_carts')
            .get();



    return snapshot.docs
        .map(

          (doc) => CoffeeCart.fromMap(
            doc.data(),
          ),

        )
        .toList();


  }





  Stream<List<CoffeeCart>> getCoffeeCarts() {


    return _firestore
        .collection('coffee_carts')
        .snapshots()
        .map(

          (snapshot) => snapshot.docs
              .map(

                (doc) => CoffeeCart.fromMap(
                  doc.data(),
                ),

              )
              .toList(),

        );


  }


}