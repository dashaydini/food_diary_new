import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MigrateCoffeeCarts {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> run() async {
    final source =
        await _firestore.collection('coffee_carts').get();

    debugPrint(
      'MIGRATION: found ${source.docs.length} coffee carts',
    );

    if (source.docs.isEmpty) {
      debugPrint('MIGRATION: nothing to migrate');
      return;
    }

    WriteBatch batch = _firestore.batch();
    int batchCount = 0;
    int migrated = 0;

    for (final doc in source.docs) {
      final data = Map<String, dynamic>.from(doc.data());

      final rawVisits = data['visits'];

      final visits = <Map<String, dynamic>>[];

      if (rawVisits is List) {
        for (final rawVisit in rawVisits) {
          if (rawVisit is! Map) {
            continue;
          }

          final visit =
              Map<String, dynamic>.from(rawVisit);

          visits.add({
            'itemName': visit['dish'] ?? '',
            'notes': visit['notes'] ?? '',
            'atmosphere': visit['atmosphere'] ?? 0,
            'cleanliness': visit['cleanliness'] ?? 0,
            'service': visit['service'] ?? 0,
            'quality': visit['foodQuality'] ?? 0,
            'variety': visit['variety'] ?? 0,
            'value': visit['value'] ?? 0,
            'imageBase64': visit['imageBase64'] ?? '',
            'tags': visit['tags'] ?? [],
            'date': visit['date'],
            'userId': visit['userId'] ?? '',
            'userName': visit['userName'] ?? '',
            'userEmail': visit['userEmail'] ?? '',
            'createdAt': visit['createdAt'],
            'prices': visit['prices'] ?? [],
            'priceRating': visit['priceRating'] ?? 0,
          });
        }
      }

      final destination =
          _firestore.collection('places').doc(doc.id);

      final migratedData = <String, dynamic>{
        'name': data['name'] ?? '',
        'location': data['location'] ?? '',
        'imageBase64': data['imageBase64'] ?? '',
        'favorite': data['favorite'] ?? false,
        'latitude': data['latitude'] ?? 0,
        'longitude': data['longitude'] ?? 0,
        'firebaseId': doc.id,
        'ownerName': data['ownerName'] ?? '',
        'ownerEmail': data['ownerEmail'] ?? '',
        'ownerId': data['ownerId'] ?? '',
        'createdAt': data['createdAt'],
        'category': 'coffee_cart',
        'visits': visits,
      };

      batch.set(
        destination,
        migratedData,
        SetOptions(merge: true),
      );

      batchCount++;
      migrated++;

      if (batchCount == 450) {
        await batch.commit();

        debugPrint(
          'MIGRATION: committed $migrated/${source.docs.length}',
        );

        batch = _firestore.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      await batch.commit();
    }

    debugPrint(
      'MIGRATION COMPLETE: $migrated carts copied to places',
    );
  }
}
