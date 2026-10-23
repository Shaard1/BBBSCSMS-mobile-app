import '../../widgets/form_feedback.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/basic_account_service.dart';

class BasicRegisterScreen extends StatefulWidget {
  const BasicRegisterScreen({super.key});
  @override
  State<BasicRegisterScreen> createState() => _BasicRegisterScreenState();
}

class _BasicRegisterScreenState extends State<BasicRegisterScreen>
    with FormFeedback<BasicRegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _accepted = false;
  bool _attempted = false;
  bool _busy = false;
  bool _hidden = true;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _phone, _email, _password, _confirm]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _notice(bool privacy) async {
    await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(privacy ? 'Privacy notice' : 'Terms of use'),
              content: SingleChildScrollView(
                  child: Text(privacy
                      ? 'Version ${BasicAccountService.noticeVersion}\n\nWe collect your name and contact details to create your account and support barangay services. Your phone number is self-declared until SMS verification is completed. Identity evidence is collected separately when a service requires it. Authorized barangay personnel access information for official processing. Do not submit real personal information in this test environment. Contact the barangay office for questions or requests concerning your information.'
                      : 'Version ${BasicAccountService.noticeVersion}\n\nProvide accurate information and use your own account. Do not impersonate another person, share passwords, or submit malicious reports. Phone ownership does not establish identity, residency, or authority to act for someone else. Document requests require separate checks before release. This app is not an emergency response channel. Applicable payment and document collection take place at the barangay office.')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ],
            ));
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _attempted = true);
    final valid = _form.currentState!.validate();
    recordFieldError(
        'terms',
        _accepted
            ? null
            : 'Read the privacy notice and accept the terms to continue.');
    if (!valid || !_accepted) {
      setState(() {});
      revealFirstError();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final immediate = await BasicAccountService().registerForTest(
        name: _name.text,
        phone: BasicAccountService.normalizePhone(_phone.text)!,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
                title: const Text('Account created'),
                content: Text(immediate
                    ? 'Your test account is ready. Phone unverified; identity unverified. No account approval queue is required. SMS verification is not yet available.'
                    : 'Check your email to confirm your account, then sign in to finish setup. Your phone and identity remain unverified. No barangay account approval is required.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Continue'))
                ],
              ));
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
          context, immediate ? '/home' : '/login', (_) => false);
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on PostgrestException {
      if (mounted) {
        setState(() => _error =
            'Account setup could not finish. Ask the developer to check the test account migration, then try signing in.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Registration is unavailable. Check your connection and that the test account workflow is enabled.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String label, TextEditingController controller,
      {TextInputType? keyboard,
      bool secret = false,
      String? Function(String?)? validator}) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
          key: fieldAnchor(label),
          focusNode: fieldFocus(label, controller),
          controller: controller,
          enabled: !_busy,
          obscureText: secret && _hidden,
          keyboardType: keyboard,
          autocorrect: !secret,
          enableSuggestions: !secret,
          textInputAction: TextInputAction.next,
          autovalidateMode: _attempted
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          validator: (value) {
            final error = validator?.call(value);
            recordFieldError(label, error);
            return error;
          },
          decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              suffixIcon: secret
                  ? IconButton(
                      tooltip: _hidden ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: Icon(_hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined))
                  : null),
        ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create your account')),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Form(
              key: _form,
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Join Bancao Connect',
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 12),
                        const Text(
                            'Test registration: SMS is not connected. Use fake details. Email is temporarily required for test sign-in; it will be optional in phone-based registration.'),
                        const SizedBox(height: 24),
                        _field('Full name', _name,
                            validator: (value) =>
                                (value?.trim().length ?? 0) < 2 ||
                                        (value?.trim().length ?? 0) > 150
                                    ? 'Enter your full name (2–150 characters).'
                                    : null),
                        _field('Mobile number', _phone,
                            keyboard: TextInputType.phone,
                            validator: (value) => BasicAccountService
                                        .normalizePhone(value ?? '') ==
                                    null
                                ? 'Enter a Philippine mobile number, such as 09XXXXXXXXX.'
                                : null),
                        _field('Email (required for this test)', _email,
                            keyboard: TextInputType.emailAddress,
                            validator: (value) =>
                                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                        .hasMatch(value?.trim() ?? '')
                                    ? null
                                    : 'Enter a valid email for test sign-in.'),
                        _field('Password', _password,
                            secret: true,
                            validator: (value) =>
                                BasicAccountService.validatePassword(
                                    value ?? '')),
                        _field('Confirm password', _confirm,
                            secret: true,
                            validator: (value) => (value?.isEmpty ?? true)
                                ? 'Confirm your password.'
                                : value != _password.text
                                    ? 'Passwords do not match.'
                                    : null),
                        Wrap(children: [
                          TextButton(
                              onPressed: () => _notice(true),
                              child: const Text('Privacy notice')),
                          TextButton(
                              onPressed: () => _notice(false),
                              child: const Text('Terms of use'))
                        ]),
                        CheckboxListTile(
                            key: fieldAnchor('terms'),
                            isError: fieldError('terms') != null,
                            contentPadding: EdgeInsets.zero,
                            value: _accepted,
                            onChanged: _busy
                                ? null
                                : (value) => setState(() {
                                      _accepted = value ?? false;
                                      clearFieldError('terms');
                                    }),
                            title: const Text(
                                'I have read the privacy notice and accept the terms of use.'),
                            controlAffinity: ListTileControlAffinity.leading),
                        fieldWarning('terms'),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(_error!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                        FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: Text(_busy
                                ? 'Creating account…'
                                : 'Create test account')),
                        const SizedBox(height: 12),
                        const Text(
                            'Phone unverified • Identity unverified\nIDs and detailed personal information are not required for signup.'),
                      ]))),
        ))),
      );
}
