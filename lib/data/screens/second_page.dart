import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tranoo_pro/data/screens/inscription_page.dart';
import 'package:tranoo_pro/l10n/app_localizations.dart';

class SecondPage extends StatefulWidget {
  const SecondPage({super.key});

  @override
  SecondPageState createState() => SecondPageState();
}

class SecondPageState extends State<SecondPage>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _animationController;
  int _currentImageIndex = 0;
  final List<String> _images = [
    'assets/images/voiture_deuxieme_page.png',
    'assets/images/voiture_deuxieme_page.png',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _startImageSlideshow();
  }

  void _startImageSlideshow() {
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      _nextImage();
    });
  }

  void _nextImage() {
    if (!mounted) return;
    setState(() {
      _currentImageIndex = (_currentImageIndex + 1) % _images.length;
    });
    
    // Continuer le défilement
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _nextImage();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 📸 Images d'arrière-plan qui défilent
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: Container(
              key: ValueKey(_currentImageIndex),
              decoration: BoxDecoration(
                color: Colors.white,
                image: DecorationImage(
                  image: AssetImage(_images[_currentImageIndex]),
                  fit: BoxFit.contain,
                  scale: 1.05,
                ),
              ),
            ),
          ),

          // Légère couche blanche pour conserver l'effet "splash pro"
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.white.withAlpha(80), Colors.white.withAlpha(20)],
              ),
            ),
          ),

          // 📄 Texte et bouton
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 30.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Tranoo Pro\nGérez vos ventes et\nservices pro',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 🔘 Bouton fléché
                Row(
                  children: [
                    Expanded(child: SizedBox()),
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xffF8BF13).withAlpha(50),
                            spreadRadius: 0,
                            blurRadius: 50,
                            offset: Offset(2, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () async {
                          // Marquer l'onboarding comme vu
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('hasSeenOnboarding', true);

                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const InscriptionPage(),
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.arrow_circle_right,
                          color: Color(0xffF8BF13),
                          size: 60,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


