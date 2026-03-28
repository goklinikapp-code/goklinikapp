# GoKlinik Medic Setup

This app is the Flutter app for GoKlinik medical staff (surgeons and nurses).

## 1. Requirements
- Flutter `3.19+`
- Dart `3.3+`
- Android Studio or Xcode
- Firebase project configured (optional in local development)

## 2. Install dependencies
```bash
cd GoKlinik/medic
flutter pub get
```

## 3. Environment variables
Create `.env` in `GoKlinik/medic/` with:

```env
API_BASE_URL=http://127.0.0.1:8000
FCM_ENABLED=false
```

Notes:
- Use backend host only in `API_BASE_URL`.
- Do not append `/api` to `API_BASE_URL`.

## 4. Firebase setup (optional for local)
### Android
- Put `google-services.json` in:
  - `android/app/google-services.json`

### iOS
- Put `GoogleService-Info.plist` in:
  - `ios/Runner/GoogleService-Info.plist`

Then run (if push notifications are enabled):
```bash
flutterfire configure
```

## 5. Run app
```bash
flutter run
```

## 6. Build
### Android debug APK
```bash
flutter build apk --debug
```

### Android release APK
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

## 7. Main routes
- `/` splash
- `/login`
- `/patients`
- `/patients/:id`
- `/schedule`
- `/chat`
- `/chat/room/:roomId`
- `/profile`

## 8. Access policy
This app is exclusive to clinic professionals.
- Allowed: `role=surgeon`, `role=nurse`, `role=clinic_master`
- Blocked: `role=patient`

If a patient tries to login, the app shows:
`Acesso nao autorizado. Este aplicativo e exclusivo para profissionais da clinica.`

## 9. API endpoints used
- Auth: `/api/auth/login/`, `/api/auth/refresh/`
- Patients: `/api/patients/my-patients/`, `/api/patients/{id}/`, `/api/patients/{id}/timeline/`
- Appointments: `/api/appointments/`, `/api/appointments/available-slots/`
- Chat: `/api/chat/rooms/`, `/api/chat/rooms/{id}/messages/`, `/api/chat/rooms/{id}/read/`
- Post-op photos: `/api/post-op/photos/`, `/api/post-op/photos/{journey_id}/`
- Medical docs: `/api/medical-records/{patient_id}/documents/`
