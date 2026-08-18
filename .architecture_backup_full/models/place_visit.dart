import 'package:hive/hive.dart';

part 'place_visit.g.dart';

@HiveType(typeId: 4)
class PlaceVisit extends HiveObject {
  @HiveField(0)
  String itemName;

  @HiveField(1)
  String notes;

  @HiveField(2)
  double atmosphere;

  @HiveField(3)
  double cleanliness;

  @HiveField(4)
  double service;

  @HiveField(5)
  double quality;

  @HiveField(6)
  double variety;

  @HiveField(7)
  double value;

  @HiveField(8)
  String imageBase64;

  @HiveField(9)
  List tags;

  @HiveField(10)
  DateTime date;

  @HiveField(11)
  String userId;

  @HiveField(12)
  String userName;

  @HiveField(13)
  String userEmail;

  @HiveField(14)
  DateTime createdAt;

  @HiveField(15)
  List prices;

  @HiveField(16)
  int priceRating;

  PlaceVisit({
    required this.itemName,
    required this.notes,
    required this.atmosphere,
    required this.cleanliness,
    required this.service,
    required this.quality,
    required this.variety,
    required this.value,
    required this.imageBase64,
    required this.tags,
    required this.date,
    this.userId = '',
    this.userName = '',
    this.userEmail = '',
    DateTime? createdAt,
    this.prices = const [],
    this.priceRating = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  double get score {
    return (atmosphere + cleanliness + service + quality + variety + value) / 6;
  }

  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'notes': notes,
      'atmosphere': atmosphere,
      'cleanliness': cleanliness,
      'service': service,
      'quality': quality,
      'variety': variety,
      'value': value,
      'imageBase64': imageBase64,
      'tags': tags,
      'date': date.toIso8601String(),
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'createdAt': createdAt.toIso8601String(),
      'prices': prices,
      'priceRating': priceRating,
    };
  }

  factory PlaceVisit.fromMap(
    Map<String, dynamic> map,
  ) {
    return PlaceVisit(
      itemName: map['itemName'] ?? '',
      notes: map['notes'] ?? '',
      atmosphere: (map['atmosphere'] ?? 0).toDouble(),
      cleanliness: (map['cleanliness'] ?? 0).toDouble(),
      service: (map['service'] ?? 0).toDouble(),
      quality: (map['quality'] ?? 0).toDouble(),
      variety: (map['variety'] ?? 0).toDouble(),
      value: (map['value'] ?? 0).toDouble(),
      imageBase64: map['imageBase64'] ?? '',
      tags: List.from(map['tags'] ?? []),
      date: DateTime.tryParse(
            map['date']?.toString() ?? '',
          ) ??
          DateTime.now(),
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      createdAt: DateTime.tryParse(
            map['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
      prices: map['prices'] is List ? List.from(map['prices']) : [],
      priceRating:
          map['priceRating'] is num ? (map['priceRating'] as num).toInt() : 0,
    );
  }
}
