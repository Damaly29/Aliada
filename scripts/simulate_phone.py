"""Simula un SEGUNDO TELÉFONO real contra Supabase (misma API y reglas RLS que la app).

Uso:
  python3 scripts/simulate_phone.py pedir-ayuda --lat -12.0689 --lng -77.0790 [--nivel emergency|companion]
      Crea una alerta ~200 m al norte del punto. Los teléfonos con "Disponible" cerca deben sonar/vibrar.
      Muestra en consola quién acude y sus mensajes. Ctrl+C marca "a salvo".

  python3 scripts/simulate_phone.py acudir --lat -12.0689 --lng -77.0790
      Se registra como aliada disponible a ~400 m, espera una alerta cercana, acepta,
      camina hacia ella cada 2 s (el servidor marca "llegó" a ≤ 30 m) y envía un mensaje.
"""
import argparse, math, os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from aliada_api import Phone


def offset(lat, lng, meters, bearing_deg):
    r = 6371000.0
    b = math.radians(bearing_deg)
    la1, lo1 = math.radians(lat), math.radians(lng)
    la2 = math.asin(math.sin(la1) * math.cos(meters / r) + math.cos(la1) * math.sin(meters / r) * math.cos(b))
    lo2 = lo1 + math.atan2(math.sin(b) * math.sin(meters / r) * math.cos(la1), math.cos(meters / r) - math.sin(la1) * math.sin(la2))
    return math.degrees(la2), math.degrees(lo2)


def dist(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (*a, *b))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * 6371000 * math.asin(math.sqrt(h))


def pedir_ayuda(a):
    phone = Phone(a.nombre or 'María (simulada)')
    lat, lng = offset(a.lat, a.lng, 200, 0)
    alert = phone.insert('alerts', {'nombre': phone.nombre, 'level': a.nivel, 'lat': lat, 'lng': lng})[0]
    print(f'[víctima] alerta {alert["id"]} creada ({a.nivel}) en {lat:.5f},{lng:.5f}')
    seen, msgs = {}, set()
    try:
        t0 = time.time()
        while time.time() - t0 < a.segundos:
            phone.rpc('push_alert_location', {'p_alert': alert['id'], 'p_lat': lat, 'p_lng': lng})
            for r in phone.select('alert_responders', f'alert_id=eq.{alert["id"]}&select=*'):
                key = (r['responder_id'], r['status'])
                if seen.get(r['responder_id']) != r['status']:
                    seen[r['responder_id']] = r['status']
                    print(f'[víctima] {r["nombre"]} → {r["status"]}  ({r.get("lat")}, {r.get("lng")})')
            for m in phone.select('alert_messages', f'alert_id=eq.{alert["id"]}&select=*&order=created_at'):
                if m['id'] not in msgs and m['sender_id'] != phone.uid:
                    msgs.add(m['id'])
                    print(f'[víctima] mensaje de {m["nombre"]}: {m["body"]}')
            time.sleep(3)
    except KeyboardInterrupt:
        pass
    phone.update('alerts', f'id=eq.{alert["id"]}', {'status': 'safe', 'closed_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())})
    print('[víctima] alerta cerrada: a salvo')


def acudir(a):
    phone = Phone(a.nombre or 'Julia (simulada)')
    me = offset(a.lat, a.lng, 400, 135)
    phone.rpc('upsert_presence', {'p_lat': me[0], 'p_lng': me[1]})
    print(f'[aliada] disponible en {me[0]:.5f},{me[1]:.5f}; esperando alertas cercanas…')
    alert, t0 = None, time.time()
    while not alert and time.time() - t0 < a.segundos:
        rows = phone.select('alerts', 'status=eq.active&select=*&order=created_at.desc')
        alert = rows[0] if rows else None
        if not alert:
            phone.rpc('upsert_presence', {'p_lat': me[0], 'p_lng': me[1]})
            time.sleep(1.5)
    if not alert:
        print('[aliada] no llegó ninguna alerta cercana'); return
    target = (alert['lat'], alert['lng'])
    print(f'[aliada] ALERTA de {alert["nombre"]} a {dist(me, target):.0f} m → acepto')
    phone.upsert('alert_responders', {'alert_id': alert['id'], 'nombre': phone.nombre, 'status': 'en_camino', 'lat': me[0], 'lng': me[1]})
    phone.insert('alert_messages', {'alert_id': alert['id'], 'nombre': phone.nombre, 'body': 'Voy en camino, ¿dónde estás exactamente?'})
    while True:
        rows = phone.select('alerts', f'id=eq.{alert["id"]}&select=status,lat,lng')
        if not rows or rows[0]['status'] != 'active':
            print('[aliada] la alerta se cerró'); break
        target = (rows[0]['lat'], rows[0]['lng'])
        d = dist(me, target)
        if d > 25:
            b = math.degrees(math.atan2(math.radians(target[1] - me[1]) * math.cos(math.radians(me[0])), math.radians(target[0] - me[0])))
            me = offset(me[0], me[1], min(25, d - 10), b)
        phone.rpc('push_responder_location', {'p_alert': alert['id'], 'p_lat': me[0], 'p_lng': me[1]})
        st = phone.select('alert_responders', f'alert_id=eq.{alert["id"]}&responder_id=eq.{phone.uid}&select=status,eta_s')[0]
        print(f'[aliada] a {dist(me, target):.0f} m · estado={st["status"]} eta={st["eta_s"]}s')
        if st['status'] == 'llego':
            phone.insert('alert_messages', {'alert_id': alert['id'], 'nombre': phone.nombre, 'body': 'Ya llegué, estoy contigo 💜'})
            print('[aliada] llegó'); break
        time.sleep(2)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('modo', choices=['pedir-ayuda', 'acudir'])
    ap.add_argument('--lat', type=float, required=True)
    ap.add_argument('--lng', type=float, required=True)
    ap.add_argument('--nivel', default='emergency', choices=['emergency', 'companion'])
    ap.add_argument('--nombre')
    ap.add_argument('--segundos', type=int, default=120)
    a = ap.parse_args()
    pedir_ayuda(a) if a.modo == 'pedir-ayuda' else acudir(a)
