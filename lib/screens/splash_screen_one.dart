import 'package:flutter/material.dart';
import 'splash_screen_two.dart';

class SplashScreenOne extends StatefulWidget {
  const SplashScreenOne({super.key});

  @override
  State<SplashScreenOne> createState() => _SplashScreenOneState();
}

class _SplashScreenOneState extends State<SplashScreenOne>
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

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const SplashScreenTwo(),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Logo Liquid Galaxy
                Image.network(
                  'https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEjzI4JzY6oUy-dQaiW-HLmn5NQ7qiw7NUOoK-2cDU9cI6JwhPrNv0EkCacuKWFViEgXYrCFzlbCtHZQffY6a73j6_ATFjfeU7r6OxXxN5K8sGjfOlp3vvd6eCXZrozlu34fUG5_cKHmzZWa4axb-vJRKjLr2tryz0Zw30gTv3S0ET57xsCiD25WMPn3wA/s800/LIQUIDGALAXYLOGO.png',
                  height: 100,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 40),

                // Logo GDG Lleida Lab
                Image.network(
                  'https://res.cloudinary.com/startup-grind/image/upload/c_fill,w_500,h_500,g_center/c_fill,dpr_2.0,f_auto,g_center,q_auto:good/v1/gcs/platform-data-goog/chapter_banners/blob_K7l4gYM',
                  height: 100,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 40),

                // Logo Red List
                Image.network(
                  'https://upload.wikimedia.org/wikipedia/en/thumb/e/ec/IUCN_Red_List.svg/1280px-IUCN_Red_List.svg.png', 
                  height: 100,
                  fit: BoxFit.contain,
                ),

                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
