import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/flow_widgets.dart';
import '../../../../core/widgets/page_header.dart';
import '../../../safety/data/trusted_contacts_repository.dart';
import '../../../safety/domain/trusted_contact.dart';
import '../../../safety/presentation/controllers/trusted_contacts_controllers.dart';
import '../../../safety/presentation/widgets/contact_sheet.dart';

/// The people Kinvo emails when the user needs help, or shares a plan.
class TrustedContactsScreen extends ConsumerWidget {
  const TrustedContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(trustedContactsProvider);
    final canAdd =
        (contacts.value?.length ?? maxTrustedContacts) < maxTrustedContacts;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Trusted contacts',
              subtitle: 'Who Kinvo emails if you need help',
              leading: const HeaderBackButton(),
              trailing: canAdd
                  ? IconButton.filled(
                      onPressed: () => showContactSheet(context),
                      tooltip: 'Add contact',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.purple,
                      ),
                      icon: const Icon(Icons.add_rounded, color: Colors.white),
                    )
                  : null,
            ),
            Expanded(
              child: switch (contacts) {
                AsyncValue(value: final contacts?) when contacts.isEmpty =>
                  const _Empty(),
                AsyncValue(value: final contacts?) => _ContactList(
                  contacts: contacts,
                ),
                AsyncValue(:final error?) => ListView(
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
                  children: [
                    SurfaceCard(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                      child: Column(
                        children: [
                          const Text(
                            "Your contacts didn't load",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            error is ApiException
                                ? error.message
                                : 'Something went wrong. Please try again.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 18),
                          PrimaryActionButton(
                            label: 'Try again',
                            onPressed: () =>
                                ref.invalidate(trustedContactsProvider),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactList extends StatelessWidget {
  const _ContactList({required this.contacts});

  final List<TrustedContact> contacts;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      children: [
        const Text(
          "They're emailed if you press the emergency button, or when you "
          "share a plan with them. They don't need the app.",
          style: TextStyle(
            fontSize: 13,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        Material(
          color: Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: Column(
            children: [
              for (final (index, contact) in contacts.indexed) ...[
                if (index > 0)
                  const Divider(
                    height: 1,
                    indent: 68,
                    color: AppColors.divider,
                  ),
                _ContactTile(contact: contact),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (contacts.length < maxTrustedContacts)
          OutlinedButton.icon(
            onPressed: () => showContactSheet(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.divider),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Add another'),
          )
        else
          const Text(
            'You have 5 trusted contacts, the most you can add.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact});

  final TrustedContact contact;

  @override
  Widget build(BuildContext context) {
    final relationship = contact.relationship;
    final reach = contact.email ?? contact.phone ?? '';
    final details = [
      if (relationship != null && relationship.isNotEmpty) relationship,
      if (reach.isNotEmpty) reach,
    ].join(' · ');

    return ListTile(
      onTap: () => showContactSheet(context, existing: contact),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: AppColors.purpleSoft,
        foregroundColor: AppColors.purple,
        child: Text(
          contact.name.isEmpty ? '?' : contact.name.characters.first,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      title: Text(
        contact.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        contact.canBeAlerted
            ? details
            : 'No email address, so Kinvo can’t alert them',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12.5,
          color: contact.canBeAlerted
              ? AppColors.textSecondary
              : AppColors.danger,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
      children: [
        SurfaceCard(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 22),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  size: 26,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'No trusted contacts yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Add up to 5 people Kinvo should email if you press the '
                'emergency button, or when you share a plan with them.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              PrimaryActionButton(
                label: 'Add a contact',
                borderRadius: 999,
                onPressed: () => showContactSheet(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
