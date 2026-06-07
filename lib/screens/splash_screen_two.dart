import 'package:flutter/material.dart';
import 'connection_screen.dart';

class SplashScreenTwo extends StatefulWidget {
  const SplashScreenTwo({super.key});

  @override
  State<SplashScreenTwo> createState() => _SplashScreenTwoState();
}

class _SplashScreenTwoState extends State<SplashScreenTwo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
 
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
 
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const ConnectionScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }
 
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FadeTransition(
        opacity: _fade,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
 
                  // ── Hook question ────────────────────────────────
                  _HookQuestion(),

                  const Spacer(flex: 2),

                  // ── Circular loading spinner ─────────────────────
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFAAAAAA),
                      ),
                    ),
                  ),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Hook question with mixed text styles
// "Do you know that more than [47,000 species] are threatened
//  with extinction?"
// where the bracketed part is red.
// ──────────────────────────────────────────────────────────────
class _HookQuestion extends StatelessWidget {
  const _HookQuestion();

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: const TextSpan(
        style: TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 24,
          fontWeight: FontWeight.w400,
          height: 1.55,
          letterSpacing: 0.1,
        ),
        children: [
          TextSpan(text: 'Do you know that\nmore than\n'),
          TextSpan(
            text: '47,000 species',
            style: TextStyle(
              color: Color(0xFFCC0000),
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(text: ' are\nthreatened with\nextinction?'),
        ],
      ),
    );
  }
}