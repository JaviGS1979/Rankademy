-- Rankademy · Fase 6a · Biblioteca de ejercicios
-- Se ejecuta después de 0001-0006.
--
-- Un ejercicio se dibuja sobre la pista (una o varias imágenes) con elementos
-- sencillos: jugadores, pelotas, conos y trayectos. Guardarlo como datos (y no
-- como una imagen) permite compararlo con los de la biblioteca para detectar
-- duplicados, también en espejo.
--
-- Todas las escrituras de ejercicios, imágenes y usos pasan a hacerse con
-- funciones, que comprueban quién llama y mantienen el anonimato de la
-- biblioteca.

-- ============================================================
-- 1. Validación del dibujo
-- ============================================================
-- Pista: viewBox 240 × 140.
--   {"t":"jugador"|"pelota"|"cono", "x":30, "y":100}
--   {"t":"trayecto", "de":[38,98], "a":[200,44], "c":[120,60]?, "tipo":"bola"|"carrera"?}
create function privado.punto_valido(p jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
begin
  if p is null or jsonb_typeof(p) <> 'array' then return false; end if;
  if jsonb_array_length(p) <> 2 then return false; end if;
  if jsonb_typeof(p -> 0) <> 'number' or jsonb_typeof(p -> 1) <> 'number' then return false; end if;
  return (p ->> 0)::numeric between 0 and 240 and (p ->> 1)::numeric between 0 and 140;
end;
$$;

create function privado.elemento_valido(el jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare
  v_claves text[];
begin
  if el is null or jsonb_typeof(el) <> 'object' then return false; end if;
  select array_agg(k) into v_claves from jsonb_object_keys(el) k;
  if el ->> 't' in ('jugador', 'pelota', 'cono') then
    if not v_claves <@ array['t', 'x', 'y'] then return false; end if;
    return privado.punto_valido(jsonb_build_array(el -> 'x', el -> 'y'));
  elsif el ->> 't' = 'trayecto' then
    if not v_claves <@ array['t', 'de', 'a', 'c', 'tipo'] then return false; end if;
    if not (privado.punto_valido(el -> 'de') and privado.punto_valido(el -> 'a')) then return false; end if;
    if el ? 'c' and not privado.punto_valido(el -> 'c') then return false; end if;
    if el ? 'tipo' and coalesce(el ->> 'tipo', '') not in ('bola', 'carrera') then return false; end if;
    return true;
  end if;
  return false;
end;
$$;

-- Una imagen: entre 1 y 40 elementos válidos
create function privado.dibujo_valido(d jsonb)
returns boolean language plpgsql immutable set search_path = '' as $$
declare
  el jsonb;
begin
  if d is null or jsonb_typeof(d) <> 'array' then return false; end if;
  if jsonb_array_length(d) not between 1 and 40 then return false; end if;
  for el in select jsonb_array_elements(d) loop
    if not privado.elemento_valido(el) then return false; end if;
  end loop;
  return true;
end;
$$;

-- Hasta 3 pasos, cada uno con texto (máx. 60 caracteres)
create function privado.pasos_validos(p text[])
returns boolean language sql immutable set search_path = '' as $$
  select coalesce(cardinality(p), 0) <= 3
     and not exists (select 1 from unnest(p) x where x is null or length(btrim(x)) = 0 or length(x) > 60);
$$;

-- ============================================================
-- 2. Huella del dibujo y parecido
-- ============================================================
-- La pista se divide en 6 × 4 casillas. La huella cuenta, por casilla, los
-- jugadores, el material (pelotas y conos) y los extremos de los trayectos:
-- 3 × 24 = 72 números. espejo: 0 tal cual, 1 izquierda-derecha, 2 arriba-abajo, 3 ambos.
create function privado.huella_imagen(d jsonb, espejo integer)
returns integer[] language plpgsql immutable set search_path = '' as $$
declare
  h integer[] := array_fill(0, array[72]);
  el jsonb;
  p jsonb;
  tipo integer;
  x numeric;
  y numeric;
  i integer;
begin
  for el in select jsonb_array_elements(d) loop
    tipo := case el ->> 't' when 'jugador' then 0 when 'trayecto' then 2 else 1 end;
    for p in
      select q from (values
        (case when el ->> 't' = 'trayecto' then el -> 'de' else jsonb_build_array(el -> 'x', el -> 'y') end),
        (case when el ->> 't' = 'trayecto' then el -> 'a' end)
      ) v(q) where q is not null
    loop
      x := (p ->> 0)::numeric;
      y := (p ->> 1)::numeric;
      if espejo in (1, 3) then x := 240 - x; end if;
      if espejo in (2, 3) then y := 140 - y; end if;
      i := 1 + tipo * 24 + least(3, floor(y / 35))::integer * 6 + least(5, floor(x / 40))::integer;
      h[i] := h[i] + 1;
    end loop;
  end loop;
  return h;
end;
$$;

-- Huella de un ejercicio: suma de sus imágenes (array de dibujos)
create function privado.huella_imagenes(imgs jsonb, espejo integer)
returns integer[] language plpgsql immutable set search_path = '' as $$
declare
  h integer[] := array_fill(0, array[72]);
  hi integer[];
  d jsonb;
begin
  for d in select jsonb_array_elements(imgs) loop
    hi := privado.huella_imagen(d, espejo);
    for i in 1..72 loop
      h[i] := h[i] + hi[i];
    end loop;
  end loop;
  return h;
end;
$$;

-- 1 = mismo dibujo, 0 = nada en común
create function privado.similitud(a integer[], b integer[])
returns numeric language sql immutable set search_path = '' as $$
  select case when coalesce(sum(x + y), 0) = 0 then 0
              else 1 - sum(abs(x - y))::numeric / sum(x + y) end
  from unnest(a, b) as u(x, y);
$$;

-- Coincidencia de dos rangos (jugadores o edad): intersección / unión
create function privado.similitud_rango(a1 integer, a2 integer, b1 integer, b2 integer)
returns numeric language sql immutable set search_path = '' as $$
  select case when a1 is null or a2 is null or b1 is null or b2 is null then 0.5
              else greatest(0, least(a2, b2) - greatest(a1, b1) + 1)::numeric
                   / (greatest(a2, b2) - least(a1, b1) + 1) end;
$$;

-- A partir de este % se avisa; a partir del otro, no se publica (salvo como variante)
create function privado.umbral_aviso() returns integer language sql immutable as $$ select 75 $$;
create function privado.umbral_duplicado() returns integer language sql immutable as $$ select 90 $$;

-- ============================================================
-- 3. Cambios en las tablas
-- ============================================================
alter table public.ejercicios
  drop column huella,
  add column huella integer[],
  add column nivel text check (nivel in ('inicio', 'medio', 'avanzado')),
  add column objetivo text check (objetivo in ('calentar', 'derecha', 'reves', 'saque', 'volea', 'pies')),
  add column espacio text check (espacio in ('pista', 'media', 'mini')),
  add column material text[] not null default '{}'
    check (material <@ array['pelotas', 'conos', 'aros', 'red']::text[]),
  add column pasos text[] not null default '{}' check (privado.pasos_validos(pasos)),
  add column retirado_at timestamptz,
  add constraint ejercicios_jugadores_rango check (jugadores_max <= 30),
  add constraint ejercicios_edad_rango check (
    (edad_min is null or edad_min between 3 and 17) and (edad_max is null or edad_max between 3 and 17));
-- Para no revelar de qué escuela es, un ejercicio público no lleva escuela
update public.ejercicios set escuela_id = null where visibilidad = 'publica';
alter table public.ejercicios add constraint ejercicios_publico_sin_escuela
  check (visibilidad = 'escuela' or escuela_id is null);

-- El dibujo pasa de SVG a elementos. (Si hubiera imágenes guardadas, esta línea
-- falla y la migración entera se deshace: no se pierde nada.)
alter table public.ejercicio_imagenes
  add column elementos jsonb not null check (privado.dibujo_valido(elementos)),
  add constraint imagenes_orden check (orden between 0 and 4);
alter table public.ejercicio_imagenes drop column dibujo;

-- Quién añadió el ejercicio a la clase (para "usado por X entrenadores" y el ranking)
alter table public.usos_ejercicio
  add column anadido_por uuid references public.personas (id) on delete set null,
  add column anadido_at timestamptz not null default now(),
  add column orden smallint not null default 0;
create index if not exists usos_anadido_por_idx on public.usos_ejercicio (anadido_por);
create index if not exists ejercicios_original_publicos_idx on public.ejercicios (visibilidad, retirado_at) where original_id is null;

-- ============================================================
-- 4. Se cierran las escrituras directas
-- ============================================================
revoke insert, update, delete on public.ejercicios from authenticated;
revoke insert, update, delete on public.ejercicio_imagenes from authenticated;
revoke insert, delete on public.usos_ejercicio from authenticated;
drop policy ejercicios_crear on public.ejercicios;
drop policy ejercicios_editar on public.ejercicios;
drop policy ejercicios_borrar on public.ejercicios;
drop policy imagenes_escribir on public.ejercicio_imagenes;
drop policy imagenes_editar on public.ejercicio_imagenes;
drop policy imagenes_borrar on public.ejercicio_imagenes;
drop policy usos_crear on public.usos_ejercicio;
drop policy usos_borrar on public.usos_ejercicio;

-- La lista anterior de la biblioteca se sustituye por biblioteca()
drop function public.biblioteca_ejercicios();

-- ============================================================
-- 5. Auxiliares
-- ============================================================
-- Número de entrenadores distintos que lo han usado en una clase no cancelada
-- (las variantes suman al original)
create function privado.usado_por(p_ejercicio uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select count(distinct u.anadido_por)::integer
  from public.usos_ejercicio u
  join public.ejercicios v on v.id = u.ejercicio_id
  join public.sesiones s on s.id = u.sesion_id
  where (v.id = p_ejercicio or v.original_id = p_ejercicio)
    and s.estado <> 'cancelada'
    and u.anadido_por is not null;
$$;

create function privado.num_variantes(p_ejercicio uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select count(*)::integer from public.ejercicios
  where original_id = p_ejercicio and visibilidad = 'publica' and retirado_at is null;
$$;

create function privado.primera_imagen(p_ejercicio uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select elementos from public.ejercicio_imagenes where ejercicio_id = p_ejercicio order by orden limit 1;
$$;

create function privado.num_imagenes(p_ejercicio uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select count(*)::integer from public.ejercicio_imagenes where ejercicio_id = p_ejercicio;
$$;

-- Ejercicios públicos (originales, no retirados) parecidos a un dibujo nuevo
create function privado.parecidos(
  p_imagenes jsonb, p_jug_min integer, p_jug_max integer, p_edad_min integer, p_edad_max integer
)
returns table (ejercicio_id uuid, parecido integer)
language sql stable security definer set search_path = '' as $$
  with nueva as (
    select m, privado.huella_imagenes(p_imagenes, m) as h from generate_series(0, 3) m
  )
  select e.id,
    round(100 * (
      0.7 * (select max(privado.similitud(n.h, e.huella)) from nueva n)
      + 0.15 * privado.similitud_rango(p_jug_min, p_jug_max, e.jugadores_min, e.jugadores_max)
      + 0.15 * privado.similitud_rango(p_edad_min, p_edad_max, e.edad_min, e.edad_max)
    ))::integer
  from public.ejercicios e
  where e.visibilidad = 'publica' and e.original_id is null and e.retirado_at is null
    and e.huella is not null;
$$;

-- ============================================================
-- 6. Publicar un ejercicio
-- ============================================================
-- p: {titulo, visibilidad ('publica'|'escuela'), escuela_id (si es de escuela),
--     jugadores_min, jugadores_max, edad_min, edad_max, nivel?, objetivo?, espacio?,
--     material: [], pasos: [], imagenes: [[elementos], …], original_id? (variante)}
create function public.publicar_ejercicio(p jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_titulo text := btrim(coalesce(p ->> 'titulo', ''));
  v_vis text := coalesce(p ->> 'visibilidad', 'publica');
  v_escuela uuid;
  v_jmin integer := (p ->> 'jugadores_min')::integer;
  v_jmax integer := (p ->> 'jugadores_max')::integer;
  v_emin integer := (p ->> 'edad_min')::integer;
  v_emax integer := (p ->> 'edad_max')::integer;
  v_imgs jsonb := p -> 'imagenes';
  v_original uuid;
  v_material text[];
  v_pasos text[];
  v_id uuid;
  o public.ejercicios;
begin
  if v_uid is null or not privado.es_staff_en_alguna() then
    raise exception 'Solo los entrenadores y directores suben ejercicios';
  end if;
  if (select count(*) from public.ejercicios
      where autor_id = v_uid and creado_at > now() - interval '1 day') >= 20 then
    raise exception 'Has subido muchos ejercicios hoy. Prueba mañana';
  end if;
  if length(v_titulo) < 2 or length(v_titulo) > 80 then
    raise exception 'El nombre debe tener entre 2 y 80 caracteres';
  end if;
  if v_vis not in ('publica', 'escuela') then
    raise exception 'Visibilidad no válida';
  end if;
  if v_vis = 'escuela' then
    v_escuela := (p ->> 'escuela_id')::uuid;
    if v_escuela is null or not privado.es_staff(v_escuela) then
      raise exception 'Elige una escuela tuya';
    end if;
  end if;
  if v_jmin is null or v_jmax is null or v_jmin < 1 or v_jmax > 30 or v_jmin > v_jmax then
    raise exception 'Jugadores: entre 1 y 30, y el mínimo no puede ser mayor que el máximo';
  end if;
  if v_emin is null or v_emax is null or v_emin < 3 or v_emax > 17 or v_emin > v_emax then
    raise exception 'Edad: entre 3 y 17 años';
  end if;
  if v_imgs is null or jsonb_typeof(v_imgs) <> 'array' or jsonb_array_length(v_imgs) not between 1 and 5 then
    raise exception 'Un ejercicio tiene entre 1 y 5 imágenes';
  end if;
  if exists (select 1 from jsonb_array_elements(v_imgs) d where not privado.dibujo_valido(d)) then
    raise exception 'El dibujo no es válido';
  end if;
  if jsonb_typeof(coalesce(p -> 'material', '[]')) <> 'array' or jsonb_typeof(coalesce(p -> 'pasos', '[]')) <> 'array' then
    raise exception 'Material y pasos van en listas';
  end if;
  select coalesce(array_agg(distinct x), '{}') into v_material
  from jsonb_array_elements_text(coalesce(p -> 'material', '[]')) x;
  select coalesce(array_agg(btrim(x) order by n), '{}') into v_pasos
  from jsonb_array_elements_text(coalesce(p -> 'pasos', '[]')) with ordinality as a(x, n)
  where length(btrim(x)) > 0;

  -- Variante: cuelga siempre del original (nunca de otra variante)
  if p ->> 'original_id' is not null then
    if v_vis <> 'publica' then
      raise exception 'Una variante se publica en la biblioteca pública';
    end if;
    select * into o from public.ejercicios
    where id = (p ->> 'original_id')::uuid and visibilidad = 'publica' and retirado_at is null;
    if not found then
      raise exception 'Ejercicio original no encontrado';
    end if;
    v_original := coalesce(o.original_id, o.id);
  elsif v_vis = 'publica' and exists (
    select 1 from privado.parecidos(v_imgs, v_jmin, v_jmax, v_emin, v_emax)
    where parecido >= privado.umbral_duplicado()
  ) then
    raise exception 'Ya existe un ejercicio muy parecido en la biblioteca: usa el existente o publica el tuyo como variante';
  end if;

  insert into public.ejercicios (
    autor_id, escuela_id, visibilidad, titulo, jugadores_min, jugadores_max, edad_min, edad_max,
    nivel, objetivo, espacio, material, pasos, original_id, huella)
  values (
    v_uid, v_escuela, v_vis::public.visibilidad_ejercicio, v_titulo, v_jmin, v_jmax, v_emin, v_emax,
    nullif(p ->> 'nivel', ''), nullif(p ->> 'objetivo', ''), nullif(p ->> 'espacio', ''),
    v_material, v_pasos, v_original, privado.huella_imagenes(v_imgs, 0))
  returning id into v_id;

  insert into public.ejercicio_imagenes (ejercicio_id, orden, elementos)
  select v_id, (n - 1)::smallint, d from jsonb_array_elements(v_imgs) with ordinality as a(d, n);

  return v_id;
end;
$$;

-- Antes de publicar: los ejercicios públicos parecidos (para avisar)
create function public.buscar_parecidos(
  p_imagenes jsonb, p_jug_min integer, p_jug_max integer, p_edad_min integer, p_edad_max integer
)
returns table (
  id uuid, titulo text, parecido integer, jugadores_min smallint, jugadores_max smallint,
  edad_min smallint, edad_max smallint, imagenes integer, variantes integer, usado_por integer, dibujo jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if not privado.es_staff_en_alguna() then
    raise exception 'Solo los entrenadores y directores';
  end if;
  if p_imagenes is null or jsonb_typeof(p_imagenes) <> 'array' or jsonb_array_length(p_imagenes) not between 1 and 5
     or exists (select 1 from jsonb_array_elements(p_imagenes) d where not privado.dibujo_valido(d)) then
    raise exception 'El dibujo no es válido';
  end if;
  return query
  select e.id, e.titulo, x.parecido, e.jugadores_min, e.jugadores_max, e.edad_min, e.edad_max,
    privado.num_imagenes(e.id), privado.num_variantes(e.id), privado.usado_por(e.id), privado.primera_imagen(e.id)
  from privado.parecidos(p_imagenes, p_jug_min, p_jug_max, p_edad_min, p_edad_max) x
  join public.ejercicios e on e.id = x.ejercicio_id
  where x.parecido >= privado.umbral_aviso()
  order by x.parecido desc, e.creado_at
  limit 3;
end;
$$;

-- ============================================================
-- 7. Biblioteca (anónima) y detalle
-- ============================================================
-- Lista: públicos (para el staff), los de mis escuelas y los míos. Nunca dice
-- quién lo subió, solo si es mío. Las variantes se agrupan bajo su original.
-- Filtros: cualquiera a null no filtra; los rangos (edad, jugadores) se solapan.
create function public.biblioteca(
  p_texto text default null,
  p_edad_min integer default null,
  p_edad_max integer default null,
  p_niveles text[] default null,
  p_objetivos text[] default null,
  p_jug_min integer default null,
  p_jug_max integer default null,
  p_materiales text[] default null,
  p_espacios text[] default null,
  p_mios boolean default false,
  p_limite integer default 50,
  p_desde integer default 0
)
returns table (
  id uuid, titulo text, visibilidad public.visibilidad_ejercicio, original_id uuid,
  jugadores_min smallint, jugadores_max smallint, edad_min smallint, edad_max smallint,
  nivel text, objetivo text, espacio text, material text[],
  imagenes integer, variantes integer, usado_por integer, es_mio boolean, retirado boolean,
  dibujo jsonb, creado_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select e.id, e.titulo, e.visibilidad, e.original_id,
    e.jugadores_min, e.jugadores_max, e.edad_min, e.edad_max,
    e.nivel, e.objetivo, e.espacio, e.material,
    privado.num_imagenes(e.id), privado.num_variantes(e.id), privado.usado_por(e.id),
    e.autor_id = (select auth.uid()), e.retirado_at is not null,
    privado.primera_imagen(e.id), e.creado_at
  from public.ejercicios e
  where (select auth.uid()) is not null
    and (
      case when coalesce(p_mios, false) then e.autor_id = (select auth.uid())
      else e.retirado_at is null and e.original_id is null and (
        (e.visibilidad = 'publica' and privado.es_staff_en_alguna())
        or (e.visibilidad = 'escuela' and privado.es_staff(e.escuela_id))
        or e.autor_id = (select auth.uid()))
      end)
    and (p_texto is null or e.titulo ilike '%' || replace(replace(replace(p_texto, '\', '\\'), '%', '\%'), '_', '\_') || '%')
    and (p_edad_min is null or e.edad_max is null or e.edad_max >= p_edad_min)
    and (p_edad_max is null or e.edad_min is null or e.edad_min <= p_edad_max)
    and (p_niveles is null or cardinality(p_niveles) = 0 or e.nivel = any (p_niveles))
    and (p_objetivos is null or cardinality(p_objetivos) = 0 or e.objetivo = any (p_objetivos))
    and (p_jug_min is null or e.jugadores_max >= p_jug_min)
    and (p_jug_max is null or e.jugadores_min <= p_jug_max)
    and (p_materiales is null or cardinality(p_materiales) = 0 or e.material && p_materiales)
    and (p_espacios is null or cardinality(p_espacios) = 0 or e.espacio = any (p_espacios))
  order by privado.usado_por(e.id) desc, e.creado_at desc
  limit least(greatest(coalesce(p_limite, 50), 1), 100)
  offset greatest(coalesce(p_desde, 0), 0);
$$;

-- Detalle de un ejercicio (sin autor). Lo pueden ver quienes pueden verlo:
-- el staff (públicos y de su escuela), su autor y los alumnos cuya clase lo usa.
create function public.detalle_ejercicio(p_ejercicio uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  e public.ejercicios;
  v_raiz uuid;
begin
  if not privado.puede_ver_ejercicio(p_ejercicio) then
    raise exception 'Ejercicio no encontrado';
  end if;
  select * into e from public.ejercicios where id = p_ejercicio;
  v_raiz := coalesce(e.original_id, e.id);
  return jsonb_build_object(
    'id', e.id,
    'titulo', e.titulo,
    'visibilidad', e.visibilidad,
    'jugadores_min', e.jugadores_min,
    'jugadores_max', e.jugadores_max,
    'edad_min', e.edad_min,
    'edad_max', e.edad_max,
    'nivel', e.nivel,
    'objetivo', e.objetivo,
    'espacio', e.espacio,
    'material', to_jsonb(e.material),
    'pasos', to_jsonb(e.pasos),
    'es_mio', e.autor_id = (select auth.uid()),
    'retirado', e.retirado_at is not null,
    'usado_por', privado.usado_por(v_raiz),
    'imagenes', coalesce((
      select jsonb_agg(i.elementos order by i.orden) from public.ejercicio_imagenes i where i.ejercicio_id = e.id), '[]'::jsonb),
    'original', (
      select jsonb_build_object('id', o.id, 'titulo', o.titulo)
      from public.ejercicios o where o.id = e.original_id and o.visibilidad = 'publica'),
    'variantes', coalesce((
      select jsonb_agg(jsonb_build_object('id', v.id, 'titulo', v.titulo) order by v.creado_at)
      from public.ejercicios v
      where v.original_id = v_raiz and v.id <> e.id and v.visibilidad = 'publica' and v.retirado_at is null), '[]'::jsonb)
  );
end;
$$;

-- ============================================================
-- 8. Cambios del autor: textos, retirar y borrar
-- ============================================================
-- El dibujo, los jugadores, la edad y la visibilidad no cambian una vez
-- publicado (otros pueden estar usándolo); para eso se publica otro.
create function public.editar_ejercicio(p_ejercicio uuid, p jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_titulo text := btrim(coalesce(p ->> 'titulo', ''));
  v_material text[];
  v_pasos text[];
begin
  if not exists (select 1 from public.ejercicios where id = p_ejercicio and autor_id = (select auth.uid())) then
    raise exception 'Ejercicio no encontrado';
  end if;
  if length(v_titulo) < 2 or length(v_titulo) > 80 then
    raise exception 'El nombre debe tener entre 2 y 80 caracteres';
  end if;
  if jsonb_typeof(coalesce(p -> 'material', '[]')) <> 'array' or jsonb_typeof(coalesce(p -> 'pasos', '[]')) <> 'array' then
    raise exception 'Material y pasos van en listas';
  end if;
  select coalesce(array_agg(distinct x), '{}') into v_material
  from jsonb_array_elements_text(coalesce(p -> 'material', '[]')) x;
  select coalesce(array_agg(btrim(x) order by n), '{}') into v_pasos
  from jsonb_array_elements_text(coalesce(p -> 'pasos', '[]')) with ordinality as a(x, n)
  where length(btrim(x)) > 0;
  update public.ejercicios set
    titulo = v_titulo,
    nivel = nullif(p ->> 'nivel', ''),
    objetivo = nullif(p ->> 'objetivo', ''),
    espacio = nullif(p ->> 'espacio', ''),
    material = v_material,
    pasos = v_pasos
  where id = p_ejercicio;
end;
$$;

-- Retirar: deja de salir en la biblioteca, pero las clases que lo usaron lo conservan
create function public.retirar_ejercicio(p_ejercicio uuid, p_retirar boolean default true)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.ejercicios
  set retirado_at = case when p_retirar then coalesce(retirado_at, now()) end
  where id = p_ejercicio and autor_id = (select auth.uid());
  if not found then
    raise exception 'Ejercicio no encontrado';
  end if;
end;
$$;

-- Borrar: solo si nadie lo ha usado ni tiene variantes (si no, se retira)
create function public.borrar_ejercicio(p_ejercicio uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (select 1 from public.ejercicios where id = p_ejercicio and autor_id = (select auth.uid())) then
    raise exception 'Ejercicio no encontrado';
  end if;
  if exists (select 1 from public.usos_ejercicio where ejercicio_id = p_ejercicio)
     or exists (select 1 from public.ejercicios where original_id = p_ejercicio) then
    raise exception 'Este ejercicio ya se ha usado o tiene variantes: retíralo de la biblioteca en lugar de borrarlo';
  end if;
  delete from public.ejercicios where id = p_ejercicio;
end;
$$;

-- ============================================================
-- 9. Ejercicios de una clase ("Preparar clase")
-- ============================================================
-- Fija la lista (y el orden) de ejercicios de la clase. Solo el entrenador del
-- grupo o el director, en una clase no cancelada y como mucho 14 días después.
create function public.guardar_ejercicios_clase(p_sesion uuid, p_ejercicios uuid[])
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.sesiones;
  v_escuela uuid;
  v_lista uuid[] := coalesce(p_ejercicios, '{}');
  e public.ejercicios;
  v_id uuid;
begin
  select * into s from public.sesiones where id = p_sesion;
  if not found or (select auth.uid()) is null or not privado.puede_gestionar_grupo(s.grupo_id) then
    raise exception 'Clase no encontrada';
  end if;
  if s.estado = 'cancelada' then
    raise exception 'Esta clase está cancelada';
  end if;
  if s.fecha < privado.hoy() - 14 then
    raise exception 'Ya no se puede cambiar esta clase';
  end if;
  if cardinality(v_lista) > 12 then
    raise exception 'Como mucho 12 ejercicios por clase';
  end if;
  if cardinality(v_lista) <> (select count(distinct x) from unnest(v_lista) x) then
    raise exception 'Hay ejercicios repetidos';
  end if;
  v_escuela := privado.escuela_de_grupo(s.grupo_id);

  foreach v_id in array v_lista loop
    select * into e from public.ejercicios where id = v_id;
    if not found or not privado.puede_ver_ejercicio(v_id)
       -- uno "solo mi escuela" solo se usa en las clases de esa escuela
       or (e.visibilidad = 'escuela' and e.escuela_id is distinct from v_escuela) then
      raise exception 'Ejercicio no encontrado';
    end if;
    -- uno retirado se puede conservar en la clase, pero no añadir
    if e.retirado_at is not null and not exists (
      select 1 from public.usos_ejercicio where sesion_id = p_sesion and ejercicio_id = v_id) then
      raise exception 'Ese ejercicio se ha retirado de la biblioteca';
    end if;
  end loop;

  delete from public.usos_ejercicio where sesion_id = p_sesion and not (ejercicio_id = any (v_lista));
  insert into public.usos_ejercicio (sesion_id, ejercicio_id, anadido_por, orden)
  select p_sesion, x, (select auth.uid()), (n - 1)::smallint
  from unnest(v_lista) with ordinality as a(x, n)
  on conflict (sesion_id, ejercicio_id) do update set orden = excluded.orden;
end;
$$;

-- Ejercicios de una clase, sin autor (para el entrenador y los alumnos del grupo)
create function public.ejercicios_de_clase(p_sesion uuid)
returns table (
  id uuid, titulo text, orden smallint, jugadores_min smallint, jugadores_max smallint,
  imagenes integer, dibujo jsonb, retirado boolean
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  s public.sesiones;
begin
  select * into s from public.sesiones where id = p_sesion;
  if not found or not (privado.es_staff(privado.escuela_de_grupo(s.grupo_id)) or privado.inscrito_en_grupo(s.grupo_id)) then
    raise exception 'Clase no encontrada';
  end if;
  return query
  select e.id, e.titulo, u.orden, e.jugadores_min, e.jugadores_max,
    privado.num_imagenes(e.id), privado.primera_imagen(e.id), e.retirado_at is not null
  from public.usos_ejercicio u
  join public.ejercicios e on e.id = u.ejercicio_id
  where u.sesion_id = p_sesion
  order by u.orden, e.titulo;
end;
$$;

-- ============================================================
-- 10. Permisos
-- ============================================================
do $$
declare f text;
begin
  foreach f in array array[
    'public.publicar_ejercicio(jsonb)',
    'public.buscar_parecidos(jsonb, integer, integer, integer, integer)',
    'public.biblioteca(text, integer, integer, text[], text[], integer, integer, text[], text[], boolean, integer, integer)',
    'public.detalle_ejercicio(uuid)',
    'public.editar_ejercicio(uuid, jsonb)',
    'public.retirar_ejercicio(uuid, boolean)',
    'public.borrar_ejercicio(uuid)',
    'public.guardar_ejercicios_clase(uuid, uuid[])',
    'public.ejercicios_de_clase(uuid)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
grant execute on all functions in schema privado to authenticated;
revoke execute on all functions in schema privado from anon, public;
