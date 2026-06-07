import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.trending_up, size: 72, color: Color(0xFF00C853)),
            SizedBox(height: 24),
            Text(
              'AI Trading Coach',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your personal trading performance platform',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(color: Color(0xFF00C853)),
          ],
        ),
      ),
    );
  }
}
