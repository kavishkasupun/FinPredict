import 'package:flutter/material.dart';
import 'dart:ui'; // Required for ImageFilter and BackdropFilter

class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final double blur;
  final EdgeInsets? padding;
  final Color? baseColor;
  final Color? highlightColor;

  const GlassmorphicCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 20,
    this.blur = 10,
    this.padding,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            width: 1.5,
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: Stack(
          children: [
            // Blur effect
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      (baseColor ?? Colors.white).withOpacity(0.15),
                      (highlightColor ?? Colors.blueGrey).withOpacity(0.05),
                    ],
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: padding ?? const EdgeInsets.all(16.0),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
