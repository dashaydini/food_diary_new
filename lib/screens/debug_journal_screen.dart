import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/premium_service.dart';

class DebugJournalScreen extends StatefulWidget {
  const DebugJournalScreen({super.key});

  @override
  State<DebugJournalScreen> createState() => _DebugJournalScreenState();
}

class _DebugJournalScreenState extends State<DebugJournalScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  Map<String, dynamic>? _user;
  bool _isPremium = false;
  String? _error;
  List<Map<String, dynamic>> _visits = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _client.auth.currentUser;

      if (user == null) {
        _user = null;
      } else {
        final appMeta = user.appMetadata;
        final userMeta = user.userMetadata;
        final role =
            ((appMeta as Map?)?['role']) ?? ((userMeta as Map?)?['role']);

        _user = {
          'id': user.id,
          'email': user.email,
          'aud': user.aud,
          'role': role,
        };
      }

      _isPremium = PremiumService.isPremium;

      if (user != null && !user.isAnonymous) {
        final rows = await _client
            .from('visits')
            .select('id, visit_date, notes, place_id, image_url')
            .eq('user_id', user.id)
            .order('visit_date', ascending: false)
            .limit(5);

        try {
          _visits = List<Map<String, dynamic>>.from(rows as List);
        } catch (_) {
          _visits = [];
        }
      } else {
        _visits = [];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Debug — Journal')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _loadDebugInfo,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                const SizedBox(width: 8),
                if (_client.auth.currentUser == null)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final creds = await showDialog<Map<String, String>>(
                        context: context,
                        builder: (c) {
                          final emailCtrl = TextEditingController();
                          final passCtrl = TextEditingController();
                          return AlertDialog(
                            title: const Text('Sign in (email/password)'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                    controller: emailCtrl,
                                    decoration: const InputDecoration(
                                        hintText: 'email')),
                                const SizedBox(height: 8),
                                TextField(
                                    controller: passCtrl,
                                    decoration: const InputDecoration(
                                        hintText: 'password'),
                                    obscureText: true),
                              ],
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.of(c).pop(null),
                                  child: const Text('Cancel')),
                              TextButton(
                                  onPressed: () => Navigator.of(c).pop({
                                        'email': emailCtrl.text.trim(),
                                        'password': passCtrl.text
                                      }),
                                  child: const Text('Sign in')),
                            ],
                          );
                        },
                      );

                      if (creds == null) return;

                      try {
                        setState(() {
                          _loading = true;
                          _error = null;
                        });
                        await _client.auth.signInWithPassword(
                            email: creds['email']!,
                            password: creds['password']!);
                        await _loadDebugInfo();
                      } catch (e) {
                        setState(() {
                          _error = e.toString();
                        });
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in'),
                  ),
                if (_client.auth.currentUser != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _client.auth.signOut();
                      await _loadDebugInfo();
                      setState(() {});
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
                ]
              ],
            ),
            const SizedBox(height: 12),
            Text('Current user:',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            _user == null
                ? const Text('No user (anonymous / not signed in)')
                : SelectableText(
                    const JsonEncoder.withIndent('  ').convert(_user)),
            const SizedBox(height: 12),
            Text('Premium:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(_isPremium ? 'Yes' : 'No'),
            const SizedBox(height: 12),
            Text('Visits (latest 5):',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            if (_loading) const LinearProgressIndicator(minHeight: 3),
            Expanded(
              child: _visits.isEmpty
                  ? const Text('No visits found for this user.')
                  : ListView.builder(
                      itemCount: _visits.length,
                      itemBuilder: (c, i) {
                        final v = _visits[i];
                        return Card(
                          child: ListTile(
                            title: Text(v['place_id']?.toString() ?? '—'),
                            subtitle: Text(v['visit_date']?.toString() ?? ''),
                            trailing: Text(v['id']?.toString() ?? ''),
                          ),
                        );
                      },
                    ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text('Error: $_error', style: const TextStyle(color: Colors.red)),
            ]
          ],
        ),
      ),
    );
  }
}
