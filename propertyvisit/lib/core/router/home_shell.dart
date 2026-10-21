import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../features/auth/domain/user.dart';
import '../../features/auth/presentation/auth_cubit.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final isBuyer =
        context.watch<AuthCubit>().state.user?.role != UserRole.admin;
    final destinations = isBuyer
        ? const [
            NavigationDestination(
              icon: Icon(LucideIcons.building2),
              selectedIcon: Icon(LucideIcons.building2),
              label: 'Каталог',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.calendarCheck),
              selectedIcon: Icon(LucideIcons.calendarCheck),
              label: 'Мои просмотры',
            ),
          ]
        : const [
            NavigationDestination(
              icon: Icon(LucideIcons.house),
              selectedIcon: Icon(LucideIcons.house),
              label: 'Квартиры',
            ),
            NavigationDestination(
              icon: Icon(LucideIcons.clipboardList),
              selectedIcon: Icon(LucideIcons.clipboardList),
              label: 'Бронирования',
            ),
          ];

    void select(int index) =>
        shell.goBranch(index, initialLocation: index == shell.currentIndex);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final ios = Theme.of(context).platform == TargetPlatform.iOS;
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: select,
              labelType: NavigationRailLabelType.all,
              destinations: destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: d.icon,
                      selectedIcon: d.selectedIcon,
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: shell),
          ],
        ),
      );
    }
    return Scaffold(
      body: shell,
      bottomNavigationBar: ios
          ? CupertinoTabBar(
              currentIndex: shell.currentIndex,
              onTap: select,
              backgroundColor: Theme.of(context).colorScheme.surface,
              activeColor: Theme.of(context).colorScheme.primary,
              inactiveColor: Theme.of(context).colorScheme.onSurfaceVariant,
              items: destinations
                  .map(
                    (d) => BottomNavigationBarItem(
                      icon: d.icon,
                      activeIcon: d.selectedIcon,
                      label: d.label,
                    ),
                  )
                  .toList(),
            )
          : NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: select,
              destinations: destinations,
            ),
    );
  }
}
