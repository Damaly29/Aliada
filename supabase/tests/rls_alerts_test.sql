-- Prueba de RLS de alertas. Todo corre dentro de una transacción con ROLLBACK: no deja datos.
\set ON_ERROR_STOP 1
begin;
insert into auth.users (id, instance_id, aud, role, email) values
  ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'victima@test.local'),
  ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'aliada.cerca@test.local'),
  ('33333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'aliada.lejos@test.local');

set local role authenticated;

-- Aliada cerca (B) y lejos (C) registran presencia
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
insert into profiles (id, nombre, disponible) values (auth.uid(), 'Julia', true);
select upsert_presence(-12.0700, -77.0800);
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
insert into profiles (id, nombre, disponible) values (auth.uid(), 'Lejana', true);
select upsert_presence(-12.1500, -77.0200);

-- Víctima (A) crea la alerta
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
insert into profiles (id, nombre) values (auth.uid(), 'Nicolle');
insert into alerts (nombre, lat, lng) values ('Nicolle', -12.0689, -77.0790) returning id as alert_id \gset

-- C (a ~10 km) NO debe verla
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
select 'C_ve_alertas=' || count(*) from alerts;
select 'C_ve_presencias=' || count(*) from responder_presence;

-- B (a ~150 m) SÍ la ve, acepta y se mueve
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select 'B_ve_alertas=' || count(*) from alerts;
insert into alert_responders (alert_id, nombre, status, lat, lng) values (:'alert_id', 'Julia', 'en_camino', -12.0700, -77.0800);
select push_responder_location(:'alert_id', -12.06891, -77.07901);
select 'B_estado=' || status || ' eta_s=' || coalesce(eta_s::text, 'null') from alert_responders where alert_id = :'alert_id';
insert into alert_messages (alert_id, nombre, body) values (:'alert_id', 'Julia', 'Estoy aquí');
select 'B_ve_historial=' || count(*) from alert_locations;

-- A ve a B y el mensaje; actualiza su ubicación
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select push_alert_location(:'alert_id', -12.0690, -77.0791);
select 'A_ve_responders=' || count(*) from alert_responders;
select 'A_ve_mensajes=' || count(*) from alert_messages;
select 'A_ve_historial=' || count(*) from alert_locations;

-- C no puede escribir en el chat ni sumarse como aliada (aunque conozca el id)
select set_config('test.alert', :'alert_id', true);
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
do $$ begin
  insert into alert_messages (alert_id, nombre, body) values (current_setting('test.alert')::uuid, 'Lejana', 'hola');
  raise notice 'C_insert_mensaje=PERMITIDO(ERROR)';
exception when insufficient_privilege then raise notice 'C_insert_mensaje=bloqueado';
end $$;
do $$ begin
  insert into alert_responders (alert_id, nombre) values (current_setting('test.alert')::uuid, 'Lejana');
  raise notice 'C_insert_responder=PERMITIDO(ERROR)';
exception when insufficient_privilege then raise notice 'C_insert_responder=bloqueado';
end $$;
select 'C_ve_mensajes=' || count(*) from alert_messages;
rollback;
