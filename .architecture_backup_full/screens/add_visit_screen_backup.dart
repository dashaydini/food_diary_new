import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/coffee_cart.dart';
import '../models/coffee_visit.dart';

import '../repositories/firebase_coffee_cart_repository.dart';

class AddVisitScreen extends StatefulWidget {
  final CoffeeCart cart;

  final CoffeeVisit? existingVisit;

  const AddVisitScreen({
    super.key,
    required this.cart,
    this.existingVisit,
  });

  @override
  State<AddVisitScreen> createState() => _AddVisitScreenState();
}

class _AddVisitScreenState extends State<AddVisitScreen> {
  final FirebaseCoffeeCartRepository firebaseRepository =
      FirebaseCoffeeCartRepository();

  final dishController = TextEditingController();

  final notesController = TextEditingController();

  final picker = ImagePicker();

  String imageBase64 = '';

  DateTime visitDate = DateTime.now();

  double atmosphere = 5;

  double cleanliness = 5;

  double service = 5;

  double foodQuality = 5;

  double variety = 5;

  double value = 5;

  List<String> tags = [];

  final List<String> allTags = [
    "טעים",
    "קפה מצוין",
    "מאפים טריים",
    "מתאים למשפחה",
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

      tags = List<String>.from(
        visit.tags,
      );
    }
  }

  Future<void> pickImage(ImageSource source) async {
    final image = await picker.pickImage(
      source: source,
      imageQuality: 80,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();

    setState(() {
      imageBase64 = base64Encode(
        bytes,
      );
    });
  }

  Future<void> chooseImage() async {
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                ),
                title: const Text(
                  "צלם תמונה",
                ),
                onTap: () {
                  Navigator.pop(context);

                  pickImage(
                    ImageSource.camera,
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo,
                ),
                title: const Text(
                  "בחר מהגלריה",
                ),
                onTap: () {
                  Navigator.pop(context);

                  pickImage(
                    ImageSource.gallery,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> save() async {
    if (dishController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "יש להכניס מה אכלת",
          ),
        ),
      );

      return;
    }

    if (widget.existingVisit != null) {
      final visit = widget.existingVisit!;

      visit.dish = dishController.text;

      visit.notes = notesController.text;

      visit.date = visitDate;

      visit.atmosphere = atmosphere;

      visit.cleanliness = cleanliness;

      visit.service = service;

      visit.foodQuality = foodQuality;

      visit.variety = variety;

      visit.value = value;

      visit.tags = tags;

      visit.imageBase64 = imageBase64;

      await visit.save();
    } else {
      widget.cart.visits.add(
        CoffeeVisit(
          date: visitDate,
          dish: dishController.text,
          notes: notesController.text,
          atmosphere: atmosphere,
          cleanliness: cleanliness,
          service: service,
          foodQuality: foodQuality,
          variety: variety,
          value: value,
          tags: List<String>.from(
            tags,
          ),
          imageBase64: imageBase64,
        ),
      );
    }

    await widget.cart.save();

    if (widget.cart.firebaseId.isNotEmpty) {
      await firebaseRepository.updateCoffeeCart(
        widget.cart,
      );
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Widget starPicker(
    String title,
    double value,
    Function(double) update,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$title: ${value.toStringAsFixed(1)}",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: List.generate(
            5,
            (index) {
              final star = index + 1.0;

              final half = index + 0.5;

              IconData icon;

              if (value >= star) {
                icon = Icons.star;
              } else if (value >= half) {
                icon = Icons.star_half;
              } else {
                icon = Icons.star_border;
              }

              return GestureDetector(
                onTapDown: (details) {
                  final position = details.localPosition.dx;

                  double newValue;

                  if (position < 12) {
                    newValue = half;
                  } else {
                    newValue = star;
                  }

                  setState(() {
                    update(
                      newValue,
                    );
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: Colors.amber,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(
          height: 10,
        ),
      ],
    );
  }

  Widget imageBox() {
    return GestureDetector(
      onTap: chooseImage,
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(
            20,
          ),
        ),
        child: imageBase64.isEmpty
            ? const Icon(
                Icons.add_a_photo,
                size: 60,
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(
                  20,
                ),
                child: Image.memory(
                  base64Decode(
                    imageBase64,
                  ),
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
      ),
    );
  }

  Future<void> pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: visitDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (result != null) {
      setState(() {
        visitDate = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existingVisit == null ? "הוספת ביקור" : "עריכת ביקור",
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            imageBox(),
            const SizedBox(
              height: 16,
            ),
            ListTile(
              leading: const Icon(
                Icons.calendar_today,
              ),
              title: const Text(
                "תאריך ביקור",
              ),
              subtitle: Text(
                "${visitDate.day}/${visitDate.month}/${visitDate.year}",
              ),
              onTap: pickDate,
            ),
            const SizedBox(
              height: 10,
            ),
            TextField(
              controller: dishController,
              decoration: const InputDecoration(
                labelText: "מה אכלת?",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(
              height: 12,
            ),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "הערות",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            starPicker(
              "אוכל",
              foodQuality,
              (v) {
                foodQuality = v;
              },
            ),
            starPicker(
              "אווירה",
              atmosphere,
              (v) {
                atmosphere = v;
              },
            ),
            starPicker(
              "שירות",
              service,
              (v) {
                service = v;
              },
            ),
            starPicker(
              "ניקיון",
              cleanliness,
              (v) {
                cleanliness = v;
              },
            ),
            starPicker(
              "מגוון",
              variety,
              (v) {
                variety = v;
              },
            ),
            starPicker(
              "תמורה למחיר",
              value,
              (v) {
                value = v;
              },
            ),
            const SizedBox(
              height: 20,
            ),
            const Text(
              "תגיות",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allTags.map(
                (tag) {
                  return FilterChip(
                    label: Text(tag),
                    selected: tags.contains(tag),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          tags.add(tag);
                        } else {
                          tags.remove(tag);
                        }
                      });
                    },
                  );
                },
              ).toList(),
            ),
            const SizedBox(
              height: 30,
            ),
            FilledButton.icon(
              onPressed: save,
              icon: const Icon(
                Icons.save,
              ),
              label: const Text(
                "שמירה",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
