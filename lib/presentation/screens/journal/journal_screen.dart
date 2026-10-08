import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/business_time.dart';
import '../../../domain/models/journal_entry.dart';
import '../../providers/content_providers.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/state_views.dart';
import 'journal_entry_screen.dart';

/// Diario privado de oración: solo su dueño puede verlo.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  void _newEntry(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const JournalEntryScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(journalEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mi diario de oración')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.orange,
        foregroundColor: AppColors.onOrange,
        onPressed: () => _newEntry(context),
        icon: const Icon(Icons.edit_rounded),
        label: const Text('Nueva reflexión'),
      ),
      body: AsyncValueView<List<JournalEntry>>(
        value: entries,
        onRetry: () => ref.invalidate(journalEntriesProvider),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 120),
          children: [
            ResponsiveCenter(child: _JournalHeader(count: list.length)),
            if (list.isEmpty)
              ResponsiveCenter(child: _EmptyJournal(onWrite: () => _newEntry(context)))
            else
              for (final group in _groupByMonth(list)) ...[
                ResponsiveCenter(child: _MonthHeader(label: group.label)),
                for (final entry in group.entries)
                  ResponsiveCenter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _EntryCard(entry: entry),
                    ),
                  ),
              ],
          ],
        ),
      ),
    );
  }

  /// Agrupa por mes (hora de El Salvador), respetando el orden recibido.
  static List<({String label, List<JournalEntry> entries})> _groupByMonth(List<JournalEntry> entries) {
    final groups = <({String label, List<JournalEntry> entries})>[];
    for (final entry in entries) {
      final date = entry.createdAt;
      final label = date == null
          ? 'Hoy'
          : toBeginningOfSentenceCase(DateFormat("MMMM 'de' y", 'es').format(BusinessTime.toWallClock(date)));
      if (groups.isEmpty || groups.last.label != label) {
        groups.add((label: label, entries: [entry]));
      } else {
        groups.last.entries.add(entry);
      }
    }
    return groups;
  }
}

class _JournalHeader extends StatelessWidget {
  const _JournalHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        gradient: const LinearGradient(
          colors: [AppColors.navyDark, AppColors.navy, AppColors.navyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.yellow,
                child: Icon(Icons.auto_stories_rounded, color: AppColors.navy, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  count == 0 ? 'Tu espacio con Dios' : (count == 1 ? '1 reflexión' : '$count reflexiones'),
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '«Orad sin cesar.»',
            style: theme.textTheme.titleMedium?.copyWith(color: AppColors.yellow, fontStyle: FontStyle.italic),
          ),
          Text('1 Tesalonicenses 5:17', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
          const SizedBox(height: AppSpacing.md),
          const Row(
            children: [
              Icon(Icons.lock_rounded, color: Colors.white70, size: 20),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Este diario es privado. Solo tú puedes leerlo.',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(label, style: Theme.of(context).textTheme.titleLarge)),
          const SizedBox(height: AppSpacing.xs),
          const BrandStripe(width: 48),
        ],
      ),
    );
  }
}

class _EmptyJournal extends StatelessWidget {
  const _EmptyJournal({required this.onWrite});

  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 44,
            backgroundColor: AppColors.yellowSoft,
            child: Icon(Icons.edit_note_rounded, size: 52, color: AppColors.orangeDark),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Tu diario está vacío', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Escribe lo que Dios te habla, tus oraciones y lo que vives en cada misión.',
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: onWrite,
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Escribir mi primera reflexión'),
          ),
        ],
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry});

  final JournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = entry.createdAt;
    final wall = created == null ? null : BusinessTime.toWallClock(created);
    final dateLabel = created == null ? 'Hoy' : BusinessTime.formatLongDate(created);

    return Semantics(
      button: true,
      label: 'Reflexión del $dateLabel. Toca para leerla o editarla.',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radius),
        clipBehavior: Clip.antiAlias,
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        child: InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JournalEntryScreen(entry: entry))),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppColors.orange, width: 6)),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 64,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.yellowSoft,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: Column(
                      children: [
                        Text(
                          wall == null ? '•' : '${wall.day}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.orangeDark,
                          ),
                        ),
                        Text(
                          wall == null ? 'hoy' : DateFormat('EEE', 'es').format(wall),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.navy),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.missionName != null) ...[
                        StatusChip.info(entry.missionName!, icon: Icons.flag_rounded),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      Text(
                        entry.text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (entry.hasPendingWrites)
                        StatusChip.warning('Pendiente de guardar', icon: Icons.cloud_upload_rounded)
                      else
                        Row(
                          children: [
                            const Icon(Icons.cloud_done_rounded, size: 18, color: AppColors.success),
                            const SizedBox(width: AppSpacing.xs),
                            Text('Guardado', style: theme.textTheme.bodySmall),
                          ],
                        ),
                    ],
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
