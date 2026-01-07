import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onAnimationComplete;

  const SplashScreen({super.key, required this.onAnimationComplete});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _animationLoaded = false;
  bool _animationError = false;

  @override
  void initState() {
    super.initState();
    _checkAnimationAsset();
    _startNavigationTimer();
  }

  _checkAnimationAsset() async {
    // Delay to check if animation loads properly
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_animationError) {
      setState(() {
        _animationLoaded = true;
      });
    }
  }

  _startNavigationTimer() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      widget.onAnimationComplete();
    }
  }

  Widget _buildFallbackAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFFBA002),
                  const Color(0xFFFFD166),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFBA002).withOpacity(0.5),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance_wallet,
              color: Colors.white,
              size: 70,
            ),
          ),
          const SizedBox(height: 20),
          // Pulsating animation
          TweenAnimationBuilder(
            tween: Tween<double>(begin: 1.0, end: 1.2),
            duration: const Duration(seconds: 1),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFFBA002).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // Background with fallback
          Positioned.fill(
            child: Container(
              color: const Color(0xFF0F172A),
              child: _animationLoaded && !_animationError
                  ? Lottie.asset(
                      'assets/animations/finance1.json',
                      fit: BoxFit.cover,
                      repeat: true,
                      animate: true,
                      errorBuilder: (context, error, stackTrace) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!_animationError) {
                            setState(() {
                              _animationError = true;
                            });
                          }
                        });
                        return _buildFallbackAnimation();
                      },
                    )
                  : _buildFallbackAnimation(),
            ),
          ),

          // Content Overlay
          Center(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0F172A).withOpacity(0.85),
                    const Color(0xFF0F172A).withOpacity(0.95),
                    const Color(0xFF0F172A),
                  ],
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated Logo with Lottie or Fallback
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withOpacity(0.7),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFBA002).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _animationLoaded && !_animationError
                          ? Lottie.asset(
                              'assets/animations/finance1.json',
                              width: 140,
                              height: 140,
                              fit: BoxFit.contain,
                              repeat: true,
                              animate: true,
                              errorBuilder: (context, error, stackTrace) {
                                WidgetsBinding.instance
                                    .addPostFrameCallback((_) {
                                  if (!_animationError) {
                                    setState(() {
                                      _animationError = true;
                                    });
                                  }
                                });
                                return _buildLogoFallback();
                              },
                            )
                          : _buildLogoFallback(),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Animated Text with Glow Effect
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: AnimatedTextKit(
                      animatedTexts: [
                        TyperAnimatedText(
                          'FinPredict',
                          textStyle: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                blurRadius: 10,
                                color: Color(0xFFFBA002),
                              ),
                            ],
                          ),
                          speed: const Duration(milliseconds: 100),
                        ),
                      ],
                      totalRepeatCount: 1,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Subtitle with fade animation
                  AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(seconds: 2),
                    child: Text(
                      'AI-Powered Financial Management',
                      style: TextStyle(
                        color: const Color(0xFF94A3B8),
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Loading Indicator with Animation Sync
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFFFBA002),
                            ),
                            strokeWidth: 3,
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBA002),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFFBA002).withOpacity(0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Additional Info Text
                  const SizedBox(height: 30),
                  AnimatedOpacity(
                    opacity: 0.7,
                    duration: const Duration(seconds: 1),
                    child: Text(
                      'Loading your financial insights...',
                      style: TextStyle(
                        color: const Color(0xFF94A3B8).withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoFallback() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFBA002),
            const Color(0xFFFFD166),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.account_balance_wallet,
        color: Colors.white,
        size: 60,
      ),
    );
  }
}
