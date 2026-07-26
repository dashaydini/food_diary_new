import 'package:flutter/material.dart';

import '../repositories/coffee_cart_repository.dart';
import '../models/coffee_cart.dart';


class StatisticsScreen extends StatelessWidget {

  const StatisticsScreen({
    super.key,
  });



  @override
  Widget build(BuildContext context) {


    final carts =
        CoffeeCartRepository.getAll();



    final totalVisits =
        carts.fold<int>(
          0,
          (sum, cart) =>
              sum + cart.visitsCount,
        );



    CoffeeCart? bestCart;


    if(carts.isNotEmpty) {

      bestCart =
          carts.reduce(
            (a,b) =>
                a.score > b.score
                    ? a
                    : b,
          );

    }





    return Scaffold(

      appBar:
          AppBar(
            title:
                const Text(
                  "סטטיסטיקות",
                ),
          ),



      body:

          ListView(

        padding:
            const EdgeInsets.all(20),


        children: [



          _card(

            icon:
                Icons.coffee,


            title:
                "מספר עגלות",


            value:
                carts.length.toString(),

          ),




          _card(

            icon:
                Icons.restaurant,


            title:
                "סה״כ ביקורים",


            value:
                totalVisits.toString(),

          ),




          _card(

            icon:
                Icons.star,


            title:
                "ממוצע כללי",


            value:
                _average(carts),

          ),




          if(bestCart != null)

            _card(

              icon:
                  Icons.emoji_events,


              title:
                  "העגלה המובילה",


              value:
                  bestCart.name,

            ),



        ],

      ),

    );


  }





  Widget _card({

    required IconData icon,

    required String title,

    required String value,

  }) {


    return Card(

      child:
          Padding(

        padding:
            const EdgeInsets.all(20),


        child:
            Row(

          children: [


            Icon(
              icon,
              size:40,
            ),


            const SizedBox(
              width:20,
            ),



            Expanded(

              child:
                  Column(

                crossAxisAlignment:
                    CrossAxisAlignment.start,


                children: [


                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontSize:16,
                    ),
                  ),



                  const SizedBox(
                    height:6,
                  ),



                  Text(

                    value,


                    style:
                        const TextStyle(
                      fontSize:24,
                      fontWeight:
                          FontWeight.bold,
                    ),

                  ),


                ],

              ),

            ),

          ],

        ),

      ),

    );

  }






  String _average(
      List<CoffeeCart> carts,
      ) {


    if(carts.isEmpty) {

      return "0";

    }



    double total = 0;



    for(final cart in carts){

      total += cart.score;

    }



    return
        (total / carts.length)
            .toStringAsFixed(1);

  }


}