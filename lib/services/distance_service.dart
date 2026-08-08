import 'package:geolocator/geolocator.dart';


class DistanceService {


  static double calculateDistanceKm(
      double lat1,
      double lng1,
      double lat2,
      double lng2,
      ) {


    final meters =
        Geolocator.distanceBetween(
          lat1,
          lng1,
          lat2,
          lng2,
        );


    return meters / 1000;

  }


}