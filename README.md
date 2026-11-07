# Aliada

Aplicación Flutter de alarma SOS y red de ayuda entre estudiantes. El módulo
**Edúcate → Eventos** muestra la cartelera real publicada en Supabase (sin datos
de demostración).

## Requisitos

- Flutter 3.x (Dart 3.13+)
- Un proyecto de Supabase con las migraciones de `supabase/migrations/` aplicadas

## Configuración de Supabase

La app toma la URL y la clave pública del entorno de compilación:

```json
{
  "SUPABASE_URL": "https://<proyecto>.supabase.co",
  "SUPABASE_ANON_KEY": "<publishable-key>"
}
```

Guarda ese archivo como `supabase.json` en la raíz (está en `.gitignore`). En VS Code
las configuraciones de `.vscode/launch.json` ya usan
`--dart-define-from-file=supabase.json`.

> No uses la `service_role` en la app. Las claves públicas + RLS son suficientes.

## Ejecutar

```bash
flutter pub get
flutter analyze
flutter run -d chrome --dart-define-from-file=supabase.json
```

Sin el archivo de configuración la app abre, pero el módulo de eventos muestra
«La cartelera de eventos no está configurada en esta compilación».

## Migraciones

**Camino rápido:** si el proyecto ya tiene aplicada la migración `0001` (tablas
`profiles`, `alerts`, `responder_presence`) y solo faltan las tablas de eventos,
ejecuta en el SQL Editor:

```
supabase/APLICAR_EVENTOS.sql
```

Ese archivo es idempotente y contiene la salvaguarda de `profiles` + todo `0008`.

**Camino completo:** aplica las migraciones en orden desde el SQL Editor de Supabase
(o con la CLI):

```
supabase/migrations/0001_alerts_mvp.sql
...
supabase/migrations/0008_events.sql
supabase/migrations/0009_events_remove_demo_seed.sql
supabase/migrations/0010_event_payments.sql
```

- `0008_events.sql` crea `events`, `event_registrations`, `event_favorites`, sus
  políticas RLS y las RPC `events_feed`, `event_attendees`, `register_free_event`
  y `confirm_event_payment`. **No inserta eventos.**
- `0009_events_remove_demo_seed.sql` elimina los 7 eventos ficticios que versiones
  anteriores de `0008` pudieron haber insertado. Es seguro ejecutarla varias veces.

### Cargar eventos reales

Publica eventos desde el panel de Supabase o con SQL (ejemplo):

```sql
insert into public.events (
  titulo, descripcion, imagen_url, categoria, organizador,
  inicio, fin, lugar, direccion, modalidad, precio, capacidad,
  estado, lat, lng
) values (
  'Feria de Bienestar Universitario',
  'Descripción del evento.',
  'https://.../imagen.jpg',
  'Bienestar',
  'Bienestar Universitario',
  now() + interval '3 days',
  now() + interval '3 days 7 hours',
  'Explanada Central',
  'Campus Central, Lima',
  'presencial',
  0,
  150,
  'publicado',
  -12.0689,
  -77.0790
);
```

Solo los eventos con `estado = 'publicado'` aparecen en la app.

Para cargar los seis eventos de ejemplo de la cartelera y la Agenda de Inicio,
ejecuta `supabase/seed_events.sql` en el SQL Editor después de aplicar el esquema.
El archivo actualiza la Feria de Bienestar y agrega los títulos que falten, así
que se puede volver a ejecutar sin duplicar estos eventos.

Los eventos gratuitos permiten confirmar la inscripción desde la app. Para los
eventos de pago, `0010_event_payments.sql` añade órdenes de Culqi y mantiene la
inscripción pendiente hasta recibir el webhook verificado.

### Pagos de prueba con Yape y Plin

La integración requiere desplegar `supabase/functions/event-payment` en el mismo
proyecto y registrar sus secretos desde **Supabase → Edge Functions → Secrets**:

- `CULQI_SECRET_KEY`: llave secreta de integración (`sk_test_...`) de Culqi.
- `CULQI_PUBLIC_KEY`: llave pública de integración (`pk_test_...`) de Culqi.
- `CULQI_WEBHOOK_AUTH`: usuario y contraseña del webhook, en el formato
  `usuario:contraseña`; usa los mismos datos al activar autenticación en Culqi.

Configura en Culqi el webhook `order.status.changed` con la URL
`https://<proyecto>.supabase.co/functions/v1/event-payment` y envía el evento de
`order.status.changed` y activa autenticación con las credenciales guardadas en
`CULQI_WEBHOOK_AUTH`. No agregues llaves privadas a Flutter ni al archivo
`supabase.json`. La Edge Function autentica la llamada del webhook y consulta la
orden directamente con Culqi antes de confirmar una inscripción.

Aplica las migraciones en orden hasta `0010_event_payments.sql`, despliega la
función y configura las tres llaves en modo test antes de probar. Culqi exige
que las órdenes de billeteras estén entre S/ 6 y S/ 500 y el checkout muestra el
QR para completar el pago. La Agenda muestra tanto pagos pendientes como
inscripciones confirmadas.

### Diagnóstico

Si la app muestra «No hay eventos disponibles» pero crees que hay eventos, ejecuta
`supabase/diagnostics/events_check.sql` en el SQL Editor. Revisa, en este orden:

1. Que existan filas con `estado = 'publicado'`.
2. Que RLS esté activo y exista la política `events_read_published`.
3. Que `events_feed` tenga `execute` para `anon` y `authenticated`.
4. Que `select * from public.events_feed()` devuelva las mismas filas.

## Inscripciones y pagos

- La inscripción gratuita pasa por `register_free_event`, que bloquea la fila del
  evento, valida la capacidad y evita duplicados con la PK `(event_id, user_id)`.
- Los eventos de pago abren la hoja de checkout, pero **no** confirman la compra:
  `confirm_event_payment` está reservada a `service_role` para que la pasarela o
  el webhook la invoque cuando el pago esté verificado.
- `0010_event_payments.sql` y `supabase/functions/event-payment` preparan el
  flujo de órdenes Culqi para Yape y Plin y el webhook asíncrono. La función y
  la migración se deben desplegar/aplicar en el proyecto Supabase para cobrar.

Culqi muestra un QR de billeteras móviles para que la participante lo pague desde
Yape o Plin. El checkout de Culqi genera el QR. Los montos de esos pagos deben
estar entre S/ 6 y S/ 500.
