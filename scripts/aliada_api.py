"""Cliente mínimo de la API real de Aliada (Supabase) para pruebas y para simular un segundo teléfono.

Usa exactamente los mismos endpoints que la app: register_device → login → tablas/RPC con RLS.
"""
import json, os, secrets, ssl, time, urllib.request, urllib.error

CFG = json.load(open(os.path.join(os.path.dirname(__file__), '..', 'supabase.json')))
URL = CFG['SUPABASE_URL']
KEY = CFG['SUPABASE_ANON_KEY']
_CTX = ssl.create_default_context(cafile='/etc/ssl/cert.pem') if os.path.exists('/etc/ssl/cert.pem') else None


def _req(method, path, body=None, token=None, headers=None):
    h = {'apikey': KEY, 'Content-Type': 'application/json'}
    if token:
        h['Authorization'] = f'Bearer {token}'
    h.update(headers or {})
    data = None if body is None else json.dumps(body).encode()
    r = urllib.request.Request(URL + path, data=data, method=method, headers=h)
    try:
        with urllib.request.urlopen(r, timeout=30, context=_CTX) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raise RuntimeError(f'{method} {path} -> {e.code}: {e.read().decode()[:300]}')


class Phone:
    """Un 'teléfono' con su propia cuenta de dispositivo."""

    def __init__(self, nombre, device=None, secret=None):
        alphabet = 'abcdefghjkmnpqrstuvwxyz23456789'
        self.nombre = nombre
        self.device = device or ''.join(secrets.choice(alphabet) for _ in range(12))
        self.secret = secret or secrets.token_urlsafe(32)
        email = _req('POST', '/rest/v1/rpc/register_device', {'p_device': self.device, 'p_secret': self.secret})
        s = _req('POST', '/auth/v1/token?grant_type=password', {'email': email, 'password': self.secret})
        self.token = s['access_token']
        self.uid = s['user']['id']
        self.upsert('profiles', {'id': self.uid, 'nombre': nombre, 'disponible': True})

    def rpc(self, fn, params=None):
        return _req('POST', f'/rest/v1/rpc/{fn}', params or {}, self.token)

    def select(self, table, query=''):
        return _req('GET', f'/rest/v1/{table}?{query}', token=self.token)

    def insert(self, table, row):
        return _req('POST', f'/rest/v1/{table}', row, self.token, {'Prefer': 'return=representation'})

    def upsert(self, table, row):
        return _req('POST', f'/rest/v1/{table}', row, self.token,
                    {'Prefer': 'resolution=merge-duplicates,return=representation'})

    def update(self, table, query, row):
        return _req('PATCH', f'/rest/v1/{table}?{query}', row, self.token, {'Prefer': 'return=representation'})

    def lumai(self, messages, timeout=60):
        rid = self.rpc('lumai_ask', {'p_messages': messages})
        t0 = time.time()
        while time.time() - t0 < timeout:
            r = self.rpc('lumai_result', {'p_id': rid})
            if not r.get('pending'):
                return r, time.time() - t0
            time.sleep(0.8)
        raise TimeoutError('LumAI no respondió')
