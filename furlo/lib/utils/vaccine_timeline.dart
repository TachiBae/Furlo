import '../models/vaccination.dart';

enum VaccineEventKind { given, due, overdue, today }

/// One point on a pet's vaccine timeline.
typedef VaccineEvent = ({
  VaccineEventKind kind,
  DateTime date,
  String title,
  Vaccination? vaccination,
});

/// A pet's vaccine history and upcoming doses in date order, with a
/// [VaccineEventKind.today] marker between past and future.
///
/// Each record contributes its dose (when [Vaccination.dateGiven] is set) and,
/// unless marked complete, its next due date: overdue when that date is
/// before today.
List<VaccineEvent> buildVaccineTimeline(
  List<Vaccination> vaccinations, {
  DateTime? today,
}) {
  final now = today ?? DateTime.now();
  final todayOnly = DateTime(now.year, now.month, now.day);
  DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);
  final events = <VaccineEvent>[
    for (final v in vaccinations) ...[
      if (v.dateGiven != null)
        (
          kind: VaccineEventKind.given,
          date: day(v.dateGiven!),
          title: v.vaccineName,
          vaccination: v,
        ),
      if (v.nextDueDate != null && !v.isCompleted)
        (
          kind: day(v.nextDueDate!).isBefore(todayOnly)
              ? VaccineEventKind.overdue
              : VaccineEventKind.due,
          date: day(v.nextDueDate!),
          title: v.vaccineName,
          vaccination: v,
        ),
    ],
  ];
  if (events.isEmpty) return const [];
  events.add((
    kind: VaccineEventKind.today,
    date: todayOnly,
    title: 'Today',
    vaccination: null,
  ));
  // Past first; on the same day, doses given come before the Today marker,
  // and due dates after it.
  int rank(VaccineEventKind kind) => switch (kind) {
    VaccineEventKind.given => 0,
    VaccineEventKind.overdue => 1,
    VaccineEventKind.today => 2,
    VaccineEventKind.due => 3,
  };
  events.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    return byDate != 0 ? byDate : rank(a.kind).compareTo(rank(b.kind));
  });
  return events;
}
