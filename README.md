# Tourist Safety App — Flutter Module

Covers: **Registration, Login, Live Tracking, SOS Button** — the mobile-app
layer of the Smart Tourist Safety Monitoring System.

Uses OpenStreetMap via `flutter_map` so no Google Maps API key is required
to run this out of the box. Swap in `google_maps_flutter` later if you want.

## 1. Setup

```bash
flutter create --project-name tourist_safety_app .   # if starting fresh, or
flutter pub get                                       # if you already have a Flutter project
```

Copy the contents of this `lib/` folder into your Flutter project's `lib/` folder,
and merge `pubspec.yaml` dependencies into yours.

### Android permissions
Merge the contents of `android_manifest_snippet/AndroidManifest_permissions.xml`
into `android/app/src/main/AndroidManifest.xml`, above the `<application>` tag.

Also set `minSdkVersion 21` or higher in `android/app/build.gradle`.

### iOS permissions
Add to `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to keep you safe and enable live tracking.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need background location to alert authorities in an emergency.</string>
```

## 2. Point it at your backend

Edit `lib/config.dart` and set `baseUrl` to your Django/FastAPI server.

## 3. Expected backend API contract

Your backend needs to expose these endpoints (matches the "Cloud Backend API"
box in your architecture diagram):

### `POST /api/auth/register`
Request:
```json
{
  "name": "Jane Doe",
  "email": "jane@example.com",
  "phone": "+911234567890",
  "password": "secret123",
  "emergency_contact": "+919876543210"
}
```
Response (200/201):
```json
{
  "token": "jwt-or-session-token",
  "user": { "id": "1", "name": "Jane Doe", "email": "jane@example.com", "phone": "+911234567890" }
}
```

### `POST /api/auth/login`
Request: `{ "email": "...", "password": "..." }`
Response: same shape as register.

### `POST /api/location/update`
Header: `Authorization: Bearer <token>`
Request:
```json
{ "lat": 19.0760, "lng": 72.8777, "speed": 1.2, "heading": 90.0, "timestamp": "2026-07-03T10:00:00Z" }
```

### `POST /api/sos`
Header: `Authorization: Bearer <token>`
Request:
```json
{ "lat": 19.0760, "lng": 72.8777, "timestamp": "2026-07-03T10:00:00Z", "message": "Emergency SOS triggered by user" }
```
This is where your backend's Decision & Alert Engine should fan the alert
out to Authorities/Rescue, Family Members, and Emergency Services.

## 4. Run it

```bash
flutter run
```

## 5. What's included vs. what's next

**Included in this module:**
- Registration & login screens with validation and token persistence (`shared_preferences`)
- Live GPS tracking on an OpenStreetMap view, pushed to the backend every ~15s (configurable)
- SOS button with confirmation dialog, sends current location + timestamp to backend

**Not included yet (from your full architecture):**
- Digital ID (blockchain) — separate module, needs backend blockchain integration first
- Safe zone / geo-fence alerts — needs zone polygons from backend; straightforward to add once that API exists
- Incident reporting (voice/image/text) — can extend the SOS flow with a form + file upload
- Push notifications (Firebase Cloud Messaging) — needed for the "Tourist Alerts" box

Happy to build any of these next.
