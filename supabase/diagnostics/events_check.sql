-- Aliada · Diagnóstico de la cartelera de eventos (Edúcate → Eventos)
--
-- Ejecuta este archivo completo en el SQL Editor de Supabase cuando la app muestre
-- «No hay eventos disponibles» o un error de carga. Cada consulta es de solo lectura.
--
-- Resultado esperado para que la app vea eventos:
--   1) public.events existe y tiene filas con estado = 'publicado'.
--   2) RLS está activo y la política events_read_published existe.
--   3) events_feed tiene permiso execute para anon y authenticated.
--   4) La función events_feed devuelve las mismas filas que la tabla.

-- 1. ¿Existe el esquema del módulo?
select
  to_regclass('public.events')                as tabla_events,
  to_regclass('public.event_registrations')   as tabla_inscripciones,
  to_regclass('public.event_favorites')       as tabla_favoritos;

-- 2. Conteo por estado. Solo 'publicado' se muestra en la app.
select estado, count(*) as total
from public.events
group by estado
order by estado;

-- 3. Los 10 eventos publicados más recientes (lo que verá «Últimos eventos»).
select id, titulo, inicio, fin, lugar, modalidad, precio, capacidad, created_at
from public.events
where estado = 'publicado'
order by created_at desc
limit 10;

-- 4. ¿RLS activo y qué políticas existen?
select c.relname as tabla, c.relrowsecurity as rls_activo
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('events', 'event_registrations', 'event_favorites');

select schemaname, tablename, policyname, roles, cmd, qual
from pg_policies
where schemaname = 'public'
  and tablename in ('events', 'event_registrations', 'event_favorites')
order by tablename, policyname;

-- 5. Funciones del módulo y permisos de ejecución.
select
  p.proname,
  pg_get_function_identity_arguments(p.oid) as argumentos,
  p.prosecdef as security_definer,
  has_function_privilege('anon', p.oid, 'execute')          as anon_puede,
  has_function_privilege('authenticated', p.oid, 'execute') as authenticated_puede
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname in ('events_feed', 'event_attendees', 'register_free_event', 'confirm_event_payment')
order by p.proname;

-- 6. ¿La RPC devuelve la cartelera? Esta es exactamente la consulta que hace Flutter.
select id, titulo, inicio, created_at, asistentes
from public.events_feed(p_search => null, p_day => null, p_event => null)
order by created_at desc;

-- 7. ¿Cuántas inscripciones confirmadas tiene cada evento?
select e.id, e.titulo, count(r.*) filter (where r.estado = 'confirmada') as inscritas
from public.events e
left join public.event_registrations r on r.event_id = e.id
where e.estado = 'publicado'
group by e.id, e.titulo
order by e.created_at desc;

-- 8. ¿Hay perfiles para mostrar el nombre de las asistentes?
select count(*) as perfiles
from public.profiles;
