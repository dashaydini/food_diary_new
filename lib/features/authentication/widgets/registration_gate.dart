import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/registration_service.dart';
import '../screens/complete_registration_screen.dart';

/// Key this widget by authenticated user ID so account changes cannot reuse
/// another user's completed onboarding state.
class RegistrationGate extends StatefulWidget {
  const RegistrationGate({super.key, required this.child});
  final Widget child;
  @override
  State<RegistrationGate> createState() => _RegistrationGateState();
}

class _RegistrationGateState extends State<RegistrationGate> {
  final _service = RegistrationService(Supabase.instance.client);
  late Future<Map<String, dynamic>> _profile;

  @override
  void initState() {
    super.initState();
    _profile = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final profile = await _service.profile();
    if (profile['registration_completed'] == true) {
      unawaited(_service.applyPendingReferral());
    }
    return profile;
  }

  void _reload() {
    setState(() {
      _profile = _load();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Scaffold(
                body: Center(
                    child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('לא ניתן לבדוק את פרטי ההרשמה כרגע.'),
                TextButton(
                    onPressed: _reload, child: const Text('ניסיון נוסף')),
              ],
            )));
          }
          if (snapshot.data!['registration_completed'] != true) {
            return CompleteRegistrationScreen(
                profile: snapshot.data!, onCompleted: _reload);
          }
          return widget.child;
        },
      );
}
