import 'package:hive/hive.dart';

import 'coffee_visit.dart';


part 'coffee_cart.g.dart';



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






  CoffeeCart({

    required this.name,

    required this.location,

    required this.visits,

    this.imageBase64 = '',

    this.favorite = false,

    this.latitude = 0,

    this.longitude = 0,

  });






  double get score {



    if(visits.isEmpty) {

      return 0;

    }



    double total = 0;



    for(final visit in visits) {

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

      'visits': visits.map((visit) => visit.toMap()).toList(),

    };

  }



  factory CoffeeCart.fromMap(
    Map<String, dynamic> map,
  ) {

    return CoffeeCart(

      name: map['name'] ?? '',

      location: map['location'] ?? '',

      imageBase64: map['imageBase64'] ?? '',

      favorite: map['favorite'] ?? false,

      latitude: (map['latitude'] ?? 0).toDouble(),

      longitude: (map['longitude'] ?? 0).toDouble(),

      visits: (map['visits'] as List<dynamic>? ?? [])
          .map(
            (item) => CoffeeVisit.fromMap(item),
          )
          .toList(),

    );

  }
}