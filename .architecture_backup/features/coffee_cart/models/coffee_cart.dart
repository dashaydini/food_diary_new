import 'package:flutter/material.dart';

import 'package:hive/hive.dart';

import './coffee_visit.dart';

part './coffee_cart.g.dart';

@HiveType(typeId: 0)
class CoffeeCart extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String location;

  @HiveField(2)
  List<CoffeeVisit> visits;

  @HiveField(3)
  String imageBase64;

  @HiveField(4)
  bool favorite;

  @HiveField(5)
  double latitude;

  @HiveField(6)
  double longitude;

  @HiveField(7)
  String firebaseId;

  @HiveField(8)
  String ownerName;

  @HiveField(9)
  DateTime? createdAt;

  @HiveField(10)
  String ownerId;

  @HiveField(11)
  String category;

  CoffeeCart({
    required this.name,
    required this.location,
    required this.visits,
    this.imageBase64 = '',
    this.favorite = false,
    this.latitude = 0,
    this.longitude = 0,
    this.firebaseId = '',
    this.ownerName = '',
    this.createdAt,
    this.ownerId = '',
    this.category = 'עגלות קפה',
  });

  double get score {
    if (visits.isEmpty) {
      return 0;
    }

    double total = 0;

    for (final visit in visits) {
      total += visit.score;
    }

    return total / visits.length;
  }

  int get visitsCount {
    return visits.length;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'location': location,
      'imageBase64': imageBase64,
      'favorite': favorite,
      'latitude': latitude,
      'longitude': longitude,
      'firebaseId': firebaseId,
      'ownerName': ownerName,
      'createdAt': createdAt?.toIso8601String(),
      'ownerId': ownerId,
      'category': category,
      'visits': visits
          .map(
            (visit) => visit.toMap(),
          )
          .toList(),
    };
  }

  factory CoffeeCart.fromMap(
    Map<String, dynamic> map, {
    String firebaseId = '',
  }) {
    debugPrint(
      "FROM MAP: name=${map['name']} owner=${map['ownerName']} created=${map['createdAt']}",
    );

    return CoffeeCart(
      name: map['name'] ?? '',
      location: map['location'] ?? '',
      imageBase64: map['imageBase64'] ?? '',
      favorite: map['favorite'] ?? false,
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      firebaseId: firebaseId,
      ownerName: map['ownerName'] ?? '',
      ownerId: map['ownerId'] ?? '',
      category: map['category'] ?? 'עגלות קפה',
      createdAt: map['createdAt'] != null &&
              map['createdAt'].runtimeType.toString().contains('Timestamp')
          ? map['createdAt'].toDate()
          : map['createdAt'] != null
              ? DateTime.tryParse(
                  map['createdAt'].toString(),
                )
              : null,
      visits: (map['visits'] as List<dynamic>? ?? [])
          .map(
            (item) => CoffeeVisit.fromMap(item),
          )
          .toList(),
    );
  }
}
