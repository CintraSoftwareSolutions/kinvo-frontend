import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../assets/app_assets.dart';

/// The Kinvo heart mark, drawn in white for gradient backgrounds.
class KinvoLogo extends StatelessWidget {
  const KinvoLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Kinvo',
      image: true,
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            SvgPicture.asset(
              AppAssets.heartFill,
              width: 28,
              height: 26,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            Positioned(
              right: 2,
              top: 0,
              child: SvgPicture.asset(AppAssets.sparkle, width: 22, height: 22),
            ),
          ],
        ),
      ),
    );
  }
}
