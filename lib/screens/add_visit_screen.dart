import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/coffee_cart.dart';
import '../models/coffee_visit.dart';



class AddVisitScreen extends StatefulWidget {


  final CoffeeCart cart;

  final CoffeeVisit? existingVisit;



  const AddVisitScreen({

    super.key,

    required this.cart,

    this.existingVisit,

  });





  @override
  State<AddVisitScreen> createState() =>
      _AddVisitScreenState();

}






class _AddVisitScreenState
    extends State<AddVisitScreen> {



  final dishController =
      TextEditingController();



  final notesController =
      TextEditingController();





  final picker =
      ImagePicker();





  String imageBase64 = '';





  double atmosphere = 5;

  double cleanliness = 5;

  double service = 5;

  double foodQuality = 5;

  double variety = 5;

  double value = 5;





  List<String> tags = [];





  final List<String> allTags = [


    "טעים",

    "מתאים למשפחה",

    "נוף",

    "ארוחת בוקר",

    "טבעוני",

    "עצירה בדרך",

    "שווה נסיעה",


  ];









  @override
  void initState() {


    super.initState();



    final visit =
        widget.existingVisit;



    if(visit != null){



      dishController.text =
          visit.dish;



      notesController.text =
          visit.notes;



      atmosphere =
          visit.atmosphere;



      cleanliness =
          visit.cleanliness;



      service =
          visit.service;



      foodQuality =
          visit.foodQuality;



      variety =
          visit.variety;



      value =
          visit.value;



      imageBase64 =
          visit.imageBase64;



      tags =
          List<String>.from(
            visit.tags,
          );


    }


  }









  Future<void> pickImage() async {


    final image =
        await picker.pickImage(

          source:
              ImageSource.gallery,

          imageQuality:
              80,

        );



    if(image == null){

      return;

    }




    final bytes =
        await image.readAsBytes();



    setState((){


      imageBase64 =
          base64Encode(bytes);


    });


  }








  Future<void> save() async {


    if(widget.existingVisit != null){



      final visit =
          widget.existingVisit!;




      visit.dish =
          dishController.text;



      visit.notes =
          notesController.text;



      visit.atmosphere =
          atmosphere;



      visit.cleanliness =
          cleanliness;



      visit.service =
          service;



      visit.foodQuality =
          foodQuality;



      visit.variety =
          variety;



      visit.value =
          value;



      visit.tags =
          tags;



      visit.imageBase64 =
          imageBase64;



      await visit.save();



    }

    else {



      widget.cart.visits.add(


        CoffeeVisit(


          date:
              DateTime.now(),


          dish:
              dishController.text,


          notes:
              notesController.text,


          atmosphere:
              atmosphere,


          cleanliness:
              cleanliness,


          service:
              service,


          foodQuality:
              foodQuality,


          variety:
              variety,


          value:
              value,


          tags:
              tags,


          imageBase64:
              imageBase64,


        ),


      );



      await widget.cart.save();


    }





    if(mounted){

      Navigator.pop(context);

    }


  }
    Widget starPicker(

      String title,

      double value,

      Function(double) update,

      ){



    return Column(

      crossAxisAlignment:
          CrossAxisAlignment.start,


      children: [



        Text(

          "$title: ${value.toStringAsFixed(1)}",

          style:
              const TextStyle(

            fontWeight:
                FontWeight.bold,

          ),

        ),





        Row(

          children:

          List.generate(

            5,

            (index){



              final starValue =
                  index + 1.0;



              final halfValue =
                  index + 0.5;



              IconData icon;



              if(value >= starValue){

                icon =
                    Icons.star;

              }

              else if(value >= halfValue){

                icon =
                    Icons.star_half;

              }

              else {

                icon =
                    Icons.star_border;

              }




              return GestureDetector(


                onTapDown:(details){



                  final box =
                      context.findRenderObject()
                      as RenderBox;



                  final local =
                      details.localPosition.dx;



                  final halfWidth =
                      24 / 2;



                  double newValue;



                  if(local < halfWidth){

                    newValue =
                        halfValue;

                  }

                  else {

                    newValue =
                        starValue;

                  }



                  setState((){


                    update(
                      newValue,
                    );


                  });



                },



                child:

                Padding(

                  padding:
                      const EdgeInsets.symmetric(
                        horizontal:2,
                      ),


                  child:

                  Icon(

                    icon,

                    color:
                        Colors.amber,

                    size:
                        32,

                  ),

                ),


              );



            },

          ),


        ),



      ],


    );


  }









  Widget imageBox(){


    return GestureDetector(

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


        ClipRRect(

          borderRadius:
              BorderRadius.circular(20),


          child:

          Image.memory(

            base64Decode(

              imageBase64,

            ),


            width:
                double.infinity,


            fit:
                BoxFit.cover,


          ),


        ),



      ),


    );


  }
    @override
  Widget build(BuildContext context) {


    return Scaffold(


      appBar:

      AppBar(

        title:

        Text(

          widget.existingVisit == null

              ? "הוספת ביקור"

              : "עריכת ביקור",

        ),

      ),





      body:

      ListView(

        padding:
            const EdgeInsets.all(16),



        children: [



          imageBox(),





          const SizedBox(
            height:16,
          ),





          TextField(

            controller:
                dishController,


            decoration:
                const InputDecoration(

              labelText:
                  "מה אכלת?",

              border:
                  OutlineInputBorder(),

            ),


          ),






          const SizedBox(
            height:12,
          ),





          TextField(

            controller:
                notesController,


            maxLines:
                3,


            decoration:
                const InputDecoration(

              labelText:
                  "הערות",

              border:
                  OutlineInputBorder(),

            ),


          ),






          const SizedBox(
            height:20,
          ),





          starPicker(

            "אוכל",

            foodQuality,

            (v){

              foodQuality =
                  v;

            },

          ),





          starPicker(

            "אווירה",

            atmosphere,

            (v){

              atmosphere =
                  v;

            },

          ),





          starPicker(

            "שירות",

            service,

            (v){

              service =
                  v;

            },

          ),





          starPicker(

            "ניקיון",

            cleanliness,

            (v){

              cleanliness =
                  v;

            },

          ),





          starPicker(

            "מגוון",

            variety,

            (v){

              variety =
                  v;

            },

          ),





          starPicker(

            "תמורה",

            value,

            (v){

              value =
                  v;

            },

          ),






          const SizedBox(
            height:20,
          ),






          const Text(

            "תגיות",

            style:

            TextStyle(

              fontSize:
                  18,

              fontWeight:
                  FontWeight.bold,

            ),

          ),






          Wrap(

            spacing:
                8,


            runSpacing:
                8,



            children:

            allTags.map(

                  (tag){



                return FilterChip(

                  label:
                      Text(tag),


                  selected:
                      tags.contains(tag),


                  onSelected:(selected){



                    setState((){



                      if(selected){

                        tags.add(tag);

                      }

                      else {

                        tags.remove(tag);

                      }



                    });



                  },


                );


              },

            ).toList(),



          ),






          const SizedBox(
            height:30,
          ),






          FilledButton(


            onPressed:
                save,


            child:

            const Text(

              "שמירה",

            ),


          ),




        ],


      ),


    );


  }


}