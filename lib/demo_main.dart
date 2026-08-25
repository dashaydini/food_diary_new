import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'screens/chat_screen.dart';
import 'theme/colors.dart';

void main() => runApp(const LogoDemoApp());

class LogoDemoApp extends StatelessWidget {
  const LogoDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BITE THE WAY — Logo Demo',
      home: const LogoDemoScreen(),
    );
  }
}

class LogoDemoScreen extends StatelessWidget {
  const LogoDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('BITE THE WAY — Logo Demo'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // SVG wordmark/monogram
            SvgPicture.asset(
              'assets/logo/bite_the_way_logo.svg',
              width: 280,
              height: 280,
            ),
            const SizedBox(height: 24),
            // PNG fallback (if generated)
            Image.asset(
              'assets/logo/icon.png',
              width: 96,
              height: 96,
              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            const Text(
              'BITE THE WAY',
              style: TextStyle(
                color: AppColors.card,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.chat_bubble),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const ChatScreen())),
      ),
    );
  }
}
