import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CherryLogo extends StatelessWidget {
  final double size;
  final Color color;

  const CherryLogo({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    final isWhite = color == Colors.white;
    final isRed = color == Colors.red;
    final cherryColor = isWhite
        ? Colors.white
        : (isRed ? Colors.red : AppColors.primary);
    final leafColor = isWhite
        ? Colors.white.withValues(alpha: 0.9)
        : (isRed ? Colors.green.shade600 : AppColors.secondary);
    final houseColor = isWhite ? Colors.white : color;

    final cherryRadius = size * 0.16;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Base house outline
          Icon(Icons.home_outlined, size: size, color: houseColor),
          // Cherry Leaf on the roof slope
          Positioned(
            top: size * 0.16,
            right: size * 0.24,
            child: Icon(Icons.eco, size: size * 0.28, color: leafColor),
          ),
          // Left cherry
          Positioned(
            bottom: size * 0.14,
            left: size * 0.28,
            child: Container(
              width: cherryRadius * 2,
              height: cherryRadius * 2,
              decoration: BoxDecoration(
                color: cherryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isWhite ? AppColors.primaryLight : Colors.white,
                  width: size * 0.03,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Right cherry
          Positioned(
            bottom: size * 0.16,
            right: size * 0.26,
            child: Container(
              width: cherryRadius * 2,
              height: cherryRadius * 2,
              decoration: BoxDecoration(
                color: cherryColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isWhite ? AppColors.primaryLight : Colors.white,
                  width: size * 0.03,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
