import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/health_record.dart';
import '../models/pet.dart';
import '../models/vaccination.dart';
import '../models/vet.dart';
import '../models/weight_log.dart' show WeightLog, weightUnit;
import '../repositories/pet_repository.dart';

class PetCareSummary {
  const PetCareSummary({
    required this.pet,
    required this.generatedAt,
    required this.age,
    required this.vaccinations,
    required this.healthRecords,
    required this.weights,
    required this.vets,
  });

  final Pet pet;
  final DateTime generatedAt;
  final String? age;
  final List<Vaccination> vaccinations;
  final List<HealthRecord> healthRecords;
  final List<WeightLog> weights;
  final List<PetCareVetSummary> vets;
}

class PetCareVetSummary {
  const PetCareVetSummary({required this.vet, this.nextAppointment});

  final Vet vet;
  final DateTime? nextAppointment;
}

class ExportService {
  ExportService({required this._repository});

  final PetRepository _repository;

  Future<PetCareSummary> assemblePetSummary(
    int petId, {
    DateTime? generatedAt,
  }) async {
    final pets = await _repository.getPets();
    final matches = pets.where((pet) => pet.id == petId);
    if (matches.isEmpty) throw StateError('Pet not found.');
    final pet = matches.first;
    final records = await Future.wait<Object>([
      _repository.getVaccinationsForPet(petId),
      _repository.getHealthRecordsForPet(petId),
      _repository.getWeightLogsForPet(petId),
      _repository.getVetsForPet(petId),
    ]);
    final vets = records[3] as List<Vet>;
    final vetAssociations = await Future.wait<List<VetPetAssociation>>(
      vets
          .where((vet) => vet.id != null)
          .map((vet) => _repository.getVetPetAssociations(vet.id!)),
    );
    final linkedVets = <PetCareVetSummary>[];
    final identifiedVets = vets.where((vet) => vet.id != null).toList();
    for (var index = 0; index < identifiedVets.length; index++) {
      final vet = identifiedVets[index];
      final association = vetAssociations[index].where(
        (item) => item.petId == petId,
      );
      linkedVets.add(
        PetCareVetSummary(
          vet: vet,
          nextAppointment: association.isEmpty
              ? null
              : association.first.nextAppointmentDate,
        ),
      );
    }
    return PetCareSummary(
      pet: pet,
      generatedAt: generatedAt ?? DateTime.now(),
      age: _petAge(pet.birthDate, generatedAt ?? DateTime.now()),
      vaccinations: records[0] as List<Vaccination>,
      healthRecords: records[1] as List<HealthRecord>,
      weights: records[2] as List<WeightLog>,
      vets: linkedVets,
    );
  }

  Future<Uint8List> renderSummary(PetCareSummary summary) async {
    final theme = pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
      italic: pw.Font.helveticaOblique(),
      boldItalic: pw.Font.helveticaBoldOblique(),
    );
    final document = pw.Document(theme: theme);
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Furlo Care Summary  |  ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.Text(
            'Furlo Care Summary',
            style: pw.TextStyle(
              fontSize: 23,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            _safePdfText(summary.pet.name),
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey900,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            _petDetails(summary),
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
          pw.Text(
            'Generated ${formatSummaryDate(summary.generatedAt)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 20),
          _section(
            'Vaccinations',
            summary.vaccinations.isEmpty
                ? [_emptyMessage()]
                : [
                    _table(
                      ['Vaccine', 'Date given', 'Next due', 'Status'],
                      summary.vaccinations
                          .map(
                            (item) => [
                              _safePdfText(item.vaccineName),
                              formatSummaryDate(item.dateGiven),
                              formatSummaryDate(item.nextDueDate),
                              _safePdfText(item.status),
                            ],
                          )
                          .toList(),
                    ),
                  ],
          ),
          _section(
            'Health Records',
            summary.healthRecords.isEmpty
                ? [_emptyMessage()]
                : summary.healthRecords
                      .map(_healthRecordBlock)
                      .toList(),
          ),
          _section(
            'Weight History',
            summary.weights.isEmpty
                ? [_emptyMessage()]
                : [
                    _table(
                      ['Date', 'Weight'],
                      summary.weights
                          .map(
                            (item) => [
                              formatSummaryDate(item.date),
                              '${item.weight.toString()} $weightUnit',
                            ],
                          )
                          .toList(),
                    ),
                  ],
          ),
          _section(
            'Vet Contacts',
            summary.vets.isEmpty
                ? [_emptyMessage()]
                : summary.vets.map(_vetBlock).toList(),
          ),
        ],
      ),
    );
    return Uint8List.fromList(await document.save());
  }

  Future<void> exportPetSummary(int petId) async {
    final summary = await assemblePetSummary(petId);
    final bytes = await renderSummary(summary);
    final filename = summaryFileName(summary.pet.name, summary.generatedAt);
    await SharePlus.instance.share(
      ShareParams(
        title: 'Furlo Care Summary',
        files: [XFile.fromData(bytes, mimeType: 'application/pdf')],
        fileNameOverrides: [filename],
        downloadFallbackEnabled: true,
      ),
    );
  }
}

String summaryFileName(String petName, DateTime date) {
  final sanitized = petName
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), ' ')
      .replaceAll(RegExp(r'\s+'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^[-.]+|[-.]+$'), '');
  final petPart = sanitized.isEmpty ? 'pet' : sanitized;
  return 'furlo-$petPart-summary-${_isoDate(date)}.pdf';
}

String formatSummaryDate(DateTime? date) {
  if (date == null) return '—';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _petAge(DateTime? birthDate, DateTime today) {
  if (birthDate == null || birthDate.isAfter(today)) return 'Not provided';
  var months = (today.year - birthDate.year) * 12 + today.month - birthDate.month;
  if (today.day < birthDate.day) months--;
  if (months < 0) return 'Not provided';
  final years = months ~/ 12;
  final extraMonths = months % 12;
  if (years == 0) return '$extraMonths ${extraMonths == 1 ? 'mo' : 'mos'}';
  if (extraMonths == 0) return '$years ${years == 1 ? 'yr' : 'yrs'}';
  return '$years ${years == 1 ? 'yr' : 'yrs'} $extraMonths ${extraMonths == 1 ? 'mo' : 'mos'}';
}

String _petDetails(PetCareSummary summary) => [
  _safePdfText(summary.pet.species),
  if (summary.pet.breed?.trim().isNotEmpty == true)
    _safePdfText(summary.pet.breed!),
  summary.age ?? 'Not provided',
].join('  |  ');

pw.Widget _section(String title, List<pw.Widget> children) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 14),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 7),
        margin: const pw.EdgeInsets.only(bottom: 6),
        color: PdfColors.grey200,
        child: pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey900,
          ),
        ),
      ),
      ...children,
    ],
  ),
);

pw.Widget _emptyMessage() => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 4),
  child: pw.Text(
    'No records',
    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
  ),
);

pw.Widget _table(List<String> headers, List<List<String>> rows) => pw.TableHelper.fromTextArray(
  headers: headers,
  data: rows.map((row) => row.map(_safePdfText).toList()).toList(),
  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
  rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
  headerStyle: pw.TextStyle(
    fontSize: 8,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.grey900,
  ),
  cellStyle: const pw.TextStyle(fontSize: 8, color: PdfColors.grey900),
  cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
);

pw.Widget _healthRecordBlock(HealthRecord record) => pw.Container(
  width: double.infinity,
  padding: const pw.EdgeInsets.only(bottom: 7),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        '${formatSummaryDate(record.date)}  |  ${_safePdfText(record.type)}  |  ${_safePdfText(record.title)}',
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
      if (record.notes?.trim().isNotEmpty == true)
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 8, top: 2),
          child: pw.Text(
            _safePdfText(record.notes!),
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
            softWrap: true,
          ),
        ),
    ],
  ),
);

pw.Widget _vetBlock(PetCareVetSummary entry) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 5),
  child: pw.Text(
    [
      _safePdfText(entry.vet.name),
      if (entry.vet.clinic?.trim().isNotEmpty == true)
        _safePdfText(entry.vet.clinic!),
      if (entry.vet.phone?.trim().isNotEmpty == true)
        _safePdfText(entry.vet.phone!),
      'Next appointment: ${formatSummaryDate(entry.nextAppointment)}',
    ].join('  |  '),
    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey900),
  ),
);

String _safePdfText(String input) {
  const replacements = <int, String>{
    0x00a0: ' ',
    0x00a9: '(c)',
    0x00ae: '(R)',
    0x00b0: ' degrees',
    0x00e9: 'e',
    0x00c9: 'E',
    0x00f1: 'n',
    0x00d1: 'N',
    0x00fc: 'u',
    0x00dc: 'U',
    0x00e4: 'a',
    0x00c4: 'A',
    0x00f6: 'o',
    0x00d6: 'O',
    0x00e5: 'a',
    0x00c5: 'A',
    0x00df: 'ss',
    0x00e6: 'ae',
    0x00c6: 'AE',
    0x00f8: 'o',
    0x00d8: 'O',
    0x2018: "'",
    0x2019: "'",
    0x201c: '"',
    0x201d: '"',
    0x2013: '-',
    0x2014: '-',
    0x2026: '...',
    0x2022: '*',
    0x20ac: 'EUR',
  };
  return String.fromCharCodes(input.runes.expand((rune) {
    if (rune == 9 || rune == 10 || rune == 13 || (rune >= 32 && rune <= 126)) {
      return [rune];
    }
    final replacement = replacements[rune];
    if (replacement != null) return replacement.codeUnits;
    return [63];
  }));
}
