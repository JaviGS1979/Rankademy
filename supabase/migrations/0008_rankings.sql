-- Rankademy · Fase 7a · Rankings
-- Se ejecuta después de 0001-0007. No cambia ninguna tabla: solo añade funciones
-- que calculan los rankings en el momento (se actualizan tras cada lista).
--
-- Reglas (ajustables en las funciones de la sección 1):
--  * Temporada: desde el 1 de septiembre (las clases anteriores no cuentan).
--  * Alumnos: desde 8 años, si la familia no lo ha desactivado y su escuela participa.
--    Puntos = XP ganado en la temporada. En "mi escuela", solo el de esa escuela; en
--    provincia, comunidad y país aparece una vez, con su total.
--  * Entrenadores: nota de 0 a 1000 = 40 % uso de sus ejercicios por otros + 30 %
--    constancia + 30 % asistencia confirmada de sus alumnos.
--  * Escuelas: media (0-1000) de sus entrenadores y alumnos, con un mínimo de participantes.
--  * Zonas: hacen falta varias escuelas participando para que haya ranking.
-- Los rankings nunca muestran datos de contacto: nombre de pila e inicial, avatar y escuela.

-- ============================================================
-- 1. Parámetros
-- ============================================================
create function privado.inicio_temporada()
returns date language sql stable set search_path = '' as $$
  select make_date(
    extract(year from privado.hoy())::integer - case when extract(month from privado.hoy()) < 9 then 1 else 0 end,
    9, 1);
$$;

-- Escuelas participantes necesarias en una zona (provincia, comunidad, país)
create function privado.minimo_escuelas_zona() returns integer language sql immutable as $$ select 3 $$;
-- Participantes (alumnos + entrenadores) para que una escuela salga en el ranking de escuelas
create function privado.minimo_participantes_escuela() returns integer language sql immutable as $$ select 5 $$;
-- Usos que cuentan como máximo entre una pareja de entrenadores en la temporada
create function privado.tope_usos_pareja() returns integer language sql immutable as $$ select 10 $$;
-- Edad mínima para salir en el ranking (los Mini no compiten)
create function privado.edad_minima_ranking() returns integer language sql immutable as $$ select 8 $$;

-- ============================================================
-- 2. Auxiliares
-- ============================================================
-- "Iker López Mora" → "Iker L."; sin apellidos, la inicial de la segunda palabra del nombre
create function privado.nombre_publico(p_nombre text, p_apellidos text default null)
returns text language sql immutable set search_path = '' as $$
  select coalesce(nullif(p[1], ''), 'Sin nombre')
         || coalesce(' ' || upper(left(coalesce(nullif(btrim(p_apellidos), ''), nullif(p[2], '')), 1)) || '.', '')
  from (select regexp_split_to_array(btrim(coalesce(p_nombre, '')), '\s+') as p) x;
$$;

create function privado.es_fundador()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.fundadores where persona_id = (select auth.uid()));
$$;

-- Ve los rankings de una escuela quien es miembro aprobado de ella (o el fundador)
create function privado.puede_ver_ranking(p_escuela uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select (select auth.uid()) is not null and (
    privado.es_fundador()
    or exists (
      select 1 from public.membresias m
      where m.escuela_id = p_escuela and m.persona_id = (select auth.uid()) and m.estado = 'activa'));
$$;

-- Escuelas participantes de la zona de una escuela de referencia.
-- ámbito: 'escuela' (solo ella), 'provincia', 'comunidad' o 'pais'.
create function privado.escuelas_de_zona(p_ref uuid, p_ambito text)
returns setof uuid language sql stable security definer set search_path = '' as $$
  select e.id
  from public.escuelas e
  join public.escuelas r on r.id = p_ref
  where e.participa_ranking and r.participa_ranking
    and case p_ambito
      when 'escuela' then e.id = r.id
      when 'provincia' then btrim(r.provincia) <> '' and lower(btrim(e.provincia)) = lower(btrim(r.provincia)) and e.pais = r.pais
      when 'comunidad' then btrim(r.comunidad) <> '' and lower(btrim(e.comunidad)) = lower(btrim(r.comunidad)) and e.pais = r.pais
      when 'pais' then e.pais = r.pais
      else false
    end;
$$;

-- Puntos de un alumno en la temporada (en unas escuelas concretas)
create function privado.puntos_temporada(p_perfil uuid, p_escuelas uuid[])
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce(sum(pu.valor), 0)::integer
  from public.puntos pu
  join public.sesiones s on s.id = pu.sesion_id
  where pu.perfil_id = p_perfil and pu.escuela_id = any (p_escuelas)
    and s.fecha >= privado.inicio_temporada();
$$;

-- Alumno que puede salir en el ranking: 8 años o más y sin haberlo desactivado
create function privado.alumno_compite(p_perfil uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.perfiles_alumno p
    where p.id = p_perfil and p.participa_ranking
      and extract(year from privado.hoy())::integer - p.anio_nacimiento >= privado.edad_minima_ranking());
$$;

-- ============================================================
-- 3. Puntuación de un entrenador (0-1000) y su desglose
-- ============================================================
--  * uso (40 %): sus ejercicios públicos (y las variantes, que suman al original) dados
--    por OTROS entrenadores en clases impartidas de la temporada. Vale doble si la clase
--    es de una escuela donde él no está. Como mucho tope_usos_pareja() por cada otro
--    entrenador. 10 puntos por uso hasta 1000.
--  * constancia (30 %): clases que tocaban según el horario de sus grupos (hasta ayer,
--    sin las canceladas) en las que se pasó lista.
--  * alumnos (30 %): en sus clases impartidas de hace al menos 7 días, asistencias
--    confirmadas por la familia frente a los alumnos apuntados (sin faltas justificadas).
create function privado.puntuacion_entrenador(p_persona uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_desde date := privado.inicio_temporada();
  v_hoy date := privado.hoy();
  v_usos integer;
  v_ponderados integer;
  v_esperadas integer;
  v_hechas integer;
  v_apuntados integer;
  v_confirmadas integer;
  v_uso integer;
  v_constancia integer;
  v_alumnos integer;
begin
  -- Uso de sus ejercicios por otros
  with usos as (
    select distinct u.sesion_id, coalesce(v.original_id, v.id) as raiz, u.anadido_por,
      privado.escuela_de_grupo(s.grupo_id) as escuela
    from public.usos_ejercicio u
    join public.ejercicios v on v.id = u.ejercicio_id
    join public.sesiones s on s.id = u.sesion_id
    where s.estado = 'impartida' and s.fecha >= v_desde and s.fecha <= v_hoy
      and u.anadido_por is not null and u.anadido_por <> p_persona
  ), suyos as (
    select x.* from usos x join public.ejercicios r on r.id = x.raiz
    where r.autor_id = p_persona and r.visibilidad = 'publica'
  ), por_pareja as (
    select anadido_por, sum(
      case when exists (
        select 1 from public.membresias m
        where m.persona_id = p_persona and m.escuela_id = suyos.escuela
          and m.rol in ('director', 'entrenador') and m.estado = 'activa') then 1 else 2 end) as peso
    from suyos group by anadido_por
  )
  select (select count(*) from suyos)::integer,
         coalesce((select sum(least(peso, privado.tope_usos_pareja())) from por_pareja), 0)::integer
  into v_usos, v_ponderados;

  -- Constancia: días de clase de sus grupos hasta ayer, sin los cancelados
  with dias as (
    select g.id as grupo_id, d::date as fecha
    from public.grupos g
    cross join generate_series(greatest(v_desde, (g.creado_at at time zone 'Europe/Madrid')::date), v_hoy - 1, interval '1 day') d
    where g.entrenador_id = p_persona and privado.es_dia_de_clase(g.id, d::date)
  )
  select
    count(*) filter (where s.estado is distinct from 'cancelada')::integer,
    count(*) filter (where s.estado = 'impartida'
                     or (s.estado = 'planificada' and exists (select 1 from public.asistencias a where a.sesion_id = s.id)))::integer
  into v_esperadas, v_hechas
  from dias
  left join public.sesiones s on s.grupo_id = dias.grupo_id and s.fecha = dias.fecha;

  -- Asistencia confirmada de sus alumnos
  with clases as (
    select s.id, s.grupo_id, s.fecha
    from public.sesiones s join public.grupos g on g.id = s.grupo_id
    where g.entrenador_id = p_persona and s.estado = 'impartida'
      and s.fecha >= v_desde and s.fecha <= v_hoy - 7
  ), esperados as (
    select c.id as sesion_id, i.perfil_id
    from clases c
    join public.inscripciones i on i.grupo_id = c.grupo_id
      and i.desde <= c.fecha and (i.hasta is null or i.hasta >= c.fecha)
  )
  select
    count(*) filter (where a.justificada is distinct from true)::integer,
    count(*) filter (where a.confirmada_at is not null and not a.justificada)::integer
  into v_apuntados, v_confirmadas
  from esperados e
  left join public.asistencias a on a.sesion_id = e.sesion_id and a.perfil_id = e.perfil_id;

  v_uso := least(1000, 10 * v_ponderados);
  v_constancia := case when v_esperadas > 0 then round(1000.0 * least(v_hechas, v_esperadas) / v_esperadas) else 0 end;
  v_alumnos := case when v_apuntados > 0 then round(1000.0 * least(v_confirmadas, v_apuntados) / v_apuntados) else 0 end;

  return jsonb_build_object(
    'puntos', round(0.4 * v_uso + 0.3 * v_constancia + 0.3 * v_alumnos)::integer,
    'uso', v_uso,
    'constancia', v_constancia,
    'alumnos', v_alumnos,
    'usos', v_usos,
    'clases_esperadas', v_esperadas,
    'clases_con_lista', v_hechas
  );
end;
$$;

-- Nota (0-1000) de un alumno para el ranking de escuelas: su XP de la temporada en esa
-- escuela frente a 300 XP por semana (lo que da ir a todas sus clases), desde que entró.
create function privado.nota_alumno_escuela(p_perfil uuid, p_escuela uuid, p_desde_membresia date)
returns integer language sql stable security definer set search_path = '' as $$
  select least(1000, round(1000.0 * privado.puntos_temporada(p_perfil, array[p_escuela])
    / (300 * greatest(1, (privado.hoy() - greatest(privado.inicio_temporada(), p_desde_membresia)) / 7.0))))::integer;
$$;

-- ============================================================
-- 4. Estado del ranking para una escuela (para las pantallas vacías)
-- ============================================================
create function public.estado_ranking(p_escuela uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  e public.escuelas;
begin
  if not privado.puede_ver_ranking(p_escuela) then
    raise exception 'Ranking no disponible';
  end if;
  select * into e from public.escuelas where id = p_escuela;
  return jsonb_build_object(
    'participa', e.participa_ranking,
    'provincia', e.provincia,
    'comunidad', e.comunidad,
    'pais', e.pais,
    'escuelas_provincia', (select count(*) from privado.escuelas_de_zona(p_escuela, 'provincia')),
    'escuelas_comunidad', (select count(*) from privado.escuelas_de_zona(p_escuela, 'comunidad')),
    'escuelas_pais', (select count(*) from privado.escuelas_de_zona(p_escuela, 'pais')),
    'minimo_escuelas', privado.minimo_escuelas_zona(),
    'minimo_participantes', privado.minimo_participantes_escuela(),
    'temporada_desde', privado.inicio_temporada()
  );
end;
$$;

-- ============================================================
-- 5. Ranking de alumnos
-- ============================================================
-- Devuelve los 100 primeros y, si quedan fuera, los perfiles propios (es_mio).
create function public.ranking_alumnos(
  p_escuela uuid, p_ambito text default 'escuela', p_edad_min integer default null, p_edad_max integer default null
)
returns table (posicion integer, nombre text, avatar text, escuela text, puntos integer, es_mio boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_zona uuid[];
  v_participantes uuid[];
  v_anio integer := extract(year from privado.hoy())::integer;
begin
  if not privado.puede_ver_ranking(p_escuela) then
    raise exception 'Ranking no disponible';
  end if;
  if p_ambito not in ('escuela', 'provincia', 'comunidad', 'pais') then
    raise exception 'Ámbito no válido';
  end if;
  select array_agg(z) into v_zona from privado.escuelas_de_zona(p_escuela, p_ambito) z;
  if v_zona is null or (p_ambito <> 'escuela' and cardinality(v_zona) < privado.minimo_escuelas_zona()) then
    return;
  end if;
  -- Los puntos de zona son el total en todas las escuelas que participan
  select array_agg(id) into v_participantes from public.escuelas where participa_ranking;

  return query
  with alumnos as (
    select distinct m.perfil_id
    from public.membresias m
    where m.rol = 'alumno' and m.estado = 'activa' and m.escuela_id = any (v_zona)
  ), con_puntos as (
    select p.id, p.nombre, p.apellidos, p.avatar,
      privado.puntos_temporada(p.id, case when p_ambito = 'escuela' then v_zona else v_participantes end) as pts
    from alumnos a
    join public.perfiles_alumno p on p.id = a.perfil_id
    where privado.alumno_compite(p.id)
      and (p_edad_min is null or v_anio - p.anio_nacimiento >= p_edad_min)
      and (p_edad_max is null or v_anio - p.anio_nacimiento <= p_edad_max)
  ), ordenados as (
    select c.*, rank() over (order by c.pts desc)::integer as pos,
      privado.es_mi_perfil(c.id) as mio
    from con_puntos c where c.pts > 0
  )
  select o.pos, privado.nombre_publico(o.nombre, o.apellidos), coalesce(o.avatar, 'av01'),
    (select e.nombre from public.membresias m join public.escuelas e on e.id = m.escuela_id
     where m.perfil_id = o.id and m.estado = 'activa' and m.escuela_id = any (v_zona)
     order by privado.puntos_temporada(o.id, array[m.escuela_id]) desc, e.nombre limit 1),
    o.pts, o.mio
  from ordenados o
  where o.pos <= 100 or o.mio
  order by o.pos, privado.nombre_publico(o.nombre, o.apellidos);
end;
$$;

-- ============================================================
-- 6. Ranking de entrenadores y su perfil
-- ============================================================
create function public.ranking_entrenadores(p_escuela uuid, p_ambito text default 'escuela')
returns table (posicion integer, entrenador_id uuid, nombre text, escuela text, puntos integer, es_mio boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_zona uuid[];
begin
  if not privado.puede_ver_ranking(p_escuela) then
    raise exception 'Ranking no disponible';
  end if;
  if p_ambito not in ('escuela', 'provincia', 'comunidad', 'pais') then
    raise exception 'Ámbito no válido';
  end if;
  select array_agg(z) into v_zona from privado.escuelas_de_zona(p_escuela, p_ambito) z;
  if v_zona is null or (p_ambito <> 'escuela' and cardinality(v_zona) < privado.minimo_escuelas_zona()) then
    return;
  end if;

  return query
  with entrenadores as (
    select distinct m.persona_id
    from public.membresias m
    where m.rol = 'entrenador' and m.estado = 'activa' and m.escuela_id = any (v_zona)
  ), con_puntos as (
    select e.persona_id, pe.nombre, (privado.puntuacion_entrenador(e.persona_id) ->> 'puntos')::integer as pts
    from entrenadores e join public.personas pe on pe.id = e.persona_id
  ), ordenados as (
    select c.*, rank() over (order by c.pts desc)::integer as pos
    from con_puntos c where c.pts > 0
  )
  select o.pos, o.persona_id, privado.nombre_publico(o.nombre),
    (select e.nombre from public.membresias m join public.escuelas e on e.id = m.escuela_id
     where m.persona_id = o.persona_id and m.rol = 'entrenador' and m.estado = 'activa' and m.escuela_id = any (v_zona)
     order by e.nombre limit 1),
    o.pts, o.persona_id = (select auth.uid())
  from ordenados o
  where o.pos <= 100 or o.persona_id = (select auth.uid())
  order by o.pos, privado.nombre_publico(o.nombre);
end;
$$;

-- Perfil público de un entrenador: nombre, escuelas y desglose de su puntuación.
-- Lo ve cualquier miembro aprobado de una escuela; el entrenador debe estar en una que participe.
create function public.perfil_entrenador(p_persona uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_escuelas jsonb;
begin
  if (select auth.uid()) is null or not (
    privado.es_fundador() or exists (
      select 1 from public.membresias where persona_id = (select auth.uid()) and estado = 'activa')) then
    raise exception 'Perfil no disponible';
  end if;
  select jsonb_agg(e.nombre order by e.nombre) into v_escuelas
  from public.membresias m join public.escuelas e on e.id = m.escuela_id
  where m.persona_id = p_persona and m.rol = 'entrenador' and m.estado = 'activa' and e.participa_ranking;
  if v_escuelas is null then
    raise exception 'Perfil no disponible';
  end if;
  return privado.puntuacion_entrenador(p_persona) || jsonb_build_object(
    'nombre', (select privado.nombre_publico(nombre) from public.personas where id = p_persona),
    'escuelas', v_escuelas,
    'es_mio', p_persona = (select auth.uid()));
end;
$$;

-- ============================================================
-- 7. Ranking de escuelas
-- ============================================================
-- Media (0-1000) de sus participantes: entrenadores (su puntuación) y alumnos que compiten
-- (su XP de la temporada en la escuela frente a 300 por semana). No muestra cuántos son.
create function public.ranking_escuelas(p_escuela uuid, p_ambito text default 'provincia')
returns table (posicion integer, nombre text, ciudad text, puntos integer, es_mia boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_zona uuid[];
begin
  if not privado.puede_ver_ranking(p_escuela) then
    raise exception 'Ranking no disponible';
  end if;
  if p_ambito not in ('provincia', 'comunidad', 'pais') then
    raise exception 'Ámbito no válido';
  end if;
  select array_agg(z) into v_zona from privado.escuelas_de_zona(p_escuela, p_ambito) z;
  if v_zona is null or cardinality(v_zona) < privado.minimo_escuelas_zona() then
    return;
  end if;

  return query
  with notas as (
    select m.escuela_id,
      case when m.rol = 'entrenador'
        then (privado.puntuacion_entrenador(m.persona_id) ->> 'puntos')::integer
        else privado.nota_alumno_escuela(m.perfil_id, m.escuela_id, (m.creada_at at time zone 'Europe/Madrid')::date)
      end as nota
    from public.membresias m
    where m.escuela_id = any (v_zona) and m.estado = 'activa'
      and (m.rol = 'entrenador' or (m.rol = 'alumno' and privado.alumno_compite(m.perfil_id)))
  ), medias as (
    select escuela_id, round(avg(nota))::integer as media
    from notas group by escuela_id
    having count(*) >= privado.minimo_participantes_escuela()
  )
  select rank() over (order by md.media desc)::integer, e.nombre, e.ciudad, md.media,
    privado.puede_ver_ranking(e.id) and not privado.es_fundador()
  from medias md join public.escuelas e on e.id = md.escuela_id
  order by 1, e.nombre;
end;
$$;

-- ============================================================
-- 8. Patrones raros (solo el director de la escuela, o el fundador)
-- ============================================================
--  * 'siempre_completo': un grupo con al menos 3 alumnos que, en sus últimas 6 clases con
--    lista, ha tenido a todos presentes en todas.
--  * 'sin_confirmar': un entrenador con al menos 10 asistencias marcadas hace más de 14
--    días que las familias han confirmado menos del 30 %.
create function public.anomalias(p_escuela uuid)
returns table (tipo text, grupo text, entrenador text, detalle text)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_desde date := privado.inicio_temporada();
begin
  if not (privado.es_director(p_escuela) or privado.es_fundador()) then
    raise exception 'Solo el director';
  end if;

  return query
  with ultimas as (
    select s.id, s.grupo_id, s.fecha,
      row_number() over (partition by s.grupo_id order by s.fecha desc) as n
    from public.sesiones s join public.grupos g on g.id = s.grupo_id
    where g.escuela_id = p_escuela and s.estado = 'impartida' and s.fecha >= v_desde
  ), por_clase as (
    select u.grupo_id, u.id,
      (select count(*) from public.inscripciones i
       where i.grupo_id = u.grupo_id and i.desde <= u.fecha and (i.hasta is null or i.hasta >= u.fecha)) as apuntados,
      (select count(*) from public.asistencias a
       join public.inscripciones i on i.perfil_id = a.perfil_id and i.grupo_id = u.grupo_id
         and i.desde <= u.fecha and (i.hasta is null or i.hasta >= u.fecha)
       where a.sesion_id = u.id and not a.justificada) as presentes
    from ultimas u where u.n <= 6
  )
  select 'siempre_completo', g.nombre, privado.nombre_publico(pe.nombre),
    'Todos los alumnos presentes en las últimas 6 clases'
  from por_clase pc
  join public.grupos g on g.id = pc.grupo_id
  left join public.personas pe on pe.id = g.entrenador_id
  group by g.id, g.nombre, pe.nombre
  having count(*) = 6 and min(pc.apuntados) >= 3 and bool_and(pc.presentes >= pc.apuntados);

  return query
  select 'sin_confirmar', null::text, privado.nombre_publico(pe.nombre),
    format('%s de %s asistencias confirmadas por las familias',
      count(*) filter (where a.confirmada_at is not null), count(*))
  from public.asistencias a
  join public.sesiones s on s.id = a.sesion_id
  join public.grupos g on g.id = s.grupo_id
  join public.personas pe on pe.id = a.marcada_por
  where g.escuela_id = p_escuela and not a.justificada
    and s.fecha >= v_desde and s.fecha < privado.hoy() - 14
  group by pe.id, pe.nombre
  having count(*) >= 10 and count(*) filter (where a.confirmada_at is not null) < 0.3 * count(*);
end;
$$;

-- ============================================================
-- 9. Permisos
-- ============================================================
do $$
declare f text;
begin
  foreach f in array array[
    'public.estado_ranking(uuid)',
    'public.ranking_alumnos(uuid, text, integer, integer)',
    'public.ranking_entrenadores(uuid, text)',
    'public.perfil_entrenador(uuid)',
    'public.ranking_escuelas(uuid, text)',
    'public.anomalias(uuid)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
grant execute on all functions in schema privado to authenticated;
revoke execute on all functions in schema privado from anon, public;
