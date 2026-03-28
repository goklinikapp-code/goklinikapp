import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_text_field.dart';
import 'auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _cpfController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _birthController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _referralCodeController = TextEditingController();

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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cpfController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _birthController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1920),
      lastDate: now,
      initialDate: DateTime(now.year - 20),
    );
    if (picked != null) {
      _birthController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Future<void> _submit() async {
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
          cpf: _cpfController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          dateOfBirth: _birthController.text.trim(),
          password: _passwordController.text,
          referralCode: _referralCodeController.text.trim(),
        );

    if (!ok || !mounted) return;
    context.go('/biometric');
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
            Image.asset('assets/images/favicon_go_klink.png', width: 56),
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
                  GKTextField(
                      controller: _nameController,
                      label: 'Nome Completo',
                      hint: 'Como deseja ser chamado?'),
                  const SizedBox(height: 12),
                  GKTextField(
                      controller: _cpfController, label: 'Número Fiscal'),
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
                    controller: _birthController,
                    label: 'Data de Nascimento',
                    readOnly: true,
                    onTap: _pickDate,
                    suffix: const Icon(Icons.calendar_month),
                  ),
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
}
