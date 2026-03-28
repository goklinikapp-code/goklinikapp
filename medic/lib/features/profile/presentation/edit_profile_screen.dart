import 'package:flutter/material.dart';

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

  final List<_EmergencyContact> _contacts = [
    const _EmergencyContact(name: 'Contato principal', relation: 'Familiar', phone: '+55 11 99999-9999'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController.text = 'Paciente';
    _emailController.text = 'paciente@goklinik.com';
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
    setState(() {
      _contacts.add(
        const _EmergencyContact(name: 'Novo contato', relation: 'Relação', phone: 'Telefone'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: Stack(
              children: [
                GKAvatar(name: 'Paciente', radius: 38),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    radius: 12,
                    backgroundColor: GKColors.primary,
                    child: Icon(Icons.camera_alt, size: 12, color: Colors.white),
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
                  style: const TextStyle(color: GKColors.darkBackground),
                  decoration: const InputDecoration(labelText: 'Nome Completo'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  cursorColor: GKColors.primary,
                  style: const TextStyle(color: GKColors.darkBackground),
                  decoration: const InputDecoration(labelText: 'E-mail'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneController,
                  cursorColor: GKColors.primary,
                  style: const TextStyle(color: GKColors.darkBackground),
                  decoration: const InputDecoration(labelText: 'Telefone'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _addressController,
                  cursorColor: GKColors.primary,
                  style: const TextStyle(color: GKColors.darkBackground),
                  decoration: const InputDecoration(labelText: 'Endereço'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GKCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Contatos de Emergência', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ..._contacts.map(
                  (contact) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.emergency_outlined, color: GKColors.accent),
                    title: Text(contact.name),
                    subtitle: Text('${contact.relation} • ${contact.phone}'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _addContact,
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GKButton(
            label: 'Salvar Alterações',
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Perfil atualizado com sucesso.')),
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
  const _EmergencyContact({required this.name, required this.relation, required this.phone});

  final String name;
  final String relation;
  final String phone;
}
