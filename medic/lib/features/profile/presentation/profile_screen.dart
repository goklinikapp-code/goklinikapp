import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_card.dart';
import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/profile_repository_impl.dart';
import 'profile_controller.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _newMessagesEnabled = true;
  bool _newAppointmentsEnabled = true;
  bool _uploadingAvatar = false;
  bool _passwordSheetOpen = false;
  File? _selectedAvatarFile;

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('Erro ao carregar perfil: $error'),
        ),
        data: (user) {
          if (user == null) {
            return const Center(
              child: Text('Sessao invalida. Faca login novamente.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GKCard(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        _buildAvatar(user.fullName, user.avatarUrl),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: _uploadingAvatar
                                ? null
                                : () => _pickAndUploadAvatar(user),
                            borderRadius: BorderRadius.circular(20),
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: GKColors.primary,
                              child: _uploadingAvatar
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.camera_alt_outlined,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.fullName,
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: const TextStyle(color: GKColors.neutral),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    _infoRow(
                        'CRM', user.crmNumber.isEmpty ? '-' : user.crmNumber),
                    _infoRow(
                      'Especialidade',
                      user.bio.isEmpty ? '-' : user.bio,
                    ),
                    _infoRow(
                      'Telefone',
                      user.phone.isEmpty ? '-' : user.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GKCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Configuracoes',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Notificacoes de novas mensagens'),
                      value: _newMessagesEnabled,
                      onChanged: (value) {
                        setState(() => _newMessagesEnabled = value);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Notificacoes de novos agendamentos'),
                      value: _newAppointmentsEnabled,
                      onChanged: (value) {
                        setState(() => _newAppointmentsEnabled = value);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Alterar senha'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openChangePasswordSheet,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: GKColors.danger),
                label: const Text(
                  'Sair da conta',
                  style: TextStyle(color: GKColors.danger),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFF5C2C2)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _confirmLogout,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAvatar(String name, String imageUrl) {
    if (_selectedAvatarFile != null) {
      return CircleAvatar(
        radius: 40,
        backgroundColor: GKColors.tealIce,
        backgroundImage: FileImage(_selectedAvatarFile!),
      );
    }
    return GKAvatar(name: name, imageUrl: imageUrl, radius: 40);
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: GKColors.neutral,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(AuthUser? user) async {
    if (_uploadingAvatar || user == null) return;

    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (image == null || !mounted) return;

    setState(() {
      _selectedAvatarFile = File(image.path);
      _uploadingAvatar = true;
    });

    try {
      final updatedUser =
          await ref.read(profileRepositoryProvider).uploadAvatar(
                filePath: image.path,
              );

      await ref.read(authControllerProvider.notifier).updateCurrentUser(
            updatedUser,
          );
      ref.invalidate(profileProvider);

      if (!mounted) return;
      setState(() {
        _selectedAvatarFile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil atualizada com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _selectedAvatarFile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _extractApiError(
              error,
              fallback: 'Não foi possível enviar a foto agora.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAvatar = false;
        });
      }
    }
  }

  Future<void> _openChangePasswordSheet() async {
    if (_passwordSheetOpen) return;
    _passwordSheetOpen = true;

    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool saving = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              Future<void> submit() async {
              final currentPassword = currentController.text.trim();
              final newPassword = newController.text.trim();
              final confirmPassword = confirmController.text.trim();

              if (currentPassword.isEmpty ||
                  newPassword.isEmpty ||
                  confirmPassword.isEmpty) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Preencha todos os campos de senha.'),
                  ),
                );
                return;
              }

              if (newPassword.length < 8) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('A nova senha deve ter pelo menos 8 caracteres.'),
                  ),
                );
                return;
              }

              if (newPassword != confirmPassword) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('A confirmação da senha não confere.'),
                  ),
                );
                return;
              }

              setSheetState(() => saving = true);
              try {
                await ref.read(profileRepositoryProvider).changePassword(
                      currentPassword: currentPassword,
                      newPassword: newPassword,
                      confirmNewPassword: confirmPassword,
                    );
                if (!mounted || !sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Senha alterada com sucesso.'),
                  ),
                );
                return;
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _extractApiError(
                        error,
                        fallback: 'Não foi possível alterar a senha agora.',
                      ),
                    ),
                  ),
                );
              }

              if (mounted && sheetContext.mounted) {
                setSheetState(() => saving = false);
              }
            }

              return AnimatedPadding(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text(
                          'Alterar senha',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: currentController,
                          obscureText: obscureCurrent,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Senha atual',
                            suffixIcon: IconButton(
                              onPressed: () => setSheetState(
                                () => obscureCurrent = !obscureCurrent,
                              ),
                              icon: Icon(
                                obscureCurrent
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: newController,
                          obscureText: obscureNew,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Nova senha',
                            suffixIcon: IconButton(
                              onPressed: () => setSheetState(
                                () => obscureNew = !obscureNew,
                              ),
                              icon: Icon(
                                obscureNew
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: confirmController,
                          obscureText: obscureConfirm,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => submit(),
                          decoration: InputDecoration(
                            labelText: 'Confirmar nova senha',
                            suffixIcon: IconButton(
                              onPressed: () => setSheetState(
                                () => obscureConfirm = !obscureConfirm,
                              ),
                              icon: Icon(
                                obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: saving
                                    ? null
                                    : () => Navigator.of(sheetContext).pop(),
                                child: const Text('Cancelar'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton(
                                onPressed: saving ? null : submit,
                                child: Text(saving ? 'Salvando...' : 'Salvar'),
                              ),
                            ),
                          ],
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      _passwordSheetOpen = false;
    }
  }

  String _extractApiError(Object error, {required String fallback}) {
    if (error is DioException) {
      final payload = error.response?.data;
      if (payload is Map<String, dynamic>) {
        final detail = payload['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
        final first = payload.values.isNotEmpty ? payload.values.first : null;
        if (first is List && first.isNotEmpty) {
          return first.first.toString();
        }
        if (first is String && first.trim().isNotEmpty) {
          return first.trim();
        }
      }
    }
    return fallback;
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Deseja encerrar a sessao deste profissional?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: GKColors.danger),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (shouldLogout != true || !mounted) return;

    final router = GoRouter.of(context);
    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    router.go('/login');
  }
}
