import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/coffee_visit.dart';



class CoffeeVisitCard extends StatelessWidget {


  final CoffeeVisit visit;

  final VoidCallback? onEdit;

  final VoidCallback? onDelete;



  const CoffeeVisitCard({

    super.key,

    required this.visit,

    this.onEdit,

    this.onDelete,

  });







  Widget stars(double score){


    final widgets = <Widget>[];


    final value =
        score / 2;



    for(int i = 1; i <= 5; i++){


      if(value >= i){

        widgets.add(

          const Icon(

            Icons.star,

            color:
                Colors.amber,

            size:
                22,

          ),

        );

      }


      else if(value >= i - 0.5){


        widgets.add(

          const Icon(

            Icons.star_half,

            color:
                Colors.amber,

            size:
                22,

          ),

        );


      }


      else {


        widgets.add(

          const Icon(

            Icons.star_border,

            color:
                Colors.amber,

            size:
                22,

          ),

        );


      }


    }


    return Row(

      mainAxisSize:
          MainAxisSize.min,


      children:
          widgets,

    );


  }








  Widget scoreLine(

      String title,

      double value,

      IconData icon,

      ){



    return Padding(

      padding:
          const EdgeInsets.symmetric(
            vertical:3,
          ),


      child:

      Row(

        children: [



          Icon(

            icon,

            size:
                18,

          ),




          const SizedBox(
            width:6,
          ),




          Expanded(

            child:

            Text(title),

          ),




          Text(

            value.toStringAsFixed(1),

            style:
                const TextStyle(

              fontWeight:
                  FontWeight.bold,

            ),

          ),



        ],


      ),

    );


  }









  String dateText(){


    return "${visit.date.day.toString().padLeft(2,'0')}/"
        "${visit.date.month.toString().padLeft(2,'0')}/"
        "${visit.date.year}";


  }









  @override
  Widget build(BuildContext context) {


    return Card(


      elevation:
          3,


      margin:
          const EdgeInsets.symmetric(
            vertical:8,
          ),




      child:

      InkWell(


        onTap:
            onEdit,



        borderRadius:
            BorderRadius.circular(15),



        child:

        Padding(

          padding:
              const EdgeInsets.all(12),



          child:

          Column(

            crossAxisAlignment:
                CrossAxisAlignment.start,


            children: [





              if(visit.imageBase64.isNotEmpty)


                ClipRRect(

                  borderRadius:
                      BorderRadius.circular(15),


                  child:

                  Image.memory(

                    base64Decode(

                      visit.imageBase64,

                    ),


                    height:
                        180,


                    width:
                        double.infinity,


                    fit:
                        BoxFit.cover,


                  ),


                ),






              const SizedBox(
                height:12,
              ),





              Row(

                children: [



                  Expanded(

                    child:

                    Text(

                      visit.dish.isEmpty

                          ? "ללא שם מנה"

                          :

                      visit.dish,


                      style:
                          const TextStyle(

                        fontSize:
                            20,

                        fontWeight:
                            FontWeight.bold,

                      ),

                    ),

                  ),





                  Text(

                    dateText(),

                    style:
                        TextStyle(

                      color:
                          Colors.grey.shade600,

                    ),

                  ),



                ],

              ),






              const SizedBox(
                height:8,
              ),






              if(visit.notes.isNotEmpty)

                Text(
                  visit.notes,
                ),






              const SizedBox(
                height:12,
              ),






              scoreLine(

                "אוכל",

                visit.foodQuality,

                Icons.restaurant,

              ),




              scoreLine(

                "אווירה",

                visit.atmosphere,

                Icons.local_cafe,

              ),




              scoreLine(

                "שירות",

                visit.service,

                Icons.support_agent,

              ),




              scoreLine(

                "ניקיון",

                visit.cleanliness,

                Icons.cleaning_services,

              ),




              scoreLine(

                "מגוון",

                visit.variety,

                Icons.menu_book,

              ),




              scoreLine(

                "תמורה",

                visit.value,

                Icons.payments,

              ),






              const SizedBox(
                height:8,
              ),






              Row(

                children: [



                  stars(
                    visit.score,
                  ),



                  const SizedBox(
                    width:8,
                  ),




                  Text(

                    visit.score.toStringAsFixed(1),

                    style:
                        const TextStyle(

                      fontWeight:
                          FontWeight.bold,

                    ),

                  ),




                  const Spacer(),





                  if(onDelete != null)


                    IconButton(

                      icon:
                          const Icon(
                            Icons.delete_outline,
                          ),


                      onPressed:
                          onDelete,


                    ),



                ],

              ),






              if(visit.tags.isNotEmpty)


                Padding(

                  padding:
                      const EdgeInsets.only(
                        top:8,
                      ),


                  child:

                  Wrap(

                    spacing:
                        6,


                    children:

                    visit.tags.map(

                          (tag)=>

                          Chip(

                            label:
                                Text(tag),

                          ),

                    ).toList(),


                  ),

                ),



            ],


          ),


        ),


      ),


    );


  }


}