import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/widgets/widgets.dart';
import 'controllers/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  final AuthNotifier? authNotifier;

  const LoginScreen({
    super.key,
    this.authNotifier,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  AuthNotifier get _notifier => widget.authNotifier ?? globalAuthNotifier;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      FocusScope.of(context).unfocus();
      final password = _passwordController.text;
      try {
        await _notifier.login(
          _identifierController.text.trim(),
          password,
        );
      } finally {
        // Discard password from the field only if still mounted and not disposed
        if (mounted) {
          _passwordController.clear();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: ResponsiveContainer(
          child: ValueListenableBuilder<AuthState>(
            valueListenable: _notifier,
            builder: (context, authState, _) {
              final isLoading = authState.isAuthenticating;

              return Center(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spaceLg,
                    vertical: AppDimensions.spaceMd,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: AppDimensions.maxMobileWidth,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBrandingHeader(theme),
                        const SizedBox(height: AppDimensions.spaceLg),
                        AquaCard(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    'Operator Sign In',
                                    style: theme.textTheme.headlineMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    'Access telemetry & centralized field controls',
                                    style: theme.textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: AppDimensions.spaceLg),
                                if (authState.status == AuthStatus.error &&
                                    authState.errorMessage != null) ...[
                                  _buildErrorBanner(theme, authState.errorMessage!),
                                  const SizedBox(height: AppDimensions.spaceMd),
                                ],
                                TextFormField(
                                  controller: _identifierController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Username or Email',
                                    prefixIcon: Icon(Icons.person_outline),
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter your username or email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppDimensions.spaceMd),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: const OutlineInputBorder(),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppDimensions.spaceLg),
                                AquaButton(
                                  label: 'Sign In',
                                  icon: Icons.login,
                                  isLoading: isLoading,
                                  onPressed: isLoading ? null : _handleLogin,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spaceLg),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            'ArvaCore Secured Field Telemetry Engine • v1.0.0',
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingHeader(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const ArvaLogo(
          size: 72,
        ),
        const SizedBox(height: AppDimensions.spaceMd),
        SizedBox(
          width: double.infinity,
          child: Text(
            AppStrings.arvaLinkName,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: Text(
            AppStrings.arvaLinkDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondaryOf(context),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(ThemeData theme, String errorMessage) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spaceSm),
      decoration: BoxDecoration(
        color: AppColors.alertError.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: AppColors.alertError),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.alertError, size: 20),
          const SizedBox(width: AppDimensions.spaceSm),
          Expanded(
            child: Text(
              errorMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.alertError,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
