import 'package:flutter/material.dart';

import '../../../../core/theme/kinvo_colors.dart';
import '../../domain/trusted_contact.dart';

/// What happened when Kinvo tried to tell one trusted contact something.
class ContactOutcomeRow extends StatelessWidget {
  const ContactOutcomeRow({required this.alert, super.key});

  final ContactAlert alert;

  @override
  Widget build(BuildContext context) {
    final (icon, color, status) = switch (alert.delivery) {
      ContactDelivery.emailed || ContactDelivery.alreadyTold => (
        Icons.check_circle_rounded,
        context.colors.green,
        'Emailed',
      ),
      ContactDelivery.noEmail => (
        Icons.mail_outline_rounded,
        context.colors.textMuted,
        'No email address',
      ),
      ContactDelivery.failed || ContactDelivery.unknown => (
        Icons.error_outline_rounded,
        context.colors.danger,
        "Couldn't send",
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alert.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ),
          Text(status, style: TextStyle(fontSize: 12.5, color: color)),
        ],
      ),
    );
  }
}
