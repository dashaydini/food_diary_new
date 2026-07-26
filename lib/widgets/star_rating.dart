import 'package:flutter/material.dart';


class StarRating extends StatelessWidget {


  final double rating;

  final double size;



  const StarRating({

    super.key,

    required this.rating,

    this.size = 28,

  });





  @override
  Widget build(BuildContext context) {


    final stars = <Widget>[];



    for(int i = 1; i <= 5; i++){


      if(rating >= i){

        stars.add(
          Icon(
            Icons.star,
            color: Colors.amber,
            size: size,
          ),
        );

      }


      else if(rating >= i - 0.5){


        stars.add(
          Icon(
            Icons.star_half,
            color: Colors.amber,
            size: size,
          ),
        );


      }


      else {


        stars.add(
          Icon(
            Icons.star_border,
            color: Colors.amber,
            size: size,
          ),
        );


      }


    }



    return Row(

      mainAxisSize:
          MainAxisSize.min,


      children:
          stars,

    );


  }


}