import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../domain/models/app_user.dart';

BoxDecoration passportDecoration({required bool isOpen}) {
  return BoxDecoration(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(isOpen ? 0 : 6),
      bottomLeft: Radius.circular(isOpen ? 0 : 6),
      topRight: Radius.circular(isOpen ? 0 : 24),
      bottomRight: Radius.circular(isOpen ? 0 : 24),
    ),
    gradient: const LinearGradient(
      colors: [AppColors.navyDark, AppColors.navy, AppColors.navyLight],
      stops: [0.0, 0.15, 1.0],
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    ),
    boxShadow: isOpen
        ? const []
        : [
            BoxShadow(color: AppColors.navy.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(10, 10)),
            const BoxShadow(color: Colors.white, offset: Offset(4, 0)),
            const BoxShadow(color: Color(0xFFE0E0E0), offset: Offset(5, 0)),
          ],
  );
}

/// Portada del pasaporte (identidad visual original del CMO).
class PassportCover extends StatelessWidget {
  const PassportCover({super.key, required this.user, required this.height});

  final AppUser user;
  final double height;

  @override
  Widget build(BuildContext context) {
    final mrzName = '${user.fullName.toUpperCase().replaceAll(' ', '<')}${'<' * 22}'.substring(0, 22);
    final mrzPass = user.passportNumber.replaceAll('-', '').padRight(12, '<');

    return Center(
      child: SizedBox(
        width: 280,
        height: height,
        child: Stack(
          children: [
            Positioned(
              left: 12,
              top: 20,
              bottom: 20,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  12,
                  (_) => Container(width: 2, height: 12, color: Colors.white.withValues(alpha: 0.15)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 35, right: 20, top: 30, bottom: 20),
              child: Column(
                children: [
                  const Text(
                    'PASAPORTE\nCENTRO MISIONERO OASIS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Image.asset(
                      'assets/images/cmo.png',
                      color: AppColors.gold,
                      errorBuilder: (_, _, _) => const Icon(Icons.public, color: AppColors.gold, size: 150),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.fullName.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'MISIONERO ACTIVO',
                    style: TextStyle(
                      color: AppColors.gold.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ExcludeSemantics(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('P<CMO<$mrzName', maxLines: 1, style: _mrzStyle),
                          Text('$mrzPass<4SLV<<<<<<<<<<<', maxLines: 1, style: _mrzStyle),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _mrzStyle = TextStyle(fontFamily: 'Courier', color: Colors.white60, fontSize: 11, letterSpacing: 1);
}
