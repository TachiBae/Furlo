abstract class PetRepository {
  // Contract for local storage access across SQLite and web-safe fallbacks.
}

class SqlitePetRepository implements PetRepository {
  // Placeholder for the SQLite-backed implementation used on mobile/native.
}

class WebPetRepository implements PetRepository {
  // Placeholder for the in-memory/shared_preferences fallback used on web.
}
