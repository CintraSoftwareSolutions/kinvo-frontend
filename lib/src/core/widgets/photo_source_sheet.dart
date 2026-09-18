import 'package:flutter/material.dart';

import '../media/photo_picker.dart';
import '../theme/app_colors.dart';

/// Asks whether to take a photo or choose one. Returns `null` when dismissed.
Future<PhotoSource?> showPhotoSourceSheet(BuildContext context) {
  return showModalBottomSheet<PhotoSource>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheet) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Add a photo',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              onTap: () => Navigator.of(sheet).pop(PhotoSource.camera),
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.purple,
              ),
              title: const Text('Take a photo'),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              onTap: () => Navigator.of(sheet).pop(PhotoSource.library),
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.purple,
              ),
              title: const Text('Choose from your photos'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    ),
  );
}
