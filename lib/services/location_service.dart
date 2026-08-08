import 'package:geolocator/geolocator.dart';


class LocationService {

  LocationService._();


  static Future<Position?> getCurrentLocation() async {

    bool enabled =
        await Geolocator.isLocationServiceEnabled();


    if (!enabled) {
      return null;
    }



    LocationPermission permission =
        await Geolocator.checkPermission();



    if(permission == LocationPermission.denied) {

      permission =
          await Geolocator.requestPermission();

    }



    if(permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {

      return null;

    }



    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

  }


}