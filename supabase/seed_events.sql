-- Aliada · Seis eventos de ejemplo para la cartelera Edúcate.
-- Se puede volver a ejecutar: actualiza la feria inicial y agrega solo títulos faltantes.
-- Horas indicadas en hora local de Lima (UTC-05:00).

update public.events
set descripcion = 'Feria universitaria con stands de bienestar, orientación psicológica, salud y recursos para estudiantes.',
    imagen_url = null,
    categoria = 'Bienestar',
    organizador = 'Bienestar Universitario',
    inicio = '2026-11-10 10:00:00-05'::timestamptz,
    fin = '2026-11-10 17:00:00-05'::timestamptz,
    lugar = 'Explanada Central',
    direccion = 'Campus Central, Lima',
    modalidad = 'presencial',
    precio = 0,
    capacidad = 150,
    estado = 'publicado',
    lat = -12.0689,
    lng = -77.0790
where titulo = 'Feria de Bienestar Universitario';

insert into public.events (
  titulo, descripcion, imagen_url, categoria, organizador,
  inicio, fin, lugar, direccion, modalidad, precio, capacidad,
  estado, lat, lng
)
select
  event_data.titulo,
  event_data.descripcion,
  event_data.imagen_url,
  event_data.categoria,
  event_data.organizador,
  event_data.inicio,
  event_data.fin,
  event_data.lugar,
  event_data.direccion,
  event_data.modalidad,
  event_data.precio,
  event_data.capacidad,
  event_data.estado,
  event_data.lat,
  event_data.lng
from (values
  (
    'Taller de Autodefensa Básica',
    'Práctica guiada de seguridad personal, límites y técnicas básicas de defensa.',
    null::text,
    'Seguridad',
    'Aliada',
    '2026-11-14 10:00:00-05'::timestamptz,
    '2026-11-14 12:00:00-05'::timestamptz,
    'Gimnasio Universitario',
    'Campus Central, Lima',
    'presencial',
    25::numeric,
    40,
    'publicado',
    -12.0689::double precision,
    -77.0790::double precision
  ),
  (
    'Círculo de Bienestar Emocional',
    'Espacio de conversación y herramientas prácticas para cuidar la salud emocional durante el ciclo.',
    null::text,
    'Bienestar',
    'Bienestar Universitario',
    '2026-11-17 18:00:00-05'::timestamptz,
    '2026-11-17 19:30:00-05'::timestamptz,
    'Sala de Bienestar',
    'Campus Central, Lima',
    'presencial',
    0::numeric,
    30,
    'publicado',
    -12.0689::double precision,
    -77.0790::double precision
  ),
  (
    'Taller de Liderazgo para Mujeres',
    'Taller participativo sobre liderazgo, comunicación y redes de apoyo entre estudiantes.',
    null::text,
    'Liderazgo',
    'Aliada',
    '2026-11-21 09:00:00-05'::timestamptz,
    '2026-11-21 12:00:00-05'::timestamptz,
    'Auditorio Central',
    'Campus Central, Lima',
    'presencial',
    35::numeric,
    60,
    'publicado',
    -12.0689::double precision,
    -77.0790::double precision
  ),
  (
    'Conversatorio Mujeres en Ciencia y Tecnología',
    'Investigadoras y egresadas comparten sus experiencias y responden preguntas de las estudiantes.',
    null::text,
    'Comunidad',
    'Bienestar Universitario',
    '2026-11-25 17:00:00-05'::timestamptz,
    '2026-11-25 19:00:00-05'::timestamptz,
    'Auditorio Central',
    'Campus Central, Lima',
    'presencial',
    0::numeric,
    100,
    'publicado',
    -12.0689::double precision,
    -77.0790::double precision
  ),
  (
    'Yoga y Mindfulness para Estudiantes',
    'Sesión introductoria de respiración, movilidad suave y atención plena. No se necesita experiencia.',
    null::text,
    'Bienestar',
    'Aliada',
    '2026-11-29 09:00:00-05'::timestamptz,
    '2026-11-29 10:30:00-05'::timestamptz,
    'Jardín Central',
    'Campus Central, Lima',
    'presencial',
    15::numeric,
    35,
    'publicado',
    -12.0689::double precision,
    -77.0790::double precision
  )
) as event_data(
  titulo, descripcion, imagen_url, categoria, organizador,
  inicio, fin, lugar, direccion, modalidad, precio, capacidad,
  estado, lat, lng
)
where not exists (
  select 1 from public.events existing where existing.titulo = event_data.titulo
);
