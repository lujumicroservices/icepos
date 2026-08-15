# Firebase Cloud Messaging (FCM) — ICE POS

Push en **tablets Android** (app cerrada o en segundo plano) para tareas pendientes y aprobaciones. La web sigue usando Web Push (VAPID).

## 1. Firebase Console

1. [Firebase Console](https://console.firebase.google.com/) → **Add project** (o usa uno existente).
2. **Add app** → **Android** → package name: `com.luju.ice_pos`.
3. Descarga **`google-services.json`** y colócalo en:
   ```
   ice_pos/android/app/google-services.json
   ```
4. En **Project settings** → **Cloud Messaging**, anota el **Sender ID** (messaging sender id).

## 2. Cuenta de servicio (servidor / Supabase Edge)

1. Firebase → **Project settings** → **Service accounts**.
2. **Generate new private key** → guarda el JSON (no lo subas al repo).
3. En Supabase (desde `ice_pos`):

```powershell
cd c:\Users\jvald\code\icepos\ice_pos
supabase secrets set `
  FIREBASE_PROJECT_ID="tu-proyecto-id" `
  FIREBASE_CLIENT_EMAIL="firebase-adminsdk-xxxxx@tu-proyecto.iam.gserviceaccount.com" `
  FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
```

`FIREBASE_PRIVATE_KEY`: pega la clave del JSON; en PowerShell usa `\n` para saltos de línea o una sola línea como en el JSON.

## 3. `firebase_options.dart`

Edita `ice_pos/lib/firebase_options.dart` y reemplaza los `YOUR_*` con los valores de Firebase → **Project settings** → tu app Android (apiKey, appId, projectId, messagingSenderId, storageBucket).

## 4. Base de datos

```powershell
supabase db push
# o ejecuta supabase/migrations/034_fcm_device_tokens.sql en SQL Editor
```

## 5. Desplegar Edge Functions

```powershell
cd c:\Users\jvald\code\icepos\ice_pos
supabase functions deploy notify-staff-task
supabase functions deploy notify-due-staff-tasks
supabase functions deploy notify-pending-approval
```

## 6. Probar en tablet

```powershell
cd c:\Users\jvald\code\icepos\ice_pos
flutter pub get
flutter run
```

1. Inicia sesión (Supabase configurado).
2. Acepta **notificaciones** cuando Android lo pida.
3. En Supabase → tabla `fcm_device_tokens` debe aparecer una fila con tu `token`.
4. Crea una tarea con “Enviar recordatorio ahora” o invoca `notify-staff-task`.

## 7. Publicar APK

Tras configurar Firebase, incluye `google-services.json` en el build y publica:

```powershell
cd c:\Users\jvald\code\icepos
.\release-apk.ps1 "FCM push notifications"
```

## Qué envía push

| Evento | Edge function | FCM + Web |
|--------|---------------|-----------|
| Nueva tarea / recordatorio | `notify-staff-task` | Sí |
| Recordatorios programados (`notify_at`) | `notify-due-staff-tasks` | Sí |
| Aprobación cajero pendiente | `notify-pending-approval` | Sí |

## iOS (opcional)

Añade app iOS en Firebase, `GoogleService-Info.plist` en `ios/Runner/`, y completa `firebase_options.dart` → `ios`.

## Sin Firebase

Si no hay `google-services.json` ni `firebase_options.dart` configurado, la app **sigue funcionando**; solo no registra FCM.
