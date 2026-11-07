-- LumAI: la clave es de una cuenta nueva de Gemini → usa la Interactions API (steps) con gemini-3.8-flash.

create or replace function public.lumai_ask(p_messages jsonb) returns bigint
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_key text;
  v_prompt record;
  v_kb text;
  v_steps jsonb;
  v_body jsonb;
  v_id bigint;
  v_model constant text := 'gemini-3.8-flash';
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

  select decrypted_secret into v_key from vault.decrypted_secrets where name = 'gemini_api_key';
  select version, content into v_prompt from lumai_prompts where active order by created_at desc limit 1;
  select string_agg('### ' || titulo || E'\n' || contenido || E'\n(Fuente: ' || fuente || ')', E'\n\n')
    into v_kb from kb_documents where aprobado;

  -- últimos 20 turnos en orden cronológico, como steps de la Interactions API
  select jsonb_agg(jsonb_build_object(
           'type', case when m->>'role' = 'model' then 'model_output' else 'user_input' end,
           'content', jsonb_build_array(jsonb_build_object('type', 'text', 'text', left(coalesce(m->>'text', ''), 2000))))
         order by i)
    into v_steps
    from (select m, i from jsonb_array_elements(p_messages) with ordinality as t(m, i)
          order by i desc limit 20) last;

  v_body := jsonb_build_object(
    'model', v_model,
    'store', false,
    'system_instruction', v_prompt.content || E'\n\n## BASE DE CONOCIMIENTO (documentos aprobados)\n' || coalesce(v_kb, '(vacía)'),
    'input', v_steps,
    'generation_config', jsonb_build_object('temperature', 0.4, 'max_output_tokens', 1500, 'thinking_level', 'low'),
    'response_format', jsonb_build_object(
      'type', 'text',
      'mime_type', 'application/json',
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

  v_id := net.http_post(
    url := 'https://generativelanguage.googleapis.com/v1beta/interactions',
    body := v_body,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-goog-api-key', v_key),
    timeout_milliseconds := 45000);

  insert into lumai_requests (id, model, prompt_version) values (v_id, v_model, coalesce(v_prompt.version, 'none'));
  return v_id;
end;
$$;

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

  select status_code, content, timed_out into v_res from net._http_response where id = p_id;
  if not found then
    if v_req.created_at < now() - interval '60 seconds' then return v_safe; end if;
    return jsonb_build_object('pending', true);
  end if;
  if v_res.timed_out or v_res.status_code is distinct from 200 then return v_safe; end if;

  begin
    select s #>> '{content,0,text}' into v_text
      from jsonb_array_elements((v_res.content::jsonb)->'steps') s
     where s->>'type' = 'model_output'
     order by 1 desc limit 1;
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
