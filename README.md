# BBBSCSMS Mobile App

**Capstone/Thesis Project**

A comprehensive **Barangay Community Management System** mobile application for residents. This app enables community members to report issues, request documents, track their applications, view announcements, and engage with their barangay officials.

## Project Overview

BBBSCSMS Mobile App is a capstone project developed as a resident-facing mobile interface for the Barangay Community Management System. It empowers residents to:
- Report community issues with detailed descriptions and photos
- Request official barangay documents
- Track the status of their requests and reports
- Receive and view barangay announcements
- Locate issues on an interactive map
- Access their personal information and history

## Features

### 📍 Community Issue Reporting
- Report problems (potholes, street lights, flooding, etc.)
- Add location via GPS or map selection
- Attach photos and videos
- Provide detailed descriptions
- Track report status in real-time
- View resolution history

### 📄 Document Request System
- Request official barangay documents
- Multiple document types supported
- Online application submission
- Instant status notifications
- View issued documents

### 📢 Announcements Feed
- Receive barangay announcements
- Browse announcement history
- Push notifications for urgent updates
- Categorized announcements
- Share announcements with neighbors

### 🗺️ Location-Based Services
- Interactive map showing community issues
- Geolocation-based reporting
- Distance-based filtering
- Heat mapping of problem areas
- Navigate to report locations

### 📊 Personal Dashboard
- Track all submitted reports
- Monitor document requests
- View request history
- Quick statistics
- Upcoming events

### 👤 User Profile Management
- Complete resident profile
- Edit personal information
- Notification preferences
- Security settings
- Privacy controls

### 🔔 Smart Notifications
- Real-time status updates
- Request approvals/rejections
- Report progress updates
- Important announcements
- Customizable alert settings

### 🔐 Secure Authentication
- Mobile number verification (OTP)
- Secure account creation
- Password recovery
- Session management
- Two-factor authentication option

## Tech Stack

- **Framework**: [Flutter](https://flutter.dev/)
- **Language**: Dart
- **Database**: Supabase PostgreSQL
- **Backend**: Supabase Realtime
- **Authentication**: Supabase Auth (Phone-based OTP)
- **Location Services**: [Geolocator](https://pub.dev/packages/geolocator)
- **UI Library**: Material Design 3
- **Image Handling**: [Image Picker](https://pub.dev/packages/image_picker)
- **State Management**: Provider / GetX
- **Local Storage**: [Shared Preferences](https://pub.dev/packages/shared_preferences)

## Project Structure

```
lib/
├── main.dart                    # Application entry point
├── screens/
│   ├── auth/
│   │   ├── splash_screen.dart           # Splash/loading screen
│   │   ├── login_screen.dart            # Login screen
│   │   └── registration_screen.dart     # Resident registration
│   ├── home/
│   │   ├── home_screen.dart             # Main dashboard
│   │   ├── announcements_screen.dart    # Announcements feed
│   │   └── profile_screen.dart          # User profile
│   ├── reports/
│   │   ├── report_list_screen.dart      # My reports list
│   │   ├── create_report_screen.dart    # Create new report
│   │   ├── report_detail_screen.dart    # Report details
│   │   └── report_map_screen.dart       # Reports map view
│   ├── documents/
│   │   ├── document_list_screen.dart    # My documents list
│   │   ├── request_document_screen.dart # Request document
│   │   └── document_detail_screen.dart  # Document details
│   └── common/
│       └── splash_screen.dart
├── services/
│   ├── auth_service.dart                # Authentication logic
│   ├── report_service.dart              # Report management
│   ├── document_service.dart            # Document handling
│   └── location_service.dart            # Geolocation services
├── models/                      # Data models and entities
├── providers/                   # State management
├── widgets/                     # Reusable UI components
└── assets/                      # Images and app assets
```

## Getting Started

### Prerequisites

- Flutter SDK (3.0+)
- Dart SDK
- Supabase account
- Google Maps API key
- Android Studio, Xcode, or VS Code
- Device or emulator for testing

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Shard1/BBBSCSMS-mobile-app.git
   cd BBBSCSMS-mobile-app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   - Get your Supabase project URL and anonymous key
   - Update the configuration in your initialization file:
   ```dart
   // Example in main.dart
   await Supabase.initialize(
     url: 'YOUR_SUPABASE_URL',
     anonKey: 'YOUR_SUPABASE_ANON_KEY',
   );
   ```


5. **Run the application**
   ```bash
   flutter run
   ```

## Usage Guide

### Creating an Account
1. Open the app and tap "Register"
2. Enter your name and mobile number
3. Verify OTP sent to your number
4. Create a password
5. Complete your profile information
6. Accept terms and conditions
7. Start using the app

### Reporting an Issue
1. Navigate to "Report Issue" from the home screen
2. Select the issue category
3. Describe the problem in detail
4. Tap the location to set it on the map
5. Attach photos if available
6. Submit the report
7. Track status in "My Reports"

### Requesting a Document
1. Go to "Documents" section
2. Tap "Request New Document"
3. Select document type
4. Fill in required information
5. Submit request
6. Receive notification when ready for pickup/delivery

### Viewing Announcements
1. Tap "Announcements" in the main menu
2. Scroll through latest updates
3. Tap any announcement for full details
4. Share announcements with others

### Tracking Your Reports
1. Open "My Reports" section
2. View all your submitted reports
3. Tap a report to see full details and updates
4. Check resolution status and admin comments

## API Integration

The mobile app integrates with:
- **Supabase Authentication** - Phone-based OTP login
- **Supabase Realtime Database** - Real-time data updates
- **Supabase Storage** - Photo/video storage

## Building for Production

```bash
# Build Android APK
flutter build apk

# Build Android App Bundle
flutter build appbundle

# Build iOS
flutter build ios

# Build Release APK with optimizations
flutter build apk --release
```

## Platforms Supported

- **Android**: 5.0 (API 21) and above
- **iOS**: 12.0 and above
- **Web**: Supported
- **macOS**: Supported (Desktop)
- **Windows**: Supported (Desktop)
- **Linux**: Supported (Desktop)

## Configuration & Environment Variables

Create a `.env` file in the project root:
```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
LOCATION_PERMISSION_MESSAGE=Allow app to access your location?
```

## Permissions Required

**Android**:
- `android.permission.ACCESS_FINE_LOCATION`
- `android.permission.ACCESS_COARSE_LOCATION`
- `android.permission.CAMERA`
- `android.permission.READ_EXTERNAL_STORAGE`
- `android.permission.WRITE_EXTERNAL_STORAGE`

**iOS**:
- `NSLocationWhenInUseUsageDescription`
- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`

## Troubleshooting

### Location Not Working
- Ensure location permissions are granted
- Verify GPS is enabled on device
- Check Geolocator configuration

### Supabase Connection Issues
- Verify internet connectivity
- Check Supabase credentials
- Ensure project is active

### Build Failures
- Run `flutter clean`
- Update dependencies: `flutter pub get`
- Check Flutter version: `flutter --version`
- Run `flutter doctor` for issues

## Security Features

- Secure OTP-based authentication
- Encrypted data transmission
- Secure token storage
- Input validation and sanitization
- Rate limiting on requests
- Secure image storage

## About This Project

This is a **Capstone/Thesis Project** developed for academic purposes as part of a Computer Science curriculum. The BBBSCSMS system demonstrates practical application of mobile development, database design, and real-time communication technologies.

## Future Enhancements

- [ ] Offline-first capabilities
- [ ] Enhanced report filtering and search
- [ ] Multi-language support (Tagalog, English)
- [ ] Dark mode theme
- [ ] Accessibility improvements
- [ ] SMS notifications

---

**Version**: 1.0.0  
**Last Updated**: April 2026  
**Project Type**: Capstone/Thesis  
**Supported Languages**: English, Tagalog
