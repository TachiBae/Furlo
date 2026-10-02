class Vet {
  final int? id;
  final String name;
  final String? clinic;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;

  Vet({
    this.id,
    required this.name,
    this.clinic,
    this.phone,
    this.email,
    this.address,
    this.notes,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'clinic': clinic,
    'phone': phone,
    'email': email,
    'address': address,
    'notes': notes,
  };

  factory Vet.fromMap(Map<String, Object?> map) => Vet(
    id: int.tryParse(map['id']?.toString() ?? ''),
    name: map['name']?.toString() ?? '',
    clinic: map['clinic']?.toString(),
    phone: map['phone']?.toString(),
    email: map['email']?.toString(),
    address: map['address']?.toString(),
    notes: map['notes']?.toString(),
  );

  Vet copyWith({
    int? id,
    String? name,
    String? clinic,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) => Vet(
    id: id ?? this.id,
    name: name ?? this.name,
    clinic: clinic ?? this.clinic,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    address: address ?? this.address,
    notes: notes ?? this.notes,
  );
}

class VetPetAssociation {
  final int vetId;
  final int petId;
  final DateTime? nextAppointmentDate;

  const VetPetAssociation({
    required this.vetId,
    required this.petId,
    this.nextAppointmentDate,
  });

  Map<String, Object?> toMap() => {
    'vet_id': vetId,
    'pet_id': petId,
    'next_appointment_date': nextAppointmentDate?.toIso8601String(),
  };

  factory VetPetAssociation.fromMap(Map<String, Object?> map) =>
      VetPetAssociation(
        vetId: int.parse(map['vet_id'].toString()),
        petId: int.parse(map['pet_id'].toString()),
        nextAppointmentDate: DateTime.tryParse(
          map['next_appointment_date']?.toString() ?? '',
        ),
      );
}
