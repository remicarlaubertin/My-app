import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/remote/auth_service.dart';
import '../../providers/app_providers.dart';

/// Connexion / création de compte Supabase.
///
/// La connexion sert uniquement à synchroniser les appareils : l'application
/// fonctionne entièrement hors ligne sans compte.
Future<void> openLoginSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: const SingleChildScrollView(child: LoginForm()),
    ),
  );
}

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _creating = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final AuthService auth = ref.read(authServiceProvider);
    final String? error = _creating
        ? await auth.signUp(_email.text, _password.text)
        : await auth.signIn(_email.text, _password.text);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }

    await ref.read(appProvider.notifier).synchronize();
    if (mounted) {
      Navigator.of(context).pop();
      showSnack(
        context,
        _creating
            ? 'Compte créé. Vérifie ta boîte courriel si une confirmation est demandée.'
            : 'Connexion réussie.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.cloudConfigured) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: <Widget>[
            Icon(Icons.cloud_off, size: 32, color: context.mutedColor),
            const SizedBox(height: 12),
            const Text(
              'Cette version a été compilée sans synchronisation cloud.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tes données restent enregistrées sur cet appareil.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.mutedColor),
            ),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            _creating ? 'Créer un compte' : 'Se connecter',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Le même compte sur Windows et Android garde tes données '
            'identiques partout.',
            style: TextStyle(fontSize: 12, color: context.mutedColor),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Courriel'),
            validator: (String? v) =>
                (v == null || !v.contains('@')) ? 'Courriel invalide' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Mot de passe'),
            validator: (String? v) =>
                (v == null || v.length < 6) ? '6 caractères minimum' : null,
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: context.dangerColor, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(
              _busy
                  ? 'Un instant…'
                  : (_creating ? 'Créer mon compte' : 'Se connecter'),
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _creating = !_creating),
            child: Text(
              _creating
                  ? 'J\'ai déjà un compte'
                  : 'Créer un nouveau compte',
            ),
          ),
        ],
      ),
    );
  }
}
