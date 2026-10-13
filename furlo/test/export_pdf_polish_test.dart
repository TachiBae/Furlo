import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:furlo/models/pet.dart';
import 'package:furlo/models/vaccination.dart';
import 'package:furlo/models/vet.dart';
import 'package:furlo/models/weight_log.dart';
import 'package:furlo/repositories/pet_repository.dart';
import 'package:furlo/services/export_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _generated = DateTime(2026, 10, 14);

PetCareSummary _summary({String? photo}) => PetCareSummary(
  pet: Pet(id: '1', name: 'Mochi', species: 'Dog', photoPath: photo),
  generatedAt: _generated,
  age: '4 yrs',
  vaccinations: [
    Vaccination(
      petId: '1',
      vaccineName: 'Rabies',
      nextDueDate: DateTime(2026, 11, 2),
    ),
    Vaccination(
      petId: '1',
      vaccineName: 'DHPP',
      nextDueDate: DateTime(2027, 3, 1),
    ),
  ],
  healthRecords: const [],
  weights: [
    WeightLog(petId: '1', date: DateTime(2026, 8, 1), weight: 12.0),
    WeightLog(petId: '1', date: DateTime(2026, 10, 10), weight: 12.4),
  ],
  vets: [
    PetCareVetSummary(
      vet: Vet(name: 'Dr. Lee', phone: '555'),
      nextAppointment: DateTime(2026, 12, 1),
    ),
  ],
);

Future<String> _pngDataUri() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 32, 32),
    Paint()..color = const Color(0xFF6E5A90),
  );
  final image = await recorder.endRecording().toImage(32, 32);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  return 'data:image/png;base64,${base64Encode(png!.buffer.asUint8List())}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('at a glance lists weight trend, next vaccine and next visit', () {
    expect(summaryHighlights(_summary()), [
      'Weight: 12.4 kg (+0.4 kg in the last month)',
      'Next vaccine: Rabies, due Nov 2, 2026',
      'Next vet visit: Dec 1, 2026 with Dr. Lee',
    ]);
  });

  test('an overdue vaccine is called out as overdue', () {
    final lines = summaryHighlights(_summary(), today: DateTime(2026, 11, 20));
    expect(lines, contains('Overdue: Rabies, was due Nov 2, 2026'));
  });

  testWidgets('the PDF embeds the pet photo, and survives a broken one', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final service = ExportService(repository: WebPetRepository());
      final plain = await service.renderSummary(_summary());
      final withPhoto = await service.renderSummary(
        _summary(photo: await _pngDataUri()),
      );
      final broken = await service.renderSummary(
        _summary(photo: 'data:image/png;base64,not-an-image'),
      );
      final notAnImage = await service.renderSummary(
        _summary(
          photo: 'data:image/png;base64,${base64Encode(List.filled(64, 7))}',
        ),
      );
      for (final bytes in [plain, withPhoto, broken, notAnImage]) {
        expect(String.fromCharCodes(bytes.take(4)), '%PDF');
      }
      expect(withPhoto.length, greaterThan(plain.length));
    });
  });
}
