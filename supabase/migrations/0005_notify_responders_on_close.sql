-- Avisar a las aliadas cuando la alerta se cierra, SIN darles acceso a la ubicación de una alerta cerrada:
-- el estado se copia a su propia fila de alert_responders (que sí pueden leer).
alter table public.alert_responders add column if not exists alert_status text not null default 'active';

create or replace function public.propagate_alert_status() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status then
    update alert_responders set alert_status = new.status, updated_at = now() where alert_id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists alerts_propagate_status on public.alerts;
create trigger alerts_propagate_status after update of status on public.alerts
  for each row execute function public.propagate_alert_status();
