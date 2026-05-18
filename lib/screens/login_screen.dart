import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/guest_browse_provider.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/auth_error_message.dart';
import '../utils/login_save_suppression.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorText;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await _authService.signInWithGoogle();
      if (mounted) {
        await context.read<GuestBrowseProvider>().exitGuestBrowse();
      }
    } catch (error) {
      setState(() {
        _errorText = authErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// End autofill scope without saving — optional DOM patch on web (delayed) to dampen Chrome’s sheet.
  void _suppressPasswordSaveOffer({bool patchDom = false}) {
    TextInput.finishAutofillContext(shouldSave: false);
    if (kIsWeb && patchDom) {
      patchWebLoginInputsAutocompleteOff();
    }
  }

  /// Run after submit so fields already held the real email/password, then try to drop the save prompt.
  void _schedulePasswordSaveSuppression() {
    _suppressPasswordSaveOffer(patchDom: false);
    if (!kIsWeb) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _suppressPasswordSaveOffer(patchDom: false);
    });
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) {
          return;
        }
        _suppressPasswordSaveOffer(patchDom: true);
      }),
    );
  }

  void _onSkipForLater() {
    setState(() => _errorText = null);
    // Local guest mode — no Firebase Anonymous (avoids admin-restricted-operation
    // when Anonymous is disabled in the Firebase project).
    context.read<GuestBrowseProvider>().enterGuestBrowse();
  }

  Future<void> _onEmailPasswordLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _authService.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      // As soon as credentials are accepted, tell the engine not to offer “save password”.
      TextInput.finishAutofillContext(shouldSave: false);
      if (mounted) {
        await context.read<GuestBrowseProvider>().exitGuestBrowse();
      }
    } catch (error) {
      setState(() {
        _errorText = authErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _schedulePasswordSaveSuppression();
      }
    }
  }

  Future<void> _onEmailPasswordRegister() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _authService.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      TextInput.finishAutofillContext(shouldSave: false);
      if (mounted) {
        await context.read<GuestBrowseProvider>().exitGuestBrowse();
      }
    } catch (error) {
      setState(() {
        _errorText = authErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _schedulePasswordSaveSuppression();
      }
    }
  }

  static const double _splitLayoutBreakpoint = 720;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextTheme textTheme = theme.textTheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= _splitLayoutBreakpoint;
            final Widget loginColumn = _LoginFormColumn(
              textTheme: textTheme,
              theme: theme,
              formKey: _formKey,
              emailController: _emailController,
              passwordController: _passwordController,
              obscurePassword: _obscurePassword,
              onObscurePasswordChanged: (bool obscure) =>
                  setState(() => _obscurePassword = obscure),
              isLoading: _isLoading,
              inputsEnabled: !_isLoading,
              onEmailLogin: () => unawaited(_onEmailPasswordLogin()),
              onEmailRegister: () => unawaited(_onEmailPasswordRegister()),
              onGoogleSignIn: _onGoogleSignIn,
              onSkipForLater: _onSkipForLater,
              errorText: _errorText,
              maxWidth: wide ? 420 : _cardMaxWidth(constraints.maxWidth),
              horizontalPadding: _horizontalPadding(constraints.maxWidth),
              embedInParentScrollView: !wide,
            );

            if (wide) {
              return Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Expanded(
                      flex: 5,
                      child: _LoginIllustrationPanel(),
                    ),
                    Expanded(
                      flex: 4,
                      child: loginColumn,
                    ),
                  ],
                ),
              );
            }

            return ColoredBox(
              color: Colors.white,
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        height: 190,
                        child: _LoginIllustrationPanel(compact: true),
                      ),
                      loginColumn,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  static double _horizontalPadding(double width) {
    if (width >= 600) {
      return 48;
    }
    if (width >= 400) {
      return 28;
    }
    return 20;
  }

  static double _cardMaxWidth(double width) {
    const double cap = 420;
    return width > cap + 40 ? cap : width - 8;
  }
}

/// Left panel: Handala at full viewport height, anchored left so the login card stays clear.
class _LoginIllustrationPanel extends StatelessWidget {
  const _LoginIllustrationPanel({this.compact = false});

  final bool compact;

  static const String _handalaAsset = 'assets/images/handala_key.png';
  static const String _handalaFallback = 'images/login_handala.png';

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxHeight <= 0 || constraints.maxWidth <= 0) {
            return const SizedBox.shrink();
          }

          final double imageHeight = compact
              ? constraints.maxHeight * 0.88
              : constraints.maxHeight * 0.72;

          return Center(
            child: Padding(
              padding: EdgeInsets.all(compact ? 16 : 40),
              child: Image.asset(
                _handalaAsset,
                height: imageHeight,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
                errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                    Image.asset(
                  _handalaFallback,
                  height: imageHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoginFormColumn extends StatelessWidget {
  const _LoginFormColumn({
    required this.textTheme,
    required this.theme,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onObscurePasswordChanged,
    required this.isLoading,
    required this.inputsEnabled,
    required this.onEmailLogin,
    required this.onEmailRegister,
    required this.onGoogleSignIn,
    required this.onSkipForLater,
    required this.errorText,
    required this.maxWidth,
    required this.horizontalPadding,
    this.embedInParentScrollView = false,
  });

  final TextTheme textTheme;
  final ThemeData theme;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final ValueChanged<bool> onObscurePasswordChanged;
  final bool isLoading;
  final bool inputsEnabled;
  final VoidCallback onEmailLogin;
  final VoidCallback onEmailRegister;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onSkipForLater;
  final String? errorText;
  final double maxWidth;
  final double horizontalPadding;

  /// When true, a parent [SingleChildScrollView] already scrolls — avoid nested
  /// scroll + [minHeight] from unbounded constraints (infinite height on web).
  final bool embedInParentScrollView;

  Widget _formBody({
    required MainAxisAlignment mainAxisAlignment,
    double minHeight = 0,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        minHeight: minHeight,
      ),
      child: Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _BrandHeader(textTheme: textTheme),
          const SizedBox(height: 28),
          _LoginCard(
            formKey: formKey,
            theme: theme,
            emailController: emailController,
            passwordController: passwordController,
            obscurePassword: obscurePassword,
            onObscurePasswordChanged: onObscurePasswordChanged,
            isLoading: isLoading,
            inputsEnabled: inputsEnabled,
            onEmailLogin: onEmailLogin,
            onEmailRegister: onEmailRegister,
            onGoogleSignIn: onGoogleSignIn,
            onSkipForLater: onSkipForLater,
            errorText: errorText,
          ),
          const SizedBox(height: 20),
          Text(
            'تسجيل الدخول عبر البريد أو Google أو Firebase',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textMutedLight,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = EdgeInsets.fromLTRB(
      horizontalPadding,
      20,
      horizontalPadding,
      28,
    );

    if (embedInParentScrollView) {
      return ColoredBox(
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: padding,
            child: Center(child: _formBody(mainAxisAlignment: MainAxisAlignment.start)),
          ),
        ),
      );
    }

    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double minHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight -
                    MediaQuery.paddingOf(context).vertical -
                    48
                : 0;
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: padding,
              child: Center(
                child: _formBody(
                  mainAxisAlignment: MainAxisAlignment.center,
                  minHeight: minHeight,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Image.asset(
          'images/app_logo.png',
          height: 80,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 20),
        Text(
          'مرحبًا بك — نقاط التفتيش في متناول يدك',
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            color: AppColors.textMutedLight,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.theme,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onObscurePasswordChanged,
    required this.isLoading,
    required this.inputsEnabled,
    required this.onEmailLogin,
    required this.onEmailRegister,
    required this.onGoogleSignIn,
    required this.onSkipForLater,
    required this.errorText,
  });

  final GlobalKey<FormState> formKey;
  final ThemeData theme;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final ValueChanged<bool> onObscurePasswordChanged;
  final bool isLoading;
  final bool inputsEnabled;
  final VoidCallback onEmailLogin;
  final VoidCallback onEmailRegister;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onSkipForLater;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = theme.colorScheme;

    return Material(
      color: AppColors.cardLight,
      elevation: 0,
      shadowColor: Colors.transparent,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.borderSubtleLight),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.brandTeal.withValues(alpha: 0.08),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'تسجيل الدخول',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'أدخل البريد وكلمة المرور واضغط «متابعة»، أو أنشئ حساباً جديداً، أو استخدم Google.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMutedLight,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            AutofillGroup(
              onDisposeAction: AutofillContextAction.cancel,
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextFormField(
                        controller: emailController,
                        enabled: inputsEnabled,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        // One clear identity hint so browsers pair this value with password.
                        autofillHints: const <String>[AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        textAlign: TextAlign.start,
                        validator: (String? v) {
                          final String t = v?.trim() ?? '';
                          if (t.isEmpty) {
                            return 'أدخل البريد الإلكتروني';
                          }
                          if (!t.contains('@')) {
                            return 'بريد إلكتروني غير صالح';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'البريد الإلكتروني',
                          hintStyle: TextStyle(
                            color: AppColors.textMutedLight.withValues(
                              alpha: 0.85,
                            ),
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(
                            Icons.mail_outline_rounded,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: TextFormField(
                        controller: passwordController,
                        enabled: inputsEnabled,
                        obscureText: obscurePassword,
                        keyboardType: TextInputType.visiblePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        enableIMEPersonalizedLearning: false,
                        autofillHints: const <String>[AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        textAlign: TextAlign.start,
                        validator: (String? v) {
                          final String t = v ?? '';
                          if (t.length < 6) {
                            return 'كلمة المرور 6 أحرف على الأقل';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => onEmailLogin(),
                        decoration: InputDecoration(
                          hintText: 'كلمة المرور',
                          hintStyle: TextStyle(
                            color: AppColors.textMutedLight.withValues(
                              alpha: 0.85,
                            ),
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: scheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.borderSubtleLight,
                            width: 1,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          clipBehavior: Clip.antiAlias,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: inputsEnabled
                                ? () =>
                                      onObscurePasswordChanged(!obscurePassword)
                                : null,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                10,
                                8,
                                14,
                                8,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: Checkbox(
                                      value: !obscurePassword,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      side: BorderSide(
                                        color: scheme.outline.withValues(
                                          alpha: 0.55,
                                        ),
                                        width: 1.5,
                                      ),
                                      fillColor:
                                          WidgetStateProperty.resolveWith((
                                            Set<WidgetState> states,
                                          ) {
                                            if (states.contains(
                                              WidgetState.disabled,
                                            )) {
                                              return AppColors.surfaceSoft;
                                            }
                                            if (states.contains(
                                              WidgetState.selected,
                                            )) {
                                              return scheme.primary;
                                            }
                                            return AppColors.cardLight;
                                          }),
                                      checkColor: scheme.onPrimary,
                                      onChanged: inputsEnabled
                                          ? (bool? showPlain) {
                                              if (showPlain == null) {
                                                return;
                                              }
                                              onObscurePasswordChanged(
                                                !showPlain,
                                              );
                                            }
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'عرض كلمة المرور',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textPrimaryLight,
                                      fontWeight: FontWeight.w600,
                                      height: 1.25,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...<Widget>[
              FilledButton(
                onPressed: onEmailLogin,
                style: FilledButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'متابعة',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onEmailRegister,
                child: Text(
                  'إنشاء حساب جديد',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Divider(
                      color: scheme.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'أو',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMutedLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(
                      color: scheme.outline.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _GradientGoogleButton(onPressed: onGoogleSignIn),
              const SizedBox(height: 10),
              TextButton(
                onPressed: onSkipForLater,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMutedLight,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Skip for later'),
              ),
            ],
            if (errorText != null) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: scheme.error.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.error_outline_rounded,
                      color: scheme.error,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        errorText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GradientGoogleButton extends StatelessWidget {
  const _GradientGoogleButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[AppColors.brandTeal, AppColors.brandTealDark],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.brandTeal.withValues(alpha: 0.40),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.2),
          highlightColor: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandTealDark,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'Continue with Google',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
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
