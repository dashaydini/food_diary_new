import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../models/coffee_cart.dart';

import '../repositories/coffee_cart_repository.dart';
import '../repositories/firebase_coffee_cart_repository.dart';



class AddCartScreen extends StatefulWidget {

  const AddCartScreen({
    super.key,
  });



  @override
  State<AddCartScreen> createState() =>
      _AddCartScreenState();

}





class _AddCartScreenState
    extends State<AddCartScreen> {



  final nameController =
      TextEditingController();



  final locationController =
      TextEditingController();



  final picker =
      ImagePicker();



  final firebaseRepository =
      FirebaseCoffeeCartRepository();



  String imageBase64 = '';



  double latitude = 0;

  double longitude = 0;



  bool favorite = false;

  bool loadingLocation = false;

  bool saving = false;









  Future<void> pickImage() async {


    final image =
        await picker.pickImage(

      source:
          ImageSource.gallery,

      imageQuality:
          80,

    );



    if(image == null) {

      return;

    }



    final bytes =
        await image.readAsBytes();



    setState(() {

      imageBase64 =
          base64Encode(bytes);

    });


  }









  Future<void> getLocation() async {


    setState(() {

      loadingLocation = true;

    });




    final enabled =
        await Geolocator.isLocationServiceEnabled();



    if(!enabled) {

      setState(() {

        loadingLocation = false;

      });

      return;

    }





    LocationPermission permission =
        await Geolocator.checkPermission();




    if(permission ==
        LocationPermission.denied) {


      permission =
          await Geolocator.requestPermission();

    }





    if(permission ==
            LocationPermission.denied ||

        permission ==
            LocationPermission.deniedForever) {


      setState(() {

        loadingLocation = false;

      });


      return;

    }







    final position =
        await Geolocator.getCurrentPosition();




    String address = '';




    try {


      final places =
          await placemarkFromCoordinates(

        position.latitude,

        position.longitude,

      );



      if(places.isNotEmpty) {


        final place =
            places.first;


        address =
            "${place.street ?? ''} "
            "${place.subLocality ?? ''} "
            "${place.locality ?? ''}";


      }


    }

    catch(e) {


      address = '';

    }






    setState(() {


      latitude =
          position.latitude;



      longitude =
          position.longitude;



      if(address.trim().isNotEmpty) {

        locationController.text =
            address.trim();

      }



      loadingLocation =
          false;


    });


  }









  Future<void> save() async {


    if(nameController.text.trim().isEmpty) {

      return;

    }



    setState(() {

      saving = true;

    });




    final cart =
        CoffeeCart(


      name:
          nameController.text.trim(),



      location:
          locationController.text.trim(),



      visits:
          [],



      imageBase64:
          imageBase64,



      favorite:
          favorite,



      latitude:
          latitude,



      longitude:
          longitude,


    );




    try {


      // שמירה מקומית

      await CoffeeCartRepository.add(
        cart,
      );



      // שמירה בענן

      await firebaseRepository.addCoffeeCart(
        cart,
      );




      if(mounted) {

        Navigator.pop(context);

      }



    }

    catch(e) {


      if(mounted) {

        ScaffoldMessenger.of(context)
            .showSnackBar(

          SnackBar(

            content:
                Text(
                  "שגיאה בשמירה: $e",
                ),

          ),

        );

      }


    }

    finally {


      if(mounted) {

        setState(() {

          saving = false;

        });

      }


    }


  }









  @override
  void dispose() {

    nameController.dispose();

    locationController.dispose();

    super.dispose();

  }









  @override
  Widget build(BuildContext context) {


    return Scaffold(


      appBar:
          AppBar(

        title:
            const Text(
              "הוספת עגלת קפה",
            ),

      ),




      body:

      ListView(

        padding:
            const EdgeInsets.all(16),



        children: [



          GestureDetector(

            onTap:
                pickImage,



            child:

            Container(

              height:
                  220,


              decoration:

              BoxDecoration(

                color:
                    Colors.grey.shade200,


                borderRadius:
                    BorderRadius.circular(20),


              ),



              child:

              imageBase64.isEmpty


                  ?

              const Icon(

                Icons.add_a_photo,

                size:
                    60,

              )



                  :



              Image.memory(

                base64Decode(
                  imageBase64,
                ),

                fit:
                    BoxFit.cover,

              ),


            ),


          ),






          const SizedBox(
            height:20,
          ),





          TextField(

            controller:
                nameController,


            decoration:
                const InputDecoration(

              labelText:
                  "שם העגלה",

              border:
                  OutlineInputBorder(),

            ),


          ),






          const SizedBox(
            height:16,
          ),





          TextField(

            controller:
                locationController,


            decoration:
                const InputDecoration(

              labelText:
                  "מיקום",

              border:
                  OutlineInputBorder(),

            ),


          ),





          const SizedBox(
            height:16,
          ),





          FilledButton.icon(

            onPressed:
                loadingLocation

                    ? null

                    : getLocation,


            icon:

            loadingLocation

                ?

            const SizedBox(

              width:
                  18,

              height:
                  18,

              child:
              CircularProgressIndicator(),

            )


                :

            const Icon(
              Icons.location_on,
            ),



            label:
            const Text(
              "קבל מיקום וכתובת",
            ),



          ),






          if(latitude != 0)

            Padding(

              padding:
              const EdgeInsets.all(12),

              child:
              Text(

                "GPS:\n$latitude\n$longitude",

              ),

            ),





          SwitchListTile(

            title:
            const Text(
              "מועדפת ⭐",
            ),


            value:
            favorite,


            onChanged:(value){

              setState(() {

                favorite =
                    value;

              });

            },


          ),





          const SizedBox(
            height:20,
          ),





          FilledButton(

            onPressed:
            saving
                ? null
                : save,


            child:

            saving

                ?

            const CircularProgressIndicator()

                :

            const Text(
              "שמירה",
            ),


          ),



        ],


      ),


    );


  }


}