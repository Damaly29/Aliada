-- Permisos explícitos para el Data API.
-- Sirven tanto si el proyecto tiene "Automatically expose new tables" activado
-- como si está desactivado (recomendado). RLS sigue filtrando fila por fila.
--
-- Tablas sin GRANT aquí (responder_presence, lumai_requests, lumai_prompts,
-- kb_documents, lumai_model_status) solo se usan desde funciones
-- security definer; no deben ser accesibles directamente.

grant usage on schema public to anon, authenticated;

-- Feature flags: la app consulta si LumAI está activo (también antes del login).
grant select on public.features to anon, authenticated;

-- Perfil propio (upsert desde la app).
grant select, insert, update on public.profiles to authenticated;

-- Alertas: crear, leer las propias/cercanas y cerrarlas.
grant select, insert, update on public.alerts to authenticated;

-- Historial de ubicación: solo lectura (las inserta push_alert_location).
grant select on public.alert_locations to authenticated;

-- Aliadas que acuden: crear/actualizar su fila y leer las de la alerta.
grant select, insert, update on public.alert_responders to authenticated;

-- Chat de la alerta.
grant select, insert on public.alert_messages to authenticated;

-- Correcciones/reportes anonimizados.
grant insert on public.lumai_flags to authenticated;
