import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../profile/domain/user_summary.dart';
import '../../../profile/presentation/widgets/person_photo.dart';

/// What the user chose in the match dialog.
enum MatchDialogChoice { keepGoing, seeMatches }

/// Celebrates a new match with [user] in the mode called [modeLabel].
///
/// Resolves to `null` if the dialog is dismissed without choosing.
Future<MatchDialogChoice?> showMatchDialog(
  BuildContext context, {
  required UserSummary user,
  required String modeLabel,
  required Color modeColor,
  required Color modeSoftColor,
}) {
  return showGeneralDialog<MatchDialogChoice>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => MatchDialog(
      user: user,
      modeLabel: modeLabel,
      modeColor: modeColor,
      modeSoftColor: modeSoftColor,
    ),
    transitionBuilder: (_, animation, _, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
          child: child,
        ),
      );
    },
  );
}

class MatchDialog extends StatelessWidget {
  const MatchDialog({
    required this.user,
    required this.modeLabel,
    required this.modeColor,
    required this.modeSoftColor,
    super.key,
  });

  final UserSummary user;
  final String modeLabel;
  final Color modeColor;
  final Color modeSoftColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 28,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            // As AlertDialog does, so screen readers announce the dialog by
            // name when it opens.
            child: Semantics(
              scopesRoute: true,
              explicitChildNodes: true,
              namesRoute: true,
              label: "It's a match",
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: modeSoftColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: modeColor, width: 2),
                    ),
                    child: ClipOval(
                      child: PersonPhoto(
                        url: user.photoUrl,
                        name: user.displayName,
                        color: modeColor,
                        initialSize: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    "It's a match!",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You and ${user.displayName} liked each other in '
                    '$modeLabel.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pop(MatchDialogChoice.seeMatches),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('See your matches'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(MatchDialogChoice.keepGoing),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Keep discovering',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
