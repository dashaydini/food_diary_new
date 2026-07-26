import 'package:flutter/material.dart';



class CoffeeSearchBar extends StatelessWidget {


  final Function(String) onChanged;


  const CoffeeSearchBar({

    super.key,

    required this.onChanged,

  });



  @override
  Widget build(BuildContext context) {


    return TextField(


      onChanged: onChanged,


      decoration:

          const InputDecoration(


        hintText:
            "חיפוש עגלה או מקום...",


        prefixIcon:
            Icon(Icons.search),


      ),


    );


  }

}