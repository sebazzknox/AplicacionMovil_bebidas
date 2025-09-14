// lib/app_auth.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Helpers opcionales que ya tenías (no son usados por la UI, pero los dejo)
bool get kIsLoggedIn => FirebaseAuth.instance.currentUser != null;
Future<void> signInAdmin(String email, String password) async {
  await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: email.trim(),
    password: password.trim(),
  );
}
Future<void> signOutAdmin() async {
  await FirebaseAuth.instance.signOut();
}

/// Pantalla de autenticación (login/registro)
class AppAuthPage extends StatefulWidget {
  const AppAuthPage({super.key});

  @override
  State<AppAuthPage> createState() => _AppAuthPageState();
}

enum _Mode { login, register }

class _AppAuthPageState extends State<AppAuthPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  _Mode _mode = _Mode.login;
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_mode == _Mode.login ? 'Iniciar sesión' : 'Crear cuenta'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Icon(Icons.badge_outlined, size: 64, color: cs.primary),
                    const SizedBox(height: 12),
                    Text(
                      _mode == _Mode.login
                          ? 'Entrá con tu cuenta'
                          : 'Registrate para continuar',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),

                    if (_mode == _Mode.register) ...[
                      TextFormField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) {
                          if (_mode == _Mode.register && (v ?? '').trim().isEmpty) {
                            return 'Ingresá tu nombre';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.isEmpty) return 'Ingresá tu email';
                        if (!s.contains('@') || !s.contains('.')) {
                          return 'Email inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction:
                          _mode == _Mode.login ? TextInputAction.done : TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        final s = (v ?? '').trim();
                        if (s.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                    ),

                    if (_mode == _Mode.register) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _pass2Ctrl,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          labelText: 'Repetir contraseña',
                          prefixIcon: Icon(Icons.lock_reset_outlined),
                        ),
                        validator: (v) {
                          if (_mode == _Mode.register &&
                              (v ?? '').trim() != _passCtrl.text.trim()) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                height: 18, width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_mode == _Mode.login ? 'Entrar' : 'Crear cuenta'),
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (_mode == _Mode.login)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _loading ? null : _resetPass,
                          icon: const Icon(Icons.password_outlined),
                          label: const Text('Olvidé mi contraseña'),
                        ),
                      ),

                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() {
                                _mode = _mode == _Mode.login ? _Mode.register : _Mode.login;
                              }),
                      child: Text(
                        _mode == _Mode.login
                            ? '¿No tenés cuenta? Registrate'
                            : '¿Ya tenés cuenta? Iniciá sesión',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    setState(() => _loading = true);
    try {
      if (_mode == _Mode.login) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: pass,
        );
      } else {
        // Registro
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: pass,
        );
        final uid = cred.user!.uid;

        // Nombre visible
        if (_nameCtrl.text.trim().isNotEmpty) {
          await cred.user!.updateDisplayName(_nameCtrl.text.trim());
        }

        // Doc en Firestore: users/{uid}
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': email,
          'displayName': _nameCtrl.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          // NUNCA seteamos role / isAdmin desde el cliente (reglas lo bloquean)
        }, SetOptions(merge: true));
      }
      // AuthGate detecta sesión y te manda al Home automáticamente
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMsg(e));
    } catch (e) {
      _showError('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPass() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showError('Ingresá tu email para recuperar la contraseña');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Te enviamos un correo para restablecer la contraseña')),
        );
      }
    } on FirebaseAuthException catch (e) {
      _showError(_firebaseMsg(e));
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  String _firebaseMsg(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email inválido';
      case 'user-not-found':
        return 'No existe una cuenta con ese email';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'email-already-in-use':
        return 'Ese email ya está registrado';
      case 'weak-password':
        return 'La contraseña es muy débil';
      case 'too-many-requests':
        return 'Demasiados intentos. Probá más tarde';
      default:
        return 'Auth error: ${e.code}';
    }
  }
}