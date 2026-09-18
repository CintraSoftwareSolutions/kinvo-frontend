import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/units/distance.dart';
import '../../../settings/presentation/controllers/settings_controllers.dart';
import '../../domain/profile_fields.dart';
import '../../domain/public_profile.dart';
import '../../domain/user_summary.dart';
import 'person_photo.dart';

/// The big photo at the top of someone's full profile, with their name, age
/// and whether they're verified.
class PublicProfilePhotoHeader extends StatelessWidget {
  const PublicProfilePhotoHeader({
    required this.user,
    required this.accent,
    super.key,
  });

  final UserSummary user;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PersonPhoto(
              url: user.photoUrl,
              name: user.displayName,
              color: accent,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xAA000000)],
                  stops: [0.55, 1],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      [
                        user.displayName,
                        if (user.age case final age?) '$age',
                      ].join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  if (user.isVerified) ...[
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 5),
                      child: Icon(
                        Icons.verified_rounded,
                        size: 20,
                        color: Color(0xFF60A5FA),
                        semanticLabel: 'Verified',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything on someone's full profile below the photo: where they are,
/// their work, bio, interests, prompts and lifestyle. Details they left out
/// aren't shown.
class PublicProfileDetails extends ConsumerWidget {
  const PublicProfileDetails({required this.profile, super.key});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unit = ref.watch(distanceUnitProvider);
    final place = [
      ?distanceAway(profile.distanceMetres, unit),
      if (profile.city case final city? when city.trim().isNotEmpty)
        city.trim(),
    ].join(' · ');
    final work = [
      if (profile.jobTitle case final job? when job.trim().isNotEmpty)
        job.trim(),
      if (profile.organisation case final org? when org.trim().isNotEmpty)
        org.trim(),
    ].join(' at ');
    final bio = profile.bio?.trim() ?? '';
    final lifestyle = [
      if (profile.education case final education?
          when education != 'prefer_not_to_say')
        (
          ProfileField.education.label,
          profileOptionLabel(ProfileField.education, education),
        ),
      for (final field in ProfileField.lifestyle)
        if (profile.lifestyle[field.apiName] case final value?
            when value != 'prefer_not_to_say')
          (field.label, profileOptionLabel(field, value)),
      if (profile.heightCm case final height?) ('Height', heightLabel(height)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (place.isNotEmpty) _Line(icon: Icons.place_outlined, text: place),
        if (work.isNotEmpty)
          _Line(icon: Icons.work_outline_rounded, text: work),
        if (bio.isNotEmpty) ...[
          const _Heading('About'),
          Text(
            bio,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textPrimary,
            ),
          ),
        ],
        if (profile.interests.isNotEmpty) ...[
          const _Heading('Interests'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final interest in profile.interests)
                InterestChip(label: interest.label),
            ],
          ),
        ],
        for (final prompt in profile.prompts) ...[
          const SizedBox(height: 14),
          PromptCard(question: prompt.question, answer: prompt.answer),
        ],
        if (lifestyle.isNotEmpty) ...[
          const _Heading('Lifestyle'),
          for (final (label, value) in lifestyle)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// An interest on a profile.
class InterestChip extends StatelessWidget {
  const InterestChip({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// A prompt and its answer, as a profile shows them.
class PromptCard extends StatelessWidget {
  const PromptCard({
    required this.question,
    required this.answer,
    this.trailing,
    super.key,
  });

  final String question;
  final String answer;

  /// Shown beside the question, such as an edit icon.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            answer,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
