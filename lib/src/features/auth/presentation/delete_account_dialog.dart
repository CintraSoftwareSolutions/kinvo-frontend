import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/account_providers.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/forms/form_errors.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';

/// Asks the user to confirm deleting their account, then deletes it and signs
/// out.
///
/// The dialog stays open while the account is deleted, so a failure can be
/// explained and retried.
Future<void> showDeleteAccountDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _DeleteAccountDialog(),
  );
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() {
    return _DeleteAccountDialogState();
  }
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _delete() async {
    final accounts = ref.read(accountRepositoryProvider);
    final session = ref.read(sessionManagerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await accounts.deleteAccount();
    } on ApiException catch (error) {
      _showFailure(error.message);
      return;
    } on Object {
      _showFailure(unexpectedFailureMessage);
      rethrow;
    }

    // The account is gone even if this dialog closed in the meantime, so the
    // device must forget the session either way.
    if (mounted) navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Your account has been deleted.')),
    );
    await session.signOut();
  }

  void _showFailure(String message) {
    if (!mounted) return;
    setState(() {
      _deleting = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete your account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your profile and personal details will be erased, and you'll "
              "be signed out on every device. This can't be undone.",
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  error,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _deleting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _deleting ? null : () => unawaited(_delete()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              disabledBackgroundColor: AppColors.danger,
              disabledForegroundColor: Colors.white,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Hidden rather than removed, so the button keeps its size.
                Opacity(
                  opacity: _deleting ? 0 : 1,
                  alwaysIncludeSemantics: true,
                  child: const Text('Delete'),
                ),
                if (_deleting)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
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
