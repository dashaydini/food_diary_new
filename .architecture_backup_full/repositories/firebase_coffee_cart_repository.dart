import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/coffee_cart.dart';

class FirebaseCoffeeCartRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('coffee_carts');

  Future<CoffeeCart?> addCoffeeCart(
    CoffeeCart cart,
  ) async {
    if (cart.firebaseId.isNotEmpty) {
      await updateCoffeeCart(cart);

      return cart;
    }

    final user = FirebaseAuth.instance.currentUser;

    final existing = await _collection
        .where(
          'name',
          isEqualTo: cart.name,
        )
        .where(
          'location',
          isEqualTo: cart.location,
        )
        .where(
          'ownerId',
          isEqualTo: user?.uid ?? 'anonymous',
        )
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;

      final existingCart = CoffeeCart.fromMap(
        doc.data(),
        firebaseId: doc.id,
      );

      return existingCart;
    }

    final data = cart.toMap();

    data['ownerId'] = user?.uid ?? 'anonymous';

    data['ownerName'] = user?.displayName ?? '';

    data['ownerEmail'] = user?.email ?? '';

    data['createdAt'] ??= DateTime.now().toIso8601String();

    final doc = await _collection.add(
      data,
    );

    cart.firebaseId = doc.id;

    if (cart.isInBox) {
      if (cart.isInBox) {
        await cart.save();
      }
    }

    return cart;
  }

  Future<void> updateCoffeeCart(
    CoffeeCart cart,
  ) async {
    if (cart.firebaseId.isEmpty) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    await _collection.doc(cart.firebaseId).set(
      {
        ...cart.toMap(),
        'ownerId':
            cart.ownerId.isNotEmpty ? cart.ownerId : user?.uid ?? 'anonymous',
        'ownerName': cart.ownerName.isNotEmpty
            ? cart.ownerName
            : user?.displayName ?? '',
        'ownerEmail': user?.email ?? '',
      },
      SetOptions(
        merge: true,
      ),
    );
  }

  Future<void> deleteCoffeeCart(
    CoffeeCart cart,
  ) async {
    if (cart.firebaseId.isEmpty) {
      return;
    }

    await _collection.doc(cart.firebaseId).delete();
  }

  Future<List<CoffeeCart>> getCoffeeCartsOnce() async {
    final snapshot = await _collection.get();

    return snapshot.docs
        .map(
          (doc) => CoffeeCart.fromMap(
            doc.data(),
            firebaseId: doc.id,
          ),
        )
        .toList();
  }

  Stream<List<CoffeeCart>> getCoffeeCarts() {
    return _collection.snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => CoffeeCart.fromMap(
                  doc.data(),
                  firebaseId: doc.id,
                ),
              )
              .toList(),
        );
  }

  Future<void> migrateCartMeta() async {
    // No migration needed.
    // createdAt is set when the cart is created.
  }
}
