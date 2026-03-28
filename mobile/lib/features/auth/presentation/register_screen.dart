import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_text_field.dart';
import '../data/auth_repository_impl.dart';
import '../domain/signup_models.dart';
import 'auth_controller.dart';
import 'referral_deep_link_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _referralCodeController = TextEditingController();

  ProviderSubscription<ReferralDeepLinkState>? _referralSubscription;

  List<SignupClinic> _clinics = const [];
  String? _selectedClinicId;
  String? _deepLinkError;
  String? _lastProcessedDeepLinkCode;

  bool _loadingClinics = true;
  bool _loadingDeepLink = false;
  bool _lockClinicByReferral = false;
  bool _lockReferralByLink = false;
  bool _acceptTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      final text = maskPhone(_phoneController.text);
      _phoneController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
    _referralSubscription = ref.listenManual<ReferralDeepLinkState>(
      referralDeepLinkProvider,
      (previous, next) {
        final code = next.pendingCode;
        if (code == null ||
            code.isEmpty ||
            code == _lastProcessedDeepLinkCode) {
          return;
        }
        ref.read(referralDeepLinkProvider.notifier).clearPendingCode();
        _resolveDeepLinkReferral(code);
      },
    );
    Future<void>.microtask(_bootstrapRegistrationFlow);
  }

  @override
  void dispose() {
    _referralSubscription?.close();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final clinicId = _selectedClinicId;
    if (clinicId == null || clinicId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a clínica para continuar.')),
      );
      return;
    }
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aceite os termos para continuar.')),
      );
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('As senhas não conferem.')),
      );
      return;
    }

    final ok = await ref.read(authControllerProvider.notifier).register(
          fullName: _nameController.text.trim(),
          clinicId: clinicId,
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          referralCode: _referralCodeController.text.trim(),
        );

    if (!ok || !mounted) return;
    ref.read(referralDeepLinkProvider.notifier).clearPendingCode();
    context.go('/biometric');
  }

  Future<void> _bootstrapRegistrationFlow() async {
    await _loadClinics();
    final deepLinkCode = ref.read(referralDeepLinkProvider).pendingCode;
    if (deepLinkCode != null && deepLinkCode.isNotEmpty) {
      ref.read(referralDeepLinkProvider.notifier).clearPendingCode();
      await _resolveDeepLinkReferral(deepLinkCode);
    }
  }

  Future<void> _loadClinics() async {
    try {
      final clinics =
          await ref.read(authRepositoryProvider).fetchSignupClinics();
      if (!mounted) return;
      setState(() {
        _clinics = clinics;
        _loadingClinics = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingClinics = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Não foi possível carregar as clínicas agora.')),
      );
    }
  }

  Future<void> _resolveDeepLinkReferral(String code) async {
    if (_loadingDeepLink) return;

    setState(() {
      _loadingDeepLink = true;
      _deepLinkError = null;
    });

    try {
      final result =
          await ref.read(authRepositoryProvider).lookupReferralCode(code);
      if (!mounted) return;

      final hasClinicInList =
          _clinics.any((clinic) => clinic.id == result.clinicId);
      final updatedClinics = hasClinicInList
          ? _clinics
          : <SignupClinic>[
              ..._clinics,
              SignupClinic(
                id: result.clinicId,
                name: result.clinicName,
                slug: '',
              ),
            ];

      setState(() {
        _lastProcessedDeepLinkCode = result.code;
        _clinics = updatedClinics;
        _selectedClinicId = result.clinicId;
        _referralCodeController.text = result.code;
        _lockClinicByReferral = true;
        _lockReferralByLink = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _lastProcessedDeepLinkCode = code;
        _referralCodeController.text = code;
        _lockClinicByReferral = false;
        _lockReferralByLink = false;
        _deepLinkError =
            'Código de indicação inválido. Você pode escolher a clínica e editar o código.';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingDeepLink = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: GKColors.background,
      appBar: AppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Image.asset('assets/images/logo_go_klink.png', width: 140),
            const SizedBox(height: 12),
            Text('Crie sua conta',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            const Text('Inicie sua jornada estética personalizada.',
                style: TextStyle(color: GKColors.neutral)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _buildClinicField(context),
                  const SizedBox(height: 12),
                  GKTextField(
                      controller: _nameController,
                      label: 'Nome Completo',
                      hint: 'Como deseja ser chamado?'),
                  const SizedBox(height: 12),
                  GKTextField(
                      controller: _phoneController,
                      label: 'Telefone',
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  GKTextField(
                      controller: _emailController,
                      label: 'E-mail',
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  GKTextField(
                    controller: _passwordController,
                    label: 'Senha',
                    obscureText: _obscurePassword,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GKTextField(
                    controller: _confirmController,
                    label: 'Confirmar Senha',
                    obscureText: _obscureConfirm,
                    suffix: IconButton(
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_off
                          : Icons.visibility),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GKTextField(
                    controller: _referralCodeController,
                    label: 'Codigo de indicacao opcional',
                    hint: 'Ex: GK3X9A2B',
                    readOnly: _lockReferralByLink,
                  ),
                  if (_loadingDeepLink)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                  if (_deepLinkError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _deepLinkError!,
                        style: const TextStyle(
                          color: GKColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: _acceptTerms,
                        onChanged: (value) =>
                            setState(() => _acceptTerms = value ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          'Li e aceito os Termos de Uso e Política de Privacidade',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  if (authState.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(authState.errorMessage!,
                          style: const TextStyle(color: GKColors.danger)),
                    ),
                  GKButton(
                    label: 'Cadastrar',
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    onPressed: _submit,
                    isLoading: authState.loading,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClinicField(BuildContext context) {
    if (_loadingClinics) {
      return const LinearProgressIndicator(minHeight: 3);
    }

    if (_clinics.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          color: const Color(0xFFF8FAFC),
        ),
        child: const Text(
          'Nenhuma clínica ativa encontrada.',
          style: TextStyle(color: GKColors.neutral),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      key: ValueKey<String?>(_selectedClinicId),
      initialValue: _selectedClinicId,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded),
      decoration: const InputDecoration(
        labelText: 'Clínica',
        hintText: 'Selecione a clínica',
      ),
      items: _clinics
          .map(
            (clinic) => DropdownMenuItem<String>(
              value: clinic.id,
              child: Text(
                clinic.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: _lockClinicByReferral
          ? null
          : (value) {
              setState(() => _selectedClinicId = value);
            },
    );
  }
}
