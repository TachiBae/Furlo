class Pet {
  final int? id;
  final String name;
  final String species;
  final String? breed;
  final DateTime? birthDate;
  final String? photoPath;

  Pet({
    this.id,
    required this.name,
    required this.species,
    this.breed,
    this.birthDate,
    this.photoPath,
  });
}
