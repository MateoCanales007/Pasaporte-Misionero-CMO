import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/models/app_user.dart';
import '../../providers/content_providers.dart';
import '../../providers/session_providers.dart';
import '../../widgets/state_views.dart';
import 'widgets/achievements_section.dart';
import 'widgets/notification_prompt_card.dart';
import 'widgets/passport_cover.dart';
import 'widgets/pending_redemptions_section.dart';
import 'widgets/stamp_list.dart';

/// Pasaporte animado: portada y, al abrirlo, las páginas de sellos.
class PassportTab extends ConsumerStatefulWidget {
  const PassportTab({super.key});

  @override
  ConsumerState<PassportTab> createState() => _PassportTabState();
}

class _PassportTabState extends ConsumerState<PassportTab> {
  bool _isOpen = false;

  /// Las páginas internas se muestran cuando termina la animación de apertura.
  bool _pagesReady = false;

  static const _duration = Duration(milliseconds: 500);

  void _setOpen(bool open) => setState(() {
    _isOpen = open;
    if (!open) _pagesReady = false;
  });

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    return AsyncValueView<AppUser?>(
      value: userAsync,
      onRetry: () => ref.invalidate(currentUserProvider),
      data: (user) {
        if (user == null) return const LoadingView();
        return LayoutBuilder(
          builder: (context, constraints) {
            final closedHeight = (constraints.maxHeight - 140).clamp(380.0, 440.0);
            return Stack(
              children: [
                AnimatedAlign(
                  alignment: _isOpen ? Alignment.topCenter : const Alignment(0, -0.4),
                  duration: _duration,
                  curve: Curves.easeInOutCubic,
                  child: Semantics(
                    button: !_isOpen,
                    label: _isOpen ? null : 'Pasaporte de ${user.fullName}. Toca para abrirlo.',
                    child: GestureDetector(
                      onTap: _isOpen ? null : () => _setOpen(true),
                      child: AnimatedContainer(
                        duration: _duration,
                        curve: Curves.easeInOutCubic,
                        width: _isOpen ? constraints.maxWidth : 280,
                        height: _isOpen ? constraints.maxHeight : closedHeight,
                        margin: _isOpen ? EdgeInsets.zero : const EdgeInsets.only(top: AppSpacing.lg),
                        decoration: passportDecoration(isOpen: _isOpen),
                        onEnd: () {
                          if (_isOpen && !_pagesReady) setState(() => _pagesReady = true);
                        },
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: !_isOpen
                              ? PassportCover(key: const ValueKey('cover'), user: user, height: closedHeight)
                              : _pagesReady
                              ? _InsidePages(key: const ValueKey('inside'), user: user, onClose: () => _setOpen(false))
                              : const SizedBox.shrink(key: ValueKey('opening')),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Pasaporte abierto con dos páginas: "Mi progreso" y "Mis sellos".
/// En pantallas anchas se ven una junto a la otra, como un libro abierto. En
/// el teléfono se pasa de una a otra con los botones de arriba o deslizando.
class _InsidePages extends ConsumerStatefulWidget {
  const _InsidePages({super.key, required this.user, required this.onClose});

  final AppUser user;
  final VoidCallback onClose;

  @override
  ConsumerState<_InsidePages> createState() => _InsidePagesState();
}

class _InsidePagesState extends ConsumerState<_InsidePages> {
  static const _wideLayout = 760.0;

  final _pages = PageController(viewportFraction: 0.94);
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    setState(() => _page = page);
    _pages.animateToPage(page, duration: const Duration(milliseconds: 350), curve: Curves.easeInOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stamps = ref.watch(passportStampsProvider);

    // Página 1: los sellos (con los escaneos pendientes y el aviso de notificaciones).
    final stampsPage = _PassportPage(
      title: 'Mis sellos',
      icon: Icons.approval_rounded,
      pageLabel: 'Página 1',
      children: [
        Text('¡Bienvenido, ${widget.user.fullName}!', style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Estos son los sellos de tu viaje de intercesión.',
          style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
        const PendingRedemptionsSection(),
        const NotificationPromptCard(),
        const SizedBox(height: AppSpacing.md),
        StampList(stamps: stamps, showTitle: false, onRetry: () => ref.invalidate(serverRedemptionsProvider)),
      ],
    );
    // Página 2: el progreso y las insignias.
    const progressPage = _PassportPage(
      title: 'Mi progreso',
      icon: Icons.emoji_events_rounded,
      pageLabel: 'Página 2',
      children: [AchievementsSection(showTitle: false)],
    );

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.onClose,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Cerrar pasaporte'),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= _wideLayout) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: stampsPage),
                      const _Spine(),
                      Expanded(child: progressPage),
                    ],
                  );
                }
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 0, label: Text('Mis sellos'), icon: Icon(Icons.approval_rounded)),
                          ButtonSegment(value: 1, label: Text('Mi progreso'), icon: Icon(Icons.emoji_events_rounded)),
                        ],
                        selected: {_page},
                        showSelectedIcon: false,
                        onSelectionChanged: (value) => _goTo(value.first),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: PageView(
                        controller: _pages,
                        padEnds: false,
                        onPageChanged: (page) => setState(() => _page = page),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                            child: stampsPage,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.sm),
                            child: progressPage,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Una hoja del pasaporte: papel claro con título y número de página.
class _PassportPage extends StatelessWidget {
  const _PassportPage({required this.title, required this.icon, required this.pageLabel, required this.children});

  final String title;
  final IconData icon;
  final String pageLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF7),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: AppColors.yellow, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.yellowSoft,
              borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusSmall - 2)),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.orangeDark, size: 28),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(header: true, child: Text(title, style: theme.textTheme.titleLarge)),
                      Text(pageLabel, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 100),
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lomo del pasaporte entre las dos páginas (pantallas anchas).
class _Spine extends StatelessWidget {
  const _Spine();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: 28,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(
            14,
            (_) => Container(width: 2, height: 12, color: Colors.white.withValues(alpha: 0.3)),
          ),
        ),
      ),
    );
  }
}
