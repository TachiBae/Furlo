import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/pet.dart';
import '../../models/weight_log.dart';
import '../../providers/weight_tracking_provider.dart';
import '../../repositories/pet_repository.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatting.dart';
import '../../utils/weight_tracking.dart';
import '../../widgets/record_components.dart';

class WeightTrackingScreen extends StatelessWidget {
  const WeightTrackingScreen({
    super.key,
    required this.repository,
    required this.pets,
    this.selectedPet,
  });
  final PetRepository repository;
  final List<Pet> pets;
  final Pet? selectedPet;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => WeightTrackingProvider(
      repository: repository,
      pets: pets,
      selectedPet: selectedPet,
    ),
    child: const _WeightTrackingView(),
  );
}

class _WeightTrackingView extends StatefulWidget {
  const _WeightTrackingView();
  @override
  State<_WeightTrackingView> createState() => _WeightTrackingViewState();
}

class _WeightTrackingViewState extends State<_WeightTrackingView> {
  Future<void> _edit(
    WeightTrackingProvider state, [
    WeightLog? existing,
  ]) async {
    final petId = existing?.petId ?? state.selectedPet?.id;
    if (petId == null || state.saving) return;
    final result = await Navigator.of(context).push<WeightLog>(
      MaterialPageRoute(
        builder: (_) => WeightEntryFormScreen(petId: petId, existing: existing),
      ),
    );
    if (result == null || !mounted) return;
    try {
      await state.save(result);
    } catch (_) {
      if (mounted) _message('The weight entry could not be saved.');
    }
  }

  Future<void> _delete(WeightTrackingProvider state, WeightLog log) async {
    final confirmed = await confirmRecordDelete(
      context,
      title: 'Delete weight entry?',
      message: 'Delete this ${_weight(log.weight)} entry?',
    );
    if (!confirmed || !mounted) return;
    try {
      await state.delete(log);
    } catch (_) {
      if (mounted) _message('The weight entry could not be deleted.');
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) => Consumer<WeightTrackingProvider>(
    builder: (context, state, _) {
      final logs = state.logs;
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: const Text('Weight Tracking'),
        ),
        floatingActionButton: state.selectedPet == null || state.logs.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: state.saving ? null : () => _edit(state),
                icon: const Icon(Icons.add),
                label: const Text('Add weight'),
              ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: CustomScrollView(
                slivers: [
                  if (state.selectedPet != null)
                    SliverToBoxAdapter(
                      child: PetSelectorTabs(
                        pets: state.pets,
                        selectedPet: state.selectedPet!,
                        onSelected: state.selectPet,
                      ),
                    ),
                  if (state.loading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.error != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: RecordEmptyState(
                        icon: Icons.error_outline,
                        title: state.error!,
                        message: 'Check your connection, then try again.',
                        actionLabel: 'Try again',
                        onAction: state.refresh,
                      ),
                    )
                  else if (state.selectedPet == null)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: RecordEmptyState(
                        title: 'No pets yet',
                        message: 'Add a pet before tracking its weight.',
                        icon: Icons.monitor_weight_outlined,
                      ),
                    )
                  else if (logs.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: RecordEmptyState(
                        title: 'No weight entries yet',
                        message:
                            'Add your pet’s first weight to start tracking its trend.',
                        icon: Icons.monitor_weight_outlined,
                        actionLabel: 'Add weight',
                        onAction: () => _edit(state),
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(child: _SummaryRow(logs: logs)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(
                          'Weight trend ($weightUnit)',
                          style: AppTypography.h2,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 210,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
                          child: _WeightTrendChart(logs: logs),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Text('History', style: AppTypography.h2),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 104),
                      sliver: SliverList.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return RecordCard(
                            onTap: () => _edit(state, log),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _weight(log.weight),
                                          style: AppTypography.h2,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          formatShortDate(log.date),
                                          style: AppTypography.caption.copyWith(
                                            color: log.date == null
                                                ? context.appColors.textDisabled
                                                : context
                                                      .appColors
                                                      .textSecondary,
                                          ),
                                        ),
                                        if ((log.notes ?? '').trim().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Text(
                                              log.notes!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.body
                                                  .copyWith(
                                                    color: context
                                                        .appColors
                                                        .textSecondary,
                                                  ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete weight entry',
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
                                    onPressed: () => _delete(state, log),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.logs});
  final List<WeightLog> logs;
  @override
  Widget build(BuildContext context) {
    final latest = logs.first;
    final change = weightChangeSincePrevious(logs);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _SummaryValue(
              label: 'Current weight',
              value: _weight(latest.weight),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryValue(
              label: 'Change',
              value: change == null ? '—' : _formatChange(change),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Card(
    color: context.appColors.surface,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: context.appColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyStrong,
          ),
        ],
      ),
    ),
  );
}

class _WeightTrendChart extends StatelessWidget {
  const _WeightTrendChart({required this.logs});
  final List<WeightLog> logs;
  @override
  Widget build(BuildContext context) {
    final chronological = chronologicalWeightLogs(logs);
    final values = chronological.map((log) => log.weight).toList();
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final padding = maxValue == minValue
        ? (maxValue.abs() * .05).clamp(.5, 2.0)
        : (maxValue - minValue) * .18;
    final interval = (chronological.length / 4)
        .ceil()
        .toDouble()
        .clamp(1, chronological.length)
        .toDouble();
    final maxX = chronological.length <= 1
        ? 1.0
        : (chronological.length - 1).toDouble();
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: (minValue - padding).clamp(0, double.infinity),
        maxY: maxValue + padding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: ((maxValue - minValue).abs() / 3).clamp(
            .5,
            double.infinity,
          ),
          getDrawingHorizontalLine: (_) => FlLine(
            color: context.appColors.textDisabled.withValues(alpha: .35),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: true),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  value.toStringAsFixed(1),
                  style: AppTypography.label.copyWith(
                    color: context.appColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: interval,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 ||
                    index >= chronological.length ||
                    (value - index).abs() > .1) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    formatMonthDay(chronological[index].date),
                    style: AppTypography.label.copyWith(
                      color: context.appColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var index = 0; index < chronological.length; index++)
                FlSpot(index.toDouble(), chronological[index].weight),
            ],
            isCurved: false,
            color: context.appColors.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: context.appColors.accent,
                strokeColor: context.appColors.primary,
                strokeWidth: 1.5,
              ),
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

class WeightEntryFormScreen extends StatefulWidget {
  const WeightEntryFormScreen({super.key, required this.petId, this.existing});
  final String petId;
  final WeightLog? existing;
  @override
  State<WeightEntryFormScreen> createState() => _WeightEntryFormScreenState();
}

class _WeightEntryFormScreenState extends State<WeightEntryFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _weight = TextEditingController(
    text: widget.existing?.weight.toString(),
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.existing?.notes ?? '',
  );
  late DateTime _date = widget.existing?.date ?? DateTime.now();

  @override
  void dispose() {
    _weight.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final initial = _date.isAfter(now) ? now : _date;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (date != null && mounted) setState(() => _date = date);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      WeightLog(
        id: widget.existing?.id,
        petId: widget.petId,
        date: _date,
        weight: double.parse(_weight.text.trim()),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.existing == null ? 'Add Weight Entry' : 'Edit Weight Entry',
      ),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: validateWeight,
            decoration: _decoration('Weight ($weightUnit)'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _chooseDate,
            style: AppComponents.secondaryButton,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Date: ${formatShortDate(_date)}'),
                const Icon(Icons.calendar_today_outlined),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notes,
            minLines: 3,
            maxLines: 5,
            decoration: _decoration('Notes (optional)'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            style: AppComponents.primaryButton,
            child: const Text('Save entry'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: AppComponents.secondaryButton,
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: context.appColors.surface,
    border: OutlineInputBorder(borderRadius: AppRadius.mdRadius),
  );
}

String _weight(double value) =>
    '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)} $weightUnit';
String _formatChange(double change) {
  final twoPlaces = change.toStringAsFixed(2);
  final amount = twoPlaces.endsWith('00')
      ? change.toStringAsFixed(1)
      : twoPlaces.endsWith('0')
      ? twoPlaces.substring(0, twoPlaces.length - 1)
      : twoPlaces;
  return '${change > 0 ? '+' : ''}$amount $weightUnit';
}
