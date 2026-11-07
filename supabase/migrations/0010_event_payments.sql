-- Pagos de eventos con Culqi: una orden pendiente por pago, varios intentos
-- y confirmación exclusiva desde la Edge Function que valida el webhook.
create table if not exists public.event_payments (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.events(id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  provider text not null default 'culqi' check (provider = 'culqi'),
  payment_method text not null check (payment_method in ('yape', 'plin')),
  amount numeric(10, 2) not null check (amount > 0),
  currency text not null default 'PEN' check (currency = 'PEN'),
  provider_order_id text unique,
  provider_status text not null default 'creating'
    check (provider_status in ('creating', 'pending', 'paid', 'expired', 'failed')),
  checkout_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  paid_at timestamptz
);

create index if not exists event_payments_user_event_idx
  on public.event_payments(user_id, event_id, created_at desc);
create index if not exists event_payments_provider_status_idx
  on public.event_payments(provider_order_id, provider_status);

alter table public.event_payments enable row level security;
revoke all on public.event_payments from anon, authenticated;
grant select on public.event_payments to authenticated;
drop policy if exists event_payments_read_own on public.event_payments;
create policy event_payments_read_own on public.event_payments
  for select to authenticated using (user_id = auth.uid());

create or replace function public.start_event_payment(
  p_event uuid,
  p_method text,
  p_user uuid
) returns table (
  payment_id uuid,
  event_title text,
  event_amount numeric,
  payment_state text,
  order_id text,
  saved_checkout text,
  user_email text,
  user_name text,
  user_expiry timestamptz
)
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_event public.events%rowtype;
  v_user uuid := coalesce(
    auth.uid(),
    case when coalesce(auth.role(), '') = 'service_role' then p_user else null end
  );
  v_profile public.profiles%rowtype;
  v_payment uuid;
  v_count bigint;
  v_name text;
  v_existing_payment uuid;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if coalesce(auth.role(), '') <> 'service_role' and p_user is distinct from v_user then
    raise exception 'not authorized';
  end if;
  if p_method not in ('yape', 'plin') then raise exception 'invalid payment method'; end if;

  select * into v_event from public.events where id = p_event for update;
  if not found or v_event.estado <> 'publicado' then raise exception 'event unavailable'; end if;
  if v_event.precio <= 0 then raise exception 'event is free'; end if;
  if v_event.fin <= now() then raise exception 'event ended'; end if;
  if v_event.precio < 6 or v_event.precio > 500 then
    raise exception 'Culqi wallet amount must be between S/ 6 and S/ 500';
  end if;
  if exists (select 1 from public.event_registrations r
             where r.event_id = p_event and r.user_id = v_user and r.estado = 'confirmada') then
    raise exception 'already registered';
  end if;

  select count(*) into v_count from public.event_registrations r
    where r.event_id = p_event
      and r.estado in ('confirmada', 'pendiente_pago')
      and r.user_id <> v_user;
  if v_count >= v_event.capacidad then raise exception 'event sold out'; end if;

  select p.id into v_existing_payment from public.event_payments p
    where p.event_id = p_event and p.user_id = v_user
      and p.provider_status in ('creating', 'pending')
    order by p.created_at desc limit 1;
  if v_existing_payment is not null then
    select * into v_profile from public.profiles where id = v_user;
    v_name := nullif(btrim(coalesce(v_profile.nombre, '')), '');
    if (select p.provider_status from public.event_payments p where p.id = v_existing_payment) = 'creating' then
      v_existing_payment := null;
    end if;
  end if;
  if v_existing_payment is not null then
    return query select v_existing_payment, v_event.titulo, v_event.precio,
      (select p.provider_status from public.event_payments p where p.id = v_existing_payment),
      (select p.provider_order_id from public.event_payments p where p.id = v_existing_payment),
      (select p.checkout_url from public.event_payments p where p.id = v_existing_payment),
      coalesce(auth.jwt() ->> 'email', ''), coalesce(v_name, 'Participante'),
      now() + interval '30 minutes';
    return;
  end if;

  select * into v_profile from public.profiles where id = v_user;
  v_name := nullif(btrim(coalesce(v_profile.nombre, '')), '');
  insert into public.event_payments(event_id, user_id, payment_method, amount)
    values (p_event, v_user, p_method, v_event.precio)
    returning id into v_payment;

  insert into public.event_registrations as er(event_id, user_id, estado, metodo_pago)
    values (p_event, v_user, 'pendiente_pago', p_method)
    on conflict (event_id, user_id) do update
      set estado = 'pendiente_pago', metodo_pago = excluded.metodo_pago,
          pago_referencia = null, pagado_at = null, updated_at = now()
      where er.estado = 'cancelada' or er.estado = 'pendiente_pago';

  return query select v_payment, v_event.titulo, v_event.precio, 'creating'::text, null::text, null::text,
    coalesce(auth.jwt() ->> 'email', ''), coalesce(v_name, 'Participante'), now() + interval '30 minutes';
end;
$$;

revoke all on function public.start_event_payment(uuid, text, uuid) from public, anon;
grant execute on function public.start_event_payment(uuid, text, uuid) to authenticated;
grant execute on function public.start_event_payment(uuid, text, uuid) to service_role;

create or replace function public.attach_event_payment_order(
  p_payment uuid,
  p_order text,
  p_checkout text
) returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'not authorized'; end if;
  update public.event_payments set provider_order_id = p_order,
    checkout_url = p_checkout, provider_status = 'pending', updated_at = now()
  where id = p_payment and provider_status = 'creating'
    and not exists (
      select 1 from public.event_payments newer
      where newer.event_id = event_payments.event_id and newer.user_id = event_payments.user_id
        and newer.provider_status = 'pending' and newer.created_at > event_payments.created_at
    );
  if not found then raise exception 'payment not found or already initialized'; end if;
end;
$$;
revoke all on function public.attach_event_payment_order(uuid, text, text) from public, anon, authenticated;
grant execute on function public.attach_event_payment_order(uuid, text, text) to service_role;

create or replace function public.cancel_event_payment_creation(p_payment uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.event_payments%rowtype;
  v_has_another_pending boolean;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'not authorized'; end if;
  select * into v_payment from public.event_payments where id = p_payment for update;
  if not found then return; end if;
  update public.event_payments set provider_status = 'failed', updated_at = now()
    where id = p_payment and provider_status = 'creating';
  select exists (
    select 1 from public.event_payments p
    where p.event_id = v_payment.event_id and p.user_id = v_payment.user_id
      and p.provider_status in ('creating', 'pending') and p.id <> p_payment
      and p.created_at > v_payment.created_at
  ) into v_has_another_pending;
  if not v_has_another_pending then
    update public.event_registrations set estado = 'cancelada', updated_at = now()
      where event_id = v_payment.event_id and user_id = v_payment.user_id
        and estado = 'pendiente_pago';
  end if;
end;
$$;
revoke all on function public.cancel_event_payment_creation(uuid) from public, anon, authenticated;
grant execute on function public.cancel_event_payment_creation(uuid) to service_role;

create or replace function public.expire_event_payment(p_payment uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.event_payments%rowtype;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'not authorized'; end if;
  select * into v_payment from public.event_payments where id = p_payment for update;
  if not found then return; end if;
  update public.event_payments set provider_status = 'expired', updated_at = now()
    where id = p_payment and provider_status = 'pending';
  if not found then return; end if;
  if not exists (
    select 1 from public.event_payments p
    where p.event_id = v_payment.event_id and p.user_id = v_payment.user_id
      and p.provider_status in ('creating', 'pending') and p.id <> p_payment
  ) then
    update public.event_registrations set estado = 'cancelada', updated_at = now()
    where event_id = v_payment.event_id and user_id = v_payment.user_id
      and estado = 'pendiente_pago';
  end if;
end;
$$;
revoke all on function public.expire_event_payment(uuid) from public, anon, authenticated;
grant execute on function public.expire_event_payment(uuid) to service_role;

create or replace function public.finish_event_payment(
  p_order text,
  p_paid boolean
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment public.event_payments%rowtype;
  v_result text;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'not authorized'; end if;
  select * into v_payment from public.event_payments
    where provider_order_id = p_order for update;
  if not found then return 'payment_not_found'; end if;
  if v_payment.provider_status = 'paid' then return 'already_paid'; end if;
  if not p_paid then
    update public.event_payments set provider_status = 'expired', updated_at = now()
      where id = v_payment.id;
    if not exists (
      select 1 from public.event_payments p
      where p.event_id = v_payment.event_id and p.user_id = v_payment.user_id
        and p.provider_status in ('creating', 'pending') and p.id <> v_payment.id
        and p.created_at > v_payment.created_at
    ) then
      update public.event_registrations set estado = 'cancelada', updated_at = now()
        where event_id = v_payment.event_id and user_id = v_payment.user_id
          and estado = 'pendiente_pago';
    end if;
    return 'expired';
  end if;

  update public.event_payments set provider_status = 'paid', paid_at = now(), updated_at = now()
    where id = v_payment.id;
  select public.confirm_event_payment(
    v_payment.event_id, v_payment.user_id, v_payment.payment_method, p_order
  ) into v_result;
  if v_result = 'confirmada' or v_result = 'ya_inscrita' then
    update public.event_payments set provider_status = 'expired', updated_at = now()
      where event_id = v_payment.event_id and user_id = v_payment.user_id
        and id <> v_payment.id and provider_status in ('creating', 'pending');
  end if;
  if v_result <> 'confirmada' and v_result <> 'ya_inscrita' then
    raise exception 'paid order could not confirm registration: %', v_result;
  end if;
  return v_result;
end;
$$;
revoke all on function public.finish_event_payment(text, boolean) from public, anon, authenticated;
grant execute on function public.finish_event_payment(text, boolean) to service_role;
