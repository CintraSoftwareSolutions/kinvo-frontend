import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/trusted_contact.dart';
import '../controllers/trusted_contacts_controllers.dart';
import 'contact_outcome_row.dart';

/// Asks the user to confirm an emergency alert, with a message if they want,
/// sends it, and shows exactly who was reached.
Future<void> showEmergencySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _EmergencySheet(),
  );
}

class _EmergencySheet extends ConsumerStatefulWidget {
  const _EmergencySheet();

  @override
  ConsumerState<_EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends ConsumerState<_EmergencySheet> {
  // Owned by the sheet, so it lasts until the sheet has finished closing.
  final _message = TextEditingController();
  bool _sending = false;
  EmergencyOutcome? _outcome;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
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
              ...switch (_outcome) {
                null => _confirming(),
                EmergencyRaised(:final alert) => _sent(alert),
                EmergencyNotSent(:final message) => _notSent(message),
              },
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _confirming() {
    return [
      const _Title('Alert your trusted contacts?'),
      const SizedBox(height: 6),
      const _Body(
        "We'll email everyone you've added with an email address that you need "
        'help, with roughly where you are.',
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _message,
        enabled: !_sending,
        maxLength: 500,
        maxLines: 3,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Add a message (optional)',
          border: OutlineInputBorder(),
        ),
      ),
      const SizedBox(height: 8),
      _DangerButton(
        label: 'Send alert',
        loading: _sending,
        onPressed: _sending ? null : _send,
      ),
      TextButton(
        onPressed: _sending ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
    ];
  }

  List<Widget> _sent(EmergencyAlert alert) {
    return [
      Semantics(liveRegion: true, child: _Title(alert.summary)),
      const SizedBox(height: 12),
      for (final contact in alert.contacts) ContactOutcomeRow(alert: contact),
      const SizedBox(height: 8),
      const _Body(
        "If you're in danger, call your local emergency number.",
        strong: true,
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.purple,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: const StadiumBorder(),
        ),
        child: const Text('Done'),
      ),
    ];
  }

  List<Widget> _notSent(String message) {
    return [
      Semantics(
        liveRegion: true,
        child: const _Title("Your alert wasn't sent"),
      ),
      const SizedBox(height: 6),
      _Body(message),
      const SizedBox(height: 6),
      const _Body(
        'Call someone you trust, or your local emergency number.',
        strong: true,
      ),
      const SizedBox(height: 16),
      _DangerButton(
        label: 'Try again',
        loading: _sending,
        onPressed: _sending ? null : _send,
      ),
      TextButton(
        onPressed: _sending ? null : () => Navigator.of(context).pop(),
        child: const Text('Close'),
      ),
    ];
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final outcome = await ref
        .read(emergencyAlerterProvider)
        .raise(note: _message.text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _outcome = outcome;
    });
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text, {this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13.5,
        height: 1.45,
        fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
        color: strong ? AppColors.textPrimary : AppColors.textSecondary,
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  const _DangerButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : Text(label),
    );
  }
}
