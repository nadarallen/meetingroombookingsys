Meeting Room Booking System (Flutter)

Overview
- Clean architecture with feature modules (rooms, bookings, auth) and MVVM via Provider.
- Firebase Authentication for login/registration with Firestore-backed user profiles.
- Remember-me login via `shared_preferences`, password reset email flow, and profile editing.
- go_router navigation with guarded routes (splash → auth → app) and Material 3 theming (light/dark).
- Local services ready for notifications, maps, and offline caching (Sqflite).

Structure
- `lib/core`: routing, theme, constants, shared utilities (e.g., validators).
- `lib/shared`: reusable widgets/services (notifications, local db, Firestore helpers).
- `lib/features`: feature verticals (auth, rooms, bookings, home, splash) with domain → data → presentation layers.

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
5. Run the app:
   ```bash
   flutter run
   ```

Auth Features
- Splash screen checks Firebase auth state and routes automatically.
- Login with email/password, remember-me toggle, and password reset link.
- Registration captures full name, employee ID, department, and persists to Firestore.
- Profile screen lets users review/edit details, with validation and loading/error feedback.
- Logout clears session and returns to the login flow.

Testing
- Widget tests: `flutter test`
- Add integration tests once Firebase emulators or staging environment are configured (not included yet).

Next Ideas
- Hook bookings feature to Firestore and calendar/availability logic.
- Add role-based access control and approval flows for booking requests.
- Integrate Google Maps for room locations once API keys are configured in platform projects.

