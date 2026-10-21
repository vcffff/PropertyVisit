import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../auth_cubit.dart';
import '../../data/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _obscured = true;
  bool _confirmObscured = true;
  bool _registering = false;
  bool _registered = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (context.read<AuthCubit>().state.submitting ||
        !_form.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    final auth = context.read<AuthCubit>();
    if (!_registering) {
      await auth.login(_email.text.trim(), _password.text);
      return;
    }
    final created = await auth.register(_email.text.trim(), _password.text);
    if (!mounted || !created) return;
    setState(() {
      _registering = false;
      _registered = true;
      _confirmPassword.clear();
    });
    _resetValidation();
  }

  void _toggleMode() {
    if (context.read<AuthCubit>().state.submitting) return;
    context.read<AuthCubit>().clearError();
    setState(() {
      _registering = !_registering;
      _registered = false;
      _confirmPassword.clear();
    });
    _resetValidation();
  }

  void _resetValidation() {
    final email = _email.text;
    final password = _password.text;
    _form.currentState?.reset();
    _email.text = email;
    _password.text = password;
    _confirmPassword.clear();
  }

  void _demo(String email) {
    _email.text = email;
    _password.text = 'demo1234';
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submitting = context.select<AuthCubit, bool>(
      (cubit) => cubit.state.submitting,
    );
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'PropertyVisit',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 48),
                      Text(
                        _registering
                            ? 'Создайте аккаунт'
                            : 'Посмотрите.\nПочувствуйте себя дома.',
                        style: theme.textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _registering
                            ? 'Укажите email и придумайте пароль от 6 символов.'
                            : 'Бронирование просмотров недвижимости\nбез звонков и переписок',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 36),
                      TextFormField(
                        controller: _email,
                        enabled: !submitting,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'you@example.kz',
                        ),
                        validator: (value) =>
                            value == null ||
                                !RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(value.trim())
                            ? 'Введите email'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        enabled: !submitting,
                        obscureText: _obscured,
                        autofillHints: [
                          _registering
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Пароль',
                          suffixIcon: IconButton(
                            tooltip: _obscured
                                ? 'Показать пароль'
                                : 'Скрыть пароль',
                            onPressed: () =>
                                setState(() => _obscured = !_obscured),
                            icon: Icon(
                              _obscured ? LucideIcons.eye : LucideIcons.eyeOff,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Введите пароль';
                          }
                          if (_registering && value.length < 6) {
                            return 'Минимум 6 символов';
                          }
                          return null;
                        },
                      ),
                      if (_registering) ...[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPassword,
                          enabled: !submitting,
                          obscureText: _confirmObscured,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: 'Повторите пароль',
                            suffixIcon: IconButton(
                              tooltip: _confirmObscured
                                  ? 'Показать повтор пароля'
                                  : 'Скрыть повтор пароля',
                              onPressed: () => setState(
                                () => _confirmObscured = !_confirmObscured,
                              ),
                              icon: Icon(
                                _confirmObscured
                                    ? LucideIcons.eye
                                    : LucideIcons.eyeOff,
                              ),
                            ),
                          ),
                          validator: (value) => value != _password.text
                              ? 'Пароли не совпадают'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 24),
                      BlocBuilder<AuthCubit, AuthState>(
                        builder: (context, state) => Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_registered) ...[
                              Semantics(
                                liveRegion: true,
                                child: const Text(
                                  'Аккаунт создан. Нажмите «Войти», чтобы открыть каталог.',
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (state.error != null) ...[
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  state.error!,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            FilledButton(
                              onPressed: state.submitting ? null : _submit,
                              child: state.submitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator.adaptive(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(
                                      _registering
                                          ? 'Зарегистрироваться'
                                          : 'Войти',
                                    ),
                            ),
                            if (!context.read<AuthRepository>().isDemo) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: state.submitting
                                    ? null
                                    : _toggleMode,
                                child: Text(
                                  _registering
                                      ? 'Уже есть аккаунт? Войти'
                                      : 'Создать аккаунт',
                                ),
                              ),
                            ],
                            if (context.read<AuthRepository>().isDemo) ...[
                              const SizedBox(height: 32),
                              const Divider(),
                              const SizedBox(height: 24),
                              Text(
                                'Попробуйте демо',
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Знакомство с приложением без регистрации. Объекты и фотографии — для примера.',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: state.submitting
                                        ? null
                                        : () => _demo('buyer@demo.kz'),
                                    icon: const Icon(LucideIcons.userRound),
                                    label: const Text('Покупатель'),
                                  ),
                                  TextButton(
                                    onPressed: state.submitting
                                        ? null
                                        : () => _demo('admin@demo.kz'),
                                    child: const Text('Менеджер'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Демо-пароль: demo1234',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
