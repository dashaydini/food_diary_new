import 'package:flutter/foundation.dart';

import '../repositories/coffee_cart_repository.dart';
import '../repositories/firebase_coffee_cart_repository.dart';

class FirebaseSyncService {
  final FirebaseCoffeeCartRepository _firebaseRepository =
      FirebaseCoffeeCartRepository();

  Future<void> syncCoffeeCarts() async {
    try {
      debugPrint('Starting Firebase sync...');

      final firebaseCarts =
          await _firebaseRepository.getCoffeeCartsOnce();

      final localCarts =
          CoffeeCartRepository.getAll();

      for (final firebaseCart in firebaseCarts) {
        final exists = localCarts.any(
          (localCart) =>
              localCart.firebaseId.isNotEmpty &&
              localCart.firebaseId == firebaseCart.firebaseId,
        );

        if (!exists) {
          await CoffeeCartRepository.add(firebaseCart);

          debugPrint(
            'Synced: ${firebaseCart.name}',
          );
        }
      }

      
        debugPrint('Firebase sync completed');
    } catch (e) {
      debugPrint('Firebase sync error: $e');
    }
  }
}