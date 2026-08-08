import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/coffee_cart.dart';
import '../models/coffee_visit.dart';
import '../repositories/firebase_coffee_cart_repository.dart';

class AddVisitScreen extends StatefulWidget {
  final CoffeeCart cart;
  final CoffeeVisit? existingVisit;
  final bool viewOnly;

  const AddVisitScreen({
    super.key,
    required this.cart,
    this.existingVisit,
    this.viewOnly = false,
  });

  @override
  State<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends State<AddVisitScreen> {
  final FirebaseCoffeeCartRepository firebaseRepository =
      FirebaseCoffeeCartRepository();

  final TextEditingController dishController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  final ImagePicker picker = ImagePicker();

  String imageBase64 = '';

  DateTime visitDate = DateTime.now();

  double atmosphere = 5;
  double cleanliness = 5;
  double service = 5;
  double foodQuality = 5;
  double variety = 5;
  double value = 5;

  List<String> tags = [];

  bool get readOnly {

  if (widget.viewOnly) {
    return true;
  }

  final user = FirebaseAuth.instance.currentUser;

  if (widget.existingVisit == null) {
    return false;
  }

  return widget.existingVisit!.userId != user?.uid;
}


bool saving = false;
  bool hasChanges = false;

  final List<String> allTags = [
    "טעים",
    "קפה מצוין",
    "מאפים טריים",
    "מתאים למשפחה",
    "נגישות",
    "ילדים",
    "נוף",
    "שקיעה",
    "ארוחת בוקר",
    "טבעוני",
    "עצירה בדרך",
    "חניה נוחה",
    "שווה נסיעה",
    "יקר",
  ];

  @override
  void initState() {
    super.initState();

    final visit = widget.existingVisit;

    if (visit != null) {
      dishController.text = visit.dish;
      notesController.text = visit.notes;

      atmosphere = visit.atmosphere;
      cleanliness = visit.cleanliness;
      service = visit.service;
      foodQuality = visit.foodQuality;
      variety = visit.variety;
      value = visit.value;

      imageBase64 = visit.imageBase64;
      visitDate = visit.date;

      tags = List<String>.from(visit.tags);
    }

    dishController.addListener(() {
      hasChanges = true;
    });

    notesController.addListener(() {
      hasChanges = true;
    });
  }

  @override
  void dispose() {
    dishController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<bool> confirmExit() async {
    if (!hasChanges || saving) {
      return true;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("לשמור שינויים?"),
        content: const Text("בוצעו שינויים שלא נשמרו."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, "cancel"),
            child: const Text("ביטול"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, "discard"),
            child: const Text("יציאה ללא שמירה"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, "save"),
            child: const Text("שמירה"),
          ),
        ],
      ),
    );

    if (result == "save") {
      await save();
      return false;
    }

    return result == "discard";
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final image = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        imageBase64 = base64Encode(bytes);
        hasChanges = true;
      });
    } catch (e) {
      debugPrint("IMAGE ERROR: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("שגיאה בבחירת תמונה: $e"),
          ),
        );
      }
    }
  }

  Future<void> chooseImage() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("מצלמה"),
              onTap: () {
                Navigator.pop(context);
                pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text("גלריה"),
              onTap: () {
                Navigator.pop(context);
                pickImage(ImageSource.gallery);
              },
            ),
          ],
        );
      },
    );
  }
    Future<void> save() async {

    if (readOnly) {

      Navigator.pop(context);

      return;

    }
    if (saving) {
      return;
    }

    if (dishController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("יש להכניס מה אכלת"),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      debugPrint("======================================");
      debugPrint("SAVE VISIT");
      debugPrint("Cart name: ${widget.cart.name}");
      debugPrint("Firebase ID: ${widget.cart.firebaseId}");
      debugPrint("Cart isInBox: ${widget.cart.isInBox}");
      debugPrint("User ID: ${user?.uid}");

      if (widget.existingVisit != null) {
        final visit = widget.existingVisit!;

        visit.dish = dishController.text.trim();
        visit.notes = notesController.text.trim();

        visit.atmosphere = atmosphere;
        visit.cleanliness = cleanliness;
        visit.service = service;
        visit.foodQuality = foodQuality;
        visit.variety = variety;
        visit.value = value;

        visit.imageBase64 = imageBase64;
        visit.tags = List<String>.from(tags);
        visit.date = visitDate;

        debugPrint("Existing visit updated.");
      } else {
        final newVisit = CoffeeVisit(
          dish: dishController.text.trim(),
          notes: notesController.text.trim(),
          atmosphere: atmosphere,
          cleanliness: cleanliness,
          service: service,
          foodQuality: foodQuality,
          variety: variety,
          value: value,
          imageBase64: imageBase64,
          tags: List<String>.from(tags),
          date: visitDate,
          userId: user?.uid ?? '',
          userName: user?.displayName ?? user?.email ?? 'משתמש',
          userEmail: user?.email ?? '',
          createdAt: DateTime.now(),
        );

        widget.cart.visits.add(newVisit);

        debugPrint("New visit added.");
        debugPrint("Visits count: ${widget.cart.visits.length}");
      }

      if (widget.cart.isInBox) {
        debugPrint("Saving cart to Hive...");
        await widget.cart.save();
        debugPrint("Cart saved to Hive.");
      } else {
        debugPrint("Cart is NOT in Hive Box - skipping Hive save.");
      }

      if (widget.cart.firebaseId.isNotEmpty) {
        debugPrint("Updating Firebase...");

        await firebaseRepository.updateCoffeeCart(
          widget.cart,
        );

        debugPrint("Firebase update completed.");
      } else {
        debugPrint("No Firebase ID - Firebase update skipped.");
      }

      hasChanges = false;

      debugPrint("SAVE VISIT SUCCESS");
      debugPrint("======================================");

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e, stackTrace) {
      debugPrint("======================================");
      debugPrint("SAVE VISIT ERROR");
      debugPrint("$e");
      debugPrint("STACK TRACE:");
      debugPrint("$stackTrace");
      debugPrint("======================================");

      if (mounted) {
        setState(() {
          saving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("השמירה נכשלה:\n$e"),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }
    Widget starPicker(
String title,
double currentValue,
Function(double) update,
) {

if (readOnly) {

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      Text(
        "$title: ${currentValue.toStringAsFixed(1)}",
        style: const TextStyle(
          fontSize: 16,
        ),
      ),

      Row(
        children: List.generate(
          5,
          (index) => Icon(
            index < currentValue.round()
                ? Icons.star
                : Icons.star_border,
            color: Colors.amber,
            size: 24,
          ),
        ),
      ),

    ],
  );

}


return Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [

Text(
"$title: ${currentValue.toStringAsFixed(1)}",
style: const TextStyle(
fontSize: 16,
),
),

Slider(
value: currentValue,
min: 0,
max: 5,
divisions: 10,
onChanged: saving
? null
: (newValue) {

setState(() {
update(newValue);
hasChanges = true;
});

},
),

],
);

}

@override
  Widget build(BuildContext context) {

    debugPrint("BUILD ADD VISIT SCREEN");
    debugPrint("existing user: ${widget.existingVisit?.userId}");
    debugPrint("current user: ${FirebaseAuth.instance.currentUser?.uid}");
debugPrint("READ ONLY VALUE: $readOnly");


    return Directionality(


      textDirection:

      TextDirection.rtl,



      child:

      PopScope(

    canPop: false,

    onPopInvokedWithResult: (didPop, result) async {

      if (didPop) {
        return;
      }

      if (readOnly || !hasChanges) {
        Navigator.pop(context);
        return;
      }

      final shouldExit = await confirmExit();

      if (shouldExit && context.mounted) {
        Navigator.pop(context);
      }

    },

    child:

    Scaffold(



        appBar:

        AppBar(



          title:

          Text(



            widget.existingVisit == null

                ? "הוספת ביקור"

                : readOnly

                    ? "צפייה בביקור"

                    : "עריכת ביקור",



          ),



        ),






        body:



        ListView(



          padding:

          const EdgeInsets.all(16),




          children: [






            imageBox(),






            const SizedBox(

              height:

              16,

            ),






            ListTile(



              leading:

              const Icon(

                Icons.calendar_today,

              ),



              title:

              const Text(

                "תאריך ביקור",

              ),



              subtitle:

              Text(



                "${visitDate.day}/${visitDate.month}/${visitDate.year}",



              ),



              onTap:

              pickDate,



            ),








            const SizedBox(

              height:

              10,

            ),






            TextField(



              controller:

              dishController,



              

                readOnly:

                readOnly,


                decoration:

              const InputDecoration(



                labelText:

                "מה אכלת?",



                border:

                OutlineInputBorder(),



              ),



            ),






            const SizedBox(

              height:

              12,

            ),







            TextField(



              controller:

              notesController,



              

                readOnly:

                readOnly,


                maxLines:

              3,



              decoration:

              const InputDecoration(



                labelText:

                "הערות",



                border:

                OutlineInputBorder(),



              ),



            ),







            const SizedBox(

              height:

              20,

            ),






            starPicker(



              "אוכל",



              foodQuality,



              (v){



                foodQuality =

                    v;



              },



            ),






            starPicker(



              "אווירה",



              atmosphere,



              (v){



                atmosphere =

                    v;



              },



            ),






            starPicker(



              "שירות",



              service,



              (v){



                service =

                    v;



              },



            ),






            starPicker(



              "ניקיון",



              cleanliness,



              (v){



                cleanliness =

                    v;



              },



            ),






            starPicker(



              "מגוון",



              variety,



              (v){



                variety =

                    v;



              },



            ),






            starPicker(



              "תמורה למחיר",



              value,



              (v){



                value =

                    v;



              },



            ),







            const SizedBox(

              height:

              20,

            ),






            const Text(



              "תגיות",



              style:

              TextStyle(



                fontSize:

                18,



                fontWeight:

                FontWeight.bold,



              ),



            ),








            const SizedBox(

              height:

              10,

            ),







            Wrap(



              spacing:

              8,



              runSpacing:

              8,



              children:



              (readOnly ? tags : allTags).map(



                    (tag){



                  return FilterChip(



                    label:

                    Text(tag),



                    selected:

                    tags.contains(tag),



                    onSelected:(selected){



                      setState((){



                        if(selected){



                          tags.add(tag);



                        }

                        else {



                          tags.remove(tag);



                        }



                      });



                    },



                  );



                },



              ).toList(),



            ),








            const SizedBox(

              height:

              30,

            ),







            if (!readOnly)

              FilledButton.icon(



              onPressed:

              save,



              icon:

              const Icon(

                Icons.save,

              ),



              label:

              const Text(

                "שמירה",

              ),



            ),





          ],



        ),



      ),



      ),
    );



  }


  Widget imageBox(){


    return GestureDetector(


      onTap:

      chooseImage,



      child:



      Container(



        height:

        220,



        width:

        double.infinity,



        decoration:

        BoxDecoration(



          color:

          Colors.grey.shade200,



          borderRadius:

          BorderRadius.circular(

            20,

          ),



        ),





        child:



        imageBase64.isEmpty



            ?



        const Icon(



          Icons.add_a_photo,



          size:

          60,



        )



            :



        ClipRRect(



          borderRadius:

          BorderRadius.circular(

            20,

          ),



          child:



          Image.memory(



            base64Decode(

              imageBase64,

            ),



            width:

            double.infinity,



            fit:

            BoxFit.cover,



          ),



        ),



      ),


    );


  }


  Future<void> pickDate() async {



    final result =

    await showDatePicker(



      context:

      context,



      initialDate:

      visitDate,



      firstDate:

      DateTime(2020),



      lastDate:

      DateTime.now(),



    );



    if(result != null){


      setState((){


        visitDate =

            result;



      });



    }



  }
}
