# Cómo instalar la app en tu tablet

---

## iPad (instalar desde un Mac)

Necesitas un **Mac** con **Xcode** y tu **iPad** conectado por cable.

### Requisitos

- **Mac** con macOS y Xcode instalado ([App Store](https://apps.apple.com/app/xcode/id497799835)).
- **Apple ID** (el mismo de iCloud). Con una cuenta gratuita puedes instalar la app en tu propio iPad.
- **Cable** USB (o USB‑C) para conectar el iPad al Mac.
- En el Mac: **Flutter** instalado (`flutter doctor` debe mostrar iOS sin errores).

### 1. Conectar el iPad y activar Modo desarrollador

1. Conecta el iPad al Mac con el cable.
2. En el **iPad**: si sale “¿Confiar en este ordenador?”, toca **Confiar** e introduce el código si lo pide.
3. **Activar Modo desarrollador** (obligatorio para instalar apps desde Xcode/Flutter):
   - En el **iPad** ve a **Ajustes > Privacidad y seguridad**.
   - Baja hasta **Modo desarrollador** (o “Developer Mode” en inglés).
   - Actívalo. El iPad pedirá **reiniciar**; confirma.
   - Tras el reinicio puede pedir de nuevo que confirmes que quieres activar el Modo desarrollador; acepta.
4. Vuelve a conectar el iPad al Mac si hace falta y repite `flutter run --release`.

### 2. Configurar la firma (solo la primera vez)

1. Abre el proyecto iOS en Xcode:
   ```bash
   cd ice_pos
   open ios/Runner.xcworkspace
   ```
2. En Xcode, en el panel izquierdo selecciona **Runner** (el proyecto, icono azul).
3. En el centro, pestaña **Signing & Capabilities**:
   - Marca **Automatically manage signing**.
   - En **Team** elige tu Apple ID (si no sale, añade una cuenta en **Xcode > Settings > Accounts**).
4. Si Xcode pide un “Team” de desarrollo, usa tu Apple ID personal; no hace falta pagar el programa de desarrollador para instalar en tu propio iPad.
5. Cierra Xcode (o déjalo abierto).

### 3. Instalar y ejecutar en el iPad

En la terminal (con el iPad conectado):

```bash
cd ice_pos
flutter devices
```

Comprueba que aparezca tu iPad. Luego:

```bash
flutter run --release
```

O en modo debug (útil para ver logs):

```bash
flutter run
```

Flutter compilará la app, la instalará en el iPad y la abrirá. La primera vez puede tardar unos minutos.

### 4. Confiar en el desarrollador (solo la primera vez)

Si al abrir la app en el iPad sale algo como “App no fiable” o “Perfil de desarrollador no verificado”:

1. En el **iPad**: **Ajustes > General > VPN y gestión de dispositivos** (o **Gestión de dispositivos**).
2. En “APPS DE DESARROLLADOR” verás tu Apple ID o el nombre del perfil.
3. Toca y elige **Confiar en “[tu Apple ID]”**.
4. Vuelve a abrir la app.

### Resumen iPad

| Paso | Acción |
|------|--------|
| 1 | Conectar iPad al Mac y confiar en el ordenador |
| 2 | Abrir `ios/Runner.xcworkspace` en Xcode y configurar **Signing** con tu Apple ID |
| 3 | En terminal: `cd ice_pos` → `flutter run --release` (o `flutter run`) |
| 4 | Si la app no abre: Ajustes > General > Gestión de dispositivos > Confiar en tu desarrollador |

---

## Android: publicar un nuevo paquete

Para generar un paquete nuevo (por ejemplo para distribuir o subir a Play Store):

1. **Versión:** En `pubspec.yaml` está `version: 1.0.0+2`. El número tras el `+` es el *build number*; súbelo en cada publicación (p. ej. `1.0.0+3`). Opcionalmente cambia también `1.0.0` (versión visible).

2. **Generar el APK** (instalación directa / distribuir fuera de Play Store):

```bash
cd ice_pos
flutter pub get
flutter build apk --release
```

Salida: `build/app/outputs/flutter-apk/app-release.apk`

3. **Generar el App Bundle (AAB)** (para Google Play Store):

```bash
cd ice_pos
flutter pub get
flutter build appbundle --release
```

Salida: `build/app/outputs/bundle/release/app-release.aab`

Sube el `.aab` en Play Console (Producción o prueba interna). Para instalar a mano en dispositivos usa el APK.

---

## Android: APK e instalar a mano (sin cable)

Sirve para instalar en una tablet Android sin depender de Google Play.

### 1. Generar el APK

En tu computadora, en la raíz del repo:

```bash
cd ice_pos
flutter pub get
flutter build apk --release
```

El APK queda en:

```
ice_pos/build/app/outputs/flutter-apk/app-release.apk
```

### 2. Llevar el APK a la tablet

- **Opción A**: Subir el APK a Google Drive (o otro servicio), abrirlo desde la tablet y descargarlo.
- **Opción B**: Conectar la tablet por USB, copiar el archivo al almacenamiento de la tablet.
- **Opción C**: Enviarlo por email o por otra app (Telegram, etc.) y abrirlo en la tablet.

### 3. Instalar en la tablet

1. En la tablet, abre el archivo **app-release.apk** (desde el gestor de archivos o la notificación de descarga).
2. Si Android pide “Orígenes desconocidos” o “Instalar apps desconocidas”, activa el permiso para el navegador o la app desde la que abres el APK (Ajustes > Seguridad / Aplicaciones).
3. Confirma **Instalar**.
4. Cuando termine, abre la app como cualquier otra.

---

## Opción 2: Conectar la tablet por USB (desarrollo/pruebas)

Útil para probar cambios sin generar un APK cada vez.

### 1. Activar depuración USB en la tablet

1. Ve a **Ajustes > Acerca del tablet**.
2. Toca **Número de compilación** unas 7 veces hasta que diga que eres desarrollador.
3. Vuelve a Ajustes y entra en **Opciones de desarrollador**.
4. Activa **Depuración USB**.

### 2. Conectar y comprobar

1. Conecta la tablet al PC con el cable USB.
2. En la tablet, si sale el aviso “¿Permitir depuración USB?”, acepta y marca “Confiar en este equipo” si quieres.
3. En tu computadora:

```bash
cd ice_pos
flutter devices
```

Deberías ver tu tablet en la lista.

### 3. Instalar y ejecutar

```bash
flutter run --release
```

O en modo debug (más rápido para desarrollar):

```bash
flutter run
```

Flutter instalará la app en la tablet y la abrirá. Para siguientes veces, solo vuelve a ejecutar `flutter run` (o `flutter run --release`).

---

## Versión y build number (opcional)

Si quieres fijar versión y número de build del APK:

```bash
flutter build apk --release --build-name=1.0.0 --build-number=1
```

---

## Resumen rápido

| Dispositivo | Resumen |
|-------------|--------|
| **iPad** | Mac + Xcode + cable. Configurar firma en Xcode (Team = tu Apple ID). Luego `flutter run --release` con el iPad conectado. Si la app no abre, en el iPad: Ajustes > General > Gestión de dispositivos > Confiar. |
| **Android** | `flutter build apk --release` → copiar el APK a la tablet e instalarlo. O con cable: depuración USB → `flutter run --release`. |
