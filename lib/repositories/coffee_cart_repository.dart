import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/coffee_cart.dart';
import 'firebase_coffee_cart_repository.dart';


class CoffeeCartRepository {


  static const String boxName =
      'coffee_carts';



  static final FirebaseCoffeeCartRepository
      _firebaseRepository =
      FirebaseCoffeeCartRepository();





  static Box<CoffeeCart> get box {

    return Hive.box<CoffeeCart>(
      boxName,
    );

  }







  static Future<CoffeeCart?> add(
      CoffeeCart cart,
      ) async {


    // שמירה מקומית זמנית
    await box.add(cart);



    // שמירה / בדיקה מול Firebase
    final result =
        await _firebaseRepository
            .addCoffeeCart(cart);




    // נמצאה עגלה קיימת
    if(result != null &&
        result.firebaseId != cart.firebaseId){


      await cart.delete();



      return result;


    }




    debugPrint(
      "BOX LENGTH AFTER ADD: ${box.length}",
    );


    debugPrint(
      "CARTS: ${box.values.map((e) => e.name).toList()}",
    );


    debugPrint(
      "Added cart: ${cart.name}",
    );



    return cart;


  }







  static Future<void> update(
      CoffeeCart cart,
      ) async {


    if (cart.isInBox) {
      if (cart.isInBox) {
      await cart.save();
    }
    }


    await _firebaseRepository
        .updateCoffeeCart(cart);


  }







  static Future<void> delete(
      CoffeeCart cart,
      ) async {


    await _firebaseRepository
        .deleteCoffeeCart(cart);



    await cart.delete();


  }







  static ValueListenable<Box<CoffeeCart>> listen(){


    return box.listenable();


  }







  static List<CoffeeCart> getAll(){


    debugPrint(
      "Loading carts: ${box.length}",
    );


    return box.values.toList();


  }


}