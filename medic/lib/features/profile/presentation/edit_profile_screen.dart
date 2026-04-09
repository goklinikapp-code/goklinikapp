import 'package:flutter/material.dart';

import '../../../core/settings/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  late final List<_EmergencyContact> _contacts;

  @override
  void initState() {
    super.initState();
    final language =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    _nameController.text = appTr(key: 'patient_default', language: language);
    _emailController.text = 'paciente@goklinik.com';
    _contacts = [
      _EmergencyContact(
        name: appTr(key: 'edit_profile_primary_contact', language: language),
        relation:
            appTr(key: 'edit_profile_family_relation', language: language),
        phone: '+55 11 99999-9999',
      ),
    ];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _addContact() {
    final language = Localizations.localeOf(context).languageCode;
    setState(() {
      _contacts.add(
        _EmergencyContact(
          name: appTr(key: 'edit_profile_new_contact', language: language),
          relation:
              appTr(key: 'edit_profile_relation_label', language: language),
          phone: appTr(key: 'profile_phone', language: language),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    String t(String key) => _t(context, key);
    return Scaffold(
      appBar: AppBar(title: Text(t('edit_profile'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              children: [
                GKAvatar(name: t('patient_default'), radius: 38),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: GKColors.primary,
                    child:
                        Icon(Icons.camera_alt, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GKCard(
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  cursorColor: GKColors.primary,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: t('edit_profile_full_name_label'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  cursorColor: GKColors.primary,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: t('edit_profile_email_label'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  cursorColor: GKColors.primary,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(labelText: t('profile_phone')),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _addressController,
                  cursorColor: GKColors.primary,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    labelText: t('edit_profile_address_label'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GKCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('edit_profile_emergency_contacts'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                ..._contacts.map(
                  (contact) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.emergency_outlined,
                        color: GKColors.accent),
                    title: Text(contact.name),
                    subtitle: Text('${contact.relation} • ${contact.phone}'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addContact,
                  icon: const Icon(Icons.add),
                  label: Text(t('common_add')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GKButton(
            label: t('edit_profile_save_changes'),
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(t('edit_profile_updated_success'))),
              );
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}

class _EmergencyContact {
  const _EmergencyContact(
      {required this.name, required this.relation, required this.phone});

  final String name;
  final String relation;
  final String phone;
}

String _t(BuildContext context, String key) {
  final language = Localizations.localeOf(context).languageCode;
  return appTr(key: key, language: language);
}
