-- Aliada · Limpieza de la cartelera de ejemplo
--
-- Las primeras versiones de `0008_events.sql` insertaban 7 eventos ficticios con UUID fijos
-- (e0000000-0000-4000-8000-000000000001 … …007). El módulo ya no usa datos demo, así que
-- esta migración elimina únicamente esos registros si todavía existen.
--
-- Es segura de ejecutar varias veces y no toca eventos reales (los UUID son específicos).
-- Las inscripciones y favoritos asociados se eliminan en cascada.

do $$
begin
  if to_regclass('public.events') is null then
    raise notice 'public.events no existe; no hay nada que limpiar.';
    return;
  end if;

  delete from public.events
  where id in (
    'e0000000-0000-4000-8000-000000000001',
    'e0000000-0000-4000-8000-000000000002',
    'e0000000-0000-4000-8000-000000000003',
    'e0000000-0000-4000-8000-000000000004',
    'e0000000-0000-4000-8000-000000000005',
    'e0000000-0000-4000-8000-000000000006',
    'e0000000-0000-4000-8000-000000000007'
  );
end $$;
