import 'package:flutter/material.dart';

import '../features/events/event_models.dart';
import '../theme/app_theme.dart';

/// Resultado del filtro por fecha. `date == null` significa "limpiar filtro".
class DateFilterSelection {
  const DateFilterSelection(this.date);

  final DateTime? date;
}

/// Selector de fecha en español, alineado con el diseño morado de Aliada.
Future<DateFilterSelection?> showEventDatePicker(BuildContext context, {DateTime? initialDate}) {
  return showModalBottomSheet<DateFilterSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _EventDatePicker(initialDate: initialDate),
  );
}

class _EventDatePicker extends StatefulWidget {
  const _EventDatePicker({this.initialDate});

  final DateTime? initialDate;

  @override
  State<_EventDatePicker> createState() => _EventDatePickerState();
}

class _EventDatePickerState extends State<_EventDatePicker> {
  late DateTime _month;
  DateTime? _selected;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    _month = DateTime(initial.year, initial.month);
    _selected = widget.initialDate == null ? null : DateTime(initial.year, initial.month, initial.day);
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final leading = DateTime(_month.year, _month.month, 1).weekday - 1;
    final rows = ((leading + days + 6) ~/ 7);
    final today = DateTime.now();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(color: AppColors.grayLight, borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text('Filtrar por fecha', style: AppText.h2.copyWith(fontSize: 20))),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: AppColors.gray),
                  tooltip: 'Cerrar',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primary),
                  tooltip: 'Mes anterior',
                ),
                Expanded(
                  child: Text(
                    formatEventMonthYear(_month),
                    textAlign: TextAlign.center,
                    style: AppText.bodyStrong.copyWith(fontSize: 15),
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                  tooltip: 'Mes siguiente',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final label in const ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: AppText.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: rows * 7,
              itemBuilder: (context, index) {
                if (index < leading || index >= leading + days) return const SizedBox.shrink();
                final day = index - leading + 1;
                final date = DateTime(_month.year, _month.month, day);
                final isSelected = _sameDay(date, _selected);
                final isToday = _sameDay(date, today);

                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _selected = date),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: isToday && !isSelected
                          ? Border.all(color: AppColors.primary.withValues(alpha: 0.45))
                          : null,
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontFamily: AppFonts.ui,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 14,
                        color: isSelected ? Colors.white : AppColors.text,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(const DateFilterSelection(null)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: AppText.button.copyWith(fontSize: 14),
                    ),
                    child: const Text('Limpiar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _selected == null
                        ? null
                        : () => Navigator.of(context).pop(DateFilterSelection(_selected)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.grayLight,
                      disabledForegroundColor: AppColors.gray,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: AppText.button.copyWith(fontSize: 14),
                    ),
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime? b) => b != null && a.year == b.year && a.month == b.month && a.day == b.day;
}
