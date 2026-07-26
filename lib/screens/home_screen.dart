import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../repositories/coffee_cart_repository.dart';
import '../widgets/coffee_cart_card.dart';

import 'add_cart_screen.dart';
import 'add_visit_screen.dart';
import 'cart_details_screen.dart';
import 'map_screen.dart';



class HomeScreen extends StatefulWidget {

  const HomeScreen({
    super.key,
  });


  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();

}





class _HomeScreenState
    extends State<HomeScreen> {


  String search = '';

  bool favoritesOnly = false;

  String sort = 'none';





  List filterCarts(List carts) {


    final result =
        carts.where((cart) {


      final text =
          search.toLowerCase();



      final matchSearch =
          text.isEmpty ||

          cart.name
              .toLowerCase()
              .contains(text)

          ||

          cart.location
              .toLowerCase()
              .contains(text);




      final matchFavorite =
          !favoritesOnly ||

          cart.favorite;



      return matchSearch && matchFavorite;


    }).toList();





    if(sort == 'score') {


      result.sort(

        (a,b) =>
            b.score.compareTo(a.score),

      );


    }





    if(sort == 'visits') {


      result.sort(

        (a,b) =>
            b.visitsCount.compareTo(a.visitsCount),

      );


    }




    return result;

  }








  Future<void> refresh() async {


    if(mounted) {

      setState(() {});

    }


  }







  Future<void> openNavigation(cart) async {


    if(cart.latitude == 0 ||
        cart.longitude == 0) {


      ScaffoldMessenger.of(context)
          .showSnackBar(

        const SnackBar(

          content:
              Text(
                "אין מיקום GPS לעגלה",
              ),

        ),

      );


      return;

    }



    final url = Uri.parse(

      "https://www.google.com/maps/search/?api=1&query=${cart.latitude},${cart.longitude}",

    );



    await launchUrl(

      url,

      mode:
          LaunchMode.externalApplication,

    );


  }








  Future<void> addVisit(cart) async {


    await Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) =>

            AddVisitScreen(

          cart:
              cart,

        ),

      ),

    );


    await refresh();


  }








  Future<void> toggleFavorite(cart) async {


    setState(() {


      cart.favorite =
          !cart.favorite;


    });



    await cart.save();


  }






  @override
  Widget build(BuildContext context) {


    return Scaffold(



      appBar: AppBar(

        title:
            const Text(
              "Coffee Diary",
            ),



        actions: [



          IconButton(

            icon:
                const Icon(
                  Icons.map,
                ),


            onPressed: () {


              Navigator.push(

                context,

                MaterialPageRoute(

                  builder: (_) =>
                      const MapScreen(),

                ),

              );


            },

          ),





          IconButton(

            icon:
                Icon(

              favoritesOnly

                  ? Icons.star

                  : Icons.star_border,

            ),



            onPressed: () {


              setState(() {


                favoritesOnly =
                    !favoritesOnly;


              });


            },


          ),
                    PopupMenuButton<String>(


            onSelected:(value){


              setState(() {


                sort =
                    value;


              });


            },



            itemBuilder:(context)=>[


              const PopupMenuItem(

                value:
                    'none',

                child:
                    Text(
                      "ללא מיון",
                    ),

              ),



              const PopupMenuItem(

                value:
                    'score',

                child:
                    Text(
                      "לפי ציון",
                    ),

              ),



              const PopupMenuItem(

                value:
                    'visits',

                child:
                    Text(
                      "לפי ביקורים",
                    ),

              ),


            ],


          ),


        ],


      ),









      floatingActionButton:

          FloatingActionButton.extended(


        icon:
            const Icon(
              Icons.add,
            ),



        label:
            const Text(
              "עגלה",
            ),




        onPressed:() async {



          await Navigator.push(

            context,

            MaterialPageRoute(

              builder: (_) =>
                  const AddCartScreen(),

            ),

          );



          await refresh();


        },


      ),









      body:


          ValueListenableBuilder(


            valueListenable:

                CoffeeCartRepository.listen(),



            builder:(context, box, child) {



              final allCarts =
                  box.values.toList();



              final carts =
                  filterCarts(
                    allCarts,
                  );



              debugPrint(
                "HOME BOX LENGTH: ${box.length}",
              );


              debugPrint(
                "HOME CARTS: ${box.values.map((e) => e.name).toList()}",
              );





              return Column(



                children: [





                  Padding(

                    padding:
                        const EdgeInsets.all(12),



                    child:

                    TextField(


                      textDirection:
                          TextDirection.rtl,



                      decoration:
                          const InputDecoration(

                        labelText:
                            "חיפוש עגלה",


                        prefixIcon:
                            Icon(
                              Icons.search,
                            ),


                        border:
                            OutlineInputBorder(),


                      ),



                      onChanged:(value){


                        setState(() {


                          search =
                              value;


                        });


                      },


                    ),


                  ),






                  Text(

                    "נמצאו ${carts.length} עגלות",

                  ),








                  Expanded(



                    child:


                    carts.isEmpty



                        ?



                    const Center(

                      child:
                          Text(
                            "אין עגלות עדיין",
                          ),

                    )



                        :



                    ListView.builder(



                      itemCount:
                          carts.length,



                      itemBuilder:(context,index){



                        final cart =
                            carts[index];



                        return CoffeeCartCard(



                          cart:
                              cart,



                          onTap:() async {



                            await Navigator.push(


                              context,


                              MaterialPageRoute(


                                builder: (_) =>


                                    CartDetailsScreen(

                                  cart:
                                      cart,

                                ),


                              ),


                            );



                            await refresh();


                          },





                          onAddVisit:() async {


                            await addVisit(
                              cart,
                            );


                          },





                          onNavigate:() async {


                            await openNavigation(
                              cart,
                            );


                          },





                          onFavorite:() async {


                            await toggleFavorite(
                              cart,
                            );


                          },



                        );


                      },


                    ),



                  ),


                ],


              );


            },


          ),



    );


  }


}