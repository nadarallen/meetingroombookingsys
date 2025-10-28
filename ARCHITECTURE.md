# Meeting Room Booking System - Architecture & File Structure

## 📁 Project Overview

This is a Flutter-based meeting room booking system with offline-first architecture, dual database support (SQLite local + Firestore cloud), and comprehensive admin features.

---

## 🗂️ File Structure & Feature Organization

### **Core Layer** (`lib/core/`)

The foundation of the application providing database, routing, and configuration.

#### **Database Components** (`lib/core/database/`)
- **`local_database.dart`**: SQLite database for offline-first functionality
  - Handles local CRUD operations
  - Migration management (version 4)
  - Conflict detection for bookings
  
- **`firestore_service.dart`**: Firebase Firestore integration
  - Cloud CRUD operations
  - Conflict checking for bookings
  - Real-time synchronization
  
- **`database_sync_manager.dart`**: Dual database coordinator
  - Syncs local ↔ cloud
  - Handles create/update/delete operations
  - Conflict resolution
  - **🔧 Edit Feature**: Now includes `updateBooking()` method
  
- **Models** (`lib/core/database/models/`):
  - `booking.dart`: Booking model with status management
  - `room.dart`: Room model with location data
  - `app_user.dart`: User model with admin flags
  - `amenity.dart`: Amenity model for room features

#### **Configuration** (`lib/core/config/`)
- `ai_config.dart`: AI service configuration

#### **Constants** (`lib/core/constants/`)
- `app_strings.dart`: Application-wide strings
- `firebase_paths.dart`: Firebase collection paths

#### **Routing** (`lib/core/routing/`)
- `app_router.dart`: GoRouter configuration for navigation

#### **Theme** (`lib/core/theme/`)
- `app_theme.dart`: Theme configuration
- `theme_notifier.dart`: Theme state management

#### **Utils** (`lib/core/utils/`)
- `validators.dart`: Form validation utilities

---

### **Features** (`lib/features/`)

Feature-based modules using clean architecture.

#### **1. Authentication** (`lib/features/auth/`)
- **Data Layer**: Firestore datasources and repositories
- **Domain Layer**: Business logic and entities
- **Presentation Layer**: Login/signup pages and view models
- **Location**: `lib/features/auth/`

#### **2. Home** (`lib/features/home/`)
- **Main Page**: `lib/features/home/presentation/pages/home_page.dart`
  - **📱 Recent Update**: Converted to slide-based navigation with 3 slides
    - Slide 1: Quick Actions
    - Slide 2: Booking Management  
    - Slide 3: Admin Panel
  - Interactive page indicators
  - Recommendation service integration

#### **3. Rooms** (`lib/features/rooms/`)
- **Room List Page**: `lib/features/rooms/presentation/pages/room_list_page.dart`
  - **🔍 Search Feature**: Fully functional search bar
  - **✏️ Admin Edit**: Edit room details with `_EditRoomDialog`
  - **🎨 Modern UI**: Card-based layout with images
  - Location: Full room management interface

- **Room List ViewModel**: `lib/features/rooms/presentation/viewmodels/room_list_view_model.dart`
  - **🆕 Update Method**: `updateRoom()` for editing
  - **🔎 Search Filtering**: `setSearchQuery()` method
  - Full CRUD operations
  
- **Room Map Page**: `lib/features/rooms/presentation/pages/room_map_page.dart`
  - Interactive map view with room locations
  
- **Room Map ViewModel**: `lib/features/rooms/presentation/viewmodels/room_map_view_model.dart`
  - Map state management

#### **4. Bookings** (`lib/features/bookings/`)
- **Booking List Page**: `lib/features/bookings/presentation/pages/booking_list_page.dart`
  - **🎨 Modern Card Design**: Status indicators, duration display
  - **✏️ Edit Functionality**: Tap to edit bookings
  - **❌ Cancel Functionality**: Cancel with confirmation
  - **📋 Notes Preview**: Displays booking notes

- **Edit Booking Page**: `lib/features/bookings/presentation/pages/edit_booking_page.dart` ⭐ NEW
  - Full edit interface for bookings
  - Status management
  - Conflict detection
  - Real-time updates

- **New Booking Page**: `lib/features/bookings/presentation/pages/new_booking_page.dart`
  - Create new bookings
  - DateTime picker integration
  
- **Booking ViewModel**: `lib/features/bookings/presentation/viewmodels/booking_view_model.dart`
  - **🆕 Edit Methods**: `updateBooking()`, `cancelBooking()`
  - Full CRUD operations
  - Error handling

#### **5. Admin** (`lib/features/admin/`)
- **Admin Dashboard**: `lib/features/admin/presentation/pages/admin_dashboard_page.dart`
  - System analytics
  - User management
  - Settings

#### **6. Chat** (`lib/features/chat/`)
- **AI Concierge**: Chat interface for room queries
- Location: `lib/features/chat/`

#### **7. Maps** (`lib/features/maps/`)
- **Google Maps Integration**: Room location display
- Location: `lib/features/maps/`

#### **8. ML Services** (`lib/features/ml/`)
- **Recommendation Service**: `lib/features/ml/services/recommendation_service.dart`
  - ML-based room recommendations
- **Analytics Service**: `lib/features/ml/services/analytics_service.dart`
  - Usage analytics and insights
- **Prediction Service**: `lib/features/ml/services/prediction_service.dart`
  - Booking predictions

#### **9. Splash** (`lib/features/splash/`)
- **Splash Page**: Initial app screen
- Location: `lib/features/splash/`

---

### **Shared Resources** (`lib/shared/`)

Shared services and widgets used across features.

#### **Services** (`lib/shared/services/`)
- **AI Service**: `lib/shared/services/ai/` - AI integration
- **Firestore Service**: `lib/shared/services/firestore_service.dart` - Reusable Firestore operations
- **Local DB Service**: `lib/shared/services/local_db.dart` - Local database operations  
- **Map Service**: `lib/shared/services/map_service.dart` - Map functionality
- **Notification Service**: `lib/shared/services/notification_service.dart`
  - **🔧 Fixed**: Updated to use timezone package
- **Storage Service**: `lib/shared/services/storage_service.dart`
  - Image upload to Firebase Storage

#### **Widgets** (`lib/shared/widgets/`)
- `app_error.dart`: Error display widget
- `app_loading.dart`: Loading indicator widget

---

## 🔧 Recent Fixes & Enhancements

### **Fixed Issues** ✅
1. **AnimatedContainer Error**: Fixed circle/borderRadius conflict in page indicator
2. **Search Bar**: Now fully functional with real-time filtering
3. **RenderFlex Overflow**: Resolved layout overflow issues
4. **Database Schema**: Added `image_url` column migration
5. **Timestamp Errors**: Fixed Firestore Timestamp casting
6. **Notification Service**: Added timezone support
7. **Booking Conflicts**: Enhanced conflict detection

### **New Features** ⭐
1. **Edit Bookings**: Complete edit functionality with conflict checking
2. **Edit Rooms** (Admin): Full room editing capabilities
3. **Slide Navigation**: Interactive home page with 3 slides
4. **Search Functionality**: Real-time room search
5. **Cancel Bookings**: Easy booking cancellation
6. **Modern UI**: Enhanced card designs and animations

---

## 📝 How to Edit Features

### **To Add/Modify Booking Features:**
```
📁 lib/features/bookings/
├── 📄 presentation/pages/
│   ├── booking_list_page.dart (Main list UI)
│   ├── edit_booking_page.dart (Edit UI) ⭐ NEW
│   └── new_booking_page.dart (Create UI)
├── 📄 presentation/viewmodels/
│   └── booking_view_model.dart (Business logic)
└── 📄 domain/
    ├── entities/ (Business objects)
    └── repositories/ (Data contracts)
```

### **To Add/Modify Room Features:**
```
📁 lib/features/rooms/
├── 📄 presentation/pages/
│   ├── room_list_page.dart (Main list + Edit dialog)
│   └── room_map_page.dart (Map view)
├── 📄 presentation/viewmodels/
│   └── room_list_view_model.dart (Business logic)
└── 📄 data/ (Repositories & datasources)
```

### **To Modify Database Operations:**
```
📁 lib/core/database/
├── local_database.dart (Local DB operations)
├── firestore_service.dart (Cloud operations)
└── database_sync_manager.dart (Dual DB coordinator)
```

### **To Change Home Page Navigation:**
```
📁 lib/features/home/presentation/pages/
└── home_page.dart
    ├── _buildMainSlide() (Quick Actions)
    ├── _buildBookingSlide() (Booking Management)
    └── _buildAdminSlide() (Admin Panel)
```

### **To Add/Modify Admin Features:**
```
📁 lib/features/admin/
└── presentation/pages/
    └── admin_dashboard_page.dart
```

### **To Change App Routing:**
```
📁 lib/core/routing/
└── app_router.dart (All route definitions)
```

### **To Modify Models:**
```
📁 lib/core/database/models/
├── booking.dart (Booking model)
├── room.dart (Room model)
├── app_user.dart (User model)
└── amenity.dart (Amenity model)
```

---

## 🔄 Data Flow

### **Booking Creation/Edit:**
1. User fills form → UI (`new_booking_page.dart` or `edit_booking_page.dart`)
2. ViewModel validates → `booking_view_model.dart`
3. Database sync manager checks conflicts → `database_sync_manager.dart`
4. Saves to local DB → `local_database.dart`
5. Syncs to Firestore → `firestore_service.dart`
6. UI updates → List refreshed

### **Room Management:**
1. Admin creates/edits room → UI (`room_list_page.dart`)
2. ViewModel processes → `room_list_view_model.dart`
3. Image upload (if any) → `storage_service.dart`
4. Saves to local DB → `local_database.dart`
5. Syncs to Firestore → `firestore_service.dart`
6. Room list updates

---

## 🗄️ Database Architecture

### **Local Database (SQLite)**
- **Location**: App's local storage
- **Purpose**: Offline-first operations
- **Version**: 4 (with migrations)
- **Tables**: rooms, bookings, users, amenities

### **Cloud Database (Firestore)**
- **Location**: Google Firebase
- **Purpose**: Data synchronization
- **Collections**: bookings, rooms, users
- **Indexes**: Composite indexes for complex queries

---

## 🎨 UI Components Location

### **Reusable Widgets:**
- `lib/shared/widgets/` - Error, loading widgets

### **Feature-Specific UI:**
- `lib/features/[feature]/presentation/pages/` - Page components
- `lib/features/[feature]/presentation/widgets/` - Feature-specific widgets (if needed)

---

## 🔐 Admin Privileges

### **Admin Features:**
1. ✅ Edit room details
2. ✅ Delete rooms
3. ✅ Clear database
4. ✅ Add sample rooms
5. ✅ View admin dashboard
6. ✅ Manage users
7. ✅ System settings

### **Where Admin Checks Happen:**
- User model: `lib/core/database/models/app_user.dart`
- Auth check: `lib/features/auth/presentation/viewmodels/auth_view_model.dart`
- UI checks: Throughout presentation layer for conditional rendering

---

## 📱 Navigation Flow

```
Splash → Auth → Home
                      ↓
        ┌─────────────┴─────────────┐
        ↓             ↓              ↓
      Rooms      Bookings       Profile
        ↓             ↓              ↓
      Map        Edit/Cancel    Settings
```

---

## 🛠️ Configuration Files

- **`pubspec.yaml`**: Dependencies
- **`firebase.json`**: Firebase config
- **`firestore.rules`**: Security rules
- **`firestore.indexes.json`**: Database indexes
- **`analysis_options.yaml`**: Dart analyzer config

---

## 🚀 How to Run & Build

```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release
```

---

## 📊 Key Features by File

| Feature | Location | Status |
|---------|----------|--------|
| Edit Bookings | `lib/features/bookings/presentation/pages/edit_booking_page.dart` | ✅ NEW |
| Edit Rooms (Admin) | `lib/features/rooms/presentation/pages/room_list_page.dart` | ✅ NEW |
| Search Rooms | `lib/features/rooms/presentation/pages/room_list_page.dart` | ✅ FIXED |
| Slide Navigation | `lib/features/home/presentation/pages/home_page.dart` | ✅ NEW |
| Database Sync | `lib/core/database/database_sync_manager.dart` | ✅ WORKING |
| Booking Conflicts | `lib/core/database/` | ✅ ENHANCED |

---

This architecture provides a clean, maintainable codebase with clear separation of concerns and easy feature addition.
