import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/page_header.dart';
import '../widgets/settings_tile.dart';

enum ThemePreviewMode { system, light, dark }

class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen> {
  ThemePreviewMode _mode = ThemePreviewMode.dark;
  bool _largerText = true;
  bool _higherContrast = true;
  bool _reduceMotion = true;
  bool _readability = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Theme & accessibility',
              subtitle:
                  'Inclusive controls for contrast, motion, text size, and dark mode',
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
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.accessibility_new_rounded,
                            size: 18,
                            color: AppColors.purple,
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'A single place for inclusive UI controls',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Theme follows the device by default, with readability features that can be enabled individually.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Theme mode',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeToggle(
                            label: 'System',
                            selected: _mode == ThemePreviewMode.system,
                            onTap: () =>
                                setState(() => _mode = ThemePreviewMode.system),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ModeToggle(
                            label: 'Light',
                            selected: _mode == ThemePreviewMode.light,
                            onTap: () =>
                                setState(() => _mode = ThemePreviewMode.light),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ModeToggle(
                            label: 'Dark',
                            selected: _mode == ThemePreviewMode.dark,
                            onTap: () =>
                                setState(() => _mode = ThemePreviewMode.dark),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SettingsTile(
                      icon: AppAssets.textSize,
                      iconBg: const Color(0xFFEDE9FE),
                      iconColor: AppColors.purple,
                      title: 'Larger text',
                      subtitle:
                          'Scale headings and body copy for easier reading.',
                      trailing: OnOffToggle(
                        value: _largerText,
                        onChanged: (v) => setState(() => _largerText = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SettingsTile(
                      icon: AppAssets.contrast,
                      iconBg: const Color(0xFFEDE9FE),
                      iconColor: AppColors.purple,
                      title: 'Higher contrast',
                      subtitle:
                          'Increase separation for text, strokes, and controls.',
                      trailing: OnOffToggle(
                        value: _higherContrast,
                        onChanged: (v) => setState(() => _higherContrast = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SettingsTile(
                      icon: AppAssets.sparkles,
                      iconBg: const Color(0xFFEDE9FE),
                      iconColor: AppColors.purple,
                      title: 'Reduce motion',
                      subtitle:
                          'Tone down animation intensity and movement across the app.',
                      trailing: OnOffToggle(
                        value: _reduceMotion,
                        onChanged: (v) => setState(() => _reduceMotion = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SettingsTile(
                      icon: AppAssets.eye,
                      iconBg: const Color(0xFFEDE9FE),
                      iconColor: AppColors.purple,
                      title: 'Readability mode',
                      subtitle:
                          'Use calmer spacing and a reading-focused type stack.',
                      trailing: OnOffToggle(
                        value: _readability,
                        onChanged: (v) => setState(() => _readability = v),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _DarkPreviewCard(),
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

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.purple : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.purple : AppColors.divider,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _DarkPreviewCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'PREVIEW',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Accessible',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Dark mode profile card',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Olivia, 27',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Foodie Buddy · Verified · 3 miles away',
                  style: TextStyle(fontSize: 11, color: Color(0xFFD1D5DB)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'High contrast',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                    const Spacer(),
                    SvgPicture.asset(
                      AppAssets.starFilled,
                      width: 12,
                      height: 12,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Center(
                          child: Text(
                            'Pass',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: AppColors.purple,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Center(
                          child: Text(
                            'Like',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFB45309),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Center(
                          child: Text(
                            'Super',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
