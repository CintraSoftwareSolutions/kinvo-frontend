import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/call_ringtone_controller.dart';

/// The ringtone an incoming call rings with, and the way to change it.
///
/// Tapping it opens the phone's own ringtone chooser, so the list is the one
/// the person already knows — their own ringtones, including anything they
/// have added. On an iPhone there is no such chooser to open, and the row says
/// so instead of offering a button that cannot work.
class CallRingtoneRow extends ConsumerWidget {
  const CallRingtoneRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ringtone = ref.watch(callRingtoneProvider);

    // A Material rather than a decorated box, so the row's ripple shows on the
    // card instead of being painted underneath it.
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: switch (ringtone) {
        AsyncValue(value: final ringtone?) => _Row(ringtone: ringtone),
        AsyncValue(error: _?) => const ListTile(
          title: Text('Call ringtone'),
          subtitle: Text(
            'Could not read your ringtones. Calls ring with your default.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        _ => const ListTile(
          title: Text('Call ringtone'),
          subtitle: Text('Reading…', style: TextStyle(fontSize: 12)),
        ),
      },
    );
  }
}

class _Row extends ConsumerWidget {
  const _Row({required this.ringtone});

  final CallRingtone ringtone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(callRingtoneProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          leading: const Icon(
            Icons.music_note_rounded,
            color: AppColors.purple,
          ),
          title: const Text(
            'Call ringtone',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            ringtone.canChoose
                ? ringtone.title
                : 'Your iPhone decides what a call sounds like.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: ringtone.canChoose
              ? const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                )
              : null,
          onTap: ringtone.canChoose ? controller.choose : null,
        ),
        if (ringtone.canChoose && !ringtone.isDefault)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: controller.useDefault,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.purple,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Use my phone’s ringtone',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            'A call rings with this, and follows your phone: silent stays '
            'silent, vibrate only vibrates.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
