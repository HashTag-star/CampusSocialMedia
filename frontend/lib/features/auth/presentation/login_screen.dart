import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:campus_social_media/features/auth/presentation/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showErrorToast('Please enter your email and password.');
      return;
    }

    await ref.read(authStateProvider.notifier).login(email, password);

    final state = ref.read(authStateProvider);
    if (state.hasError) {
      // Extract a user-friendly message from the error
      String message = 'Something went wrong. Please try again.';
      final error = state.error;
      if (error != null) {
        final errorStr = error.toString();
        if (errorStr.contains('Invalid credentials') || errorStr.contains('400')) {
          message = 'Incorrect email or password. Please try again.';
        } else if (errorStr.contains('SocketException') || errorStr.contains('connection')) {
          message = 'No internet connection. Check your network and try again.';
        } else if (errorStr.contains('timeout') || errorStr.contains('TimeoutException')) {
          message = 'Server is taking too long. Please try again later.';
        } else if (errorStr.contains('404')) {
          message = 'Account not found. Please sign up first.';
        } else if (errorStr.contains('500')) {
          message = 'Server error. Please try again later.';
        }
      }
      if (mounted) _showErrorToast(message);
    } else {
      if (mounted) context.go('/feed');
    }
  }

  void _showErrorToast(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 4),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authStateProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          // Gradient Mesh Logic (Simulated with Radial Gradients)
          image: DecorationImage(
            image: const NetworkImage("https://transparenttextures.com/patterns/cubes.png"), // Subtle texture if needed, or just gradients
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              theme.scaffoldBackgroundColor.withOpacity(0.9), 
              BlendMode.srcOver
            )
          )
        ),
        child: Stack(
          children: [
            // Background Orbs
            Positioned(
              top: -100,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.15),
                ),
                child: DecoratedBox(decoration: BoxDecoration(backgroundBlendMode: BlendMode.srcOver)), // Blur handler?
              ),
            ),
             Positioned(
              bottom: 50,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.1),
                ),
              ),
            ),
            
            // Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Column(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26, 
                                  blurRadius: 20, 
                                  offset: Offset(0, 10)
                                )
                              ]
                            ),
                            child: const Icon(Icons.school_rounded, color: Colors.white, size: 40),
                          ),
                          const SizedBox(height: 24),
                          RichText(
                            text: TextSpan(
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: theme.colorScheme.onBackground,
                              ),
                              children: [
                                const TextSpan(text: 'Uni'),
                                TextSpan(
                                  text: 'Gram', 
                                  style: TextStyle(color: theme.colorScheme.primary)
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Connect your campus life',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white54 : Colors.grey[500],
                              fontWeight: FontWeight.w500
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),

                      // Format
                      // Email
                      TextField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          hintText: 'University Email (@edu)',
                          prefixIcon: Icon(Icons.alternate_email_rounded, color: isDark ? Colors.white54 : Colors.grey[400]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Password
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: isDark ? Colors.white54 : Colors.grey[400]),
                          suffixIcon: Icon(Icons.visibility_outlined, color: isDark ? Colors.white54 : Colors.grey[400]),
                        ),
                      ),
                      
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text('Forgot Password?'),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Login Button
                      ElevatedButton(
                        onPressed: state.isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          elevation: 8,
                          shadowColor: theme.colorScheme.primary.withOpacity(0.5),
                        ),
                        child: state.isLoading 
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text('Log In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),

                      const SizedBox(height: 40),

                      // Social Divder
                      Row(
                        children: [
                          Expanded(child: Divider(color: isDark ? Colors.white10 : Colors.grey[200])),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR CONTINUE WITH',
                              style: TextStyle(
                                fontSize: 10, 
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white30 : Colors.grey[400],
                                letterSpacing: 1.5
                              ),
                            ),
                          ),
                          Expanded(child: Divider(color: isDark ? Colors.white10 : Colors.grey[200])),
                        ],
                      ),
                      
                      const SizedBox(height: 24),

                      // Social Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _socialButton(Icons.g_mobiledata_rounded, theme),
                          const SizedBox(width: 16),
                          _socialButton(Icons.apple, theme),
                        ],
                      ),
                      
                      const SizedBox(height: 24),

                      // Register Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: TextStyle(color: isDark ? Colors.white60 : Colors.grey[600]),
                          ),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            child: const Text('Sign Up'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _socialButton(IconData icon, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey[200]!), // Added ! to force non-null
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
      ),
      child: Center(
        child: Icon(icon, size: 28, color: isDark ? Colors.white70 : Colors.grey[600]),
      ),
    );
  }
}
