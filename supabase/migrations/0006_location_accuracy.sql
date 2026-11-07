-- Precisión del GPS (metros) para que la aliada sepa qué tan exacto es el punto de la usuaria.
alter table public.alerts add column if not exists accuracy_m double precision;
alter table public.alert_locations add column if not exists accuracy_m double precision;

drop function if exists public.push_alert_location(uuid, double precision, double precision);
create or replace function public.push_alert_location(p_alert uuid, p_lat double precision, p_lng double precision,
                                                     p_acc double precision default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  update alerts set lat = p_lat, lng = p_lng, accuracy_m = p_acc, updated_at = now()
  where id = p_alert and user_id = auth.uid() and status = 'active';
  if found then
    insert into alert_locations (alert_id, lat, lng, accuracy_m) values (p_alert, p_lat, p_lng, p_acc);
  end if;
end;
$$;
revoke execute on function public.push_alert_location(uuid, double precision, double precision, double precision) from anon, public;
grant execute on function public.push_alert_location(uuid, double precision, double precision, double precision) to authenticated;
