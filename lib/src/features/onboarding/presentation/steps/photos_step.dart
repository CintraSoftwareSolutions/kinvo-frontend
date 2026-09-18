import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/photo_source_sheet.dart';
import '../../../profile/domain/profile_photo.dart';
import '../controllers/onboarding_controller.dart';
import '../controllers/photos_step_controller.dart';
import '../widgets/onboarding_step_layout.dart';

class PhotosStep extends ConsumerWidget {
  const PhotosStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final album = ref.watch(
      onboardingControllerProvider.select((state) => state.value?.album),
    );
    final progress = ref.watch(photosStepControllerProvider);
    final controller = ref.read(photosStepControllerProvider.notifier);
    if (album == null) return const SizedBox.shrink();

    return OnboardingStepLayout(
      step: OnboardingStep.photos,
      title: 'Add your photos',
      subtitle:
          'Add at least one clear, recent photo of yourself. Your first photo '
          'is the one people see first.',
      error: progress.error,
      actionLabel: 'Continue',
      onAction: progress.isAdding ? null : controller.continueToNext,
      body: _PhotoGrid(
        album: album,
        progress: progress,
        onAdd: () => unawaited(_addPhoto(context, ref)),
        onRemove: (photo) => unawaited(controller.removePhoto(photo.id)),
      ),
    );
  }

  Future<void> _addPhoto(BuildContext context, WidgetRef ref) async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !context.mounted) return;
    await ref.read(photosStepControllerProvider.notifier).addPhoto(source);
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.album,
    required this.progress,
    required this.onAdd,
    required this.onRemove,
  });

  static const _columns = 3;
  static const _gap = 8.0;

  final PhotoAlbum album;
  final PhotosStepState progress;
  final VoidCallback onAdd;
  final ValueChanged<ProfilePhoto> onRemove;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - _gap * (_columns - 1)) / _columns;
        final photos = album.photos;

        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (var slot = 0; slot < album.maxPhotos; slot++)
              SizedBox(
                width: width,
                // Portrait, like the cards people will see.
                height: width * 4 / 3,
                child: switch (slot) {
                  _ when slot < photos.length => _PhotoTile(
                    photo: photos[slot],
                    number: slot + 1,
                    isRemoving: progress.removing.contains(photos[slot].id),
                    onRemove: () => onRemove(photos[slot]),
                  ),
                  _ when slot == photos.length && progress.isAdding =>
                    const _UploadingTile(),
                  _ => _AddTile(
                    onTap: progress.isAdding ? null : onAdd,
                    isNext: slot == photos.length,
                  ),
                },
              ),
          ],
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.number,
    required this.isRemoving,
    required this.onRemove,
  });

  final ProfilePhoto photo;
  final int number;
  final bool isRemoving;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final url = photo.url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Semantics(
            image: true,
            label: photo.isPrimary ? 'Main photo' : 'Photo $number',
            child: ColoredBox(
              color: AppColors.surfaceSoft,
              child: url == null
                  ? const _BrokenImage()
                  : Image.network(
                      url.toString(),
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      loadingBuilder: (context, child, progress) =>
                          progress == null ? child : const _TileSpinner(),
                      errorBuilder: (_, _, _) => const _BrokenImage(),
                    ),
            ),
          ),
          if (photo.isPrimary)
            const Positioned(left: 6, bottom: 6, child: _MainBadge()),
          Positioned(
            top: 4,
            right: 4,
            child: isRemoving
                ? const _RoundBackdrop(
                    child: _TileSpinner(size: 14, color: Colors.white),
                  )
                : IconButton(
                    onPressed: onRemove,
                    tooltip: 'Remove photo $number',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.square(32),
                      padding: EdgeInsets.zero,
                    ),
                    iconSize: 16,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap, required this.isNext});

  final VoidCallback? onTap;

  /// Whether this is the first empty slot, which is drawn more strongly.
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: 'Add a photo',
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isNext ? AppColors.purpleSoft : AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isNext ? AppColors.purpleLight : AppColors.border,
            ),
          ),
          child: Center(
            child: Icon(
              Icons.add_rounded,
              size: 26,
              color: isNext ? AppColors.purple : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadingTile extends StatelessWidget {
  const _UploadingTile();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Uploading photo',
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.purpleSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const _TileSpinner(),
      ),
    );
  }
}

class _MainBadge extends StatelessWidget {
  const _MainBadge();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.purple,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'Main',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _RoundBackdrop extends StatelessWidget {
  const _RoundBackdrop({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: const BoxDecoration(
        color: Colors.black54,
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

class _TileSpinner extends StatelessWidget {
  const _TileSpinner({this.size = 22, this.color = AppColors.purple});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      ),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted),
    );
  }
}
