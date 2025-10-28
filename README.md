Meeting Room Booking System (Flutter)

Overview
- Clean architecture with feature modules (rooms, bookings, auth) and MVVM via Provider.
- Firebase Authentication for login/registration with Firestore-backed user profiles.
- Remember-me login via `shared_preferences`, password reset email flow, and profile editing.
- go_router navigation with guarded routes (splash -> auth -> app) and Material 3 theming (light/dark).
- Offline-first data layer (Sqflite + Firestore) with sync management.
- Google Maps view for visualising rooms with navigation hand-off to native maps.
- AI concierge chatbot powered by OpenAI or Gemini for booking assistance.

Structure
- `lib/core`: routing, theme, constants, shared utilities (e.g., validators).
- `lib/shared`: reusable widgets/services (notifications, local db, Firestore helpers, storage).
- `lib/features`: feature verticals (auth, rooms, bookings, home, splash) with domain + data + presentation layers.

Getting Started
1. Scaffold platform folders (if absent):
   ```bash
   flutter create .
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Firebase setup:
   - Run `flutterfire configure` (Android/iOS/Web as needed).
   - Add generated config files to the platform folders.
   - Ensure a `users` collection exists in Firestore for profile data.
4. Android specifics:
   - Confirm `coreLibraryDesugaringEnabled true` with `desugar_jdk_libs:2.1.4` in `android/app/build.gradle(.kts)`.
   - Add `POST_NOTIFICATIONS` permission for Android 13+ if using local notifications.
5. AI API keys:
   - Provide an OpenAI key via `--dart-define=OPENAI_API_KEY=sk-...` (or replace the placeholder in `ai_config.dart`).
   - Optional: supply a Gemini key with `--dart-define=GEMINI_API_KEY=...` to use Google’s models instead.
6. Google Maps API keys:
   - Enable the Maps SDK for Android and iOS in Google Cloud.
   - Android: add the key to `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY` meta-data).
   - iOS: call `GMSServices.provideAPIKey("<YOUR_KEY>")` in `ios/Runner/AppDelegate.swift`.
   - Web (optional): include the Maps JavaScript API script tag with your key in `web/index.html`.
7. Run the app:
   ```bash
   flutter run
   ```

Maps & Navigation
- Rooms accept latitude/longitude alongside textual locations.
- A dedicated map view (`/rooms/map`) renders markers for geo-tagged rooms.
- Tapping a marker reveals room details with a one-tap launch into Google Maps directions.
- Home and rooms list screens link straight to the map experience.

AI Concierge
- Accessible via the “AI Concierge” card on the home screen (`/chat` route).
- Summarises known rooms from the offline cache to ground responses.
- Supports either OpenAI Chat Completions or Gemini Generate Content depending on which key is supplied.
- Gracefully falls back with guidance if no API key is configured.

Auth Features
- Splash screen checks Firebase auth state and routes automatically.
- Login with email/password, remember-me toggle, and password reset link.
- Registration captures full name, employee ID, department, and persists to Firestore.
- Profile screen lets users review/edit details, with validation and loading/error feedback.
- Logout clears session and returns to the login flow.

Testing
- Widget tests: `flutter test`
- Add integration tests once Firebase emulators or a staging environment are configured (not included yet).

Next Ideas
- Hook bookings feature to Firestore and calendar/availability logic.
- Add role-based access control and approval flows for booking requests.
- Expand map filters (capacity, amenities) and explore indoor guidance.
- Add chat-specific analytics and fine-tune prompts per department.
