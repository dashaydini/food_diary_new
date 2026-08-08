import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../repositories/firebase_coffee_cart_repository.dart';

import '../services/location_service.dart';

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



class _HomeScreenState extends State<HomeScreen> {


  final FirebaseCoffeeCartRepository firebaseRepository =
      FirebaseCoffeeCartRepository();



  final TextEditingController searchController =
      TextEditingController();



  String search = '';

  bool favoritesOnly = false;

  bool myContentOnly = false;

  String sort = 'none';

  Position? currentPosition;




  @override
  void initState(){

    super.initState();

    loadLocation();

  }





  Future<void> loadLocation() async {

    final position =
        await LocationService.getCurrentLocation();



    if(position != null && mounted){

      setState((){

        currentPosition = position;

      });

    }

  }





  @override
  void dispose(){

    searchController.dispose();

    super.dispose();

  }





  List filterCarts(List carts){


    final result =
    carts.where((cart){


      final text =
      search.trim().toLowerCase();



      bool matchSearch =
          text.isEmpty;




      if(!matchSearch){


        final searchable = <String>[

          cart.name,

          cart.location,

        ];



        for(final visit in cart.visits){


          searchable.add(
            visit.dish,
          );


          searchable.add(
            visit.notes,
          );


          searchable.addAll(
            visit.tags,
          );

        }




        matchSearch =
            searchable.any(

                  (item) =>
                  item
                      .toLowerCase()
                      .contains(text),

            );


      }




      final matchFavorite =
          !favoritesOnly ||
              cart.favorite;





        final matchOwner =
            !myContentOnly ||
            cart.ownerId ==
                FirebaseAuth.instance.currentUser?.uid;
        return matchSearch && matchFavorite && matchOwner;



    }).toList();





    if(sort == 'score'){


      result.sort(

            (a,b) =>
            b.score.compareTo(
              a.score,
            ),

      );

    }




    if(sort == 'visits'){


      result.sort(

            (a,b) =>
            b.visitsCount.compareTo(
              a.visitsCount,
            ),

      );

    }





    if(sort == 'distance' &&
        currentPosition != null){


      result.sort(

            (a,b){


          final distanceA =
          Geolocator.distanceBetween(

            currentPosition!.latitude,

            currentPosition!.longitude,

            a.latitude,

            a.longitude,

          );



          final distanceB =
          Geolocator.distanceBetween(

            currentPosition!.latitude,

            currentPosition!.longitude,

            b.latitude,

            b.longitude,

          );



          return distanceA.compareTo(
            distanceB,
          );


        },

      );

    }



    return result;

  }





  Future<void> refresh() async {

    if(mounted){

      setState((){});

    }

  }





  Future<void> openNavigation(cart) async {


    if(cart.latitude == 0 ||
        cart.longitude == 0){


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
      
      if (FirebaseAuth.instance.currentUser?.isAnonymous == true) {
        return;
      }


    await Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) =>
            AddVisitScreen(
              cart: cart,
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



    await firebaseRepository.updateCoffeeCart(

      cart,

    );


  }





  @override
  Widget build(BuildContext context) {


    return Scaffold(


      appBar:

      AppBar(

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


            onPressed:(){


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


            onPressed:(){

              setState(() {

                favoritesOnly =
                    !favoritesOnly;

              });

            },

          ),






            IconButton(
              icon:
                Icon(
                  myContentOnly
                      ? Icons.person
                      : Icons.groups,

                  color:
                      myContentOnly
                          ? Theme.of(context).colorScheme.primary
                          : null,
                ),

                tooltip:
                    myContentOnly
                        ? 'הצג את כולם'
                        : 'הצג רק שלי',

              onPressed:(){

                setState(() {

                  myContentOnly =
                      !myContentOnly;

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



              const PopupMenuItem(

                value:
                'distance',

                child:
                Text(
                  "לפי מרחק",
                ),

              ),


            ],


          ),


        ],

      ),






      floatingActionButton:


      FirebaseAuth.instance.currentUser?.isAnonymous == true
        ? null
        : FloatingActionButton.extended(


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


      StreamBuilder<List<dynamic>>(


        stream:

        firebaseRepository.getCoffeeCarts(),





        builder:(context, snapshot){



          if(snapshot.connectionState ==
              ConnectionState.waiting){


            return const Center(

              child:

              CircularProgressIndicator(),

            );


          }






          final allCarts =

              snapshot.data ?? [];







          final carts =

          filterCarts(

            allCarts,

          );








          return Column(



            children: [




              Padding(


                padding:

                const EdgeInsets.all(12),





                child:


                TextField(



                  controller:

                  searchController,




                  textDirection:

                  TextDirection.rtl,




                  decoration:


                  InputDecoration(



                    labelText:

                    "חיפוש עגלה",





                    prefixIcon:

                    const Icon(

                      Icons.search,

                    ),





                    suffixIcon:

                    search.isNotEmpty

                        ?

                    IconButton(

                      icon:

                      const Icon(

                        Icons.clear,

                      ),


                      onPressed:(){


                        searchController.clear();



                        setState(() {


                          search = '';

                        });



                      },

                    )

                        :

                    null,





                    border:

                    const OutlineInputBorder(),



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

                                myContentOnly:
                                    myContentOnly,



                            ),



                          ),



                        );



                        await refresh();



                      },






                      onAddVisit:
                            FirebaseAuth.instance.currentUser?.isAnonymous == true
                                ? null
                                : () async {

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
