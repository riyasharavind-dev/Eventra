import 'minimal_booking_calendar.dart';

import 'package:flutter/material.dart';

import '../../models/booking_model.dart';
import '../../models/calendar_bookings.dart';
import '../bookings/booking_ui.dart';

Color calendarStatusColor(String status) => switch (status) {
  'accepted' => const Color(0xFF22844F),
  'completed' => const Color(0xFF216AB0),
  'rejected' => const Color(0xFFC62828),
  'cancelled' => const Color(0xFF757575),
  _ => const Color(0xFFBF7600),
};

class BookingMonthCalendar extends StatelessWidget {
  final bool compact;
  final List<BookingModel> bookings;
  final DateTime focusedMonth, selectedDay;
  final ValueChanged<DateTime> onMonthChanged, onDaySelected;
  const BookingMonthCalendar({
    super.key,
    this.compact = false,
    required this.bookings,
    required this.focusedMonth,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDaySelected,
  });
  @override
  Widget build(BuildContext context) {
    if (compact) {
      return MinimalBookingCalendar(
        bookings: bookings,
        focusedMonth: focusedMonth,
        selectedDay: selectedDay,
        onMonthChanged: onMonthChanged,
        onDaySelected: onDaySelected,
      );
    }
    final colors = Theme.of(context).colorScheme,
        locale = MaterialLocalizations.of(context);
    final first = DateTime(focusedMonth.year, focusedMonth.month),
        last = DateTime(first.year, first.month + 1, 0);
    final offset = (first.weekday % 7 - locale.firstDayOfWeekIndex + 7) % 7;
    final cells = ((offset + last.day) / 7).ceil() * 7;
    final start = DateTime(first.year, first.month, 1 - offset);
    final today = calendarDay(DateTime.now());
    String t(String en, String ta) => bookingText(context, en, ta);
    Future<void> jump() async {
      final picked = await showDatePicker(
        context: context,
        initialDate: selectedDay,
        firstDate: DateTime(1900),
        lastDate: DateTime(2200, 12, 31),
        initialDatePickerMode: DatePickerMode.year,
      );
      if (picked != null) {
        onMonthChanged(DateTime(picked.year, picked.month));
        onDaySelected(picked);
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      elevation: compact ? 0 : null,
      color: compact ? const Color(0xFFFCF8FA) : null,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: t('Previous month', 'முந்தைய மாதம்'),
                  onPressed: first.year <= 1900 && first.month == 1
                      ? null
                      : () => onMonthChanged(
                          DateTime(first.year, first.month - 1),
                        ),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: jump,
                    child: Text(
                      locale.formatMonthYear(first),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: t('Next month', 'அடுத்த மாதம்'),
                  onPressed: first.year >= 2200 && first.month == 12
                      ? null
                      : () => onMonthChanged(
                          DateTime(first.year, first.month + 1),
                        ),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Row(
              children: List.generate(
                7,
                (i) => Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Text(
                        locale.narrowWeekdays[(locale.firstDayOfWeekIndex + i) %
                            7],
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            ...List.generate(
              cells ~/ 7,
              (week) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(7, (column) {
                  // Construct calendar dates rather than adding 24-hour instants across DST.
                  final day = DateTime(
                    start.year,
                    start.month,
                    start.day + week * 7 + column,
                  );
                  final rows = bookingsOnDay(bookings, day),
                      selected = calendarDay(selectedDay) == day,
                      inMonth = day.month == first.month;
                  final statuses = rows.map((b) => b.status).toSet().toList()
                    ..sort();
                  final accepted = rows
                      .where((b) => b.status == 'accepted')
                      .length;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Semantics(
                        label:
                            '${locale.formatFullDate(day)}, ${rows.length} ${t('bookings', 'முன்பதிவுகள்')}, $accepted ${t('accepted commitments', 'ஏற்கப்பட்ட நிகழ்வுகள்')}',
                        selected: selected,
                        button: day.year >= 1900 && day.year <= 2200,
                        child: Material(
                          color: selected
                              ? (compact
                                    ? const Color(0xFF850E2B)
                                    : colors.primaryContainer)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            compact ? 24 : 10,
                          ),
                          child: InkWell(
                            key: ValueKey(
                              'calendar-${day.year}-${day.month}-${day.day}',
                            ),
                            onTap: day.year < 1900 || day.year > 2200
                                ? null
                                : () {
                                    if (!inMonth) {
                                      onMonthChanged(
                                        DateTime(day.year, day.month),
                                      );
                                    }
                                    onDaySelected(day);
                                  },
                            borderRadius: BorderRadius.circular(
                              compact ? 24 : 10,
                            ),
                            child: Container(
                              constraints: BoxConstraints(
                                minHeight: compact ? 48 : 68,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: day == today
                                    ? Border.all(color: colors.primary)
                                    : null,
                                borderRadius: BorderRadius.circular(
                                  compact ? 24 : 10,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      fontWeight: selected || day == today
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: compact && selected
                                          ? Colors.white
                                          : inMonth
                                          ? colors.onSurface
                                          : colors.onSurfaceVariant.withValues(
                                              alpha: 0.55,
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 2,
                                    runSpacing: 2,
                                    children: statuses
                                        .map(
                                          (s) => Container(
                                            width: 5,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              color: calendarStatusColor(s),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                  if (!compact && rows.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      '${rows.length}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: colors.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 12),
            if (!compact)
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children:
                    [
                          'pending',
                          'accepted',
                          'completed',
                          'rejected',
                          'cancelled',
                        ]
                        .map(
                          (s) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: calendarStatusColor(s),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  bookingStatus(context, s),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
              ),
          ],
        ),
      ),
    );
  }
}
