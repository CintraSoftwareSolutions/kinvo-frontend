import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/page_header.dart';
import '../controllers/profile_controller.dart';

class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key});

  Future<void> _pickPhoto(BuildContext context, WidgetRef ref, int index) async {
    final result = await showModalBottomSheet<ImageSource>(
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
                    color: const Color(0xFFE5E7EB),
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
                onTap: () => Navigator.of(sheet).pop(ImageSource.camera),
                leading: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.purple),
                title: const Text('Take a photo'),
                contentPadding: EdgeInsets.zero,
              ),
              ListTile(
                onTap: () => Navigator.of(sheet).pop(ImageSource.gallery),
                leading: const Icon(Icons.photo_library_outlined,
                    color: AppColors.purple),
                title: const Text('Choose from gallery'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: result, imageQuality: 78);
      if (picked != null) {
        ref
            .read(profileControllerProvider.notifier)
            .setPhoto(index, picked.path);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Edit Profile',
              subtitle: 'Update photos, bio, and the modes you want active',
              leading: HeaderBackButton(),
              trailing: GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: const Text(
                  'Save',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.purple,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Photos',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                            ),
                            itemCount: p.photos.length,
                            itemBuilder: (_, i) => _PhotoTile(
                              path: p.photos[i],
                              onTap: () => _pickPhoto(context, ref, i),
                              onClear: p.photos[i] != null
                                  ? () => controller.setPhoto(i, null)
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _EditField(
                      label: 'NAME',
                      value: p.name,
                      onChanged: controller.updateName,
                    ),
                    const SizedBox(height: 10),
                    _EditField(
                      label: 'LOCATION',
                      value: p.location,
                      onChanged: controller.updateLocation,
                    ),
                    const SizedBox(height: 10),
                    _EditField(
                      label: 'JOB TITLE',
                      value: p.jobTitle,
                      onChanged: controller.updateJobTitle,
                    ),
                    const SizedBox(height: 10),
                    _EditField(
                      label: 'ORGANIZATION',
                      value: p.organization,
                      onChanged: controller.updateOrganization,
                    ),
                    const SizedBox(height: 10),
                    _EditField(
                      label: 'BIO',
                      value: p.bio,
                      maxLines: 3,
                      onChanged: controller.updateBio,
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

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.path, required this.onTap, this.onClear});

  final String? path;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.divider,
                  style: path == null
                      ? BorderStyle.solid
                      : BorderStyle.solid,
                ),
              ),
              child: path == null
                  ? const Center(
                      child: Icon(
                        Icons.add_rounded,
                        size: 22,
                        color: AppColors.textMuted,
                      ),
                    )
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.file(
                        File(path!),
                        fit: BoxFit.cover,
                      ),
                    ),
            ),
          ),
          if (path != null && onClear != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          TextFormField(
            initialValue: value,
            onChanged: onChanged,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
