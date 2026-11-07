-- LumAI v2: rotación de modelos según cuota, red de seguridad por reglas (no depende de la IA),
-- oferta humana garantizada, registro anonimizado de respuestas con riesgo (Módulo 3) y parámetros más consistentes.

-- Cadena de modelos (la clave es de plan gratuito: ~20 respuestas/día por modelo).
create or replace function public.lumai_models() returns text[] language sql immutable as $$
  select array['gemini-3.8-flash', 'gemini-3.5-flash', 'gemini-3-flash-preview',
               'gemini-3.5-flash-lite', 'gemini-3.1-flash-lite', 'gemini-flash-lite-latest'];
$$;

create table if not exists public.lumai_model_status (
  model text primary key,
  blocked_until timestamptz not null,
  reason text
);
alter table public.lumai_model_status enable row level security; -- solo servidor

-- Próxima medianoche del Pacífico (cuando Google reinicia la cuota diaria gratuita).
create or replace function public._next_quota_reset() returns timestamptz language sql stable as $$
  select (date_trunc('day', now() at time zone 'America/Los_Angeles') + interval '1 day') at time zone 'America/Los_Angeles';
$$;

-- Índice del siguiente modelo disponible a partir de p_from (null si ninguno).
create or replace function public._lumai_next_model(p_from int) returns int
language sql stable security definer set search_path = public as $$
  select min(i) from generate_subscripts(public.lumai_models(), 1) i
   where i >= p_from
     and not exists (select 1 from lumai_model_status s
                      where s.model = (public.lumai_models())[i] and s.blocked_until > now());
$$;

-- ───────── Reglas de seguridad (deterministas) ─────────
create or replace function public.lumai_danger_level(t text) returns text language sql immutable as $$
  select case
    when t ~* '(suicid|matarme|quitarme la vida|no quiero (seguir )?vivi(r|endo)|no quiero estar viva|hacerme da[ñn]o|lastimarme|cortarme|ya no quiero estar aqu[ií]|desaparecer para siempre|mejor (estar|estaría) muerta)' then 'autolesion'
    when t ~* '(me (est[aá]n? )?sigu(e|en|iendo)(?! en (instagram|insta|ig|tiktok|redes|twitter|facebook|fb|x)\M)|me persigue|est[aá] afuera esper|no me deja salir|me tiene encerrad|estoy encerrad|me quiere (pegar|matar|violar)|me va a (pegar|matar|hacer algo)|me est[aá]n? (agrediendo|tocando|golpeando)|auxilio|ayuda urgente|ay[uú]dame ya|me est[aá] amenazando)' then 'inmediato'
    else null end;
$$;

drop function if exists public.lumai_banned_hit(text);
create or replace function public.lumai_banned_hit(t_in text) returns text language plpgsql immutable as $$
declare t text;
begin
  -- Quitar frases negadas ("no estás exagerando", "no fue tu culpa", "no lo confrontes") antes de buscar.
  t := regexp_replace(coalesce(t_in, ''), '\m(no|nunca|ni|jam[aá]s)\s+([^\s.,;:!?]+\s+){0,2}[^\s.,;:!?]+', ' ', 'gi');
  return coalesce(
    (regexp_match(t, '(no es para tanto|seguro no quiso|est[aá]s exagerando|le das demasiada importancia|t[oó]malo con calma)', 'i'))[1],
    (regexp_match(t, '((tienes|hay|cuentas con) pruebas|est[aá]s segura de que|qu[eé] llevabas|por qu[eé] no (dijiste|te fuiste|gritaste|avisaste)|por qu[eé] fuiste)', 'i'))[1],
    (regexp_match(t, '(debiste|deber[ií]as haber|fue tu culpa|es tu culpa|por haber tomado)', 'i'))[1],
    (regexp_match(t, '((tienes|sufres|padeces|presentas) (de )?(ansiedad|depresi[oó]n|trauma|estr[eé]s postraum|tept|un trastorno))', 'i'))[1],
    (regexp_match(t, '(\m(es|[eé]l es) (un )?(acosador|agresor|abusador)\M)', 'i'))[1],
    (regexp_match(t, '(conf?r[oó]ntalo|enfr[eé]ntalo|enc[aá]ralo|ve a encararlo)', 'i'))[1]
  );
end;
$$;

create or replace function public._lumai_emergency_text(kind text) returns text language sql immutable as $$
  select case when kind = 'autolesion' then
    'Gracias por contármelo, no estás sola. Lo que sientes es muy importante. Llama ahora a la Línea 113, opción 5 (salud mental, 24 horas), o busca a una persona de confianza que pueda estar contigo. Si estás en peligro, usa el botón rojo de alerta de Aliada o llama al 105. Yo no puedo ir hasta ti, pero una persona capacitada sí puede ayudarte ahora.'
  else
    'Tu seguridad es lo primero. Si puedes, entra ya a un lugar concurrido e iluminado. Usa el botón rojo de alerta de Aliada: avisa a aliadas cercanas y a tu contacto de emergencia con tu ubicación. También puedes llamar al 105 (Policía) o a la Línea 100 (24 h). Yo no puedo ir hasta ti, pero puedes pedir ayuda ahora.'
  end;
$$;

-- ───────── Ask ─────────
create or replace function public.lumai_ask(p_messages jsonb) returns bigint
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_prompt record;
  v_kb text;
  v_steps jsonb;
  v_body jsonb;
  v_id bigint;
  v_idx int;
  v_last text;
begin
  if auth.uid() is null then raise exception 'not authenticated'; end if;
  if not coalesce((select enabled from features where key = 'lumai_chat'), false) then
    raise exception 'lumai disabled';
  end if;
  if jsonb_typeof(p_messages) <> 'array' or jsonb_array_length(p_messages) = 0 then
    raise exception 'invalid messages';
  end if;
  if (select count(*) from lumai_requests where user_id = auth.uid() and created_at > now() - interval '10 minutes') >= 30 then
    raise exception 'rate limited';
  end if;

  select version, content into v_prompt from lumai_prompts where active order by created_at desc limit 1;
  select string_agg('### ' || titulo || E'\n' || contenido || E'\n(Fuente: ' || fuente || ')', E'\n\n')
    into v_kb from kb_documents where aprobado;

  select jsonb_agg(jsonb_build_object(
           'type', case when m->>'role' = 'model' then 'model_output' else 'user_input' end,
           'content', jsonb_build_array(jsonb_build_object('type', 'text', 'text', left(coalesce(m->>'text', ''), 2000))))
         order by i)
    into v_steps
    from (select m, i from jsonb_array_elements(p_messages) with ordinality as t(m, i)
          order by i desc limit 20) last;
  select left(m->>'text', 2000) into v_last
    from jsonb_array_elements(p_messages) with ordinality as t(m, i)
   where coalesce(m->>'role', 'user') <> 'model' order by i desc limit 1;

  v_body := jsonb_build_object(
    'store', false,
    'system_instruction', v_prompt.content || E'\n\n## BASE DE CONOCIMIENTO (documentos aprobados)\n' || coalesce(v_kb, '(vacía)'),
    'input', v_steps,
    'generation_config', jsonb_build_object('temperature', 0.2, 'max_output_tokens', 1200, 'thinking_level', 'low'),
    'response_format', jsonb_build_object(
      'type', 'text', 'mime_type', 'application/json',
      'schema', jsonb_build_object(
        'type', 'object',
        'properties', jsonb_build_object(
          'respuesta', jsonb_build_object('type', 'string'),
          'riesgo', jsonb_build_object('type', 'string', 'enum', jsonb_build_array('ninguno', 'posible', 'inmediato')),
          'necesidad_detectada', jsonb_build_object('type', 'string', 'enum',
            jsonb_build_array('informacion', 'acompanamiento', 'apoyo_emocional', 'reporte', 'no_claro')),
          'sugerir_derivacion', jsonb_build_object('type', 'boolean'),
          'acciones_sugeridas', jsonb_build_object('type', 'array', 'items', jsonb_build_object('type', 'string', 'enum',
            jsonb_build_array('ver_protocolo', 'solicitar_acompanamiento', 'contactar_psicologia', 'contactar_bienestar', 'iniciar_reporte', 'emergencia')))),
        'required', jsonb_build_array('respuesta', 'riesgo', 'necesidad_detectada', 'sugerir_derivacion', 'acciones_sugeridas'))));

  v_idx := public._lumai_next_model(1);
  if v_idx is null then
    -- Sin cuota en ningún modelo: se responde con la red de seguridad (sin llamar a la IA).
    v_id := -(extract(epoch from clock_timestamp()) * 1000)::bigint;
    insert into lumai_requests (id, net_id, attempt, body, model, prompt_version)
    values (v_id, null, 0, jsonb_build_object('last_user', v_last), 'sin_cuota', coalesce(v_prompt.version, 'none'));
    return v_id;
  end if;
  v_id := public._lumai_send(v_body, (public.lumai_models())[v_idx]);
  insert into lumai_requests (id, net_id, attempt, body, model, prompt_version)
  values (v_id, v_id, v_idx - 1, v_body || jsonb_build_object('last_user', v_last), (public.lumai_models())[v_idx], coalesce(v_prompt.version, 'none'));
  return v_id;
end;
$$;

-- ───────── Result (validación + reglas + seguridad) ─────────
create or replace function public.lumai_result(p_id bigint) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_req record;
  v_res record;
  v_text text;
  v_out jsonb;
  v_last text;
  v_danger text;
  v_hit text;
  v_next int;
  v_net bigint;
  v_acc jsonb;
begin
  select * into v_req from lumai_requests where id = p_id and user_id = auth.uid();
  if not found then raise exception 'not found'; end if;
  v_last := v_req.body->>'last_user';
  v_danger := public.lumai_danger_level(coalesce(v_last, ''));

  if v_req.net_id is not null then
    select status_code, content, timed_out into v_res from net._http_response where id = v_req.net_id;
    if not found then
      if v_req.created_at < now() - interval '90 seconds' then v_res := null; else return jsonb_build_object('pending', true); end if;
    end if;
  end if;

  -- Error temporal o sin cuota → marcar el modelo y pasar al siguiente.
  if v_res is not null and (v_res.timed_out or v_res.status_code in (400, 404, 429, 500, 502, 503, 504)) and v_req.body ? 'input' then
    if v_res.status_code = 429 and v_res.content ilike '%per day%' then
      insert into lumai_model_status (model, blocked_until, reason) values (v_req.model, public._next_quota_reset(), 'cuota diaria')
      on conflict (model) do update set blocked_until = excluded.blocked_until, reason = excluded.reason;
    elsif v_res.status_code in (400, 404) then
      insert into lumai_model_status (model, blocked_until, reason) values (v_req.model, now() + interval '6 hours', 'no compatible')
      on conflict (model) do update set blocked_until = excluded.blocked_until, reason = excluded.reason;
    end if;
    v_next := public._lumai_next_model(v_req.attempt + 2);
    if v_next is not null and v_req.created_at > now() - interval '80 seconds' then
      v_net := public._lumai_send(v_req.body - 'last_user', (public.lumai_models())[v_next]);
      update lumai_requests set net_id = v_net, attempt = v_next - 1, model = (public.lumai_models())[v_next] where id = p_id;
      return jsonb_build_object('pending', true, 'retry', (public.lumai_models())[v_next]);
    end if;
  end if;

  update lumai_requests set body = null where id = p_id; -- la conversación no se conserva

  -- Parseo y validación estricta
  begin
    if v_res is not null and v_res.status_code = 200 then
      select s #>> '{content,0,text}' into v_text
        from jsonb_array_elements((v_res.content::jsonb)->'steps') s where s->>'type' = 'model_output' limit 1;
      v_out := v_text::jsonb;
      if jsonb_typeof(v_out->'respuesta') <> 'string' or (v_out->>'riesgo') not in ('ninguno', 'posible', 'inmediato')
         or jsonb_typeof(v_out->'sugerir_derivacion') <> 'boolean' or jsonb_typeof(v_out->'acciones_sugeridas') <> 'array' then
        v_out := null;
      end if;
    end if;
  exception when others then v_out := null;
  end;

  if v_out is null then
    -- Fallo seguro: riesgo "posible" + derivación (o "inmediato" si las reglas detectan peligro).
    v_out := jsonb_build_object(
      'respuesta', 'Perdón, ahora no pude generar una respuesta completa. Lo que me cuentas importa. Si lo necesitas, puedes hablar con una persona capacitada (Bienestar, psicología o la Línea 100). Si estás en peligro, usa el botón de alerta o llama al 105.',
      'riesgo', 'posible', 'necesidad_detectada', 'no_claro', 'sugerir_derivacion', true,
      'acciones_sugeridas', jsonb_build_array('contactar_bienestar', 'emergencia'), 'fallback', true);
  end if;

  -- Red de seguridad 1: peligro detectado por reglas → nunca por debajo de "inmediato".
  if v_danger is not null then
    v_acc := coalesce(v_out->'acciones_sugeridas', '[]'::jsonb);
    if not v_acc ? 'emergencia' then v_acc := jsonb_build_array('emergencia') || v_acc; end if;
    v_out := v_out || jsonb_build_object('riesgo', 'inmediato', 'sugerir_derivacion', true, 'acciones_sugeridas', v_acc);
    if coalesce((v_out->>'fallback')::boolean, false)
       or (v_out->>'respuesta') !~* (case when v_danger = 'autolesion' then '113' else '(105|alerta)' end) then
      v_out := v_out || jsonb_build_object('respuesta', public._lumai_emergency_text(v_danger)
        || case when coalesce((v_out->>'fallback')::boolean, false) then '' else E'\n\n' || (v_out->>'respuesta') end);
    end if;
  end if;

  -- Red de seguridad 2: frases prohibidas (minimizar, cuestionar, culpar, diagnosticar, etiquetar, confrontar).
  v_hit := public.lumai_banned_hit(v_out->>'respuesta');
  if v_hit is not null then
    insert into lumai_flags (tipo, respuesta, comentario, riesgo, model, prompt_version)
    values ('riesgo', v_out->>'respuesta', 'Filtro automático: «' || v_hit || '»', v_out->>'riesgo', v_req.model, v_req.prompt_version);
    v_out := v_out || jsonb_build_object('respuesta',
      coalesce(case when v_danger is not null then public._lumai_emergency_text(v_danger) end,
        'Gracias por contármelo. Lo que sientes es válido y no tienes que decidir nada ahora. Puedo explicarte tus opciones o, si prefieres, conectarte con una persona capacitada de Bienestar, psicología o la Línea 100. Esto no es un diagnóstico ni una decisión institucional. ¿Qué necesitas en este momento?'),
      'filtrada', true, 'sugerir_derivacion', true);
  end if;

  -- Red de seguridad 3: siempre ofrecer la opción humana cuando hay riesgo.
  if (v_out->>'riesgo') <> 'ninguno' and (v_out->>'respuesta') !~* '(persona|profesional|psic[oó]log|bienestar|defensor|l[ií]nea 100|113)' then
    v_out := v_out || jsonb_build_object('respuesta', (v_out->>'respuesta')
      || E'\n\nSi quieres, también puedes hablar con una persona capacitada: toca «Hablar con una persona».');
  end if;
  if (v_out->>'riesgo') <> 'ninguno' then
    v_out := v_out || jsonb_build_object('sugerir_derivacion', true);
  end if;

  -- Módulo 3: respuestas con riesgo se registran ANONIMIZADAS (sin usuaria ni mensaje; solo la respuesta, redactada).
  if (v_out->>'riesgo') <> 'ninguno' and v_hit is null then
    insert into lumai_flags (tipo, respuesta, riesgo, model, prompt_version)
    values ('riesgo', v_out->>'respuesta', v_out->>'riesgo', v_req.model, v_req.prompt_version);
  end if;

  return v_out || jsonb_build_object('model', v_req.model, 'prompt_version', v_req.prompt_version);
end;
$$;

-- Línea de salud mental (DEMO – verificar vigencia)
insert into public.kb_documents (titulo, contenido, fuente, revisado_por, aprobado)
select 'DEMO – Salud mental y crisis',
       'DEMO – verificar vigencia. Línea 113, opción 5 (MINSA): orientación en salud mental gratuita, 24 horas. Ante ideas de hacerse daño, buscar compañía de una persona de confianza y acudir a emergencias. El servicio de psicología de la universidad puede brindar acompañamiento.',
       'DEMO – MINSA', 'pendiente', true
where not exists (select 1 from public.kb_documents where titulo = 'DEMO – Salud mental y crisis');
