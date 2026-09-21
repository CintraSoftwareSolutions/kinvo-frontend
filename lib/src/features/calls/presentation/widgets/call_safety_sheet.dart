import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/call.dart';
import '../controllers/call_controller.dart';

/// The safety controls during a call (spec §5.7).
///
/// Every action is recorded whatever else happens, because the record is the
/// point: a pattern of flags against one account is what moderation acts on.
Future<void> showCallSafetySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _CallSafetySheet(),
  );
}

class _CallSafetySheet extends ConsumerStatefulWidget {
  const _CallSafetySheet();

  @override
  ConsumerState<_CallSafetySheet> createState() => _CallSafetySheetState();
}

class _CallSafetySheetState extends ConsumerState<_CallSafetySheet> {
  CallSafetyAction? _running;
  String? _outcome;
  String? _failure;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Safety',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Kinvo keeps a record of anything you use here. Nobody on the '
              'call is told.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (_outcome case final outcome?) _Message(text: outcome),
            if (_failure case final failure?)
              _Message(text: failure, isFailure: true),
            _Action(
              icon: Icons.flag_rounded,
              title: 'Flag this call',
              description:
                  'Records that something felt wrong. The call carries on.',
              busy: _running == CallSafetyAction.flag,
              onTap: () => _run(CallSafetyAction.flag),
            ),
            _Action(
              icon: Icons.shield_moon_rounded,
              title: 'Tell a trusted contact',
              description:
                  'Emails your trusted contacts that you are on this call.',
              busy: _running == CallSafetyAction.sendLiveUpdate,
              onTap: () => _run(CallSafetyAction.sendLiveUpdate),
            ),
            _Action(
              icon: Icons.report_rounded,
              title: 'End the call and report',
              description:
                  'Hangs up straight away and sends a report to Kinvo.',
              danger: true,
              busy: _running == CallSafetyAction.endAndReport,
              onTap: () => _run(CallSafetyAction.endAndReport),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _run(CallSafetyAction action) async {
    if (_running != null) return;
    setState(() {
      _running = action;
      _failure = null;
      _outcome = null;
    });

    try {
      final result = await ref
          .read(callControllerProvider.notifier)
          .recordSafetyAction(action);

      if (!mounted) return;

      if (result.callEnded) {
        // The call screen closes itself behind this sheet, so the sheet must
        // go too rather than sit over whatever is underneath.
        Navigator.of(context).pop();
        return;
      }

      setState(() {
        _running = null;
        _outcome = switch (action) {
          CallSafetyAction.flag => 'Noted. The call carries on.',
          CallSafetyAction.sendLiveUpdate =>
            'Sent. Your notifications say exactly who was emailed.',
          CallSafetyAction.endAndReport => 'Reported.',
        };
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _running = null;
        _failure = switch (error) {
          ApiErrorException(:final message) => message,
          _ => 'Could not reach Kinvo. Check your connection.',
        };
      });
    }
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.description,
    required this.busy,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool busy;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colour = danger ? AppColors.danger : AppColors.purple;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: danger ? AppColors.dangerSoft : AppColors.surfaceSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: busy
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : Icon(icon, color: colour, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: danger
                              ? AppColors.danger
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.isFailure = false});

  final String text;
  final bool isFailure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isFailure ? AppColors.dangerSoft : AppColors.greenSoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: isFailure ? AppColors.danger : AppColors.green,
          ),
        ),
      ),
    );
  }
}
