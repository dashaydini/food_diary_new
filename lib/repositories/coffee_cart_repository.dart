import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/coffee_cart.dart';


class CoffeeCartRepository {


  static const String boxName =
      'coffee_carts';



  static Box<CoffeeCart> get box {

    return Hive.box<CoffeeCart>(boxName);

  }




  static Future<void> add(
      CoffeeCart cart,
      ) async {

    await box.add(cart);
    debugPrint("BOX LENGTH AFTER ADD: ${box.length}");
debugPrint("CARTS: ${box.values.map((e) => e.name).toList()}");

    debugPrint(
      "Added cart: ${cart.name}",
    );

    debugPrint(
      "Total carts: ${box.length}",
    );

  }




  static Future<void> update(
      CoffeeCart cart,
      ) async {

    await cart.save();

  }




  static Future<void> delete(
      CoffeeCart cart,
      ) async {

    await cart.delete();

  }




  static ValueListenable<Box<CoffeeCart>> listen() {

    return box.listenable();

  }




  static List<CoffeeCart> getAll() {

    debugPrint(
      "Loading carts: ${box.length}",
    );

    return box.values.toList();

  }


}