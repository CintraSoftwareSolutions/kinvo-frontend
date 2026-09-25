import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../safety/domain/trusted_contact.dart';
import '../../../safety/presentation/controllers/trusted_contacts_controllers.dart';
import '../../../safety/presentation/widgets/contact_outcome_row.dart';
import '../../domain/plan.dart';
import '../controllers/plans_controllers.dart';

/// Emails a confirmed [plan] to the trusted contacts the user picks: who
/// they're meeting, where and when.
Future<void> showSharePlanSheet(BuildContext context, Plan plan) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _SharePlanSheet(plan: plan),
  );
}

class _SharePlanSheet extends ConsumerStatefulWidget {
  const _SharePlanSheet({required this.plan});

  final Plan plan;

  @override
  ConsumerState<_SharePlanSheet> createState() => _SharePlanSheetState();
}

class _SharePlanSheetState extends ConsumerState<_SharePlanSheet> {
  final Set<String> _chosen = {};
  bool _sending = false;
  PlanShare? _shared;
  String? _error;

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
              'Tell a trusted contact',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "We'll email them that you're meeting "
              '${widget.plan.user.displayName}, and where and when.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            ...switch (_shared) {
              final shared? => _result(shared),
              null => _choosing(),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _choosing() {
    final contacts = ref.watch(trustedContactsProvider);
    return switch (contacts) {
      AsyncValue(value: final contacts?) when contacts.isEmpty => [
        const Text(
          "You haven't added any trusted contacts yet.",
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.push(AppRoutes.trustedContacts);
          },
          style: _outlined,
          child: const Text('Add a trusted contact'),
        ),
      ],
      AsyncValue(value: final contacts?) => [
        for (final contact in contacts) _choice(contact),
        if (_error case final message?) ...[
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 13, color: AppColors.danger),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _chosen.isEmpty || _sending ? null : _send,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.purple,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: const StadiumBorder(),
          ),
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Text('Send'),
        ),
      ],
      AsyncValue(hasError: true) => [
        const Text(
          "Your trusted contacts didn't load.",
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        TextButton(
          onPressed: () => ref.invalidate(trustedContactsProvider),
          child: const Text('Try again'),
        ),
      ],
      _ => [
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    };
  }

  Widget _choice(TrustedContact contact) {
    return CheckboxListTile(
      value: _chosen.contains(contact.id),
      onChanged: contact.canBeAlerted && !_sending
          ? (chosen) => setState(() {
              if (chosen ?? false) {
                _chosen.add(contact.id);
              } else {
                _chosen.remove(contact.id);
              }
            })
          : null,
      contentPadding: EdgeInsets.zero,
      activeColor: AppColors.purple,
      title: Text(
        contact.name,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        contact.email ?? 'No email address',
        style: const TextStyle(fontSize: 12.5),
      ),
    );
  }

  List<Widget> _result(PlanShare shared) {
    return [
      if (shared.contacts.isEmpty)
        const Text(
          'Nobody was emailed.',
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
        )
      else
        for (final contact in shared.contacts)
          ContactOutcomeRow(alert: contact),
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

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final result = await ref
        .read(planActionsProvider)
        .share(widget.plan, _chosen.toList());
    if (!mounted) return;
    setState(() {
      _sending = false;
      _shared = result.shared;
      _error = result.error;
    });
  }

  static final _outlined = OutlinedButton.styleFrom(
    foregroundColor: AppColors.textPrimary,
    side: const BorderSide(color: AppColors.divider),
    padding: const EdgeInsets.symmetric(vertical: 13),
    shape: const StadiumBorder(),
  );
}
