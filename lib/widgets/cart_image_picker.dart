import 'dart:convert';


import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/coffee_cart.dart';



class CartImagePicker extends StatefulWidget {


  final CoffeeCart cart;



  const CartImagePicker({

    super.key,

    required this.cart,

  });



  @override
  State<CartImagePicker> createState() =>
      _CartImagePickerState();


}






class _CartImagePickerState
    extends State<CartImagePicker> {



  final ImagePicker picker =
      ImagePicker();





  Future<void> chooseImage() async {


    final source =

        await showModalBottomSheet<ImageSource>(

      context:
          context,


      builder: (_) => Directionality(

        textDirection:
            TextDirection.rtl,


        child:
            Wrap(

          children: [



            ListTile(

              leading:
                  const Icon(
                    Icons.camera_alt,
                  ),


              title:
                  const Text(
                    "צלם תמונה",
                  ),


              onTap: () =>

                  Navigator.pop(

                    context,

                    ImageSource.camera,

                  ),


            ),




            ListTile(

              leading:
                  const Icon(
                    Icons.photo,
                  ),


              title:
                  const Text(
                    "בחר מהגלריה",
                  ),


              onTap: () =>

                  Navigator.pop(

                    context,

                    ImageSource.gallery,

                  ),


            ),



          ],


        ),


      ),


    );





    if(source == null){

      return;

    }



    await pickImage(source);


  }









  Future<void> pickImage(
      ImageSource source
      ) async {



    final image =

        await picker.pickImage(

      source:
          source,


      imageQuality:
          85,


    );



    if(image == null){

      return;

    }






    final bytes =

        await image.readAsBytes();




    final encoded =

        base64Encode(bytes);





    setState(() {


      widget.cart.imageBase64 =
          encoded;


    });





    await widget.cart.save();


  }









  Widget showImage(){



    if(widget.cart.imageBase64.isNotEmpty){



      return Image.memory(



        base64Decode(

          widget.cart.imageBase64,

        ),



        fit:

            BoxFit.cover,



        width:

            double.infinity,



      );



    }







    return const Column(



      mainAxisAlignment:

          MainAxisAlignment.center,



      children: [



        Icon(

          Icons.add_a_photo,

          size:
              40,

        ),



        SizedBox(

          height:
              8,

        ),



        Text(

          "הוסף תמונה",

        ),



      ],



    );



  }









  @override
  Widget build(BuildContext context) {



    return GestureDetector(



      onTap:

          chooseImage,



      child:



          Container(



        height:

            220,



        width:

            double.infinity,



        decoration:

            BoxDecoration(



          color:

              Colors.grey.shade200,



          borderRadius:

              BorderRadius.circular(

                16,

              ),



        ),




        child:



            ClipRRect(



          borderRadius:

              BorderRadius.circular(

                16,

              ),




          child:

              showImage(),



        ),



      ),



    );


  }



}