import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/coffee_cart.dart';
import '../../repositories/firebase_coffee_cart_repository.dart';

class EditCoffeeCartScreen extends StatefulWidget {
  final CoffeeCart cart;

  const EditCoffeeCartScreen({
    super.key,
    required this.cart,
  });

  @override
  State<EditCoffeeCartScreen> createState() => _EditCoffeeCartScreenState();
}

class _EditCoffeeCartScreenState extends State<EditCoffeeCartScreen> {
  late TextEditingController nameController;
  late TextEditingController locationController;

  final ImagePicker picker = ImagePicker();

  late String imageBase64;
  late bool favorite;

  final FirebaseCoffeeCartRepository firebaseRepository =
      FirebaseCoffeeCartRepository();

  @override
  void initState() {
    super.initState();

    nameController = TextEditingController(
      text: widget.cart.name,
    );

    locationController = TextEditingController(
      text: widget.cart.location,
    );

    imageBase64 = widget.cart.imageBase64;
    favorite = widget.cart.favorite;
  }

  Future<void> pickImage() async {
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();

    setState(() {
      imageBase64 = base64Encode(bytes);
    });
  }

  Future<void> save() async {
    widget.cart.name = nameController.text.trim();
    widget.cart.location = locationController.text.trim();
    widget.cart.imageBase64 = imageBase64;
    widget.cart.favorite = favorite;

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

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('עריכת עגלה'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: pickImage,
            child: Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
              child: imageBase64.isEmpty
                  ? const Icon(
                      Icons.add_a_photo,
                      size: 60,
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.memory(
                        base64Decode(imageBase64),
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'שם העגלה',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: locationController,
            decoration: const InputDecoration(
              labelText: 'מיקום',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('מועדפת ⭐'),
            value: favorite,
            onChanged: (value) {
              setState(() {
                favorite = value;
              });
            },
          ),
          const SizedBox(height: 30),
          FilledButton(
            onPressed: save,
            child: const Text('שמירה'),
          ),
        ],
      ),
    );
  }
}
