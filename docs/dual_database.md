# Dual Database Architecture

This application now persists data in both a local SQLite store and Firebase
Cloud Firestore. The local database guarantees offline functionality, while
Firestore provides real‑time collaboration and multi-device synchronisation.

## Package Requirements

Run the following once to pull in the required packages:

```bash
flutter pub add sqflite path cloud_firestore
```

These dependencies are used by the local database helper (`sqflite`, `path`) and
the Firestore integration (`cloud_firestore`).

## Data Model Overview

| Entity   | SQLite Table | Firestore Collection | Notes                                                   |
|----------|--------------|----------------------|---------------------------------------------------------|
| Room     | `rooms`      | `rooms`              | Stores capacity, location and amenity references        |
| Booking  | `bookings`   | `bookings`           | Tracks start/end time, status and sync metadata         |
| User     | `users`      | `users`              | Cached profile data for offline access                  |
| Amenity  | `amenities`  | `amenities`          | Shared amenity catalogue                                |
| –        | –            | `notifications`      | Cloud-only collection for push / in-app notifications   |

## Local Database (`LocalDatabase`)

Located at `lib/core/database/local_database.dart`, this helper:

- Creates and migrates tables for rooms, bookings, users and amenities.
- Provides CRUD helpers for each table plus queue handling for unsynchronised
  bookings (via the `sync_status` column).
- Exposes utility methods (`getPendingBookings`, `markBookingSynced`, etc.) for
  the sync manager to use.

## Cloud Database (`FirestoreService`)

`lib/core/database/firestore_service.dart` wraps the core Firestore
collections:

- Fetch/stream helpers for rooms and bookings.
- Transactional booking creation (`createBookingWithConflictCheck`) to prevent
  double-bookings by checking overlapping time ranges.
- Utility methods for pushing updates and notifications.

The recommended indexes for these queries live in `firestore.indexes.json`.
Deploy them via:

```bash
firebase deploy --only firestore:indexes
```

## Synchronisation Flow (`DatabaseSyncManager`)

`lib/core/database/database_sync_manager.dart` coordinates the two databases:

1. **Bootstrap** – loads authoritative data from Firestore into SQLite.
2. **Listeners** – subscribes to room and booking snapshots to mirror updates
   in real time.
3. **Offline writes** – writes always land in SQLite first, marked with a
   `syncStatus`. When a network call succeeds the entry is marked as `synced`;
   on failure it remains queued or moves to `failed` when a conflict is
   detected.
4. **Conflict resolution** – cloud writes use Firestore transactions. If an
   overlapping booking exists, a `BookingConflictException` is thrown and the
   local record is tagged `failed` so the UI can surface the failure.
5. **Retry loop** – `pushPendingChanges` replays queued bookings; call it after
   connectivity resumes or during app start-up.

An instance of `DatabaseSyncManager` (together with the raw helpers) is exposed
via the global `Provider` tree in `lib/main.dart`.

## Next Steps / Integration Points

- Inject `DatabaseSyncManager` into view models that currently read/write
  bookings so they get offline-first behaviour transparently.
- Surface booking conflict errors to the end user when
  `BookingConflictException` bubbles up.
- Schedule periodic syncs or hook into connectivity change events to call
  `pushPendingChanges`.
- Consider extending the schema with audit tables or change logs if you need a
  full history of edits.
