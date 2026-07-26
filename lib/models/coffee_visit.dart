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


  });





  double get score {


    return (

      atmosphere +

      cleanliness +

      service +

      foodQuality +

      variety +

      value

    ) / 6;


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

    );

  }

}