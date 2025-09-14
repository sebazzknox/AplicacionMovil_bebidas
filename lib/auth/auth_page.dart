// lib/auth/auth_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  bool _busy = false;

  // login
  final _loginEmail = TextEditingController();
  final _loginPass  = TextEditingController();

  // registro
  final _name = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPass  = TextEditingController();

  @override
  void dispose() {
    _tab.dispose();
    _loginEmail.dispose();
    _loginPass.dispose();
    _name.dispose();
    _regEmail.dispose();
    _regPass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuenta'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Ingresar'),
            Tab(text: 'Registrarme'),
          ],
        ),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Stack(
          children: [
            Column(
              children: [
                const SizedBox(height: 12),
                // Header DESCABIO (cambia subtítulo según tab)
                AnimatedBuilder(
                  animation: _tab,
                  builder: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _BrandHeader(isLogin: _tab.index == 0),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _LoginForm(
                        email: _loginEmail,
                        pass: _loginPass,
                        onSubmit: _signInEmail,
                        onForgot: _resetPassword,
                      ),
                      _RegisterForm(
                        name: _name,
                        email: _regEmail,
                        pass: _regPass,
                        onSubmit: _registerEmail,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_busy)
              Positioned.fill(
                child: Container(
                  color: cs.surface.withOpacity(.4),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- acciones ----------

  Future<void> _signInEmail() async {
    FocusScope.of(context).unfocus();
    final email = _loginEmail.text.trim();
    final pass  = _loginPass.text;
    if (email.isEmpty || pass.length < 6) {
      _msg('Completá email y contraseña (mínimo 6).');
      return;
    }
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
      // refresco doc users (merge)
      final u = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
        'email': u.email,
        'displayName': u.displayName,
        'emailLower': (u.email ?? '').toLowerCase(),
        'nameLower': (u.displayName ?? '').toLowerCase(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (e) {
      _msg(_authErr(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _registerEmail() async {
    FocusScope.of(context).unfocus();
    final name  = _name.text.trim();
    final email = _regEmail.text.trim();
    final pass  = _regPass.text;
    if (name.isEmpty || email.isEmpty || pass.length < 6) {
      _msg('Completá nombre, email y contraseña (mínimo 6).');
      return;
    }
    setState(() => _busy = true);
    try {
      // Si el user actual es anónimo, linkeamos para conservar UID
      final current = FirebaseAuth.instance.currentUser;
      if (current != null && current.isAnonymous) {
        final cred = EmailAuthProvider.credential(email: email, password: pass);
        await current.linkWithCredential(cred);
        await current.updateDisplayName(name);
      } else {
        final res = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email, password: pass,
        );
        await res.user?.updateDisplayName(name);
      }

      // crear/actualizar doc users/{uid}
      final u = FirebaseAuth.instance.currentUser!;
      await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
        'email': u.email,
        'displayName': name,
        'emailLower': (u.email ?? '').toLowerCase(),
        'nameLower': name.toLowerCase(),
        'photoURL': u.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _msg('Cuenta creada. ¡Bienvenido, $name!');
    } on FirebaseAuthException catch (e) {
      _msg(_authErr(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _loginEmail.text.trim();
    if (email.isEmpty) {
      _msg('Escribí tu email en el campo de arriba.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _msg('Te mandamos un email para restablecer la contraseña.');
    } on FirebaseAuthException catch (e) {
      _msg(_authErr(e));
    }
  }

  // ---------- helpers ----------
  void _msg(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  String _authErr(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email': return 'Email inválido.';
      case 'user-disabled': return 'Usuario deshabilitado.';
      case 'user-not-found': return 'No existe un usuario con ese email.';
      case 'wrong-password': return 'Contraseña incorrecta.';
      case 'email-already-in-use': return 'Ese email ya está registrado.';
      case 'weak-password': return 'La contraseña es muy débil.';
      case 'operation-not-allowed': return 'Operación no permitida.';
      default: return 'Error: ${e.message ?? e.code}';
    }
  }
}

/* ====== Header DESCABIO ====== */

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.isLogin});
  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    final title = isLogin ? 'Iniciá sesión' : 'Crear cuenta';
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFFB388FF), Color(0xFFFF80AB)],
            ),
          ),
          child: const Text(
            'DESCABIO',
            style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

/* ====== UI de formularios ====== */

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.email,
    required this.pass,
    required this.onSubmit,
    required this.onForgot,
  });

  final TextEditingController email;
  final TextEditingController pass;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onForgot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AutofillGroup(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username, AutofillHints.email],
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email_outlined),
              labelText: 'Email',
            ),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pass,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.lock_outline),
              labelText: 'Contraseña',
            ),
            onSubmitted: (_) => onSubmit(),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onForgot,
              child: const Text('Olvidé mi contraseña'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.login),
            label: const Text('Ingresar'),
          ),
          const SizedBox(height: 8),
          Text(
            'Tu sesión queda guardada hasta que cierres sesión.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.name,
    required this.email,
    required this.pass,
    required this.onSubmit,
  });

  final TextEditingController name;
  final TextEditingController email;
  final TextEditingController pass;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AutofillGroup(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline),
              labelText: 'Nombre y apellido',
            ),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email_outlined),
              labelText: 'Email',
            ),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pass,
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.lock_outline),
              labelText: 'Contraseña (mín. 6)',
            ),
            onSubmitted: (_) => onSubmit(),
            onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onSubmit,
            icon: const Icon(Icons.app_registration),
            label: const Text('Crear cuenta'),
          ),
          const SizedBox(height: 8),
          Text(
            'Al crear la cuenta se guarda tu ficha en “users” para que el admin te encuentre por nombre o email.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}