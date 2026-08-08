import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/coffee_cart.dart';
import '../services/location_service.dart';



class CoffeeCartCard extends StatefulWidget {


  final CoffeeCart cart;


  final VoidCallback onTap;


  final VoidCallback? onAddVisit;


  final VoidCallback? onNavigate;


  final VoidCallback? onFavorite;




  const CoffeeCartCard({


    super.key,


    required this.cart,


    required this.onTap,


    this.onAddVisit,


    this.onNavigate,


    this.onFavorite,


  });





  @override
  State<CoffeeCartCard> createState() =>

      _CoffeeCartCardState();


}







class _CoffeeCartCardState

    extends State<CoffeeCartCard> {



  Position? currentPosition;






  @override

  void initState() {


    super.initState();


    loadLocation();


  }






  Future<void> loadLocation() async {



    final position =

    await LocationService.getCurrentLocation();





    if(position != null && mounted){


      setState((){


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



      return

      "${meters.round()} מטר ממך";



    }







    return

    "${(meters / 1000).toStringAsFixed(1)} ק\"מ ממך";



  }







  List<String> getTags(){



    final Set<String> tags = {};





    for(final visit in widget.cart.visits){


      tags.addAll(

        visit.tags,

      );


    }





    return tags.take(3).toList();



  }








  String getLastVisit(){



    if(widget.cart.visits.isEmpty){


      return '';

    }





    final visits =

    [...widget.cart.visits];





    visits.sort(

          (a,b) =>

          b.date.compareTo(

            a.date,

          ),

    );






    final last =

    visits.first;







    return

    last.dish;



  }







  String getLastVisitDate(){



    if(widget.cart.visits.isEmpty){


      return '';

    }





    final visits =

    [...widget.cart.visits];





    visits.sort(

          (a,b) =>

          b.date.compareTo(

            a.date,

          ),

    );






    final date =

    visits.first.date;





    final now =

    DateTime.now();





    final days =

        now.difference(date).inDays;







    if(days == 0){


      return "היום";


    }





    if(days == 1){


      return "אתמול";


    }






    return

    "לפני $days ימים";



  }
    @override
  Widget build(BuildContext context) {


    debugPrint(
        "CART DEBUG: ${widget.cart.name} | owner=${widget.cart.ownerName} | created=${widget.cart.createdAt}",
      );


      final tags =

    getTags();



    final distance =

    getDistance();



    final lastDish =

    getLastVisit();



    final lastDate =

    getLastVisitDate();





    return Card(



      margin:

      const EdgeInsets.symmetric(

        horizontal:

        12,

        vertical:

        8,

      ),





      elevation:

      3,





      shape:

      RoundedRectangleBorder(

        borderRadius:

        BorderRadius.circular(

          20,

        ),

      ),






      child:

      InkWell(



        borderRadius:

        BorderRadius.circular(

          20,

        ),



        onTap:

        widget.onTap,





        child:

        Column(



          crossAxisAlignment:

          CrossAxisAlignment.start,





          children: [





            if(widget.cart.imageBase64.isNotEmpty)



              ClipRRect(



                borderRadius:

                const BorderRadius.vertical(

                  top:

                  Radius.circular(

                    20,

                  ),

                ),



                child:

                Image.memory(



                  base64Decode(

                    widget.cart.imageBase64,

                  ),





                  height:

                  170,





                  width:

                  double.infinity,





                  fit:

                  BoxFit.cover,



                ),



              ),








            Padding(



              padding:

              const EdgeInsets.all(

                14,

              ),





              child:

              Column(



                crossAxisAlignment:

                CrossAxisAlignment.start,





                children: [





                  Row(



                    children: [





                      Expanded(



                        child:

                        Text(



                          widget.cart.name,





                          style:

                          const TextStyle(



                            fontSize:

                            22,



                            fontWeight:

                            FontWeight.bold,



                          ),



                        ),



                      ),






                      IconButton(



                        icon:

                        Icon(



                          widget.cart.favorite

                              ? Icons.favorite

                              : Icons.favorite_border,



                          color:

                          widget.cart.favorite

                              ? Colors.red

                              : null,



                        ),



                        onPressed:

                        widget.onFavorite,



                      ),



                    ],



                  ),






                  Row(



                    children: [



                      const Icon(



                        Icons.star,



                        size:

                        20,



                        color:

                        Colors.amber,



                      ),





                      const SizedBox(

                        width:

                        4,

                      ),






                      Text(



                        widget.cart.score

                            .toStringAsFixed(1),



                      ),






                      const SizedBox(

                        width:

                        20,

                      ),






                      Text(



                        "${widget.cart.visitsCount} ביקורים",



                      ),



                    ],



                  ),








                  const SizedBox(

                    height:

                    8,

                  ),






                  Text(



                    widget.cart.location,



                    maxLines:

                    1,



                    overflow:

                    TextOverflow.ellipsis,



                  ),







                    if(widget.cart.ownerName.isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 6),
                        child:
                            Text(
                              "נוצר על ידי: ${widget.cart.ownerName}",
                            ),
                      ),


                    if(widget.cart.createdAt != null)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 4),
                        child:
                            Text(
                              "בתאריך: ${widget.cart.createdAt!.day}/${widget.cart.createdAt!.month}/${widget.cart.createdAt!.year}",
                            ),
                      ),

                  if(distance.isNotEmpty)



                    Padding(



                      padding:

                      const EdgeInsets.only(

                        top:

                        8,

                      ),




                      child:

                      Row(



                        children: [



                          const Icon(



                            Icons.location_on,



                            size:

                            18,



                            color:

                            Colors.blue,



                          ),





                          const SizedBox(

                            width:

                            4,

                          ),






                          Text(distance),



                        ],



                      ),



                    ),








                  if(lastDish.isNotEmpty)



                    Padding(



                      padding:

                      const EdgeInsets.only(

                        top:

                        10,

                      ),





                      child:

                      Row(



                        children: [



                          const Icon(



                            Icons.restaurant,



                            size:

                            18,



                          ),





                          const SizedBox(

                            width:

                            6,

                          ),





                          Expanded(



                            child:

                            Text(



                              "אחרון: $lastDish",



                              overflow:

                              TextOverflow.ellipsis,



                            ),



                          ),



                        ],



                      ),



                    ),








                  if(lastDate.isNotEmpty)



                    Padding(



                      padding:

                      const EdgeInsets.only(

                        top:

                        4,

                      ),




                      child:

                      Row(



                        children: [



                          const Icon(



                            Icons.history,



                            size:

                            18,



                          ),





                          const SizedBox(

                            width:

                            6,

                          ),






                          Text(



                            "ביקור $lastDate",



                          ),



                        ],



                      ),



                    ),









                  if(tags.isNotEmpty)



                    Padding(



                      padding:

                      const EdgeInsets.only(

                        top:

                        10,

                      ),





                      child:

                      Wrap(



                        spacing:

                        6,



                        children:



                        tags.map(



                              (tag) =>



                              Chip(



                                label:

                                Text(tag),



                              ),



                        ).toList(),



                      ),



                    ),








                  const SizedBox(

                    height:

                    8,

                  ),








                  Row(



                    mainAxisAlignment:

                    MainAxisAlignment.spaceEvenly,





                    children: [





                      TextButton.icon(



                        onPressed:

                        widget.onAddVisit,



                        icon:

                        const Icon(

                          Icons.add,

                        ),



                        label:

                        const Text(

                          "ביקור",

                        ),



                      ),






                      if (widget.onAddVisit != null)
                          TextButton.icon(
                            onPressed:
                                widget.onAddVisit,

                            icon:
                                const Icon(
                                  Icons.add,
                                ),

                            label:
                                const Text(
                                  "ביקור",
                                ),
                          ),



                        TextButton.icon(

                          onPressed:
                              widget.onNavigate,

                          icon:
                              const Icon(
                                Icons.navigation,
                              ),

                        label:

                        const Text(

                          "ניווט",

                        ),



                      ),



                    ],



                  ),





                ],



              ),



            ),



          ],



        ),



      ),



    );



  }



}
