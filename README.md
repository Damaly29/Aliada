# Aliada

App móvil de seguridad y comunidad para estudiantes universitarias en Perú. Combina un **botón SOS** con una **red de aliadas cercanas** (geolocalización en tiempo real) y **LumAI**, un asistente de primera orientación ante acoso u hostigamiento.

> MVP en Flutter. La alarma funciona de forma local aunque el backend o la red fallen.

## Funcionalidad

- **Alerta SOS** en dos niveles: 🔴 emergencia (sirena + aliadas) y 🟡 compañía (silenciosa).
- **Cuenta regresiva cancelable** de 30 s: si nadie elige, se envía la emergencia.
- **Mapa en vivo** con la ubicación de la usuaria, su precisión GPS y las aliadas que acuden.
- **Modo aliada**: recibe alertas a ≤ 2 km, acepta, comparte su ubicación y el servidor marca "llegó" a ≤ 30 m.
- **Chat de la alerta** entre la usuaria y las aliadas que aceptan.
- **LumAI**: orientación con consentimiento explícito, red de seguridad por reglas, derivación humana garantizada y registro anonimizado de respuestas de riesgo.
- **Accesos directos** a 105 (Policía), Línea 100 y Línea 113.
- **Privacidad**: historial de LumAI solo en el teléfono y borrado de ubicaciones 24 h después de cerrar la alerta (Ley 29733).

## Stack

| Capa | Tecnología |
|---|---|
| App | Flutter 3.47+ / Dart 3.13+ |
| Estado | `ChangeNotifier` + singletons (`AppState`, `Cloud`, `LumaiService`) |
| Backend | Supabase (Postgres + RLS + Realtime + `pg_net` + Vault) |
| IA | Google Gemini vía RPC asíncrona, con cadena de modelos y fallback |
| Mapas | `google_maps_flutter` |
| Notificaciones | `flutter_local_notifications` |

## Estructura

```
lib/
  core/        estado local, Supabase, geo, ubicación precisa, notificaciones
  features/
    alert/     controlador de alerta + backends (real, demo, local)
    incoming/  escucha de alertas cercanas y acciones de la aliada
    lumai/     cliente del asistente
  screens/     pantallas (inicio, alerta, respondedora, LumAI, chat, perfil…)
  widgets/     mapa, botón SOS, tab bar, PIN, toasts, tarjetas
  theme/       tokens de diseño
supabase/
  migrations/  esquema, RLS, RPCs, LumAI y retención (aplicar en orden)
  lumai/       prompt de sistema
  tests/       prueba transaccional de RLS
scripts/       cliente Python de la API real y simulador de segundo teléfono
tests/         suite de sesgo de LumAI
```

## Puesta en marcha

### 1. Dependencias

```bash
flutter pub get
```

### 2. Supabase

**Al crear el proyecto** (Dashboard → New project):

| Campo | Valor recomendado |
|---|---|
| Nombre | `aliada` |
| Contraseña de base de datos | Generarla y guardarla en un gestor de contraseñas |
| Región | `sa-east-1` (São Paulo) si está disponible; si no, `us-east-1` |
| Enable Data API | ✅ Activado |
| Automatically expose new tables | ✅ Activado (o desactivado: la migración `0009` concede lo necesario) |
| Enable automatic RLS | ✅ Activado |

**Extensiones** (Database → Extensions): verifica que estén activas `pg_cron`, `pg_net`, `pgcrypto` y `postgis`.

**Migraciones**: aplica **en orden** `0001` → `0009` desde el SQL Editor (o con la CLI):

```bash
supabase link --project-ref <project-ref>
supabase db push
```

La migración `0009` concede permisos explícitos a `authenticated`; sin ella, si desactivas "Automatically expose new tables", la app falla con `permission denied`.

**Configura después de migrar**:

1. **Vault** (Database → Vault): crea el secreto `gemini_api_key` con tu clave de Google AI Studio.

   ```sql
   select vault.create_secret('TU_API_KEY', 'gemini_api_key', 'Clave Gemini para LumAI');
   ```

2. **Autenticación** (Authentication → Sign In / Providers): activa **Anonymous sign-ins**. Si lo dejas desactivado, la app usa el respaldo `register_device` de la migración `0002` (también funciona).
3. **Realtime**: las migraciones ya agregan `alerts`, `alert_responders` y `alert_messages` a la publicación. Verifica con:

   ```sql
   select tablename from pg_publication_tables where pubname = 'supabase_realtime';
   ```

4. **LumAI**: comprueba que `0008` sembró el prompt:

   ```sql
   select version, active from public.lumai_prompts where active;
   ```

### 3. Variables de compilación

La app lee los valores con `String.fromEnvironment`, así que se pasan como `--dart-define` (no hay `.env` en runtime).

Opción A — archivo local (recomendado). Copia `env.example.json` a `env.json` (**ignorado por git**) y rellena:

```json
{
  "SUPABASE_URL": "https://TU-PROYECTO.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_..."
}
```

```bash
flutter run --dart-define-from-file=env.json
```

Opción B — directo:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

> Los valores se embeben en el binario: si cambias de proyecto, hay que **recompilar** (no basta hot reload).

### 4. Google Maps (Android)

Crea `android/secrets.properties` (**no se versiona**):

```properties
MAPS_API_KEY=tu_clave_de_google_maps
```

En iOS la clave se configura en `ios/Runner/AppDelegate.swift` o vía `maps_config`.

### 5. Ejecutar

```bash
flutter run --dart-define-from-file=env.json

flutter build apk --release --dart-define-from-file=env.json
```

### 6. Scripts de prueba (opcional)

`scripts/aliada_api.py` lee `supabase.json` en la raíz (**ignorado por git**):

```json
{
  "SUPABASE_URL": "https://TU-PROYECTO.supabase.co",
  "SUPABASE_ANON_KEY": "sb_publishable_..."
}
```

Para `psql` o la CLI, guarda la cadena de conexión en `supabase.env`:

```
DATABASE_URL=postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres
```

## Modo demo

- **PIN de cancelación**: `1234` (solo demo; en producción debe validarse en el servidor).
- **Aliadas simuladas**: el interruptor está en *Perfil*. Muestra 3 aliadas falsas (Julia, Camila, Andrea) para probar el flujo sin un segundo teléfono.
- Para una prueba real con dos dispositivos o consola:

```bash
python3 scripts/simulate_phone.py pedir-ayuda --lat -12.0689 --lng -77.0790
python3 scripts/simulate_phone.py acudir      --lat -12.0689 --lng -77.0790
```

## Pruebas

```bash
flutter analyze          # análisis estático
flutter test             # pruebas unitarias/widget
```

- **RLS**: `supabase/tests/rls_alerts_test.sql` corre en una transacción con `ROLLBACK`.
- **Sesgo de LumAI**: `python3 tests/lumai-bias/run_bias_suite.py --etiqueta v3` (requiere `GEMINI_API_KEY` para el evaluador LLM). Reportes previos en `tests/lumai-bias/`.

## Permisos y segundo plano

- Android: `ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE_LOCATION`, `WAKE_LOCK`, `POST_NOTIFICATIONS`.
- iOS: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription` y `UIBackgroundModes = location`.
- Durante una alerta, el GPS corre como **servicio en primer plano** (notificación persistente) para seguir enviando la ubicación con la pantalla apagada.

## Limitaciones conocidas

- **No hay push (FCM/APNs)**: si el sistema operativo mata la app, no llegan alertas nuevas. El sonido funciona con la app viva en segundo plano.
- La **grabación de audio** es solo un indicador visual.
- Los **contactos de universidad** (Bienestar, Defensoría, psicología) son marcadores DEMO.
- El **SMS al contacto** solo existe en el backend demo.
- La pantalla **Educate** y la agenda/mensajes del dashboard son datos de ejemplo.

## Seguridad

- Nunca subas `supabase.json`, `supabase.env`, `android/secrets.properties` ni claves de servicio.
- La `anon key` es pública por diseño; la protección real está en las políticas RLS.
- La `service_role key` solo debe usarse en scripts locales, jamás en la app.
