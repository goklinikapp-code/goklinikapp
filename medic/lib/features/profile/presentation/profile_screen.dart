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
    final preferences = ref.watch(appPreferencesControllerProvider);
    final language = preferences.language;
    String t(String key) => appTr(key: key, language: language);

    return Scaffold(
      appBar: AppBar(title: Text(t('profile_title'))),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text('${t('profile_load_error')}: $error'),
        ),
        data: (user) {
          if (user == null) {
            return Center(
              child: Text(t('session_invalid_login_again')),
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
                      t('profile_crm'),
                      user.crmNumber.isEmpty ? '-' : user.crmNumber,
                    ),
                    _infoRow(
                      t('profile_specialty'),
                      user.bio.isEmpty ? '-' : user.bio,
                    ),
                    _infoRow(
                      t('profile_phone'),
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
                    Text(
                      t('profile_settings_title'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('profile_notifications_new_messages')),
                      value: _newMessagesEnabled,
                      onChanged: (value) {
                        setState(() => _newMessagesEnabled = value);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('profile_notifications_new_appointments')),
                      value: _newAppointmentsEnabled,
                      onChanged: (value) {
                        setState(() => _newAppointmentsEnabled = value);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(t('dark_mode')),
                      secondary: const Icon(Icons.dark_mode_outlined),
                      value: preferences.darkMode,
                      onChanged: (value) {
                        ref
                            .read(appPreferencesControllerProvider.notifier)
                            .setDarkMode(value);
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.language),
                      title: Text(t('language')),
                      subtitle: Text(
                          languageLabels[preferences.language] ?? 'English'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _openLanguageSelector(context, preferences.language),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_outline),
                      title: Text(t('change_password')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _openChangePasswordSheet,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: GKColors.danger),
                label: Text(
                  t('logout'),
                  style: const TextStyle(color: GKColors.danger),
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
        SnackBar(content: Text(t('profile_photo_updated'))),
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
              fallback: t('profile_photo_upload_error'),
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

    final language = ref.read(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);

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
                    SnackBar(
                      content: Text(t('password_fill_all_fields')),
                    ),
                  );
                  return;
                }

                if (newPassword.length < 8) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(t('password_min_length')),
                    ),
                  );
                  return;
                }

                if (newPassword != confirmPassword) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(t('password_confirmation_mismatch')),
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
                  didCloseSheet = true;
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(t('password_changed_success')),
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
                          fallback: t('password_change_error'),
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
                            t('change_password'),
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
                              labelText: t('current_password'),
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
                              labelText: t('new_password'),
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
                              labelText: t('confirm_new_password'),
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
                                  child: Text(t('cancel')),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FilledButton(
                                  onPressed: saving ? null : submit,
                                  child: Text(
                                    saving ? t('saving') : t('save'),
                                  ),
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
    BuildContext context,
    String currentLanguage,
  ) async {
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

  Future<void> _confirmLogout() async {
    final language = ref.read(appPreferencesControllerProvider).language;
    String t(String key) => appTr(key: key, language: language);

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('logout')),
        content: Text(t('logout_confirm_message')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: GKColors.danger),
            child: Text(t('logout')),
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
