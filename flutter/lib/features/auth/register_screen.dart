import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/app_preferences.dart';
import '../../core/storage/auth_storage.dart';
import '../../data/repositories/student_repository.dart';
import '../../features/eino/eino_face.dart';
import '../../shared/widgets/app_card.dart';
import '../../shared/utils/academic_labels.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _academicLoading = true;
  String? _errorMessage;
  String? _academicLoadError;
  List<Map<String, dynamic>> _departments = const [];
  List<Map<String, dynamic>> _semesters = const [];
  String? _selectedDepartment;
  String? _selectedSemester;

  ApiClient? _client;
  AuthStorage? _storage;
  StudentRepository? _studentRepo;

  @override
  void initState() {
    super.initState();
    _initAuth();
  }

  Future<void> _initAuth() async {
    try {
      _storage = await AuthStorage.create();
      _client = ApiClient(baseUrl: AppConstants.apiBaseUrl, authStorage: _storage!);
      _studentRepo = StudentRepository(_client!);
      final repo = _studentRepo!;
      final results = await Future.wait<List<Map<String, dynamic>>>([
        repo.departments(),
        repo.semesters(),
      ]);
      if (!mounted) return;
      setState(() {
        _departments = results[0];
        _semesters = results[1];
        _academicLoading = false;
        _academicLoadError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _academicLoading = false;
          _academicLoadError = e.toString();
          _errorMessage ??= e.toString();
        });
      }
    }
  }


  @override
  void dispose() {
    _studentNumberController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _client?.dispose();
    super.dispose();
  }

  Future<void> _performRegister() async {
    final l10n = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = l10n.t('passwordMismatch'));
      return;
    }

    if (_passwordController.text.length < 8) {
      setState(() => _errorMessage = l10n.t('passwordTooShort'));
      return;
    }
    final studentNumber = _studentNumberController.text.trim();
    if (!isValidAcademicId(studentNumber)) {
      setState(() => _errorMessage = l10n.t('academicIdFormatHelp'));
      return;
    }
    if (_selectedDepartment == null || _selectedSemester == null) {
      setState(() => _errorMessage = l10n.t('academicSelectionRequired'));
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_studentRepo == null || _storage == null) {
        await _initAuth();
      }
      if (_studentRepo == null || _storage == null) {
        throw const ApiException('تعذر تهيئة خدمة التسجيل. أعد المحاولة.');
      }
      final repo = _studentRepo!;
      final result = await repo.register(
        studentNumber: studentNumber,
        password: _passwordController.text,
        email: _emailController.text.trim(),
        departmentId: _selectedDepartment!,
        semesterId: _selectedSemester!,
      );

      await _storage?.saveSession(result);

      final prefs = AppPreferences();
      await prefs.init();
      await prefs.setOnboardingCompleted(true);

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.t('registerSuccess')),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
      context.go('/media');
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? switch (e.code) {
              'STUDENT_NOT_FOUND' => l10n.t('registerStudentNotFound'),
              'REGISTER_ACADEMIC_MISMATCH' => l10n.t('registerAcademicMismatch'),
              'ACCOUNT_ALREADY_REGISTERED' => l10n.t('registerAlreadyRegistered'),
              'EMAIL_ALREADY_IN_USE' => l10n.t('registerEmailInUse'),
              'REGISTER_FIELDS_REQUIRED' => l10n.t('academicSelectionRequired'),
              _ => l10n.t('registerGenericError'),
            }
          : l10n.t('registerGenericError');
      setState(() => _errorMessage = message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('registerTitle')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/media');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22.08, vertical: 14.72),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header with Eino
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(3.68),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: primary.withValues(alpha: 0.3), width: 2),
                              ),
                              child: const EinoFace(size: 80, mood: EinoMood.happy),
                            ),
                          ),
                          const SizedBox(height: 14),

                          Text(
                            l10n.t('registerTitle'),
                            textAlign: TextAlign.center,
                            style:
                                theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.t('registerSubtitle'),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Form Card
                          AppCard(
                            padding: const EdgeInsets.all(20.24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Error Message Display
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(11.04),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(10.8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.error_outline_rounded,
                                            color: theme.colorScheme.onErrorContainer, size: 20),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: TextStyle(
                                              color: theme.colorScheme.onErrorContainer,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Academic ID Field
                                TextFormField(
                                  controller: _studentNumberController,
                                  keyboardType: const TextInputType.numberWithOptions(
                                    signed: true,
                                    decimal: false,
                                  ),
                                  inputFormatters: const [AcademicIdInputFormatter()],
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.left,
                                  textInputAction: TextInputAction.next,
                                  validator: (v) {
                                    final value = v?.trim() ?? '';
                                    if (value.isEmpty) return l10n.t('loginFieldsRequired');
                                    if (!isValidAcademicId(value)) return l10n.t('academicIdFormatHelp');
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    labelText: l10n.t('academicId'),
                                    hintText: l10n.t('academicIdHint'),
                                    helperText: l10n.t('academicIdFormatHelp'),
                                    prefixIcon: const Icon(Icons.badge_outlined),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.6)),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Academic department
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedDepartment,
                                  isExpanded: true,
                                  items: _departments
                                      .map(
                                        (department) => DropdownMenuItem<String>(
                                          value: department['id']?.toString(),
                                          child: Text(
                                            AcademicLabels.department(
                                              department,
                                              Localizations.localeOf(context).languageCode,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: _academicLoading
                                      ? null
                                      : (value) => setState(() => _selectedDepartment = value),
                                  validator: (value) =>
                                      value == null ? l10n.t('selectDepartment') : null,
                                  decoration: InputDecoration(
                                    labelText: l10n.t('selectDepartment'),
                                    helperText: l10n.t('departmentLockedHelp'),
                                    prefixIcon: const Icon(Icons.account_tree_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.6),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Academic semester
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedSemester,
                                  isExpanded: true,
                                  items: _semesters
                                      .map(
                                        (semester) => DropdownMenuItem<String>(
                                          value: semester['id']?.toString(),
                                          child: Text(
                                            AcademicLabels.semester(
                                              semester,
                                              Localizations.localeOf(context).languageCode,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: _academicLoading
                                      ? null
                                      : (value) => setState(() => _selectedSemester = value),
                                  validator: (value) =>
                                      value == null ? l10n.t('selectSemester') : null,
                                  decoration: InputDecoration(
                                    labelText: l10n.t('selectSemester'),
                                    helperText: l10n.t('semesterFlexibleHelp'),
                                    prefixIcon: const Icon(Icons.calendar_month_outlined),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.6),
                                    ),
                                  ),
                                ),
                                if (_academicLoading) ...[
                                  const SizedBox(height: 8),
                                  const LinearProgressIndicator(minHeight: 2),
                                ],
                                if (_academicLoadError != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _academicLoadError!,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),

                                // Email (Optional)
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: InputDecoration(
                                    labelText: l10n.t('email'),
                                    hintText: l10n.t('emailHint'),
                                    prefixIcon: const Icon(Icons.email_outlined),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.6)),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Password
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.next,
                                  validator: (v) {
                                    if (v == null || v.length < 8) {
                                      return l10n.t('passwordTooShort');
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    labelText: l10n.t('password'),
                                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () => setState(
                                          () => _obscurePassword = !_obscurePassword),
                                    ),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.6)),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Confirm Password
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: _obscureConfirm,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _performRegister(),
                                  validator: (v) {
                                    if (v != _passwordController.text) {
                                      return l10n.t('passwordMismatch');
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    labelText: l10n.t('confirmPassword'),
                                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirm
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                      onPressed: () =>
                                          setState(() => _obscureConfirm = !_obscureConfirm),
                                    ),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12.6)),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Submit Button
                                SizedBox(
                                  height: 50,
                                  child: FilledButton(
                                    onPressed: _isLoading ? null : _performRegister,
                                    style: FilledButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12.6)),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            l10n.t('createAccount'),
                                            style: const TextStyle(
                                                fontSize: 14.7, fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Already have account
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                l10n.t('alreadyHaveAccount'),
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              ),
                              TextButton(
                                onPressed: () {
                                  if (context.canPop()) {
                                    context.pop();
                                  } else {
                                    context.push('/login');
                                  }
                                },
                                child: Text(
                                  l10n.t('signIn'),
                                  style: TextStyle(
                                    color: primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
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
}
