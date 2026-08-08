// ignore_for_file: deprecated_member_use
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../models/coffee_cart.dart';
import '../models/coffee_visit.dart';

import '../repositories/coffee_cart_repository.dart';
import '../repositories/firebase_coffee_cart_repository.dart';

import '../services/location_service.dart';

import 'add_visit_screen.dart';
import 'cart_stats_screen.dart';
import 'edit_cart_screen.dart';



class CartDetailsScreen extends StatefulWidget {


  final CoffeeCart cart;



  const CartDetailsScreen({

    super.key,

    required this.cart,

  });



  @override
  State<CartDetailsScreen> createState() =>
      _CartDetailsScreenState();


}







class _CartDetailsScreenState
    extends State<CartDetailsScreen> {



  final FirebaseCoffeeCartRepository firebaseRepository =
      FirebaseCoffeeCartRepository();



  String? defaultNavigation;


  Position? currentPosition;





  @override
  void initState() {

    super.initState();

    loadNavigation();

    loadLocation();

  }







  Future<void> loadNavigation() async {


    final prefs =
        await SharedPreferences.getInstance();



    if(!mounted) return;



    setState(() {


      defaultNavigation =
          prefs.getString(
            'default_navigation',
          );


    });


  }







  Future<void> loadLocation() async {


    final position =
        await LocationService.getCurrentLocation();



    if(position != null && mounted){


      setState(() {


        currentPosition =
            position;


      });


    }


  }







  String getDistance(){


    if(currentPosition == null){

      return '';

    }



    if(widget.cart.latitude == 0 ||
        widget.cart.longitude == 0){

      return '';

    }





    final meters =
        Geolocator.distanceBetween(

          currentPosition!.latitude,

          currentPosition!.longitude,

          widget.cart.latitude,

          widget.cart.longitude,

        );





    if(meters < 1000){

      return "${meters.round()} מטר ממך";

    }



    return "${(meters / 1000).toStringAsFixed(1)} ק״מ ממך";


  }







  bool hasLocation(){


    return widget.cart.latitude != 0 &&

        widget.cart.longitude != 0;


  }







  Future<void> navigate(String type) async {


    final lat =
        widget.cart.latitude;


    final lng =
        widget.cart.longitude;



    Uri url;



    if(type == "waze"){


      url = Uri.parse(

        "https://waze.com/ul?ll=$lat,$lng&navigate=yes",

      );


    } else if(type == "apple"){


      url = Uri.parse(

        "https://maps.apple.com/?daddr=$lat,$lng",

      );


    } else {


      url = Uri.parse(

        "https://www.google.com/maps/search/?api=1&query=$lat,$lng",

      );


    }



    await launchUrl(

      url,

      mode:

      LaunchMode.externalApplication,

    );


  }
    Future<void> chooseNavigation() async {


    if(!hasLocation()){


      ScaffoldMessenger.of(context)
          .showSnackBar(

        const SnackBar(

          content:

          Text(

            "אין מיקום GPS",

          ),

        ),

      );


      return;

    }





    if(defaultNavigation != null){


      await navigate(

        defaultNavigation!,

      );


      return;


    }





    String selected = "google";

    bool remember = false;





    await showDialog(

      context:

      context,


      builder:(context){


        return StatefulBuilder(

          builder:(context,setDialogState){



            return AlertDialog(



              title:

              const Text(

                "בחר ניווט",

              ),





              content:

              Column(

                mainAxisSize:

                MainAxisSize.min,


                children: [



                  RadioListTile(

                    value:

                    "google",


                    groupValue:

                    selected,


                    title:

                    const Text(

                      "Google Maps",

                    ),



                    onChanged:(v){



                      setDialogState((){


                        selected =

                            v.toString();



                      });



                    },


                  ),





                  RadioListTile(

                    value:

                    "waze",


                    groupValue:

                    selected,


                    title:

                    const Text(

                      "Waze",

                    ),



                    onChanged:(v){



                      setDialogState((){


                        selected =

                            v.toString();



                      });



                    },


                  ),






                  RadioListTile(

                    value:

                    "apple",


                    groupValue:

                    selected,


                    title:

                    const Text(

                      "Apple Maps",

                    ),



                    onChanged:(v){



                      setDialogState((){


                        selected =

                            v.toString();



                      });



                    },


                  ),






                  CheckboxListTile(

                    value:

                    remember,


                    title:

                    const Text(

                      "זכור בחירה",

                    ),



                    onChanged:(v){



                      setDialogState((){


                        remember =

                            v ?? false;



                      });



                    },


                  ),



                ],

              ),





              actions: [



                TextButton(

                  onPressed:(){


                    Navigator.pop(context);


                  },


                  child:

                  const Text(

                    "ביטול",

                  ),


                ),





                FilledButton(

                  onPressed:() async {


                    Navigator.pop(context);





                    if(remember){



                      final prefs =

                      await SharedPreferences
                          .getInstance();





                      await prefs.setString(

                        'default_navigation',

                        selected,

                      );





                      defaultNavigation =

                          selected;



                    }






                    await navigate(

                      selected,

                    );



                  },



                  child:

                  const Text(

                    "פתח",

                  ),


                ),


              ],


            );


          },

        );


      },


    );


  }







  double average(List<double> values){


    if(values.isEmpty){

      return 0;

    }



    return values.reduce(

          (a,b)=>a+b,

    ) / values.length;


  }







  List<String> getCartTags(){


    final Set<String> result = {};



    for(final visit in widget.cart.visits){


      result.addAll(

        visit.tags,

      );


    }



    return result.toList();


  }







  Widget ratingRow(

      String title,

      double value,

      ){


    return Padding(

      padding:

      const EdgeInsets.symmetric(

        vertical:

        5,

      ),



      child:

      Row(



        children: [



          Expanded(

            child:

            Text(

              title,

              style:

              const TextStyle(

                fontSize:

                16,

              ),

            ),

          ),





          Text(

            value == 0

                ? "-"

                : value.toStringAsFixed(1),

          ),





          const SizedBox(

            width:

            6,

          ),





          const Icon(

            Icons.star,

            size:

            18,

            color:

            Colors.amber,

          ),



        ],


      ),


    );


  }
    Future<void> deleteCart() async {


    final confirm =
        await showDialog<bool>(

      context:

      context,


      builder:(context){


        return AlertDialog(


          title:

          const Text(

            "מחיקת עגלה",

          ),




          content:

          const Text(

            "האם למחוק את העגלה?",

          ),





          actions: [



            TextButton(

              onPressed:(){

                Navigator.pop(

                  context,

                  false,

                );


              },


              child:

              const Text(

                "ביטול",

              ),


            ),





            FilledButton(

              onPressed:(){


                Navigator.pop(

                  context,

                  true,

                );


              },


              child:

              const Text(

                "מחיקה",

              ),


            ),


          ],


        );


      },


    );







    if(confirm == true){



      await CoffeeCartRepository.delete(

        widget.cart,

      );




      if(widget.cart.firebaseId.isNotEmpty){


        await firebaseRepository
            .deleteCoffeeCart(

          widget.cart,

        );


      }





      if(mounted){

        Navigator.pop(context);

      }


    }


  }







  Future<void> deleteVisit(
      CoffeeVisit visit,
      ) async {



    final confirm =
        await showDialog<bool>(

      context:

      context,


      builder:(context){


        return AlertDialog(

          title:

          const Text(

            "מחיקת ביקור",

          ),



          content:

          const Text(

            "האם למחוק את הביקור?",

          ),





          actions: [



            TextButton(

              onPressed:(){

                Navigator.pop(

                  context,

                  false,

                );


              },


              child:

              const Text(

                "ביטול",

              ),


            ),





            FilledButton(

              onPressed:(){


                Navigator.pop(

                  context,

                  true,

                );


              },


              child:

              const Text(

                "מחיקה",

              ),


            ),



          ],


        );


      },


    );






    if(confirm == true){



      setState((){


        widget.cart.visits.remove(

          visit,

        );


      });





      await widget.cart.save();



      await firebaseRepository
          .updateCoffeeCart(

        widget.cart,

      );


    }


  }








  @override
  Widget build(BuildContext context) {



    final cart =

    widget.cart;



    final visits =

    cart.visits;



    final tags =

    getCartTags();



    final distance =

    getDistance();





    final atmosphere =

    average(

      visits.map((e)=>e.atmosphere)

          .toList(),

    );



    final cleanliness =

    average(

      visits.map((e)=>e.cleanliness)

          .toList(),

    );



    final service =

    average(

      visits.map((e)=>e.service)

          .toList(),

    );



    final food =

    average(

      visits.map((e)=>e.foodQuality)

          .toList(),

    );



    final variety =

    average(

      visits.map((e)=>e.variety)

          .toList(),

    );



    final value =

    average(

      visits.map((e)=>e.value)

          .toList(),

    );







    return Directionality(

      textDirection:

      TextDirection.rtl,


      child:

      Scaffold(



        appBar:

        AppBar(



          title:

          Text(cart.name),



          actions: [



            IconButton(

              icon:

              const Icon(

                Icons.analytics,

              ),


              onPressed:(){


                Navigator.push(

                  context,

                  MaterialPageRoute(

                    builder:(_)=>

                    CartStatsScreen(

                      cart:

                      cart,

                    ),

                  ),

                );


              },

            ),




            IconButton(

              icon:

              const Icon(

                Icons.navigation,

              ),



              onPressed:

              chooseNavigation,


            ),





            IconButton(

              icon:

              const Icon(

                Icons.edit,

              ),



              onPressed:() async {



                await Navigator.push(

                  context,

                  MaterialPageRoute(

                    builder:(_)=>

                    EditCartScreen(

                      cart:

                      cart,

                    ),

                  ),

                );



                setState((){});


              },


            ),





            IconButton(

              icon:

              const Icon(

                Icons.delete,

              ),


              onPressed:

              deleteCart,


            ),



          ],


        ),





        floatingActionButton:

        FloatingActionButton.extended(



          onPressed:() async {



            await Navigator.push(

              context,

              MaterialPageRoute(

                builder:(_)=>

                AddVisitScreen(

                  cart:

                  cart,

                ),

              ),

            );



            setState((){});


          },



          icon:

          const Icon(

            Icons.add,

          ),



          label:

          const Text(

            "ביקור",

          ),



        ),





        body:

        ListView(

          padding:

          const EdgeInsets.all(16),



          children: [



            if(cart.imageBase64.isNotEmpty)

              ClipRRect(

                borderRadius:

                BorderRadius.circular(20),


                child:

                Image.memory(

                  base64Decode(

                    cart.imageBase64,

                  ),


                  height:

                  220,


                  fit:

                  BoxFit.cover,


                ),

              ),






            const SizedBox(

              height:

              16,

            ),






            Text(

              cart.name,


              style:

              const TextStyle(

                fontSize:

                28,

                fontWeight:

                FontWeight.bold,

              ),

            ),




            Text(

              cart.location,

            ),





            if(distance.isNotEmpty)

              Text(

                "📍 $distance",

              ),





            const SizedBox(

              height:

              16,

            ),






            Card(

              child:

              Padding(

                padding:

                const EdgeInsets.all(16),


                child:

                Column(

                  crossAxisAlignment:

                  CrossAxisAlignment.start,


                  children: [


                    const Text(

                      "📊 דירוגים",

                      style:

                      TextStyle(

                        fontSize:

                        20,

                        fontWeight:

                        FontWeight.bold,

                      ),

                    ),



                    ratingRow(

                      "אווירה",

                      atmosphere,

                    ),



                    ratingRow(

                      "ניקיון",

                      cleanliness,

                    ),



                    ratingRow(

                      "שירות",

                      service,

                    ),



                    ratingRow(

                      "אוכל",

                      food,

                    ),



                    ratingRow(

                      "מגוון",

                      variety,

                    ),



                    ratingRow(

                      "תמורה",

                      value,

                    ),


                  ],

                ),

              ),

            ),





            const SizedBox(

              height:

              16,

            ),





            Text(

              "ציון כולל: ${cart.score.toStringAsFixed(1)} ⭐",

              style:

              const TextStyle(

                fontSize:

                22,

                fontWeight:

                FontWeight.bold,

              ),

            ),






            if(tags.isNotEmpty)

              Wrap(

                spacing:

                8,


                children:

                tags.map(

                      (tag)=>

                      Chip(

                        label:

                        Text(tag),

                      ),

                ).toList(),


              ),






            const SizedBox(

              height:

              20,

            ),





            const Text(

              "ביקורים",

              style:

              TextStyle(

                fontSize:

                22,

                fontWeight:

                FontWeight.bold,

              ),

            ),






            ...visits.map(

                  (visit)=>

                  Card(

                    child:

                    ListTile(

                      title:

                      Text(

                        visit.dish,

                      ),



                      subtitle:

                      Text(

                        "⭐ ${visit.score.toStringAsFixed(1)}\n${visit.notes}",

                      ),



                      trailing:

                      IconButton(

                        icon:

                        const Icon(

                          Icons.delete_outline,

                        ),


                        onPressed:(){

                          deleteVisit(

                            visit,

                          );


                        },


                      ),


                    ),

                  ),

            ),



          ],


        ),



      ),

    );


  }


}