import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/settings/app_preferences.dart';
import '../../../core/settings/app_translations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_avatar.dart';
import '../../../core/widgets/gk_button.dart';
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
  bool _agendaToggle = true;
  bool _offersToggle = false;
  bool _uploadingAvatar = false;
  bool _passwordSheetOpen = false;
  File? _selectedAvatarFile;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(profileProvider);
    final preferences = ref.watch(appPreferencesControllerProvider);
    final language = preferences.language;
    String t(String key) => appTr(key: key, language: language);

    return Scaffold(
      appBar: AppBar(title: Text(t('profile_title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GKCard(
            child: Column(
              children: [
                Stack(
                  children: [
                    _buildAvatar(
                      name: user?.fullName ?? t('patient_default'),
                      imageUrl: user?.avatarUrl,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _uploadingAvatar
                            ? null
                            : () => _pickAndUploadAvatar(user),
                        borderRadius: BorderRadius.circular(20),
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: GKColors.primary,
                          child: _uploadingAvatar
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Icon(Icons.camera_alt,
                                  size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(user?.fullName ?? t('patient_default'),
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(user?.email ?? '-'),
                const SizedBox(height: 10),
                GKButton(
                  label: t('edit_profile'),
                  variant: GKButtonVariant.secondary,
                  onPressed: () => context.push('/profile/edit'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GKCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('notifications_title'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('agenda_reminders')),
                  value: _agendaToggle,
                  onChanged: (v) => setState(() => _agendaToggle = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('news_offers')),
                  value: _offersToggle,
                  onChanged: (v) => setState(() => _offersToggle = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GKCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('privacy_title'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                _arrowTile(
                  t('change_password'),
                  Icons.lock_outline,
                  onTap: _openChangePasswordSheet,
                ),
                _arrowTile(t('biometrics'), Icons.fingerprint),
                _arrowTile(t('access_history'), Icons.history),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GKCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('app_settings_title'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('dark_mode')),
                  secondary: const Icon(Icons.dark_mode_outlined),
                  value: preferences.darkMode,
                  onChanged: (v) {
                    ref
                        .read(appPreferencesControllerProvider.notifier)
                        .setDarkMode(v);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language),
                  title: Text(t('language')),
                  subtitle:
                      Text(languageLabels[preferences.language] ?? 'English'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      _openLanguageSelector(context, preferences.language),
                ),
                _arrowTile(t('typography'), Icons.text_fields),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(t('notification_preferences')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.push('/profile/notification-preferences'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GKCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('help_title'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                _arrowTile(t('faq'), Icons.help_outline),
                _arrowTile(t('support_chat'), Icons.support_agent),
                _arrowTile(t('tutorial'), Icons.menu_book_outlined),
              ],
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: () async {
              final router = GoRouter.of(context);
              await ref.read(authControllerProvider.notifier).logout();
              if (!mounted) return;
              router.go('/login');
            },
            icon: const Icon(Icons.logout, color: GKColors.danger),
            label: Text(t('logout'),
                style: const TextStyle(color: GKColors.danger)),
          ),
        ],
      ),
    );
  }

  Widget _arrowTile(String title, IconData icon, {VoidCallback? onTap}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap ?? () {},
    );
  }

  Widget _buildAvatar({required String name, required String? imageUrl}) {
    if (_selectedAvatarFile != null) {
      return CircleAvatar(
        radius: 36,
        backgroundColor: GKColors.primary.withValues(alpha: 0.12),
        backgroundImage: FileImage(_selectedAvatarFile!),
      );
    }
    return GKAvatar(name: name, imageUrl: imageUrl, radius: 36);
  }

  Future<void> _pickAndUploadAvatar(AuthUser? user) async {
    if (user == null || _uploadingAvatar) return;

    final language = ref.read(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);

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
      final updatedUser = await ref
          .read(profileRepositoryProvider)
          .uploadAvatar(filePath: image.path);
      await ref
          .read(authControllerProvider.notifier)
          .updateCurrentUser(updatedUser);
      ref.invalidate(profileProvider);
      if (!mounted) return;

      setState(() {
        _selectedAvatarFile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t('profile_photo_updated'))),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _selectedAvatarFile = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_avatarUploadErrorMessage(
                error, t('profile_photo_upload_error')))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAvatar = false;
        });
      }
    }
  }

  String _avatarUploadErrorMessage(Object error, String fallback) {
    if (error is DioException) {
      final payload = error.response?.data;
      if (payload is Map<String, dynamic>) {
        final detail = payload['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
      }
    }
    return fallback;
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
    bool didCloseSheet = false;

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
                      content: Text('Preencha todos os campos'),
                    ),
                  );
                  return;
                }

                if (newPassword.length < 8) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('A nova senha deve ter pelo menos 8 caracteres'),
                    ),
                  );
                  return;
                }

                if (newPassword != confirmPassword) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('As senhas nao coincidem'),
                    ),
                  );
                  return;
                }

                setSheetState(() => saving = true);
                try {
                  await ref.read(profileRepositoryProvider).changePassword(
                        currentPassword: currentPassword,
                        newPassword: newPassword,
                      );
                  if (!mounted || !sheetContext.mounted) return;
                  didCloseSheet = true;
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Senha alterada com sucesso'),
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
                          fallback: 'Nao foi possivel alterar a senha',
                        ),
                      ),
                    ),
                  );
                }

                if (!didCloseSheet && mounted && sheetContext.mounted) {
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
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
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
                                  child:
                                      Text(saving ? 'Salvando...' : 'Salvar'),
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

  Future<void> _openLanguageSelector(
      BuildContext context, String currentLanguage) async {
    final language = ref.read(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(t('choose_language')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...supportedLanguages.map((language) {
                  final selected = language == currentLanguage;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(languageLabels[language] ?? language),
                    trailing: selected
                        ? const Icon(Icons.check, color: GKColors.primary)
                        : null,
                    onTap: () {
                      ref
                          .read(appPreferencesControllerProvider.notifier)
                          .setLanguage(language);
                      Navigator.of(context).pop();
                    },
                  );
                }),
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.sync),
                  title: Text(t('use_device_language')),
                  onTap: () {
                    ref
                        .read(appPreferencesControllerProvider.notifier)
                        .useAutomaticLanguage();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
