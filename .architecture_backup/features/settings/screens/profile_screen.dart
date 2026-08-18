import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../authentication/services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService authService = AuthService();
  final ImagePicker imagePicker = ImagePicker();

  final TextEditingController nameController = TextEditingController();

  bool saving = false;

  User? get user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();

    nameController.text = user?.displayName ?? "";
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> editName() async {
    nameController.text = user?.displayName ?? "";

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            "עריכת שם משתמש",
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: "שם משתמש",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                "ביטול",
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  nameController.text.trim(),
                );
              },
              child: const Text(
                "שמירה",
              ),
            ),
          ],
        );
      },
    );

    if (newName == null || newName.trim().isEmpty) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await user?.updateDisplayName(
        newName.trim(),
      );

      await user?.reload();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "שגיאה בשמירת השם: $e",
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  Future<void> editPhoto() async {
    final picked = await imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 600,
      maxHeight: 600,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      saving = true;
    });

    try {
      final file = File(picked.path);

      // בשלב זה נשמור את התמונה מקומית
      // עד שנחבר Firebase Storage לתמונת הפרופיל.
      debugPrint(
        "PROFILE IMAGE: ${file.path}",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "התמונה נבחרה",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "שגיאה בבחירת התמונה: $e",
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "פרופיל",
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundImage: currentUser?.photoURL != null
                        ? NetworkImage(
                            currentUser!.photoURL!,
                          )
                        : null,
                    child: currentUser?.photoURL == null
                        ? const Icon(
                            Icons.person,
                            size: 55,
                          )
                        : null,
                  ),
                  IconButton(
                    onPressed: saving ? null : editPhoto,
                    icon: const Icon(
                      Icons.camera_alt,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 20,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentUser?.displayName ?? "משתמש",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: saving ? null : editName,
                    icon: const Icon(
                      Icons.edit,
                    ),
                  ),
                ],
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                currentUser?.email ?? "",
              ),
              const SizedBox(
                height: 40,
              ),
              if (saving) const CircularProgressIndicator(),
              if (!saving)
                FilledButton.icon(
                  icon: const Icon(
                    Icons.logout,
                  ),
                  label: const Text(
                    "התנתקות",
                  ),
                  onPressed: () async {
                    await authService.signOut();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
