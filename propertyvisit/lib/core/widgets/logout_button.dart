import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../features/auth/presentation/auth_cubit.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Выйти',
    icon: const Icon(LucideIcons.logOut),
    onPressed: () async {
      final confirmed = await showAdaptiveDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog.adaptive(
          title: const Text('Выйти из аккаунта?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Выйти'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      try {
        await context.read<AuthCubit>().logout();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Не удалось выйти. Попробуйте снова.'),
            ),
          );
        }
      }
    },
  );
}
