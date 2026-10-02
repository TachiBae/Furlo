/// Species-specific vaccine choices for the vaccination form.
abstract final class VaccineCatalog {
  static const dogVaccines = <String>[
    'Rabies',
    'DHPP',
    'DHLPP',
    'Distemper',
    'Parvovirus',
    'Adenovirus (CAV-2)',
    'Parainfluenza',
    'Bordetella (Kennel Cough)',
    'Canine Influenza',
    'Leptospirosis',
    'Lyme Disease',
    'Canine Coronavirus',
    'Rattlesnake',
  ];

  static const catVaccines = <String>[
    'Rabies',
    'FVRCP',
    'Feline Panleukopenia',
    'Feline Calicivirus',
    'Feline Viral Rhinotracheitis',
    'FeLV (Feline Leukemia)',
    'FIV',
    'Bordetella',
    'Chlamydophila felis',
  ];
}

/// Returns the vaccine list for a stored species value such as `Dog` or `Cat`.
List<String> vaccinesFor(String species) =>
    switch (species.trim().toLowerCase()) {
      'dog' => VaccineCatalog.dogVaccines,
      'cat' => VaccineCatalog.catVaccines,
      _ => const [],
    };
