// lib/screens/login_screen.dart
// Mock login screen. Email + password + role selector (Owner / Provider).
// On submit, marks session as logged in and routes to Onboarding (first run)
// or directly to the appropriate home.
//
// Round 11 polish (LG1): documentation only — file was already on-theme.
// Already uses AppColors.primary, SemanticColors, and Material 3 components.

import 'package:flutter/material.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'owner@smartrental.my');
  final _passCtrl = TextEditingController(text: 'demo1234');
  UserRole _role = UserRole.owner;
  bool _obscure = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    // Simulate a brief async auth check.
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final session = UserSessionAccess.of(context);
    session.signIn(
      email: _emailCtrl.text.trim(),
      displayName: _role == UserRole.owner ? 'Oh Wan Ting' : 'Provider A',
      role: _role,
    );
    setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final sem = SemanticColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                _buildBrand(),
                const SizedBox(height: 32),
                Text(
                  'Sign in to your account',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: sem.textPrimary, letterSpacing: -0.3),
                ),
                const SizedBox(height: 4),
                Text(
                  'Demo credentials are pre-filled.',
                  style: TextStyle(fontSize: 13, color: sem.textSecondary),
                ),
                const SizedBox(height: 24),
                _buildRoleSelector(),
                const SizedBox(height: 20),
                AppTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Password',
                  controller: _passCtrl,
                  obscureText: _obscure,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Reset link - Sprint 1 feature'), behavior: SnackBarBehavior.floating),
                      );
                    },
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  child: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_role == UserRole.owner ? 'Sign in as Owner' : 'Sign in as Provider'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Divider(color: sem.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or', style: TextStyle(color: sem.textSecondary, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: sem.border)),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: const Icon(Icons.fingerprint, size: 18),
                  label: const Text('Continue as guest (demo)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ", style: TextStyle(color: sem.textSecondary, fontSize: 13)),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Sign up - Sprint 1 feature'), behavior: SnackBarBehavior.floating),
                        );
                      },
                      child: const Text('Sign up'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryLight],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.3),
                blurRadius: 16, offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Icon(Icons.apartment, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        Text(
          'Smart Rental',
          style: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w700,
            color: SemanticColors.of(context).textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Owner & Cleaning Service Provider',
          style: TextStyle(
            fontSize: 12,
            color: SemanticColors.of(context).textSecondary,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SemanticColors.of(context).surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SemanticColors.of(context).border),
      ),
      child: Row(
        children: [
          _roleTab(UserRole.owner, Icons.apartment, 'Owner'),
          _roleTab(UserRole.provider, Icons.work_outline, 'Provider'),
        ],
      ),
    );
  }

  Widget _roleTab(UserRole role, IconData icon, String label) {
    final selected = _role == role;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _role = role),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : SemanticColors.of(context).textSecondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : SemanticColors.of(context).textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
