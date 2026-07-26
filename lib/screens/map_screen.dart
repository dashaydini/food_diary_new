import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import '../repositories/coffee_cart_repository.dart';
import 'cart_details_screen.dart';



class MapScreen extends StatefulWidget {

  const MapScreen({
    super.key,
  });



  @override
  State<MapScreen> createState() =>
      _MapScreenState();

}





class _MapScreenState extends State<MapScreen> {


  final MapController mapController =
      MapController();



  LatLng? currentLocation;







  Future<void> getCurrentLocation() async {


    final permission =
        await Geolocator.requestPermission();


    if(permission ==
        LocationPermission.denied ||
        permission ==
            LocationPermission.deniedForever) {

      return;

    }



    final position =
        await Geolocator.getCurrentPosition();




    final point =
        LatLng(

          position.latitude,

          position.longitude,

        );



    setState(() {

      currentLocation =
          point;

    });



    mapController.move(

      point,

      15,

    );


  }








  @override
  Widget build(BuildContext context) {


    return Scaffold(



      appBar:

          AppBar(

        title:

            const Text(
              "מפת עגלות",
            ),

        actions: [



          IconButton(

            icon:

                const Icon(
                  Icons.my_location,
                ),


            tooltip:
                "המיקום שלי",


            onPressed:
                getCurrentLocation,


          ),



        ],


      ),






      body:

          ValueListenableBuilder(



        valueListenable:

            CoffeeCartRepository.listen(),




        builder:

            (context, box, child) {



          final carts =

              box.values

                  .where(

                    (cart) =>

                        cart.latitude != 0 &&

                        cart.longitude != 0,

                  )

                  .toList();







          if(carts.isEmpty){


            return const Center(

              child:

                  Text(

                    "אין עגלות עם מיקום",

                  ),

            );


          }







          return FlutterMap(



            mapController:

                mapController,




            options:

                MapOptions(

              initialCenter:

                  LatLng(

                    carts.first.latitude,

                    carts.first.longitude,

                  ),



              initialZoom:

                  12,


            ),






            children: [




              TileLayer(



                urlTemplate:

                    "https://tile.openstreetmap.org/{z}/{x}/{y}.png",



                userAgentPackageName:

                    "com.example.food_diary",



              ),







              MarkerLayer(



                markers:



                    [



                  ...carts.map(



                        (cart) => Marker(



                      point:

                          LatLng(

                            cart.latitude,

                            cart.longitude,

                          ),




                      width:

                          70,




                      height:

                          70,




                      child:

                          GestureDetector(



                        onTap:(){



                          showModalBottomSheet(



                            context:

                                context,



                            builder:

                                (_) => Directionality(



                              textDirection:

                                  TextDirection.rtl,



                              child:

                                  Padding(



                                padding:

                                    const EdgeInsets.all(20),



                                child:

                                    Column(



                                  mainAxisSize:

                                      MainAxisSize.min,



                                  children: [



                                    Text(



                                      cart.name,



                                      style:

                                          const TextStyle(

                                        fontSize:

                                            22,

                                        fontWeight:

                                            FontWeight.bold,

                                      ),



                                    ),





                                    const SizedBox(
                                      height:10,
                                    ),





                                    Text(

                                      "⭐ ${cart.score.toStringAsFixed(1)}",

                                    ),




                                    Text(

                                      "ביקורים: ${cart.visitsCount}",

                                    ),






                                    const SizedBox(
                                      height:20,
                                    ),






                                    FilledButton(

                                      onPressed:(){



                                        Navigator.pop(context);



                                        Navigator.push(



                                          context,



                                          MaterialPageRoute(



                                            builder:(_)=>

                                                CartDetailsScreen(

                                              cart:

                                                  cart,

                                            ),



                                          ),



                                        );



                                      },



                                      child:

                                          const Text(

                                            "פתח עגלה",

                                          ),



                                    ),



                                  ],



                                ),



                              ),



                            ),



                          );



                        },




                        child:

                            const Icon(



                          Icons.local_cafe,



                          size:

                              45,



                        ),



                      ),



                    ),



                  ),




                  if(currentLocation != null)



                    Marker(



                      point:

                          currentLocation!,



                      width:

                          50,



                      height:

                          50,



                      child:

                          const Icon(



                        Icons.person_pin_circle,



                        size:

                            45,



                      ),



                    ),



                ],



              ),



            ],



          );



        },



      ),



    );


  }


}