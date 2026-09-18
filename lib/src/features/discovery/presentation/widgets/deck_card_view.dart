import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/units/distance.dart';
import '../../../profile/presentation/widgets/person_photo.dart';
import '../../domain/deck_card.dart';
import '../../domain/discovery_formatting.dart';

/// The card on show in the deck.
class DeckCardView extends StatelessWidget {
  const DeckCardView({
    required this.card,
    required this.modeLabel,
    required this.modeIcon,
    required this.modeColor,
    required this.interestLabel,
    required this.now,
    required this.onOpenProfile,
    this.distanceUnit = DistanceUnit.miles,
    this.onPreviousMode,
    this.onNextMode,
    super.key,
  });

  /// Interests shown on the card before the rest are counted as "+2".
  static const shownInterests = 3;

  final DeckCard card;
  final String modeLabel;
  final String modeIcon;
  final Color modeColor;

  /// An interest's label, by its slug.
  final String Function(String slug) interestLabel;

  final DateTime now;
  final VoidCallback onOpenProfile;

  /// How the distance to them is shown.
  final DistanceUnit distanceUnit;

  /// Switch to the previous or next mode. Left out when there's only one.
  final VoidCallback? onPreviousMode;
  final VoidCallback? onNextMode;

  @override
  Widget build(BuildContext context) {
    final user = card.user;
    final distance = distanceAway(card.distanceMetres, distanceUnit);
    final activity = activityLabel(user, now: now);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 0.78,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Semantics(
              button: true,
              label: [
                user.displayName,
                if (user.age case final age?) '$age',
                ?distance,
                if (user.isVerified) 'verified',
                'Open full profile',
              ].join(', '),
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onOpenProfile,
                behavior: HitTestBehavior.opaque,
                child: PersonPhoto(
                  url: user.photoUrl,
                  name: user.displayName,
                  color: modeColor,
                ),
              ),
            ),
            const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x66000000),
                      Color(0xCC000000),
                    ],
                    stops: [0.45, 0.75, 1.0],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Badge(
                          color: modeColor,
                          leading: SvgPicture.asset(
                            modeIcon,
                            width: 11,
                            height: 11,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                          label: modeLabel,
                        ),
                        if (user.isVerified)
                          _Badge(
                            color: const Color(0xFF3B82F6),
                            leading: SvgPicture.asset(
                              AppAssets.shield,
                              width: 10,
                              height: 10,
                              colorFilter: const ColorFilter.mode(
                                Colors.white,
                                BlendMode.srcIn,
                              ),
                            ),
                            label: 'Verified',
                          ),
                        if (user.isPremium)
                          const _Badge(
                            gradient: LinearGradient(
                              colors: [Color(0xFFF59E0B), Color(0xFFEF8E0B)],
                            ),
                            leading: Icon(
                              Icons.workspace_premium_rounded,
                              size: 12,
                              color: Colors.white,
                            ),
                            label: 'Premium',
                          ),
                      ],
                    ),
                  ),
                  if (activity != null) ...[
                    const SizedBox(width: 8),
                    _ActivityBadge(label: activity, online: user.isOnline),
                  ],
                ],
              ),
            ),
            if (onPreviousMode case final onTap?)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: _SideButton(
                    icon: Icons.arrow_back_rounded,
                    label: 'Previous mode',
                    backgroundColor: Colors.black.withValues(alpha: 0.55),
                    onTap: onTap,
                  ),
                ),
              ),
            if (onNextMode case final onTap?)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: _SideButton(
                    icon: Icons.arrow_forward_rounded,
                    label: 'Next mode',
                    backgroundColor: modeColor,
                    onTap: onTap,
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: _CardBody(
                card: card,
                distance: distance,
                interestLabel: interestLabel,
                onOpenProfile: onOpenProfile,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.leading,
    required this.label,
    this.color,
    this.gradient,
  });

  final Widget leading;
  final String label;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        gradient: gradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 5),
          // Narrow cards and large text settings can't fit every label.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({required this.label, required this.online});

  final String label;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: online ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.card,
    required this.distance,
    required this.interestLabel,
    required this.onOpenProfile,
  });

  final DeckCard card;
  final String? distance;
  final String Function(String slug) interestLabel;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final user = card.user;
    final interests = card.interestSlugs;
    final hidden = interests.length - DeckCardView.shownInterests;
    final bio = card.bio?.trim() ?? '';

    return ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                    height: 1.05,
                  ),
                ),
              ),
              if (user.age case final age?) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '$age',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (distance != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  AppAssets.locationPin,
                  width: 12,
                  height: 12,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    distance!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (bio.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              bio,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ],
          if (interests.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final slug in interests.take(DeckCardView.shownInterests))
                  _Chip(label: interestLabel(slug)),
                if (hidden > 0) _Chip(label: '+$hidden more'),
              ],
            ),
          ],
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onOpenProfile,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(AppAssets.sparkle, width: 12, height: 12),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'Tap to see the full profile',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
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
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
