import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

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
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  bool _ready = false;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await AuthService.initializeGoogleSignIn();
      _subscription = AuthService.googleSignIn.authenticationEvents.listen(
        _handleEvent,
        onError: (Object error) {
          if (mounted && ModalRoute.of(context)?.isCurrent == true) {
            widget.onError(error);
          }
        },
      );
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      if (mounted) widget.onError(error);
    }
  }

  Future<void> _handleEvent(GoogleSignInAuthenticationEvent event) async {
    if (!mounted ||
        ModalRoute.of(context)?.isCurrent != true ||
        _processing ||
        event is! GoogleSignInAuthenticationEventSignIn) {
      return;
    }
    _processing = true;
    try {
      await widget.onStarted();
      await AuthService().completeGoogleSignIn(event.user);
      await widget.onAuthenticated();
    } catch (error) {
      widget.onError(error);
    } finally {
      _processing = false;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const SizedBox(
        height: 50,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return SizedBox(
      height: 50,
      child: AbsorbPointer(
        absorbing: widget.loading || _processing,
        child: Opacity(
          opacity: widget.loading || _processing ? 0.55 : 1,
          child: Center(
            child: google_web.renderButton(
              configuration: google_web.GSIButtonConfiguration(
                type: google_web.GSIButtonType.standard,
                theme: google_web.GSIButtonTheme.outline,
                size: google_web.GSIButtonSize.large,
                text: widget.signUp
                    ? google_web.GSIButtonText.signupWith
                    : google_web.GSIButtonText.continueWith,
                shape: google_web.GSIButtonShape.rectangular,
                logoAlignment: google_web.GSIButtonLogoAlignment.left,
                minimumWidth: 320,
                locale: 'he',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
