import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/place.dart';

class FirebasePlaceRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('places');

  Future<Place?> addPlace(Place place) async {
    final user = FirebaseAuth.instance.currentUser;

    if (place.firebaseId.isNotEmpty) {
      await updatePlace(place);
      return place;
    }

    final ownerId = user?.uid ?? 'anonymous';

    final existing = await _collection
        .where('name', isEqualTo: place.name)
        .where('location', isEqualTo: place.location)
        .where('category', isEqualTo: place.category)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final doc = existing.docs.first;

      return Place.fromMap(
        doc.data(),
        firebaseId: doc.id,
      );
    }

    final data = place.toMap();

    data['ownerId'] = ownerId;
    data['ownerName'] =
        place.ownerName.isNotEmpty ? place.ownerName : user?.displayName ?? '';
    data['ownerEmail'] = user?.email ?? '';
    data['category'] = place.category;
    data['createdAt'] ??= DateTime.now().toIso8601String();

    final doc = await _collection.add(data);

    place.firebaseId = doc.id;

    return place;
  }

  Future<void> updatePlace(Place place) async {
    if (place.firebaseId.isEmpty) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    await _collection.doc(place.firebaseId).set(
      {
        ...place.toMap(),
        'ownerId':
            place.ownerId.isNotEmpty ? place.ownerId : user?.uid ?? 'anonymous',
        'ownerName': place.ownerName.isNotEmpty
            ? place.ownerName
            : user?.displayName ?? '',
        'ownerEmail': user?.email ?? '',
        'category': place.category,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deletePlace(Place place) async {
    if (place.firebaseId.isEmpty) {
      return;
    }

    await _collection.doc(place.firebaseId).delete();
  }

  Future<List<Place>> getPlacesOnce({
    String? category,
  }) async {
    Query<Map<String, dynamic>> query = _collection;

    if (category != null && category.isNotEmpty) {
      query = query.where(
        'category',
        isEqualTo: category,
      );
    }

    final snapshot = await query.get();

    return snapshot.docs
        .map(
          (doc) => Place.fromMap(
            doc.data(),
            firebaseId: doc.id,
          ),
        )
        .toList();
  }

  Stream<List<Place>> getPlaces({
    String? category,
  }) {
    Query<Map<String, dynamic>> query = _collection;

    if (category != null && category.isNotEmpty) {
      query = query.where(
        'category',
        isEqualTo: category,
      );
    }

    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => Place.fromMap(
                  doc.data(),
                  firebaseId: doc.id,
                ),
              )
              .toList(),
        );
  }
}
