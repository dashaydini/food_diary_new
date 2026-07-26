import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/coffee_cart.dart';


class CoffeeCartCard extends StatelessWidget {

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



  List<String> getTags(){

    final Set<String> tags = {};


    for(final visit in cart.visits){

      tags.addAll(
        visit.tags,
      );

    }


    return tags.take(3).toList();

  }





  @override
  Widget build(BuildContext context) {


    final tags = getTags();



    return Card(

      margin:
          const EdgeInsets.symmetric(

            horizontal:12,

            vertical:8,

          ),


      elevation:
          3,


      shape:
          RoundedRectangleBorder(

        borderRadius:
            BorderRadius.circular(20),

      ),



      child:

      InkWell(

        borderRadius:
            BorderRadius.circular(20),


        onTap:
            onTap,



        child:

        Column(

          crossAxisAlignment:
              CrossAxisAlignment.start,


          children: [



            if(cart.imageBase64.isNotEmpty)

              ClipRRect(

                borderRadius:
                    const BorderRadius.vertical(

                  top:
                      Radius.circular(20),

                ),


                child:

                Image.memory(

                  base64Decode(
                    cart.imageBase64,
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
                  const EdgeInsets.all(14),


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

                          cart.name,


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

                          cart.favorite

                              ? Icons.favorite

                              : Icons.favorite_border,


                          color:

                          cart.favorite

                              ? Colors.red

                              : null,

                        ),


                        onPressed:
                            onFavorite,

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
                        width:4,
                      ),



                      Text(

                        cart.score
                            .toStringAsFixed(1),

                      ),





                      const SizedBox(
                        width:20,
                      ),




                      Text(

                        "${cart.visitsCount} ביקורים",

                      ),


                    ],

                  ),





                  const SizedBox(
                    height:8,
                  ),





                  Text(

                    cart.location,

                    maxLines:
                        1,


                    overflow:
                        TextOverflow.ellipsis,

                  ),






                  if(tags.isNotEmpty)

                    Padding(

                      padding:
                          const EdgeInsets.only(
                            top:10,
                          ),


                      child:

                      Wrap(

                        spacing:
                            6,


                        children:

                        tags.map(

                          (tag)=>

                          Chip(

                            label:
                                Text(tag),

                          ),

                        ).toList(),


                      ),

                    ),





                  const SizedBox(
                    height:8,
                  ),





                  Row(

                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,


                    children: [



                      TextButton.icon(

                        onPressed:
                            onAddVisit,


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
                            onNavigate,


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