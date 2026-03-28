# GoKlinik Mobile Setup

This mobile app is the Flutter patient app for GoKlinik.

## 1. Requirements
- Flutter `3.19+`
- Dart `3.3+`
- Android Studio or Xcode
- Firebase project configured (for push notifications)

## 2. Install dependencies
```bash
cd GoKlinik/mobile
flutter pub get
```

## 3. Environment variables
Create `.env` from `.env.example`:
```bash
cp .env.example .env
```

Required variables:
- `API_BASE_URL`: backend host only (example: `http://127.0.0.1:8000`)

Optional variables:
- `DEFAULT_PROFESSIONAL_ID`: surgeon UUID for appointment scheduling flow
- `DEFAULT_PROFESSIONAL_NAME`: display name for that professional
- `FCM_ENABLED`: feature flag

## 4. Firebase setup
### Android
- Put `google-services.json` in:
  - `android/app/google-services.json`

### iOS
- Put `GoogleService-Info.plist` in:
  - `ios/Runner/GoogleService-Info.plist`

Then run:
```bash
flutterfire configure
```

## 5. Native splash
Generate/update splash assets:
```bash
dart run flutter_native_splash:create
```

## 6. Run app
```bash
flutter run
```

## 7. Build
### Android APK
```bash
flutter build apk --release
```

### Android App Bundle
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## 8. API endpoints used
The app is wired to these routes:
- Auth: `/api/auth/login/`, `/api/auth/register/`, `/api/auth/refresh/`
- Post-op: `/api/post-op/my-journey/`, `/api/post-op/checklist/{id}/complete/`, `/api/post-op/photos/`, `/api/post-op/care-center/{journey_id}/`
- Chat: `/api/chat/rooms/`, `/api/chat/rooms/{id}/messages/`, `/api/chat/rooms/{id}/read/`
- Notifications: `/api/notifications/`, `/api/notifications/unread-count/`, `/api/notifications/register-token/`
- Financial: `/api/financial/my-transactions/`, `/api/financial/my-packages/`
- Medical records: `/api/medical-records/my-record/`, `/api/medical-records/{patient_id}/documents/`
- Appointments: `/api/appointments/`, `/api/appointments/available-slots/`

## 9. Notes
- Endpoints already include `/api/...`, so do not add `/api` in `API_BASE_URL`.
- If appointment creation fails due missing professional assignment, set `DEFAULT_PROFESSIONAL_ID` in `.env`.
