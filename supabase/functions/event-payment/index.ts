import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })

const supabaseUrl = Deno.env.get('SUPABASE_URL')!
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const culqiSecret = Deno.env.get('CULQI_SECRET_KEY')
const admin = createClient(supabaseUrl, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
})

async function authenticatedUser(request: Request) {
  const header = request.headers.get('Authorization')
  if (!header?.startsWith('Bearer ')) return null
  const client = createClient(supabaseUrl, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: header } },
    auth: { autoRefreshToken: false, persistSession: false },
  })
  const { data, error } = await client.auth.getUser()
  return error ? null : data.user
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  const path = new URL(request.url).pathname
  if (path.endsWith('/checkout')) {
    if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405)
    const checkoutHtml = await Deno.readTextFile(new URL('./checkout.html', import.meta.url))
    const paymentQuery = new URL(request.url).searchParams
    const orderId = paymentQuery.get('order') ?? ''
    if (!orderId.startsWith('ord_')) return json({ error: 'invalid_order' }, 400)
    const { data: payment } = await admin.from('event_payments')
      .select('amount,currency,provider_status,event_id')
      .eq('provider_order_id', orderId)
      .maybeSingle()
    if (!payment || payment.provider_status === 'expired' || payment.provider_status === 'failed') {
      return json({ error: 'payment_not_available' }, 404)
    }
    const { data: event } = await admin.from('events')
      .select('titulo')
      .eq('id', payment.event_id)
      .maybeSingle()
    const html = checkoutHtml
      .replaceAll('__ORDER_ID__', orderId)
      .replaceAll('__PUBLIC_KEY__', Deno.env.get('CULQI_PUBLIC_KEY') ?? '')
      .replaceAll('__AMOUNT__', String(Math.round(Number(payment.amount) * 100)))
      .replaceAll('__TITLE__', JSON.stringify(`Aliada · ${event?.titulo ?? 'Entrada a evento'}`))
      .replaceAll('__ANON_KEY__', JSON.stringify(Deno.env.get('SUPABASE_ANON_KEY') ?? ''))
    return new Response(html, { headers: { ...corsHeaders, 'Content-Type': 'text/html; charset=utf-8' } })
  }
  if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

  let body: Record<string, unknown>
  try {
    body = await request.json()
  } catch {
    return json({ error: 'invalid_json' }, 400)
  }

  const configuredWebhookAuth = Deno.env.get('CULQI_WEBHOOK_AUTH')
  const authorization = request.headers.get('Authorization') ?? ''
  const basicToken = btoa(configuredWebhookAuth ?? '')
  const isCulqiWebhook = Boolean(configuredWebhookAuth) && authorization === `Basic ${basicToken}`
  if (isCulqiWebhook) {
    if (!culqiSecret) return json({ error: 'payment_not_configured' }, 503)

    const event = body.data && typeof body.data === 'object'
      ? (body.data as Record<string, unknown>)
      : {}
    const orderId = String(event.id ?? body.id ?? '')
    if (!orderId.startsWith('ord_')) return json({ error: 'invalid_order' }, 400)

    // No confiar en el texto del webhook: consultar la orden en Culqi y usar
    // su estado/currency/amount autoritativos antes de confirmar la inscripción.
    const providerResponse = await fetch(`https://api.culqi.com/v2/orders/${encodeURIComponent(orderId)}`, {
      headers: { Authorization: `Bearer ${culqiSecret}` },
    })
    if (!providerResponse.ok) return json({ error: 'could_not_verify_order' }, 502)
    const order = await providerResponse.json()
    const { data: payment, error: findError } = await admin
      .from('event_payments')
      .select('amount,currency')
      .eq('provider_order_id', orderId)
      .maybeSingle()
    if (findError || !payment) return json({ error: 'payment_not_found' }, 404)

    const amountMatches = Number(order.amount) === Math.round(Number(payment.amount) * 100)
    const currencyMatches = order.currency_code === payment.currency
    const isPaid = order.state === 'paid' && amountMatches && currencyMatches
    if (order.state === 'paid' && !isPaid) {
      return json({ error: 'paid_order_mismatch' }, 409)
    }
    if (!isPaid) {
      const { data: pendingPayment, error: pendingLookupError } = await admin.from('event_payments')
        .select('id')
        .eq('provider_order_id', orderId)
        .maybeSingle()
      if (pendingLookupError) return json({ error: 'could_not_find_payment' }, 500)
      if (pendingPayment) {
        const expiresAt = Number(order.expiration_date)
        const expiryMs = expiresAt > 1_000_000_000_000 ? expiresAt : expiresAt * 1000
        if (order.state !== 'pending' || expiryMs <= Date.now()) {
          const { error: expirationError } = await admin.rpc('expire_event_payment', { p_payment: pendingPayment.id })
          if (expirationError) return json({ error: 'could_not_expire_payment' }, 500)
          return json({ received: true, result: 'expired' })
        }
      }
    }
    const { data: result, error } = await admin.rpc('finish_event_payment', {
      p_order: orderId,
      p_paid: isPaid,
    })
    if (error) return json({ error: 'could_not_finish_payment' }, 500)
    return json({ received: true, result })
  }

  if (body.action === 'public-payment-status') {
    const orderId = typeof body.order_id === 'string' ? body.order_id : ''
    if (!orderId.startsWith('ord_')) return json({ error: 'invalid_order' }, 400)
    const { data: payment, error } = await admin
      .from('event_payments')
      .select('id,provider_status,created_at')
      .eq('provider_order_id', orderId)
      .maybeSingle()
    if (error || !payment) return json({ error: 'payment_not_found' }, 404)
    const status = await normalizedPaymentStatus(payment)
    return json({ status })
  }

  const user = await authenticatedUser(request)
  if (!user) return json({ error: 'unauthorized' }, 401)

  if (body.action === 'payment-status') {
    const orderId = typeof body.order_id === 'string' ? body.order_id : ''
    if (!orderId.startsWith('ord_')) return json({ error: 'invalid_order' }, 400)
    const { data: payment, error } = await admin
      .from('event_payments')
      .select('id,provider_status,created_at')
      .eq('provider_order_id', orderId)
      .eq('user_id', user.id)
      .maybeSingle()
    if (error) return json({ error: 'database_error' }, 500)
    if (!payment) return json({ error: 'payment_not_found' }, 404)
    return json({ status: await normalizedPaymentStatus(payment) })
  }

  if (body.action !== 'create-order') return json({ error: 'invalid_action' }, 400)
  if (!culqiSecret || !Deno.env.get('CULQI_PUBLIC_KEY')) {
    return json({ error: 'CULQI_TEST_KEYS_missing' }, 503)
  }

  const eventId = typeof body.event_id === 'string' ? body.event_id : ''
  const paymentMethod = body.payment_method === 'plin' ? 'plin' : body.payment_method === 'yape' ? 'yape' : ''
  if (!eventId || !paymentMethod) return json({ error: 'invalid_payment_request' }, 400)
  const payerEmail = typeof body.payer_email === 'string' ? body.payer_email.trim().toLowerCase() : ''
  const payerPhone = typeof body.payer_phone === 'string' ? body.payer_phone.trim() : ''
  const phoneDigits = payerPhone.replace(/\D/g, '')
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(payerEmail)) {
    return json({ error: 'invalid_email', message: 'Escribe un correo electrónico válido.' }, 400)
  }
  const validPeruvianPhone = phoneDigits.length === 9 || (phoneDigits.length === 11 && phoneDigits.startsWith('51'))
  if (!validPeruvianPhone) {
    return json({ error: 'invalid_phone', message: 'Escribe un celular peruano válido.' }, 400)
  }
  const culqiPhone = phoneDigits.startsWith('51') ? `+${phoneDigits}` : `+51${phoneDigits}`

  const { data: rows, error: startError } = await admin.rpc('start_event_payment', {
    p_event: eventId,
    p_method: paymentMethod,
    p_user: user.id,
  })
  if (startError || !Array.isArray(rows) || rows.length !== 1) {
    const detail = startError?.message ?? ''
    const isWalletAmountError = detail.includes('between S/ 6 and S/ 500')
    return json({
      error: isWalletAmountError ? 'unsupported_wallet_amount' : 'could_not_start_payment',
      message: isWalletAmountError
        ? 'Culqi acepta pagos con billetera móvil entre S/ 6 y S/ 500.'
        : 'No pudimos iniciar el pago. Revisa que el evento siga publicado y tenga cupos.',
    }, 400)
  }

  const payment = rows[0]
  if (payment.payment_state === 'pending' && payment.order_id && payment.saved_checkout) {
    return json({
      order_id: payment.order_id,
      checkout_url: payment.saved_checkout,
      expires_at: payment.user_expiry,
    })
  }
  const expiration = Math.floor(new Date(payment.user_expiry).getTime() / 1000)
  const orderPayload = {
    amount: Math.round(Number(payment.event_amount) * 100),
    currency_code: 'PEN',
    description: `Entrada: ${payment.event_title}`.slice(0, 80),
    order_number: `AL-${String(payment.payment_id).replaceAll('-', '').slice(0, 24)}`,
    client_details: {
      first_name: payment.user_name || 'Participante',
      last_name: 'Aliada',
      email: payerEmail,
      phone_number: culqiPhone,
    },
    expiration_date: expiration,
    metadata: {
      payment_id: payment.payment_id,
      event_id: eventId,
      user_id: user.id,
      selected_wallet: paymentMethod,
    },
  }

  let culqiResponse: Response
  let order: Record<string, unknown>
  try {
    culqiResponse = await fetch('https://api.culqi.com/v2/orders', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${culqiSecret}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(orderPayload),
    })
    order = await culqiResponse.json().catch(() => ({}))
  } catch (_) {
    await admin.rpc('cancel_event_payment_creation', { p_payment: payment.payment_id })
    return json({ error: 'culqi_unreachable', message: 'No pudimos conectar con Culqi. Inténtalo nuevamente.' }, 502)
  }
  if (!culqiResponse.ok || typeof order.id !== 'string') {
    await admin.rpc('cancel_event_payment_creation', { p_payment: payment.payment_id })
    return json({ error: 'culqi_order_failed', details: order.user_message ?? order.merchant_message }, 502)
  }

  if (order.state === 'created') {
    const confirmResponse = await fetch(`https://api.culqi.com/v2/orders/${encodeURIComponent(order.id)}/confirm`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${Deno.env.get('CULQI_PUBLIC_KEY') ?? ''}`,
        'Content-Type': 'application/json',
      },
    })
    if (!confirmResponse.ok) {
      await admin.rpc('cancel_event_payment_creation', { p_payment: payment.payment_id })
      return json({ error: 'culqi_order_confirmation_failed' }, 502)
    }
  }

  // El Checkout seguro usa la llave pública y el ID de orden; la llave secreta
  // se mantiene en Supabase. La pantalla habilita las billeteras móviles.
  const checkoutUrl = `${supabaseUrl}/functions/v1/event-payment/checkout?order=${encodeURIComponent(order.id)}`
  const { error: attachError } = await admin.rpc('attach_event_payment_order', {
    p_payment: payment.payment_id,
    p_order: order.id,
    p_checkout: checkoutUrl,
  })
  if (attachError) return json({ error: 'could_not_save_order' }, 500)

  return json({ order_id: order.id, checkout_url: checkoutUrl, expires_at: expiration })
})

async function normalizedPaymentStatus(payment: {
  id: string
  provider_status: string
  created_at: string
}): Promise<'pending' | 'paid' | 'expired'> {
  if (payment.provider_status === 'paid') return 'paid'
  if (payment.provider_status === 'expired' || payment.provider_status === 'failed') return 'expired'
  const hasExpired = Date.now() - new Date(payment.created_at).getTime() >= 30 * 60 * 1000
  if (!hasExpired) return 'pending'
  if (payment.provider_status === 'pending') {
    await admin.rpc('expire_event_payment', { p_payment: payment.id })
  } else if (payment.provider_status === 'creating') {
    await admin.rpc('cancel_event_payment_creation', { p_payment: payment.id })
  }
  return 'expired'
}
