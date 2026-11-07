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

Los eventos gratuitos permiten confirmar la inscripción desde la app. Los eventos
con precio muestran su costo, pero la pasarela todavía no está conectada; por eso
la app no confirma ni cobra una inscripción pagada.

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
