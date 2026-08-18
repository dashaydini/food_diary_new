import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/authentication/screens/login_screen.dart';
import 'screens/category_selection_screen.dart';
import 'theme/app_theme.dart';
import 'utils/permissions.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qvqrretduhivnxrquzte.supabase.co',
    publishableKey: 'sb_publishable_sUSiHvHBVYZBsNDwHz49_A_QJ2vzDMP',
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  await Permissions.load();

  runApp(const FoodDiaryApp());
}

class FoodDiaryApp extends StatelessWidget {
  const FoodDiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Food Diary',
      theme: AppTheme.light,
      locale: const Locale('he', 'IL'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Stream<AuthState> _authStream;
  Future<void>? _permissionsFuture;
  String? _permissionsUserId;

  @override
  void initState() {
    super.initState();
    _authStream = Supabase.instance.client.auth.onAuthStateChange;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        Supabase.instance.client.auth.currentSession,
      ),
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        if (session == null) {
          _permissionsFuture = null;
          _permissionsUserId = null;
          return const LoginScreen();
        }

        if (_permissionsUserId != session.user.id) {
          _permissionsUserId = session.user.id;
          _permissionsFuture = Permissions.load();
        }

        return FutureBuilder<void>(
          future: _permissionsFuture,
          builder: (context, permissionsSnapshot) {
            if (permissionsSnapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            return const CategorySelectionScreen();
          },
        );
      },
    );
  }
}
