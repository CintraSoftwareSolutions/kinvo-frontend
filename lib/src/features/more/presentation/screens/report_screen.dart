import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/config/server_config.dart';
import '../../../../core/media/photo_picker.dart';
import '../../../../core/media/photo_processing.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../../core/widgets/photo_source_sheet.dart';
import '../../../safety/data/safety_repository.dart';
import '../../../safety/presentation/controllers/report_controller.dart';

/// Reports someone: what happened, in the user's words, with screenshots, and
/// whether to block them too. Closes with the [ReportResult].
///
/// Without a [target] it explains where reporting starts, since a report has
/// to be about someone.
class ReportScreen extends StatelessWidget {
  const ReportScreen({this.target, super.key});

  final ReportTarget? target;

  @override
  Widget build(BuildContext context) {
    final target = this.target;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: target == null
                  ? 'Report someone'
                  : 'Report ${target.displayName}',
              subtitle: 'Document what happened and optionally block them',
              leading: const HeaderBackButton(),
            ),
            Expanded(
              child: target == null
                  ? const _WhereToReport()
                  : _ReportForm(target: target),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhereToReport extends StatelessWidget {
  const _WhereToReport();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      children: const [
        _AnonymousNotice(),
        SizedBox(height: 12),
        SurfaceCard(
          child: Text(
            'To report someone, open your conversation with them or their '
            'profile, and choose Report from the menu. That tells our team '
            'exactly who you mean.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReportForm extends ConsumerWidget {
  const _ReportForm({required this.target});

  final ReportTarget target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = reportFormProvider(target.userId);
    final form = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final reasons = ref.watch(reportReasonsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      children: [
        const _AnonymousNotice(),
        const SizedBox(height: 12),
        _Section(
          title: 'Reason',
          child: switch (reasons) {
            AsyncValue(value: final options?) => Column(
              children: [
                for (final (index, option) in options.indexed)
                  _ReasonRow(
                    option: option,
                    selected: option.value == form.reason,
                    isFirst: index == 0,
                    onTap: form.isSubmitting
                        ? null
                        : () => controller.selectReason(option.value),
                  ),
              ],
            ),
            AsyncValue(:final error?) => _ReasonsFailed(
              message: error is ApiException
                  ? error.message
                  : "The reasons didn't load. Please try again.",
              onRetry: () => ref.invalidate(reportReasonsProvider),
            ),
            _ => const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            ),
          },
        ),
        const SizedBox(height: 12),
        _Section(
          title: 'Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: form.details,
                enabled: !form.isSubmitting,
                minLines: 3,
                maxLines: 6,
                maxLength: ReportDraft.maxDetailsLength,
                textCapitalization: TextCapitalization.sentences,
                onChanged: controller.setDetails,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'What happened? Anything you add helps our team.',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              _EvidencePicker(
                evidence: form.evidence,
                enabled: !form.isSubmitting,
                onAdd: form.canAddEvidence
                    ? () => _addEvidence(context, ref)
                    : null,
                onRemove: controller.removeEvidence,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _AlsoBlockToggle(
          name: target.displayName,
          value: form.alsoBlock,
          onChanged: form.isSubmitting ? null : controller.setAlsoBlock,
        ),
        if (form.error case final error?) ...[
          const SizedBox(height: 12),
          FormErrorBanner(message: error),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: form.isSubmitting ? null : () => _submit(context, ref),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.danger.withValues(alpha: 0.5),
            disabledForegroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          child: form.isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Text('Submit report'),
        ),
      ],
    );
  }

  Future<void> _addEvidence(BuildContext context, WidgetRef ref) async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !context.mounted) return;
    try {
      final photo = await ref.read(photoPickerProvider).pick(source);
      if (photo == null || !context.mounted) return;
      ref.read(reportFormProvider(target.userId).notifier).addEvidence(photo);
    } on PhotoPickException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error.failure.message)));
    }
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(reportFormProvider(target.userId).notifier)
        .submit(target);
    if (result == null || !context.mounted) return;
    Navigator.of(context).pop(result);
  }
}

class _AnonymousNotice extends StatelessWidget {
  const _AnonymousNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            AppAssets.triangleAlert,
            width: 18,
            height: 18,
            colorFilter: const ColorFilter.mode(
              AppColors.danger,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reports are anonymous',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB91C1C),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'The person you report is never told who reported them.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.option,
    required this.selected,
    required this.isFirst,
    required this.onTap,
  });

  final ReportReasonOption option;
  final bool selected;
  final bool isFirst;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              top: isFirst
                  ? BorderSide.none
                  : const BorderSide(color: AppColors.divider),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  option.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
              ),
              if (selected)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dangerSoft,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.danger),
                  ),
                  child: const Text(
                    'Selected',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReasonsFailed extends StatelessWidget {
  const _ReasonsFailed({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.textSecondary,
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}

class _EvidencePicker extends StatelessWidget {
  const _EvidencePicker({
    required this.evidence,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final List<PreparedPhoto> evidence;
  final bool enabled;
  final VoidCallback? onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    final count = evidence.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          enabled: enabled && onAdd != null,
          label: 'Attach evidence',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: enabled ? onAdd : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Attach evidence',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    switch (count) {
                      0 => 'Screenshots help',
                      1 => '1 screenshot',
                      _ when onAdd == null => '$count screenshots (most)',
                      _ => '$count screenshots',
                    },
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SvgPicture.asset(
                    AppAssets.uploadTray,
                    width: 16,
                    height: 16,
                    colorFilter: const ColorFilter.mode(
                      AppColors.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
        if (count > 0) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (index, photo) in evidence.indexed)
                _EvidenceThumbnail(
                  photo: photo,
                  number: index + 1,
                  onRemove: enabled ? () => onRemove(index) : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _EvidenceThumbnail extends StatelessWidget {
  const _EvidenceThumbnail({
    required this.photo,
    required this.number,
    required this.onRemove,
  });

  final PreparedPhoto photo;
  final int number;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              photo.bytes,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              semanticLabel: 'Screenshot $number',
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: -6,
              right: -6,
              child: Semantics(
                button: true,
                label: 'Remove screenshot $number',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AlsoBlockToggle extends StatelessWidget {
  const _AlsoBlockToggle({
    required this.name,
    required this.value,
    required this.onChanged,
  });

  final String name;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return Semantics(
      toggled: value,
      label: 'Also block $name',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged(!value),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Also block $name',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "You won't see each other again, and any match between "
                      'you ends.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: value ? AppColors.danger : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.danger, width: 1.5),
                ),
                child: value
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
