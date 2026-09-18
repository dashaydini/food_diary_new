import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';

class GoogleAuthButton extends StatefulWidget {
  const GoogleAuthButton({
    super.key,
    required this.label,
    required this.onStarted,
    required this.onAuthenticated,
    required this.onError,
    this.loading = false,
    this.signUp = false,
  });

  final String label;
  final Future<void> Function() onStarted;
  final Future<void> Function() onAuthenticated;
  final void Function(Object error) onError;
  final bool loading;
  final bool signUp;

  @override
  State<GoogleAuthButton> createState() => _GoogleAuthButtonState();
}

class _GoogleAuthButtonState extends State<GoogleAuthButton> {
  Future<void> _authenticate() async {
    try {
      await widget.onStarted();
      await AuthService().signInWithGoogle();
      await widget.onAuthenticated();
    } catch (error) {
      widget.onError(error);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 50,
        child: OutlinedButton(
          onPressed: widget.loading ? null : _authenticate,
          child: Text(widget.label, style: const TextStyle(fontSize: 15)),
        ),
      );
}
