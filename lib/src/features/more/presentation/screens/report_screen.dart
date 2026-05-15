import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../connections/domain/connection.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({this.target, super.key});

  final Connection? target;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String _reason = 'Harassment';
  String _details =
      'Sarah became aggressive during the video call and continued after I asked to stop.';
  bool _alsoBlock = true;
  final List<String> _evidence = ['screenshot_1.png', 'screenshot_2.png'];

  static const _reasons = [
    'Harassment',
    'Fake profile',
    'Spam or scam',
    'Safety concern',
  ];

  Future<void> _attachEvidence() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() => _evidence.add(picked.name));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not attach: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.target?.name ?? 'user';
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Report $name',
              subtitle: 'Document what happened and optionally block this user',
              leading: HeaderBackButton(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE4E8),
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
                              Color(0xFFEF4458),
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
                                  'Your report stays private and helps moderate the community safely.',
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
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Reason',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          for (int i = 0; i < _reasons.length; i++)
                            _ReasonRow(
                              label: _reasons[i],
                              selected: _reasons[i] == _reason,
                              isFirst: i == 0,
                              isLast: i == _reasons.length - 1,
                              onTap: () =>
                                  setState(() => _reason = _reasons[i]),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Details',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            initialValue: _details,
                            maxLines: 3,
                            onChanged: (v) => _details = v,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _attachEvidence,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceSoft
                                    .withValues(alpha: 0.55),
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
                                    '${_evidence.length} screenshots selected',
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _alsoBlock = !_alsoBlock),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E8),
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
                                      color: Color(0xFFEF4458),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    "You won't see each other after submission.",
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: _alsoBlock
                                    ? const Color(0xFFEF4458)
                                    : Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFEF4458),
                                  width: 1.5,
                                ),
                              ),
                              child: _alsoBlock
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
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Report submitted'),
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4458),
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
                        child: const Text('Submit report'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? const Color(0xFFEF4458)
                      : AppColors.textPrimary,
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
                  color: const Color(0xFFFFE4E8),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFEF4458)),
                ),
                child: const Text(
                  'Selected',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4458),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
