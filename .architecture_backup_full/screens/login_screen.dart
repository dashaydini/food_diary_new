// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "התחברות",
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Coffee Diary",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(
                height: 40,
              ),
              FilledButton.icon(
                icon: const Icon(
                  Icons.login,
                ),
                label: const Text(
                  "כניסה עם Google",
                ),
                onPressed: () async {
                  try {
                    final result = await authService.signInWithGoogle();

                    if (result == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "ההתחברות בוטלה",
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint(
                      "GOOGLE LOGIN ERROR: $e",
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          "שגיאת Google: $e",
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(
                height: 15,
              ),
              TextButton(
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Center(
                          child: Text(
                            "לתשומת ליבך",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        content: const Directionality(
                          textDirection: TextDirection.rtl,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                "התחברות במצב אורח מוגבלת לצפייה בעגלות קיימות "
                                "וקריאת ביקורות של משתמשים.",
                                textAlign: TextAlign.right,
                              ),
                              SizedBox(
                                height: 16,
                              ),
                              Text(
                                "* לא ניתן להוסיף עגלות חדשות.",
                                textAlign: TextAlign.right,
                              ),
                              SizedBox(
                                height: 8,
                              ),
                              Text(
                                "* לא ניתן לתעד ביקורים בעגלות קיימות.",
                                textAlign: TextAlign.right,
                              ),
                              SizedBox(
                                height: 8,
                              ),
                              Text(
                                "* לא ניתן להעלות חוות דעת או להגיב "
                                "למשתמשים רשומים.",
                                textAlign: TextAlign.right,
                              ),
                            ],
                          ),
                        ),
                        actionsAlignment: MainAxisAlignment.center,
                        actions: [
                          SizedBox(
                            width: 160,
                            height: 48,
                            child: FilledButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text(
                                "הבנתי",
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  if (!context.mounted) {
                    return;
                  }

                  final result = await authService.signInAnonymously();

                  if (result == null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("כניסת אורח נכשלה"),
                      ),
                    );
                  }
                },
                child: const Text(
                  "כניסה כאורח",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
