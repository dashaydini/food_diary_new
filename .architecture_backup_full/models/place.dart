import 'package:hive/hive.dart';

import 'place_visit.dart';

part 'place.g.dart';

@HiveType(typeId: 3)
class Place extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String location;

  @HiveField(2)
  List visits;

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

  Place({
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
    this.category = 'coffee_cart',
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
      'visits': visits.map((visit) => visit.toMap()).toList(),
    };
  }

  factory Place.fromMap(
    Map<String, dynamic> map, {
    String firebaseId = '',
  }) {
    return Place(
      name: map['name'] ?? '',
      location: map['location'] ?? '',
      imageBase64: map['imageBase64'] ?? '',
      favorite: map['favorite'] ?? false,
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      firebaseId: firebaseId,
      ownerName: map['ownerName'] ?? '',
      ownerId: map['ownerId'] ?? '',
      category: map['category'] ?? 'coffee_cart',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      visits: (map['visits'] as List<dynamic>? ?? [])
          .map((item) => PlaceVisit.fromMap(item))
          .toList(),
    );
  }
}
