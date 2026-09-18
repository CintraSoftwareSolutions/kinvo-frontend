import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/photo_source_sheet.dart';
import '../../domain/profile_photo.dart';
import '../controllers/profile_controllers.dart';
import 'person_photo.dart';

/// The profile's photos, to add, delete, reorder and choose the main one.
///
/// Photos are reordered by holding one and dragging it onto another's place.
/// Tapping a photo offers the same moves as buttons, for anyone who can't
/// drag.
class PhotoEditorGrid extends ConsumerWidget {
  const PhotoEditorGrid({
    required this.album,
    required this.edits,
    required this.name,
    super.key,
  });

  static const _columns = 3;
  static const _gap = 8.0;

  final PhotoAlbum album;
  final PhotoEdits edits;

  /// The profile's name, for the initial shown while a photo loads.
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = album.photos;
    final controller = ref.read(profilePhotosProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - _gap * (_columns - 1)) / _columns;
        final size = Size(width, width * 4 / 3);

        return Wrap(
          spacing: _gap,
          runSpacing: _gap,
          children: [
            for (var slot = 0; slot < album.maxPhotos; slot++)
              SizedBox.fromSize(
                size: size,
                child: switch (slot) {
                  _ when slot < photos.length => _DraggablePhoto(
                    photo: photos[slot],
                    index: slot,
                    count: photos.length,
                    name: name,
                    size: size,
                    canMove: !edits.isBusy && photos.length > 1,
                    isRemoving: edits.removing.contains(photos[slot].id),
                    onMove: (from) => unawaited(
                      controller.reorder(album.idsWithMove(from, slot)),
                    ),
                    onTap: () => unawaited(
                      _showOptions(context, ref, photos[slot], slot),
                    ),
                  ),
                  _ when slot == photos.length && edits.isAdding =>
                    const _UploadingTile(),
                  _ => _AddTile(
                    isNext: slot == photos.length,
                    onTap: edits.isBusy
                        ? null
                        : () => unawaited(_addPhoto(context, ref)),
                  ),
                },
              ),
          ],
        );
      },
    );
  }

  Future<void> _addPhoto(BuildContext context, WidgetRef ref) async {
    final source = await showPhotoSourceSheet(context);
    if (source == null || !context.mounted) return;
    await ref.read(profilePhotosProvider.notifier).addPhoto(source);
  }

  Future<void> _showOptions(
    BuildContext context,
    WidgetRef ref,
    ProfilePhoto photo,
    int index,
  ) async {
    final photos = album.photos;
    final choice = await showModalBottomSheet<_PhotoAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => _PhotoOptionsSheet(
        isMain: photo.isPrimary,
        canMoveEarlier: index > 0,
        canMoveLater: index < photos.length - 1,
        canDelete: photos.length > 1,
      ),
    );
    if (choice == null || !context.mounted) return;

    final controller = ref.read(profilePhotosProvider.notifier);
    switch (choice) {
      case _PhotoAction.makeMain:
        await controller.makeMain(photo.id);
      case _PhotoAction.moveEarlier:
        await controller.reorder(album.idsWithMove(index, index - 1));
      case _PhotoAction.moveLater:
        await controller.reorder(album.idsWithMove(index, index + 1));
      case _PhotoAction.delete:
        if (await _confirmDelete(context) && context.mounted) {
          await controller.removePhoto(photo.id);
        }
    }
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Delete this photo?'),
        content: const Text("It's removed from your profile straight away."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

enum _PhotoAction { makeMain, moveEarlier, moveLater, delete }

class _PhotoOptionsSheet extends StatelessWidget {
  const _PhotoOptionsSheet({
    required this.isMain,
    required this.canMoveEarlier,
    required this.canMoveLater,
    required this.canDelete,
  });

  final bool isMain;
  final bool canMoveEarlier;
  final bool canMoveLater;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    void choose(_PhotoAction action) => Navigator.of(context).pop(action);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
            Text(
              isMain ? 'Your main photo' : 'Photo',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (!isMain)
              ListTile(
                onTap: () => choose(_PhotoAction.makeMain),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.star_rounded,
                  color: AppColors.purple,
                ),
                title: const Text('Make it my main photo'),
              ),
            if (canMoveEarlier)
              ListTile(
                onTap: () => choose(_PhotoAction.moveEarlier),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.purple,
                ),
                title: const Text('Move earlier'),
              ),
            if (canMoveLater)
              ListTile(
                onTap: () => choose(_PhotoAction.moveLater),
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.purple,
                ),
                title: const Text('Move later'),
              ),
            ListTile(
              onTap: canDelete ? () => choose(_PhotoAction.delete) : null,
              enabled: canDelete,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline_rounded,
                color: canDelete ? AppColors.danger : AppColors.textMuted,
              ),
              title: Text(
                'Delete photo',
                style: TextStyle(
                  color: canDelete ? AppColors.danger : AppColors.textMuted,
                ),
              ),
              subtitle: canDelete
                  ? null
                  : const Text(
                      'Your profile needs at least one photo. Add another '
                      'first.',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DraggablePhoto extends StatelessWidget {
  const _DraggablePhoto({
    required this.photo,
    required this.index,
    required this.count,
    required this.name,
    required this.size,
    required this.canMove,
    required this.isRemoving,
    required this.onMove,
    required this.onTap,
  });

  final ProfilePhoto photo;
  final int index;
  final int count;
  final String name;
  final Size size;
  final bool canMove;
  final bool isRemoving;

  /// The photo at the given place was dropped here.
  final ValueChanged<int> onMove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The server's flag, not the place: the main photo is always first on a
    // server from 18 September on, and this stays right on an older one.
    final tile = _PhotoTile(
      photo: photo,
      isMain: photo.isPrimary,
      name: name,
      isRemoving: isRemoving,
    );

    return DragTarget<int>(
      onWillAcceptWithDetails: (details) => canMove && details.data != index,
      onAcceptWithDetails: (details) => onMove(details.data),
      builder: (context, candidates, _) {
        final highlighted = candidates.isNotEmpty;
        return Semantics(
          button: true,
          label: photo.isPrimary
              ? 'Main photo, ${index + 1} of $count'
              : 'Photo ${index + 1} of $count',
          hint: 'Photo options',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: isRemoving ? null : onTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: highlighted ? AppColors.purple : Colors.transparent,
                  width: 2,
                ),
              ),
              child: canMove
                  ? LongPressDraggable<int>(
                      data: index,
                      // Drawn in the overlay, outside any Material, so it
                      // brings its own for the badge's text.
                      feedback: Material(
                        type: MaterialType.transparency,
                        child: SizedBox.fromSize(
                          size: size,
                          child: Opacity(opacity: 0.85, child: tile),
                        ),
                      ),
                      childWhenDragging: Opacity(opacity: 0.3, child: tile),
                      child: tile,
                    )
                  : tile,
            ),
          ),
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.isMain,
    required this.name,
    required this.isRemoving,
  });

  final ProfilePhoto photo;
  final bool isMain;
  final String name;
  final bool isRemoving;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PersonPhoto(
            url: photo.url,
            name: name,
            color: AppColors.purpleLight,
            initialSize: 32,
          ),
          if (isMain)
            const Positioned(left: 6, top: 6, child: _Badge(label: 'Main')),
          if (photo.isRemovedByModerators)
            const Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: _Badge(label: 'Removed by moderators', warning: true),
            ),
          if (isRemoving)
            const ColoredBox(
              color: Color(0x99FFFFFF),
              child: Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.warning = false});

  final String label;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: warning ? AppColors.danger : AppColors.purple,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.isNext, required this.onTap});

  /// Whether it's the first empty place, which is highlighted.
  final bool isNext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: 'Add a photo',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: isNext ? AppColors.purpleSoft : AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isNext
                  ? AppColors.purple.withValues(alpha: 0.4)
                  : AppColors.divider,
            ),
          ),
          child: Icon(
            Icons.add_rounded,
            size: 26,
            color: isNext ? AppColors.purple : AppColors.textMuted,
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
      label: 'Adding a photo',
      liveRegion: true,
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: SizedBox.square(
            dimension: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      ),
    );
  }
}
