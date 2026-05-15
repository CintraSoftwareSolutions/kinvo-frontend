import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/assets/app_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/page_header.dart';
import '../../domain/plan.dart';

class VenuesScreen extends StatefulWidget {
  const VenuesScreen({super.key});

  @override
  State<VenuesScreen> createState() => _VenuesScreenState();
}

class _VenuesScreenState extends State<VenuesScreen> {
  String _query = '';
  final Set<String> _saved = {};

  @override
  Widget build(BuildContext context) {
    final results = SampleVenues.all
        .where((v) => v.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Venue Browser',
              subtitle: 'Suggestions tuned to your shared mode and distance',
              leading: HeaderBackButton(),
              trailing: const Icon(
                Icons.search_rounded,
                color: AppColors.textPrimary,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      size: 16,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          hintText: 'Search cafes, parks, study spots, or gyms',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                children: [
                  for (final v in results) ...[
                    _VenueCard(
                      venue: v,
                      saved: _saved.contains(v.id),
                      onSaveToggle: () => setState(() {
                        if (_saved.contains(v.id)) {
                          _saved.remove(v.id);
                        } else {
                          _saved.add(v.id);
                        }
                      }),
                      onSuggest: () {
                        Navigator.of(context).pop(v);
                      },
                    ),
                    const SizedBox(height: 12),
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

class _VenueCard extends StatelessWidget {
  const _VenueCard({
    required this.venue,
    required this.saved,
    required this.onSaveToggle,
    required this.onSuggest,
  });

  final Venue venue;
  final bool saved;
  final VoidCallback onSaveToggle;
  final VoidCallback onSuggest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0C132A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              venue.image,
              width: 76,
              height: 76,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 76,
                height: 76,
                color: AppColors.surfaceSoft,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        venue.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SvgPicture.asset(
                      AppAssets.starFilled,
                      width: 12,
                      height: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${venue.rating}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  venue.type,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${venue.distanceMiles.toStringAsFixed(1)} mi · ${venue.savedCount}  Save for later',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onSaveToggle,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: saved
                              ? AppColors.purpleChip
                              : AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          saved ? 'Saved' : 'Save',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: saved
                                ? AppColors.purple
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onSuggest,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.purple,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Suggest',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
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
