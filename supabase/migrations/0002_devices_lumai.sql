-- Aliada MVP · Cuentas de dispositivo (respaldo si las sesiones anónimas están desactivadas) + LumAI.

create extension if not exists pg_net with schema extensions;

-- ───────── Cuenta por dispositivo ─────────
-- Crea (una sola vez) una cuenta confirmada para el dispositivo. La app luego inicia sesión con
-- email+secreto. Si la cuenta ya existe no se toca (no permite cambiar el secreto de otro).
create or replace function public.register_device(p_device text, p_secret text) returns text
language plpgsql security definer set search_path = public, auth, extensions as $$
declare
  uid uuid;
  em text;
begin
  if p_device !~ '^[a-z0-9]{10,40}$' or length(coalesce(p_secret, '')) < 24 then
    raise exception 'invalid device credentials';
  end if;
  em := p_device || '@devices.aliada.app';
  select id into uid from auth.users where email = em;
  if uid is not null then
    return em;
  end if;
  uid := gen_random_uuid();
  insert into auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
                          raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
                          confirmation_token, recovery_token, email_change_token_new, email_change)
  values ('00000000-0000-0000-0000-000000000000', uid, 'authenticated', 'authenticated', em,
          crypt(p_secret, gen_salt('bf')), now(),
          '{"provider":"email","providers":["email"],"device":true}', '{}', now(), now(), '', '', '', '');
  insert into auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
  values (uid::text, uid, jsonb_build_object('sub', uid::text, 'email', em, 'email_verified', true), 'email', now(), now(), now());
  return em;
end;
$$;
revoke all on function public.register_device(text, text) from public;
grant execute on function public.register_device(text, text) to anon, authenticated;

-- ───────── Feature flags ─────────
create table if not exists public.features (
  key text primary key,
  enabled boolean not null default false,
  note text,
  updated_at timestamptz not null default now()
);
alter table public.features enable row level security;
drop policy if exists features_read on public.features;
create policy features_read on public.features for select to anon, authenticated using (true);
insert into public.features (key, enabled, note) values
  ('lumai_chat', true, 'Chat LumAI'),
  ('lumai_resumen', false, 'Resumen para derivación (Módulo 2)'),
  ('moderacion', false, 'Moderación de chats (Módulo 6)'),
  ('activacion_voz', false, 'Palabra clave experimental (Módulo 5)')
on conflict (key) do nothing;

-- ───────── Prompt versionado ─────────
create table if not exists public.lumai_prompts (
  version text primary key,
  content text not null,
  active boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.lumai_prompts enable row level security; -- sin políticas: solo el servidor

-- ───────── Base de conocimiento (solo documentos aprobados llegan a LumAI) ─────────
create table if not exists public.kb_documents (
  id uuid primary key default gen_random_uuid(),
  titulo text not null,
  contenido text not null,
  fuente text not null,
  revisado_por text,
  aprobado boolean not null default false,
  version integer not null default 1,
  created_at timestamptz not null default now()
);
alter table public.kb_documents enable row level security; -- sin políticas: solo el servidor
-- PROHIBIDO cargar aquí conversaciones o testimonios de estudiantes.

insert into public.kb_documents (titulo, contenido, fuente, revisado_por, aprobado)
select * from (values
  ('DEMO – ¿Qué es el hostigamiento sexual?',
   'DEMO – reemplazar por protocolo real. En Perú, la Ley 27942 y su reglamento definen el hostigamiento sexual como una conducta de naturaleza o connotación sexual o sexista no deseada por la persona a la que se dirige, que puede crear un ambiente intimidatorio, hostil o humillante, o afectar su actividad o situación académica. No se requiere que la conducta se repita para ser reportada.',
   'DEMO – Ley 27942 (resumen no oficial)', 'pendiente', true),
  ('DEMO – Canales de la universidad',
   'DEMO – reemplazar por protocolo real. Cada universidad debe tener un Comité o instancia de intervención frente al hostigamiento sexual y canales de atención (Bienestar Universitario, Defensoría Universitaria). La estudiante puede pedir orientación sin estar obligada a presentar una queja formal. Las medidas de protección pueden solicitarse desde el inicio.',
   'DEMO – Protocolo institucional (plantilla)', 'pendiente', true),
  ('DEMO – Líneas de ayuda',
   'DEMO – verificar vigencia. Policía Nacional: 105. Línea 100 (MIMP): orientación y atención gratuita ante violencia familiar y sexual, 24 horas. Chat 100 disponible en la web del MIMP. En una emergencia inmediata, usar el botón rojo de alerta de Aliada.',
   'DEMO – MIMP / PNP', 'pendiente', true),
  ('DEMO – Consentimiento',
   'DEMO – reemplazar por material revisado. El consentimiento es libre, informado, específico, reversible y entusiasta. Puede retirarse en cualquier momento. El silencio o la falta de resistencia no es consentimiento. Una persona bajo efectos de alcohol u otras sustancias puede no estar en capacidad de consentir.',
   'DEMO – Material educativo', 'pendiente', true)
) v(titulo, contenido, fuente, revisado_por, aprobado)
where not exists (select 1 from public.kb_documents);

-- ───────── Solicitudes a Gemini (asíncronas vía pg_net; la clave vive en Vault) ─────────
create table if not exists public.lumai_requests (
  id bigint primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  model text not null,
  prompt_version text not null,
  created_at timestamptz not null default now()
);
alter table public.lumai_requests enable row level security; -- acceso solo vía RPC

create or replace function public.lumai_ask(p_messages jsonb) returns bigint
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_key text;
  v_prompt record;
  v_kb text;
  v_contents jsonb;
  v_body jsonb;
  v_id bigint;
  v_model constant text := 'gemini-2.5-flash';
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not coalesce((select enabled from features where key = 'lumai_chat'), false) then
    raise exception 'lumai disabled';
  end if;
  if jsonb_typeof(p_messages) <> 'array' or jsonb_array_length(p_messages) = 0 then
    raise exception 'invalid messages';
  end if;
  -- límite simple de uso: 30 solicitudes por usuaria cada 10 min
  if (select count(*) from lumai_requests where user_id = auth.uid() and created_at > now() - interval '10 minutes') >= 30 then
    raise exception 'rate limited';
  end if;

  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'gemini_api_key';
  select version, content into v_prompt from lumai_prompts where active order by created_at desc limit 1;
  select string_agg('### ' || titulo || E'\n' || contenido || E'\n(Fuente: ' || fuente || ')', E'\n\n')
    into v_kb from kb_documents where aprobado;

  -- últimos 20 turnos, texto recortado
  select jsonb_agg(jsonb_build_object(
           'role', case when m->>'role' = 'model' then 'model' else 'user' end,
           'parts', jsonb_build_array(jsonb_build_object('text', left(coalesce(m->>'text', ''), 2000)))))
    into v_contents
    from (select m from jsonb_array_elements(p_messages) with ordinality as t(m, i)
          order by i desc limit 20) last
    , lateral (select 1) _;
  -- restaurar orden cronológico
  select jsonb_agg(e order by ord desc) into v_contents
    from jsonb_array_elements(v_contents) with ordinality as t(e, ord);

  v_body := jsonb_build_object(
    'systemInstruction', jsonb_build_object('parts', jsonb_build_array(jsonb_build_object(
      'text', v_prompt.content || E'\n\n## BASE DE CONOCIMIENTO (documentos aprobados)\n' || coalesce(v_kb, '(vacía)')))),
    'contents', v_contents,
    'generationConfig', jsonb_build_object(
      'temperature', 0.4,
      'maxOutputTokens', 1024,
      'responseMimeType', 'application/json',
      'responseSchema', jsonb_build_object(
        'type', 'OBJECT',
        'properties', jsonb_build_object(
          'respuesta', jsonb_build_object('type', 'STRING'),
          'riesgo', jsonb_build_object('type', 'STRING', 'enum', jsonb_build_array('ninguno', 'posible', 'inmediato')),
          'necesidad_detectada', jsonb_build_object('type', 'STRING', 'enum',
            jsonb_build_array('informacion', 'acompanamiento', 'apoyo_emocional', 'reporte', 'no_claro')),
          'sugerir_derivacion', jsonb_build_object('type', 'BOOLEAN'),
          'acciones_sugeridas', jsonb_build_object('type', 'ARRAY', 'items', jsonb_build_object('type', 'STRING', 'enum',
            jsonb_build_array('ver_protocolo', 'solicitar_acompanamiento', 'contactar_psicologia', 'contactar_bienestar', 'iniciar_reporte', 'emergencia')))),
        'required', jsonb_build_array('respuesta', 'riesgo', 'necesidad_detectada', 'sugerir_derivacion', 'acciones_sugeridas'))));

  v_id := net.http_post(
    url := 'https://generativelanguage.googleapis.com/v1beta/models/' || v_model || ':generateContent',
    body := v_body,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-goog-api-key', v_key),
    timeout_milliseconds := 45000);

  insert into lumai_requests (id, model, prompt_version) values (v_id, v_model, coalesce(v_prompt.version, 'none'));
  return v_id;
end;
$$;

-- Resultado validado. Cualquier fallo → riesgo "posible" + derivación (fallo seguro).
create or replace function public.lumai_result(p_id bigint) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_req record;
  v_res record;
  v_text text;
  v_out jsonb;
  v_safe jsonb;
begin
  select * into v_req from lumai_requests where id = p_id and user_id = auth.uid();
  if not found then raise exception 'not found'; end if;

  v_safe := jsonb_build_object(
    'respuesta', 'Perdón, ahora no pude generar una respuesta. Si lo necesitas, puedes hablar con una persona capacitada o, si estás en peligro, usar el botón de alerta, el 105 o la Línea 100.',
    'riesgo', 'posible', 'necesidad_detectada', 'no_claro', 'sugerir_derivacion', true,
    'acciones_sugeridas', jsonb_build_array('contactar_bienestar', 'emergencia'),
    'fallback', true, 'model', v_req.model, 'prompt_version', v_req.prompt_version);

  select status_code, content, timed_out, error_msg into v_res from net._http_response where id = p_id;
  if not found then
    if v_req.created_at < now() - interval '60 seconds' then return v_safe; end if;
    return jsonb_build_object('pending', true);
  end if;
  if v_res.timed_out or v_res.status_code is distinct from 200 then return v_safe; end if;

  begin
    v_text := (v_res.content::jsonb) #>> '{candidates,0,content,parts,0,text}';
    v_out := v_text::jsonb;
    if jsonb_typeof(v_out->'respuesta') <> 'string'
       or (v_out->>'riesgo') not in ('ninguno', 'posible', 'inmediato')
       or jsonb_typeof(v_out->'sugerir_derivacion') <> 'boolean'
       or jsonb_typeof(v_out->'acciones_sugeridas') <> 'array' then
      return v_safe;
    end if;
    return v_out || jsonb_build_object('model', v_req.model, 'prompt_version', v_req.prompt_version);
  exception when others then
    return v_safe;
  end;
end;
$$;

revoke all on function public.lumai_ask(jsonb), public.lumai_result(bigint) from public, anon;
grant execute on function public.lumai_ask(jsonb), public.lumai_result(bigint) to authenticated;

-- ───────── Reportes / correcciones (anonimizados: sin user_id) ─────────
create table if not exists public.lumai_flags (
  id uuid primary key default gen_random_uuid(),
  tipo text not null check (tipo in ('correccion', 'danina', 'riesgo')),
  respuesta text not null,
  comentario text,
  riesgo text,
  model text,
  prompt_version text,
  gravedad text,
  revisado boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.lumai_flags enable row level security;
drop policy if exists flags_insert on public.lumai_flags;
create policy flags_insert on public.lumai_flags for insert to authenticated with check (true);

create or replace function public.redact_pii(t text) returns text language sql immutable as $$
  select regexp_replace(regexp_replace(regexp_replace(coalesce(t, ''),
    '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '[correo]', 'g'),
    '(\+?51)?[ -]?9\d{2}[ -]?\d{3}[ -]?\d{3}', '[teléfono]', 'g'),
    '\m\d{8}\M', '[DNI]', 'g');
$$;

create or replace function public.lumai_flags_redact() returns trigger language plpgsql as $$
begin
  new.respuesta := redact_pii(new.respuesta);
  new.comentario := redact_pii(new.comentario);
  return new;
end;
$$;
drop trigger if exists lumai_flags_redact on public.lumai_flags;
create trigger lumai_flags_redact before insert on public.lumai_flags for each row execute function public.lumai_flags_redact();

-- limpiar solicitudes viejas (no guardamos el contenido del chat en el servidor)
select cron.unschedule(jobid) from cron.job where jobname = 'aliada_purge_lumai';
select cron.schedule('aliada_purge_lumai', '30 * * * *', $$delete from public.lumai_requests where created_at < now() - interval '1 day';$$);
