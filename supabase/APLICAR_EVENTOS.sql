-- ALIADA · Aplicar esquema de Eventos (proyecto jiiyyhcsmyvjokqsqazz)
--
-- Cómo usarlo:
--   1. Abre https://supabase.com/dashboard/project/jiiyyhcsmyvjokqsqazz/sql/new
--   2. Pega TODO el contenido de este archivo.
--   3. Pulsa Run (o Ctrl+Enter).
--
-- Es idempotente: puedes ejecutarlo más de una vez sin duplicar nada.
-- No inserta eventos ficticios. Los eventos reales se cargan después.

-- Perfil de la usuaria (salvaguarda por si 0001 quedó incompleta).
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nombre text not null default 'Estudiante' check (char_length(nombre) between 1 and 60),
  disponible boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
drop policy if exists profiles_own on public.profiles;
create policy profiles_own on public.profiles for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
grant select, insert, update on public.profiles to authenticated;

-- Aliada · Módulo Edúcate → Eventos
-- Catálogo público de eventos + inscripciones + favoritos.
--
-- Reglas de negocio:
--   · Solo se exponen eventos con estado = 'publicado'.
--   · Las inscripciones se crean únicamente por RPC (security definer), nunca por INSERT directo.
--   · La PK (event_id, user_id) impide que una usuaria se inscriba dos veces.
--   · La capacidad se valida dentro de la RPC con bloqueo de la fila del evento.
--   · Los pagos NO se confirman desde la app: `confirm_event_payment` queda reservada a service_role
--     para que la pasarela/webhook la invoque cuando el pago haya sido validado.
--
-- Esta migración NO inserta eventos: la cartelera se llena con datos reales desde el panel
-- de administración de Supabase o mediante `insert into public.events (...)`.

-- `ubicacion` usa geography(Point, 4326); la extensión también la crea 0001, pero se repite
-- aquí para que esta migración sea segura si se aplica por separado.
create extension if not exists postgis with schema extensions;

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  titulo text not null check (char_length(titulo) between 3 and 120),
  descripcion text not null default '' check (char_length(descripcion) <= 5000),
  imagen_url text,
  categoria text not null default 'Comunidad' check (char_length(categoria) between 2 and 60),
  organizador text not null check (char_length(organizador) between 2 and 120),
  organizador_avatar_url text,
  organizador_bio text check (organizador_bio is null or char_length(organizador_bio) <= 500),
  inicio timestamptz not null,
  fin timestamptz not null,
  lugar text not null check (char_length(lugar) between 2 and 160),
  direccion text,
  modalidad text not null default 'presencial' check (modalidad in ('presencial', 'virtual')),
  enlace_virtual text,
  precio numeric(10, 2) not null default 0 check (precio >= 0),
  capacidad integer not null default 100 check (capacidad > 0),
  estado text not null default 'publicado' check (estado in ('borrador', 'publicado', 'cancelado')),
  lat double precision,
  lng double precision,
  ubicacion extensions.geography(Point, 4326) generated always as (
    case
      when lat is null or lng is null then null
      else extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography
    end
  ) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint events_fechas_validas check (fin > inicio),
  constraint events_lat_lng_pair check ((lat is null) = (lng is null)),
  constraint events_lat_range check (lat is null or lat between -90 and 90),
  constraint events_lng_range check (lng is null or lng between -180 and 180)
);

create index if not exists events_estado_inicio_idx on public.events (estado, inicio);
create index if not exists events_created_idx on public.events (created_at desc);
create index if not exists events_ubicacion_gix on public.events using gist (ubicacion);

create table if not exists public.event_registrations (
  event_id uuid not null references public.events (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  estado text not null default 'confirmada' check (estado in ('pendiente_pago', 'confirmada', 'cancelada')),
  metodo_pago text check (metodo_pago in ('gratuito', 'yape', 'plin', 'tarjeta', 'transferencia')),
  pago_referencia text check (pago_referencia is null or char_length(pago_referencia) <= 200),
  pagado_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

create index if not exists event_registrations_user_idx on public.event_registrations (user_id);
create index if not exists event_registrations_event_estado_idx on public.event_registrations (event_id, estado);

create table if not exists public.event_favorites (
  event_id uuid not null references public.events (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (event_id, user_id)
);

create index if not exists event_favorites_user_idx on public.event_favorites (user_id);

-- Mantiene updated_at al día sin depender de la app.
create or replace function public.touch_event_row() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists events_touch_row on public.events;
create trigger events_touch_row before update on public.events
  for each row execute function public.touch_event_row();

drop trigger if exists event_registrations_touch_row on public.event_registrations;
create trigger event_registrations_touch_row before update on public.event_registrations
  for each row execute function public.touch_event_row();

-- ───────── RLS ─────────
alter table public.events enable row level security;
alter table public.event_registrations enable row level security;
alter table public.event_favorites enable row level security;

drop policy if exists events_read_published on public.events;
create policy events_read_published on public.events for select to anon, authenticated
  using (estado = 'publicado');

-- Las inscripciones solo se leen por su dueña. La escritura pasa por RPC.
drop policy if exists event_registrations_read_own on public.event_registrations;
create policy event_registrations_read_own on public.event_registrations for select to authenticated
  using (user_id = auth.uid());

drop policy if exists event_favorites_read_own on public.event_favorites;
create policy event_favorites_read_own on public.event_favorites for select to authenticated
  using (user_id = auth.uid());
drop policy if exists event_favorites_insert_own on public.event_favorites;
create policy event_favorites_insert_own on public.event_favorites for insert to authenticated
  with check (user_id = auth.uid());
drop policy if exists event_favorites_delete_own on public.event_favorites;
create policy event_favorites_delete_own on public.event_favorites for delete to authenticated
  using (user_id = auth.uid());

revoke all on public.events from anon, authenticated;
grant select on public.events to anon, authenticated;

revoke all on public.event_registrations from anon, authenticated;
grant select on public.event_registrations to authenticated;

revoke all on public.event_favorites from anon, authenticated;
grant select, insert, delete on public.event_favorites to authenticated;

-- ───────── Feed con contadores y estado de la usuaria ─────────
-- Devuelve el catálogo publicado con:
--   asistentes   = inscripciones confirmadas (dato agregado, no expone identidades)
--   mi_estado    = estado de la inscripción de auth.uid() (null si no está inscrita)
--   es_favorito  = si auth.uid() la guardó
create or replace function public.events_feed(
  p_search text default null,
  p_day date default null,
  p_event uuid default null
) returns table (
  id uuid,
  titulo text,
  descripcion text,
  imagen_url text,
  categoria text,
  organizador text,
  organizador_avatar_url text,
  organizador_bio text,
  inicio timestamptz,
  fin timestamptz,
  lugar text,
  direccion text,
  modalidad text,
  precio numeric,
  capacidad integer,
  estado text,
  lat double precision,
  lng double precision,
  created_at timestamptz,
  asistentes bigint,
  mi_estado text,
  es_favorito boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    e.id,
    e.titulo,
    e.descripcion,
    e.imagen_url,
    e.categoria,
    e.organizador,
    e.organizador_avatar_url,
    e.organizador_bio,
    e.inicio,
    e.fin,
    e.lugar,
    e.direccion,
    e.modalidad,
    e.precio,
    e.capacidad,
    e.estado,
    e.lat,
    e.lng,
    e.created_at,
    coalesce((
      select count(*) from public.event_registrations r
      where r.event_id = e.id and r.estado = 'confirmada'
    ), 0)::bigint as asistentes,
    (
      select r.estado from public.event_registrations r
      where r.event_id = e.id and r.user_id = auth.uid()
      limit 1
    ) as mi_estado,
    exists (
      select 1 from public.event_favorites f
      where f.event_id = e.id and f.user_id = auth.uid()
    ) as es_favorito
  from public.events e
  where e.estado = 'publicado'
    and (p_event is null or e.id = p_event)
    and (
      p_search is null or btrim(p_search) = ''
      or e.titulo ilike '%' || btrim(p_search) || '%'
      or e.lugar ilike '%' || btrim(p_search) || '%'
      or coalesce(e.direccion, '') ilike '%' || btrim(p_search) || '%'
      or e.organizador ilike '%' || btrim(p_search) || '%'
    )
    and (
      p_day is null
      or (e.inicio at time zone 'America/Lima')::date = p_day
    )
  order by e.inicio asc;
$$;

-- Lista de asistentes con privacidad: solo el primer nombre.
create or replace function public.event_attendees(p_event uuid)
returns table (nombre text, created_at timestamptz)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(nullif(split_part(btrim(pr.nombre), ' ', 1), ''), 'Estudiante') as nombre,
    r.created_at
  from public.event_registrations r
  join public.events e on e.id = r.event_id
  left join public.profiles pr on pr.id = r.user_id
  where r.event_id = p_event
    and r.estado = 'confirmada'
    and e.estado = 'publicado'
  order by r.created_at asc;
$$;

revoke all on function public.events_feed(text, date, uuid) from public, anon, authenticated;
grant execute on function public.events_feed(text, date, uuid) to anon, authenticated;

revoke all on function public.event_attendees(uuid) from public, anon, authenticated;
grant execute on function public.event_attendees(uuid) to authenticated;

-- ───────── Inscripción gratuita (atómica y sin doble registro) ─────────
create or replace function public.register_free_event(p_event uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.events%rowtype;
  v_count bigint;
begin
  if auth.uid() is null then
    return 'no_autenticada';
  end if;

  -- Bloquea la fila del evento mientras se valida la capacidad.
  select * into v_event
  from public.events
  where id = p_event and estado = 'publicado'
  for update;

  if not found then
    return 'no_disponible';
  end if;
  if v_event.fin <= now() then
    return 'finalizado';
  end if;
  if v_event.precio > 0 then
    return 'requiere_pago';
  end if;
  if exists (
    select 1 from public.event_registrations
    where event_id = p_event and user_id = auth.uid() and estado <> 'cancelada'
  ) then
    return 'ya_inscrita';
  end if;

  select count(*) into v_count
  from public.event_registrations
  where event_id = p_event and estado = 'confirmada';

  if v_count >= v_event.capacidad then
    return 'agotado';
  end if;

  begin
    insert into public.event_registrations as er
      (event_id, user_id, estado, metodo_pago, pagado_at)
    values
      (p_event, auth.uid(), 'confirmada', 'gratuito', now())
    on conflict (event_id, user_id) do update
      set estado = 'confirmada',
          metodo_pago = 'gratuito',
          pagado_at = now(),
          updated_at = now()
      where er.estado = 'cancelada';
  exception when unique_violation then
    return 'ya_inscrita';
  end;

  return 'confirmada';
end;
$$;

-- ───────── Confirmación de pago (solo backend / service_role) ─────────
-- La app NUNCA llama a esta función. Cuando se integre una pasarela, el webhook
-- validado del proveedor (o una Edge Function con service_role) debe invocarla.
create or replace function public.confirm_event_payment(
  p_event uuid,
  p_user uuid,
  p_provider text,
  p_reference text
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_event public.events%rowtype;
  v_count bigint;
begin
  if coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'not authorized';
  end if;
  if p_provider not in ('yape', 'plin', 'tarjeta', 'transferencia') then
    raise exception 'invalid payment provider';
  end if;
  if p_reference is null or btrim(p_reference) = '' then
    raise exception 'invalid payment reference';
  end if;

  select * into v_event from public.events where id = p_event for update;
  if not found then
    return 'no_disponible';
  end if;
  if v_event.estado <> 'publicado' then
    return 'no_disponible';
  end if;
  if v_event.precio <= 0 then
    return 'evento_gratuito';
  end if;
  if v_event.fin <= now() then
    return 'finalizado';
  end if;
  if exists (
    select 1 from public.event_registrations
    where event_id = p_event and user_id = p_user and estado = 'confirmada'
  ) then
    return 'ya_inscrita';
  end if;

  select count(*) into v_count
  from public.event_registrations
  where event_id = p_event and estado = 'confirmada';
  if v_count >= v_event.capacidad then
    return 'agotado';
  end if;

  insert into public.event_registrations as er
    (event_id, user_id, estado, metodo_pago, pago_referencia, pagado_at)
  values
    (p_event, p_user, 'confirmada', p_provider, btrim(p_reference), now())
  on conflict (event_id, user_id) do update
    set estado = 'confirmada',
        metodo_pago = excluded.metodo_pago,
        pago_referencia = excluded.pago_referencia,
        pagado_at = now(),
        updated_at = now()
    where er.estado <> 'confirmada';

  return 'confirmada';
end;
$$;

revoke all on function public.register_free_event(uuid) from public, anon, authenticated;
grant execute on function public.register_free_event(uuid) to authenticated;

revoke all on function public.confirm_event_payment(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.confirm_event_payment(uuid, uuid, text, text) to service_role;
