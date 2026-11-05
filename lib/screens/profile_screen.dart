
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final _newPasswordController = TextEditingController();
  final _currentPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _message;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _currentPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);

    try {
      await _authService.signOut();
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Unable to sign out. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changePassword() async {
    _newPasswordController.clear();
    _currentPasswordController.clear();

    final formKey = GlobalKey<FormState>();
    bool updating = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Update Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _currentPasswordController,
                      obscureText: true,
                      enabled: !updating,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty
                              ? 'Enter your current password'
                              : null,
                    ),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      enabled: !updating,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Use at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    if (errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    if (updating)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: CircularProgressIndicator(),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: updating
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: updating
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setDialogState(() {
                            updating = true;
                            errorMessage = null;
                          });

                          try {
                            // Verify the current password first.
                            await _authService.reauthenticate(
                              _currentPasswordController.text,
                            );

                            await _authService.updatePassword(
                              _newPasswordController.text,
                            );

                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);

                            if (mounted) {
                              setState(() {
                                _message =
                                    'Password updated successfully!';
                              });
                            }
                          } on FirebaseAuthException catch (e) {
                            if (!dialogContext.mounted) return;

                            setDialogState(() {
                              switch (e.code) {
                                case 'wrong-password':
                                case 'invalid-credential':
                                  errorMessage =
                                      'Current password is incorrect.';
                                  break;
                                case 'weak-password':
                                  errorMessage =
                                      'Choose a stronger password.';
                                  break;
                                case 'requires-recent-login':
                                  errorMessage =
                                      'Please verify your current password and retry.';
                                  break;
                                case 'network-request-failed':
                                  errorMessage =
                                      'Check your internet connection.';
                                  break;
                                case 'too-many-requests':
                                  errorMessage =
                                      'Too many attempts. Try again later.';
                                  break;
                                default:
                                  errorMessage =
                                      'Password update failed. Try again.';
                              }
                            });
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              errorMessage =
                                  'Something went wrong. Try again.';
                            });
                          } finally {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                updating = false;
                              });
                            }
                          }
                        },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    _currentPasswordController.clear();
    _newPasswordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.deepPurple.shade100,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.account_circle,
                  size: 100,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Welcome!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user?.email ?? 'No email available',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 30),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _message!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _changePassword,
                    icon: const Icon(Icons.lock_reset),
                    label: const Text('Update Password'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signOut,
                    icon: const Icon(Icons.logout),
                    label: Text(
                      _isLoading ? 'Signing out...' : 'Sign Out',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
