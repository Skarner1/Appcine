import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/services/notification_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/models/content_item.dart';
import 'features/catalog/catalog_screen.dart';
import 'features/content_form/content_form_screen.dart';
import 'features/detail/content_detail_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/recommendations/recommendations_screen.dart';
import 'features/watchlist/watchlist_screen.dart';
import 'providers/providers.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class CineLogApp extends StatelessWidget {
  const CineLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CineLog Pro',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: AppTheme.dark(),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppShell(),
    );
  }
}

/// Contenedor principal con BottomNavigationBar custom de 72dp y 4 pestañas.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _tabs = [
    (
      icon: Icons.video_library_outlined,
      activeIcon: Icons.video_library,
      label: 'Catálogo',
    ),
    (
      icon: Icons.bookmark_outline,
      activeIcon: Icons.bookmark,
      label: 'Por Ver',
    ),
    (
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'Recomendados',
    ),
    (
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Mi Perfil',
    ),
  ];

  @override
  void initState() {
    super.initState();
    NotificationService.instance.onNotificationTap = _handleNotificationTap;
    // Si la app se abrió desde una notificación (cold start), procesarla.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final response = await NotificationService.instance.launchResponse();
      if (response?.payload != null && response!.payload!.isNotEmpty) {
        _handleNotificationTap(response.payload!, response.actionId);
      }
    });
  }

  Future<void> _handleNotificationTap(
    String contentId,
    String? actionId,
  ) async {
    final item = ref.read(contentRepositoryProvider).getById(contentId);
    if (item == null) return;
    final actions = ref.read(contentActionsProvider);

    switch (actionId) {
      case NotificationActions.snooze:
        await actions.snooze(item);
      case NotificationActions.dismiss:
        await actions.dismissNotification(item);
      case NotificationActions.watchNow:
        await actions.save(item.copyWith(
          status: item.status == WatchStatus.completed
              ? item.status
              : WatchStatus.watching,
          notifyMe: false,
          clearNotificationDate: true,
        ));
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ContentDetailScreen(contentId: contentId),
          ),
        );
      default:
        appNavigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => ContentDetailScreen(contentId: contentId),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          CatalogScreen(),
          WatchlistScreen(),
          RecommendationsScreen(),
          ProfileScreen(),
        ],
      ),
      floatingActionButton: _index == 0
          ? AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _CatalogFab(key: const ValueKey('fab')),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: _tabs[i].icon,
                      activeIcon: _tabs[i].activeIcon,
                      label: _tabs[i].label,
                      selected: _index == i,
                      onTap: () => setState(() => _index = i),
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

class _CatalogFab extends StatelessWidget {
  const _CatalogFab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: SizedBox(
        height: 64,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: AppColors.primaryGradient,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ContentFormScreen()),
              ),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: Colors.white, size: 26),
                    const SizedBox(width: 8),
                    Text(
                      'Agregar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  selected ? activeIcon : icon,
                  key: ValueKey(selected),
                  size: 26,
                  color:
                      selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
