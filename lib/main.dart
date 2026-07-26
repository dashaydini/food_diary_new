import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'models/coffee_cart.dart';
import 'models/coffee_visit.dart';

import 'repositories/coffee_cart_repository.dart';

import 'services/firebase_sync_service.dart';

import 'screens/main_navigation_screen.dart';

import 'theme/app_theme.dart';



Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();



  await Firebase.initializeApp(

    options:
        DefaultFirebaseOptions.currentPlatform,

  );



  await Hive.initFlutter();



  if (!Hive.isAdapterRegistered(
      CoffeeCartAdapter().typeId)) {

    Hive.registerAdapter(
      CoffeeCartAdapter(),
    );

  }



  if (!Hive.isAdapterRegistered(
      CoffeeVisitAdapter().typeId)) {

    Hive.registerAdapter(
      CoffeeVisitAdapter(),
    );

  }



  await Hive.openBox<CoffeeCart>(

    CoffeeCartRepository.boxName,

  );



  await FirebaseSyncService()
      .syncCoffeeCarts();



  runApp(

    const CoffeeDiaryApp(),

  );

}





class CoffeeDiaryApp extends StatelessWidget {


  const CoffeeDiaryApp({

    super.key,

  });



  @override
  Widget build(BuildContext context) {


    return MaterialApp(


      title: 'Coffee Diary',


      debugShowCheckedModeBanner: false,


      theme:

          AppTheme.light(),


      home:

          const MainNavigationScreen(),


    );


  }


}