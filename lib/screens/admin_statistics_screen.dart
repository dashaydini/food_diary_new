import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/colors.dart';
import '../widgets/home_button.dart';

class AdminStatisticsScreen extends StatefulWidget {
  const AdminStatisticsScreen({super.key});

  @override
  State<AdminStatisticsScreen> createState() => _AdminStatisticsScreenState();
}

class _AdminStatisticsScreenState extends State<AdminStatisticsScreen> {
  bool _loading = true;
  String? _error;
  int _users = 0;
  int _activeUsers = 0;
  int _places = 0;
  int _experiences = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<dynamic>([
        Supabase.instance.client.functions
            .invoke('admin-users', body: {'action': 'list'}),
        Supabase.instance.client.from('places').select('id'),
        Supabase.instance.client.from('visits').select('id'),
      ]);
      final response = results[0] as FunctionResponse;
      final data = Map<String, dynamic>.from(response.data as Map);
      final summary = Map<String, dynamic>.from(data['summary'] as Map);
      if (!mounted) return;
      setState(() {
        _users = (summary['registered'] as num?)?.toInt() ?? 0;
        _activeUsers = (summary['active_30d'] as num?)?.toInt() ?? 0;
        _places = (results[1] as List).length;
        _experiences = (results[2] as List).length;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'לא ניתן לטעון נתונים: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('סטטיסטיקות'),
        actions: const [HomeButton()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.champagne),
                )
              : _error != null
                  ? Center(child: Text(_error!))
                  : LayoutBuilder(
                      builder: (context, constraints) => GridView.count(
                        padding: const EdgeInsets.all(18),
                        crossAxisCount: constraints.maxWidth >= 700 ? 2 : 1,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 2.6,
                        children: [
                          _StatCard('משתמשים רשומים', '$_users'),
                          _StatCard('פעילים ב־30 יום', '$_activeUsers'),
                          _StatCard('מקומות', '$_places'),
                          _StatCard('חוויות ששותפו', '$_experiences'),
                          const _StatCard('הורדות', 'טרם מחובר'),
                          const _StatCard('פילוח גיאוגרפי', 'טרם נאסף'),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.champagne.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
