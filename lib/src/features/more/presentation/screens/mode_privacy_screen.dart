import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/page_header.dart';
import '../widgets/settings_tile.dart';

class ModePrivacyScreen extends StatefulWidget {
  const ModePrivacyScreen({super.key});

  @override
  State<ModePrivacyScreen> createState() => _ModePrivacyScreenState();
}

class _ModePrivacyScreenState extends State<ModePrivacyScreen> {
  String _language = 'English';
  final Set<String> _modes = {'Dating', 'Study Buddy', 'Networking'};
  bool _snooze = false;
  bool _verifiedOnly = true;
  bool _showLastActive = true;
  bool _activityReminders = true;

  static const _languages = ['English', 'Urdu', 'Hindi', 'Spanish'];
  static const _availableModes = [
    'Dating',
    'Study Buddy',
    'Networking',
    'Trading Buddy',
    'Foodie Buddy',
    'Health & Fitness',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Mode & privacy preferences',
              subtitle:
                  'Language, snooze mode, visibility, and connection types',
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
                        color: AppColors.surfaceSoft.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(
                              Icons.privacy_tip_outlined,
                              size: 16,
                              color: AppColors.purple,
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Privacy controls from the spec',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Hide profile, manage visibility, and choose languages and modes.',
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
                    const SizedBox(height: 14),
                    _ChipSection(
                      title: 'Language',
                      options: _languages,
                      selected: {_language},
                      onTap: (v) => setState(() => _language = v),
                    ),
                    const SizedBox(height: 14),
                    _ChipSection(
                      title: 'Connection modes',
                      options: _availableModes,
                      selected: _modes,
                      multiple: true,
                      onTap: (v) => setState(() {
                        if (_modes.contains(v)) {
                          _modes.remove(v);
                        } else {
                          _modes.add(v);
                        }
                      }),
                    ),
                    const SizedBox(height: 14),
                    SettingsTile(
                      title: 'Snooze Mode',
                      subtitle:
                          'Hide profile temporarily without deleting anything.',
                      trailing: OnOffToggle(
                        value: _snooze,
                        onChanged: (v) => setState(() => _snooze = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SettingsTile(
                      title: 'Verified users only',
                      subtitle:
                          'Restrict profile discovery to verified members.',
                      trailing: OnOffToggle(
                        value: _verifiedOnly,
                        onChanged: (v) => setState(() => _verifiedOnly = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SettingsTile(
                      title: 'Show last active',
                      subtitle:
                          'Let matches see when you were last online.',
                      trailing: OnOffToggle(
                        value: _showLastActive,
                        onChanged: (v) =>
                            setState(() => _showLastActive = v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SettingsTile(
                      title: 'Date & activity reminders',
                      subtitle:
                          'Receive reminders for plans and shared availability.',
                      trailing: OnOffToggle(
                        value: _activityReminders,
                        onChanged: (v) =>
                            setState(() => _activityReminders = v),
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

class _ChipSection extends StatelessWidget {
  const _ChipSection({
    required this.title,
    required this.options,
    required this.selected,
    required this.onTap,
    this.multiple = false,
  });

  final String title;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onTap;
  final bool multiple;

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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                GestureDetector(
                  onTap: () => onTap(o),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: selected.contains(o)
                          ? (multiple
                              ? AppColors.purpleChip
                              : AppColors.purple)
                          : AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      o,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: selected.contains(o)
                            ? (multiple ? AppColors.purple : Colors.white)
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
