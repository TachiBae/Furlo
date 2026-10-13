import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

import '../models/feeding_entry.dart';
import '../models/health_record.dart';
import '../models/pet.dart';
import '../models/vaccination.dart';
import '../models/vet.dart';
import '../models/weight_log.dart';
import '../utils/app_diagnostics.dart';
import '../utils/user_storage_scope.dart';

part 'firestore_pet_repository.dart';
part 'legacy/sqlite_pet_repository.dart';
part 'legacy/web_pet_repository.dart';
part 'pet_photo_store.dart';
part 'pet_record_mappers.dart';

abstract class PetRepository {
  Future<List<Pet>> getPets();
  Future<void> addPet(Pet pet);
  Future<void> updatePet(Pet pet);
  Future<void> deletePet(String id);
  Future<void> clearAllData();
  Future<List<FeedingEntry>> getFeedingSchedules(String petId);
  Future<FeedingEntry> addFeedingSchedule(FeedingEntry entry);
  Future<void> updateFeedingSchedule(FeedingEntry entry);
  Future<void> deleteFeedingSchedule(String id, String petId);
  Future<List<HealthRecord>> getHealthRecordsForPet(String petId);
  Future<HealthRecord> addHealthRecord(HealthRecord record);
  Future<void> updateHealthRecord(HealthRecord record);
  Future<void> deleteHealthRecord(String id, String petId);
  Future<List<Vaccination>> getVaccinationsForPet(String petId);
  Future<Vaccination> addVaccination(Vaccination vaccination);
  Future<void> updateVaccination(Vaccination vaccination);
  Future<void> deleteVaccination(String id, String petId);
  Future<List<Vet>> getAllVets();
  Future<List<Vet>> getVetsForPet(String petId);
  Future<Vet?> getVetById(String id);
  Future<List<Pet>> getPetsForVet(String vetId);
  Future<List<VetPetAssociation>> getVetPetAssociations(String vetId);
  Future<Vet> addVet(Vet vet, List<String> petIds);
  Future<void> updateVet(Vet vet, List<String> petIds);
  Future<void> deleteVet(String id);
  Future<void> setNextAppointment(String vetId, String petId, DateTime? date);
  Future<List<WeightLog>> getWeightLogsForPet(String petId);
  Future<WeightLog> addWeightLog(WeightLog log);
  Future<void> updateWeightLog(WeightLog log);
  Future<void> deleteWeightLog(String id, String petId);

  // Whole-account reads. Screens that summarise every pet (Today's Reminders,
  // the vet list, reminder scheduling) use these so a refresh costs one read
  // per collection rather than several per pet.
  Future<List<FeedingEntry>> getAllFeedingSchedules();
  Future<List<Vaccination>> getAllVaccinations();
  Future<List<HealthRecord>> getAllHealthRecords();
  Future<List<VetPetAssociation>> getAllVetLinks();
}

/// The cloud-backed repository is the system of record for signed-in accounts.
///
/// Requires [storageScope] to be the signed-in user's uid; pet data then lives in
/// Firestore under `users/{uid}/…` and follows the account across devices.
///
/// The local implementations remain only as read-only legacy readers used by the
/// one-time migration and by tests. New writes never go to device storage.
PetRepository createPetRepository({required String storageScope}) =>
    FirestorePetRepository(uid: storageScope);
