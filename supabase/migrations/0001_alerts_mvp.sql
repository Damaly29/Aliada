-- Aliada MVP · Alarma SOS y red de aliadas entre teléfonos.
-- Sesiones anónimas de Supabase Auth (auth.uid()) + RLS estricta + Realtime (postgres_changes).

create extension if not exists postgis with schema extensions;
create extension if not exists pg_cron;

-- ───────── Perfiles ─────────
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nombre text not null default 'Estudiante' check (char_length(nombre) between 1 and 60),
  disponible boolean not null default true,
  updated_at timestamptz not null default now()
);

-- ───────── Presencia de aliadas (solo disponibles; nadie ve presencias ajenas) ─────────
create table if not exists public.responder_presence (
  user_id uuid primary key references auth.users (id) on delete cascade,
  location extensions.geography(Point, 4326) not null,
  updated_at timestamptz not null default now()
);
create index if not exists responder_presence_gix on public.responder_presence using gist (location);

-- ───────── Alertas ─────────
create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nombre text not null check (char_length(nombre) between 1 and 60),
  level text not null default 'emergency' check (level in ('emergency', 'companion')),
  status text not null default 'active' check (status in ('active', 'safe', 'cancelled')),
  lat double precision,
  lng double precision,
  location extensions.geography(Point, 4326) generated always as (
    case when lat is null or lng is null then null
    else extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography end
  ) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  closed_at timestamptz
);
create index if not exists alerts_active_gix on public.alerts using gist (location) where status = 'active';
create index if not exists alerts_user_idx on public.alerts (user_id);

-- Historial de ubicaciones de la usuaria durante la alerta.
create table if not exists public.alert_locations (
  id bigint generated always as identity primary key,
  alert_id uuid not null references public.alerts (id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  created_at timestamptz not null default now()
);
create index if not exists alert_locations_alert_idx on public.alert_locations (alert_id, created_at);

create table if not exists public.alert_responders (
  alert_id uuid not null references public.alerts (id) on delete cascade,
  responder_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nombre text not null check (char_length(nombre) between 1 and 60),
  status text not null default 'en_camino' check (status in ('notified', 'en_camino', 'llego', 'rechazo')),
  lat double precision,
  lng double precision,
  eta_s integer,
  updated_at timestamptz not null default now(),
  primary key (alert_id, responder_id)
);

create table if not exists public.alert_messages (
  id uuid primary key default gen_random_uuid(),
  alert_id uuid not null references public.alerts (id) on delete cascade,
  sender_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nombre text not null check (char_length(nombre) between 1 and 60),
  body text not null check (char_length(body) between 1 and 1000),
  created_at timestamptz not null default now()
);
create index if not exists alert_messages_alert_idx on public.alert_messages (alert_id, created_at);

-- ───────── Helpers (security definer: evitan recursión de RLS) ─────────
create or replace function public.is_alert_owner(a uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from alerts where id = a and user_id = auth.uid());
$$;

create or replace function public.is_active_responder(a uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from alert_responders r join alerts al on al.id = r.alert_id
    where r.alert_id = a and r.responder_id = auth.uid()
      and r.status in ('en_camino', 'llego') and al.status = 'active'
  );
$$;

-- Aliada disponible con presencia reciente a ≤ 2 km de la alerta activa.
create or replace function public.can_see_nearby_alert(a uuid) returns boolean
language sql stable security definer set search_path = public, extensions as $$
  select exists (
    select 1
    from alerts al
    join responder_presence p on p.user_id = auth.uid()
    join profiles pr on pr.id = auth.uid() and pr.disponible
    where al.id = a and al.status = 'active' and al.user_id <> auth.uid()
      and p.updated_at > now() - interval '15 minutes'
      and al.location is not null
      and st_dwithin(al.location, p.location, 2000)
  );
$$;

-- ───────── RPCs ─────────
create or replace function public.upsert_presence(p_lat double precision, p_lng double precision) returns void
language sql security definer set search_path = public, extensions as $$
  insert into responder_presence (user_id, location, updated_at)
  values (auth.uid(), st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography, now())
  on conflict (user_id) do update set location = excluded.location, updated_at = now();
$$;

create or replace function public.clear_presence() returns void
language sql security definer set search_path = public as $$
  delete from responder_presence where user_id = auth.uid();
$$;

-- Actualiza la ubicación de la alerta y guarda historial (solo la dueña, solo alerta activa).
create or replace function public.push_alert_location(p_alert uuid, p_lat double precision, p_lng double precision) returns void
language plpgsql security definer set search_path = public as $$
begin
  update alerts set lat = p_lat, lng = p_lng, updated_at = now()
  where id = p_alert and user_id = auth.uid() and status = 'active';
  if found then
    insert into alert_locations (alert_id, lat, lng) values (p_alert, p_lat, p_lng);
  end if;
end;
$$;

-- Ubicación de la aliada; marca "llego" en el servidor a ≤ 30 m.
create or replace function public.push_responder_location(p_alert uuid, p_lat double precision, p_lng double precision) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare d double precision;
begin
  select st_distance(al.location, st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography)
    into d from alerts al where al.id = p_alert and al.status = 'active';
  update alert_responders
     set lat = p_lat, lng = p_lng, updated_at = now(),
         eta_s = case when d is null then null else round(d / 1.3)::int end,
         status = case when d is not null and d <= 30 and status = 'en_camino' then 'llego' else status end
   where alert_id = p_alert and responder_id = auth.uid() and status in ('en_camino', 'llego');
end;
$$;

-- ───────── RLS ─────────
alter table public.profiles enable row level security;
alter table public.responder_presence enable row level security;
alter table public.alerts enable row level security;
alter table public.alert_locations enable row level security;
alter table public.alert_responders enable row level security;
alter table public.alert_messages enable row level security;

drop policy if exists profiles_own on public.profiles;
create policy profiles_own on public.profiles for all to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- presence: sin políticas → solo accesible vía RPC security definer.

drop policy if exists alerts_insert on public.alerts;
create policy alerts_insert on public.alerts for insert to authenticated with check (user_id = auth.uid());
drop policy if exists alerts_update_own on public.alerts;
create policy alerts_update_own on public.alerts for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists alerts_select on public.alerts;
create policy alerts_select on public.alerts for select to authenticated using (
  user_id = auth.uid() or public.is_active_responder(id) or public.can_see_nearby_alert(id)
);

drop policy if exists alert_locations_select on public.alert_locations;
create policy alert_locations_select on public.alert_locations for select to authenticated using (
  public.is_alert_owner(alert_id) or public.is_active_responder(alert_id)
);

drop policy if exists responders_insert on public.alert_responders;
create policy responders_insert on public.alert_responders for insert to authenticated with check (
  responder_id = auth.uid() and public.can_see_nearby_alert(alert_id)
);
drop policy if exists responders_update_own on public.alert_responders;
create policy responders_update_own on public.alert_responders for update to authenticated
  using (responder_id = auth.uid()) with check (responder_id = auth.uid());
drop policy if exists responders_select on public.alert_responders;
create policy responders_select on public.alert_responders for select to authenticated using (
  responder_id = auth.uid() or public.is_alert_owner(alert_id)
);

drop policy if exists messages_insert on public.alert_messages;
create policy messages_insert on public.alert_messages for insert to authenticated with check (
  sender_id = auth.uid() and (public.is_alert_owner(alert_id) or public.is_active_responder(alert_id))
);
drop policy if exists messages_select on public.alert_messages;
create policy messages_select on public.alert_messages for select to authenticated using (
  public.is_alert_owner(alert_id) or public.is_active_responder(alert_id)
);

grant execute on function public.upsert_presence, public.clear_presence, public.push_alert_location,
  public.push_responder_location to authenticated;
revoke execute on function public.upsert_presence, public.clear_presence, public.push_alert_location,
  public.push_responder_location from anon, public;

-- ───────── Realtime ─────────
alter table public.alerts replica identity full;
alter table public.alert_responders replica identity full;
do $$
begin
  begin alter publication supabase_realtime add table public.alerts; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.alert_responders; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.alert_messages; exception when duplicate_object then null; end;
end $$;

-- ───────── Retención (Ley 29733): ubicación borrada 24 h tras cerrar la alerta ─────────
create or replace function public.purge_closed_alert_locations() returns void
language sql security definer set search_path = public as $$
  delete from alert_locations al using alerts a
   where a.id = al.alert_id and a.status <> 'active' and a.closed_at < now() - interval '24 hours';
  update alerts set lat = null, lng = null
   where status <> 'active' and closed_at < now() - interval '24 hours' and lat is not null;
  update alert_responders r set lat = null, lng = null from alerts a
   where a.id = r.alert_id and a.status <> 'active' and a.closed_at < now() - interval '24 hours' and r.lat is not null;
  -- alertas abiertas y olvidadas: se cierran tras 6 h
  update alerts set status = 'cancelled', closed_at = now()
   where status = 'active' and updated_at < now() - interval '6 hours';
  delete from responder_presence where updated_at < now() - interval '1 day';
$$;

select cron.unschedule(jobid) from cron.job where jobname = 'aliada_purge_locations';
select cron.schedule('aliada_purge_locations', '15 * * * *', $$select public.purge_closed_alert_locations();$$);
