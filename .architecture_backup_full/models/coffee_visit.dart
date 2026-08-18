import 'package:hive/hive.dart';

part 'coffee_visit.g.dart';

@HiveType(typeId: 2)
class CoffeeVisit extends HiveObject {
  @HiveField(0)
  String dish;

  @HiveField(1)
  String notes;

  @HiveField(2)
  double atmosphere;

  @HiveField(3)
  double cleanliness;

  @HiveField(4)
  double service;

  @HiveField(5)
  double foodQuality;

  @HiveField(6)
  double variety;

  @HiveField(7)
  double value;

  @HiveField(8)
  String imageBase64;

  @HiveField(9)
  List<String> tags;

  @HiveField(10)
  DateTime date;

  // חדש - מי הוסיף את הביקור

  @HiveField(11)
  String userId;

  @HiveField(12)
  String userName;

  @HiveField(13)
  String userEmail;

  @HiveField(14)
  DateTime createdAt;

  @HiveField(15, defaultValue: <double>[])
  List<double> prices;

  // דירוג מחיר לפי דעת המשתמש:
  // 0 = לא דורג
  // 1 = ₪
  // 2 = ₪₪
  // 3 = ₪₪₪
  @HiveField(16, defaultValue: 0)
  int priceRating;

  CoffeeVisit({
    required this.dish,
    required this.notes,
    required this.atmosphere,
    required this.cleanliness,
    required this.service,
    required this.foodQuality,
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
    return (atmosphere +
            cleanliness +
            service +
            foodQuality +
            variety +
            value) /
        6;
  }

  Map<String, dynamic> toMap() {
    return {
      'dish': dish,
      'notes': notes,
      'atmosphere': atmosphere,
      'cleanliness': cleanliness,
      'service': service,
      'foodQuality': foodQuality,
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

  factory CoffeeVisit.fromMap(
    Map<String, dynamic> map,
  ) {
    return CoffeeVisit(
      dish: map['dish'] ?? '',
      notes: map['notes'] ?? '',
      atmosphere: (map['atmosphere'] ?? 0).toDouble(),
      cleanliness: (map['cleanliness'] ?? 0).toDouble(),
      service: (map['service'] ?? 0).toDouble(),
      foodQuality: (map['foodQuality'] ?? 0).toDouble(),
      variety: (map['variety'] ?? 0).toDouble(),
      value: (map['value'] ?? 0).toDouble(),
      imageBase64: map['imageBase64'] ?? '',
      tags: List<String>.from(
        map['tags'] ?? [],
      ),
      date: DateTime.parse(
        map['date'] ?? DateTime.now().toIso8601String(),
      ),
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      userEmail: map['userEmail'] ?? '',
      createdAt: DateTime.parse(
        map['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      prices: (() {
        final rawPrices = map['prices'];

        if (rawPrices is! List) {
          return <double>[];
        }

        final result = <double>[];

        for (final item in rawPrices) {
          if (item is num) {
            result.add(item.toDouble());
          } else {
            result.add(double.tryParse(item.toString()) ?? 0);
          }
        }

        return result;
      })(),
      priceRating:
          (map['priceRating'] is num) ? (map['priceRating'] as num).toInt() : 0,
    );
  }
}
