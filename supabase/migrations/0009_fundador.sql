-- Rankademy · Fase 8a · Panel del fundador
-- Se ejecuta después de 0001-0008. No cambia tablas: añade funciones de solo lectura
-- que SOLO puede usar quien esté en public.fundadores.
--
-- Devuelven cifras agregadas (cuántos, qué porcentaje, por semana) y, por escuela, sus
-- datos públicos (nombre, ciudad) con contadores. Nunca datos de un menor concreto ni
-- correos: el panel sirve para seguir el piloto, no para mirar personas.

create function privado.exigir_fundador()
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if (select auth.uid()) is null or not privado.es_fundador() then
    raise exception 'Solo el fundador';
  end if;
end;
$$;

-- Lunes de la semana (hora de Madrid) de una fecha
create function privado.semana(p_fecha date)
returns date language sql immutable set search_path = '' as $$
  select (p_fecha - (extract(isodow from p_fecha)::integer - 1))::date;
$$;

-- ============================================================
-- 1. Resumen: crecimiento, actividad, retención, biblioteca y rankings
-- ============================================================
-- p_dias: periodo de "nuevos" y "en el periodo" (por defecto, 30 días)
create function public.panel_fundador(p_dias integer default 30)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_hoy date := privado.hoy();
  v_dias integer := least(greatest(coalesce(p_dias, 30), 1), 365);
  v_desde date;
  v_semanas date[];
  r jsonb := '{}'::jsonb;
begin
  perform privado.exigir_fundador();
  v_desde := v_hoy - v_dias;
  -- Las últimas 12 semanas (lunes), de la más antigua a la actual
  select array_agg(privado.semana(v_hoy) - 7 * k order by k desc) into v_semanas from generate_series(0, 11) k;

  -- Crecimiento
  r := r || jsonb_build_object('crecimiento', jsonb_build_object(
    'escuelas', (select count(*) from public.escuelas),
    'escuelas_nuevas', (select count(*) from public.escuelas where (creada_at at time zone 'Europe/Madrid')::date > v_desde),
    'personas', (select count(*) from public.personas),
    'personas_nuevas', (select count(*) from public.personas where (creada_at at time zone 'Europe/Madrid')::date > v_desde),
    'directores', (select count(distinct persona_id) from public.membresias where rol = 'director' and estado = 'activa'),
    'entrenadores', (select count(distinct persona_id) from public.membresias where rol = 'entrenador' and estado = 'activa'),
    'familias', (select count(distinct p.familia_id) from public.perfiles_alumno p
                 join public.membresias m on m.perfil_id = p.id and m.estado = 'activa'),
    'alumnos', (select count(distinct m.perfil_id) from public.membresias m where m.rol = 'alumno' and m.estado = 'activa'),
    'alumnos_mini', (select count(distinct m.perfil_id) from public.membresias m join public.perfiles_alumno p on p.id = m.perfil_id
                     where m.rol = 'alumno' and m.estado = 'activa' and extract(year from v_hoy)::integer - p.anio_nacimiento <= 7),
    'alumnos_nuevos', (select count(*) from public.perfiles_alumno where (creado_at at time zone 'Europe/Madrid')::date > v_desde),
    'solicitudes_pendientes', (select count(*) from public.membresias where estado = 'pendiente'),
    'por_semana', (
      select jsonb_agg(jsonb_build_object(
        'semana', s,
        'personas', (select count(*) from public.personas where privado.semana((creada_at at time zone 'Europe/Madrid')::date) = s),
        'escuelas', (select count(*) from public.escuelas where privado.semana((creada_at at time zone 'Europe/Madrid')::date) = s),
        'alumnos', (select count(*) from public.perfiles_alumno where privado.semana((creado_at at time zone 'Europe/Madrid')::date) = s)
      ) order by s) from unnest(v_semanas) s)
  ));

  -- Actividad (clases con lista y asistencias)
  r := r || jsonb_build_object('actividad', jsonb_build_object(
    'clases_con_lista', (select count(*) from public.sesiones where estado = 'impartida' and fecha > v_desde and fecha <= v_hoy),
    'clases_canceladas', (select count(*) from public.sesiones where estado = 'cancelada' and fecha > v_desde and fecha <= v_hoy),
    'asistencias_marcadas', (select count(*) from public.asistencias a join public.sesiones s on s.id = a.sesion_id
                             where s.fecha > v_desde and s.fecha <= v_hoy and not a.justificada),
    'asistencias_confirmadas', (select count(*) from public.asistencias a join public.sesiones s on s.id = a.sesion_id
                                where s.fecha > v_desde and s.fecha <= v_hoy and not a.justificada and a.confirmada_at is not null),
    'entrenadores_que_pasan_lista', (select count(distinct a.marcada_por) from public.asistencias a join public.sesiones s on s.id = a.sesion_id
                                     where s.fecha > v_desde and s.fecha <= v_hoy),
    'familias_que_confirman', (select count(distinct a.confirmada_por) from public.asistencias a
                               where a.confirmada_at is not null and (a.confirmada_at at time zone 'Europe/Madrid')::date > v_desde),
    'por_semana', (
      select jsonb_agg(jsonb_build_object(
        'semana', s,
        'clases', (select count(*) from public.sesiones x where x.estado = 'impartida' and privado.semana(x.fecha) = s),
        'confirmadas', (select count(*) from public.asistencias a join public.sesiones x on x.id = a.sesion_id
                        where a.confirmada_at is not null and privado.semana(x.fecha) = s)
      ) order by s) from unnest(v_semanas) s)
  ));

  -- Retención: quién sigue activo
  r := r || jsonb_build_object('retencion', jsonb_build_object(
    -- Escuelas con alguna clase con lista en los últimos 14 días
    'escuelas_activas_14d', (select count(distinct g.escuela_id) from public.sesiones s join public.grupos g on g.id = s.grupo_id
                             where s.estado = 'impartida' and s.fecha > v_hoy - 14 and s.fecha <= v_hoy),
    -- Entrenadores que han pasado lista en los últimos 14 días, de los entrenadores activos
    'entrenadores_activos_14d', (select count(distinct a.marcada_por) from public.asistencias a join public.sesiones s on s.id = a.sesion_id
                                 where s.fecha > v_hoy - 14 and s.fecha <= v_hoy),
    -- Alumnos con al menos 30 días en la app y alguna asistencia en los últimos 30 días
    'alumnos_veteranos', (select count(distinct m.perfil_id) from public.membresias m
                          where m.rol = 'alumno' and m.estado = 'activa' and (m.creada_at at time zone 'Europe/Madrid')::date <= v_hoy - 30),
    'alumnos_veteranos_activos_30d', (
      select count(distinct m.perfil_id) from public.membresias m
      where m.rol = 'alumno' and m.estado = 'activa' and (m.creada_at at time zone 'Europe/Madrid')::date <= v_hoy - 30
        and exists (select 1 from public.asistencias a join public.sesiones s on s.id = a.sesion_id
                    where a.perfil_id = m.perfil_id and not a.justificada and s.fecha > v_hoy - 30 and s.fecha <= v_hoy)),
    -- Bajas en el periodo
    'bajas', (select count(*) from public.membresias where estado = 'baja')
  ));

  -- Biblioteca
  r := r || jsonb_build_object('biblioteca', jsonb_build_object(
    'publicos', (select count(*) from public.ejercicios where visibilidad = 'publica' and original_id is null and retirado_at is null),
    'variantes', (select count(*) from public.ejercicios where original_id is not null and retirado_at is null),
    'privados', (select count(*) from public.ejercicios where visibilidad = 'escuela' and retirado_at is null),
    'retirados', (select count(*) from public.ejercicios where retirado_at is not null),
    'nuevos', (select count(*) from public.ejercicios where (creado_at at time zone 'Europe/Madrid')::date > v_desde),
    'autores', (select count(distinct autor_id) from public.ejercicios),
    'usos_periodo', (select count(*) from public.usos_ejercicio u join public.sesiones s on s.id = u.sesion_id
                     where s.estado <> 'cancelada' and s.fecha > v_desde and s.fecha <= v_hoy),
    'clases_con_ejercicios', (select count(distinct u.sesion_id) from public.usos_ejercicio u join public.sesiones s on s.id = u.sesion_id
                              where s.estado = 'impartida' and s.fecha > v_desde and s.fecha <= v_hoy),
    'mas_usados', (
      select coalesce(jsonb_agg(x order by x.usado_por desc, x.titulo), '[]'::jsonb) from (
        select e.titulo, privado.usado_por(e.id) as usado_por
        from public.ejercicios e
        where e.visibilidad = 'publica' and e.original_id is null and e.retirado_at is null
        order by privado.usado_por(e.id) desc, e.titulo limit 5) x
      where x.usado_por > 0)
  ));

  -- Rankings
  r := r || jsonb_build_object('rankings', jsonb_build_object(
    'escuelas_participan', (select count(*) from public.escuelas where participa_ranking),
    'escuelas_sin_provincia', (select count(*) from public.escuelas where participa_ranking and btrim(provincia) = ''),
    'alumnos_compiten', (select count(distinct m.perfil_id) from public.membresias m
                         where m.rol = 'alumno' and m.estado = 'activa' and privado.alumno_compite(m.perfil_id)),
    'alumnos_no_quieren', (select count(distinct m.perfil_id) from public.membresias m join public.perfiles_alumno p on p.id = m.perfil_id
                           where m.rol = 'alumno' and m.estado = 'activa' and not p.participa_ranking),
    'minimo_escuelas', privado.minimo_escuelas_zona(),
    -- Provincias con escuelas participando y si ya tienen ranking
    'provincias', (
      select coalesce(jsonb_agg(jsonb_build_object('provincia', x.provincia, 'escuelas', x.n,
               'con_ranking', x.n >= privado.minimo_escuelas_zona()) order by x.n desc, x.provincia), '[]'::jsonb)
      from (select initcap(lower(btrim(provincia))) as provincia, count(*) as n
            from public.escuelas where participa_ranking and btrim(provincia) <> ''
            group by initcap(lower(btrim(provincia)))) x),
    'temporada_desde', privado.inicio_temporada()
  ));

  return r || jsonb_build_object('periodo_dias', v_dias, 'generado', now());
end;
$$;

-- ============================================================
-- 2. Piloto: una fila por escuela
-- ============================================================
create function public.escuelas_fundador()
returns table (
  id uuid, nombre text, ciudad text, provincia text, creada date, participa boolean,
  entrenadores integer, alumnos integer, alumnos_con_familia integer, grupos integer,
  clases_4_semanas integer, asistencias_4_semanas integer, confirmadas_4_semanas integer,
  ejercicios integer, ultima_clase date, solicitudes_pendientes integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_hoy date := privado.hoy();
begin
  perform privado.exigir_fundador();
  return query
  select e.id, e.nombre, e.ciudad, e.provincia, (e.creada_at at time zone 'Europe/Madrid')::date, e.participa_ranking,
    (select count(*) from public.membresias m where m.escuela_id = e.id and m.rol = 'entrenador' and m.estado = 'activa')::integer,
    (select count(*) from public.membresias m where m.escuela_id = e.id and m.rol = 'alumno' and m.estado = 'activa')::integer,
    (select count(*) from public.membresias m join public.perfiles_alumno p on p.id = m.perfil_id
     where m.escuela_id = e.id and m.rol = 'alumno' and m.estado = 'activa' and p.familia_id is not null)::integer,
    (select count(*) from public.grupos g where g.escuela_id = e.id and g.archivado_at is null)::integer,
    (select count(*) from public.sesiones s join public.grupos g on g.id = s.grupo_id
     where g.escuela_id = e.id and s.estado = 'impartida' and s.fecha > v_hoy - 28 and s.fecha <= v_hoy)::integer,
    (select count(*) from public.asistencias a join public.sesiones s on s.id = a.sesion_id join public.grupos g on g.id = s.grupo_id
     where g.escuela_id = e.id and not a.justificada and s.fecha > v_hoy - 28 and s.fecha <= v_hoy)::integer,
    (select count(*) from public.asistencias a join public.sesiones s on s.id = a.sesion_id join public.grupos g on g.id = s.grupo_id
     where g.escuela_id = e.id and not a.justificada and a.confirmada_at is not null and s.fecha > v_hoy - 28 and s.fecha <= v_hoy)::integer,
    (select count(*) from public.ejercicios x where x.escuela_id = e.id
       or x.autor_id in (select m.persona_id from public.membresias m where m.escuela_id = e.id and m.rol in ('director', 'entrenador') and m.estado = 'activa'))::integer,
    (select max(s.fecha) from public.sesiones s join public.grupos g on g.id = s.grupo_id
     where g.escuela_id = e.id and s.estado = 'impartida'),
    (select count(*) from public.membresias m where m.escuela_id = e.id and m.estado = 'pendiente')::integer
  from public.escuelas e
  order by e.creada_at;
end;
$$;

-- ============================================================
-- 3. Alertas: lo que conviene mirar
-- ============================================================
--  nivel: 'alta' (algo no funciona), 'media' (conviene revisar), 'info'
create function public.alertas_fundador()
returns table (nivel text, tipo text, escuela text, detalle text)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  v_hoy date := privado.hoy();
  e record;
  a record;
begin
  perform privado.exigir_fundador();

  for e in select * from public.escuelas order by nombre loop
    -- Escuela con grupos pero sin ninguna clase con lista en 14 días
    if exists (select 1 from public.grupos g where g.escuela_id = e.id and g.archivado_at is null)
       and not exists (select 1 from public.sesiones s join public.grupos g on g.id = s.grupo_id
                       where g.escuela_id = e.id and s.estado = 'impartida' and s.fecha > v_hoy - 14) then
      nivel := 'alta'; tipo := 'sin_actividad'; escuela := e.nombre;
      detalle := 'Tiene grupos pero no ha pasado lista en los últimos 14 días';
      return next;
    end if;
    -- Escuela creada hace más de 7 días sin grupos
    if (e.creada_at at time zone 'Europe/Madrid')::date <= v_hoy - 7
       and not exists (select 1 from public.grupos g where g.escuela_id = e.id) then
      nivel := 'media'; tipo := 'sin_grupos'; escuela := e.nombre;
      detalle := 'Creada hace más de una semana y aún sin grupos';
      return next;
    end if;
    -- Solicitudes de entrada esperando más de 7 días
    if exists (select 1 from public.membresias m where m.escuela_id = e.id and m.estado = 'pendiente'
               and (m.creada_at at time zone 'Europe/Madrid')::date <= v_hoy - 7) then
      nivel := 'media'; tipo := 'solicitudes_viejas'; escuela := e.nombre;
      detalle := format('%s solicitudes esperan al director desde hace más de 7 días',
        (select count(*) from public.membresias m where m.escuela_id = e.id and m.estado = 'pendiente'
         and (m.creada_at at time zone 'Europe/Madrid')::date <= v_hoy - 7));
      return next;
    end if;
    -- Alumnos dados de alta por la escuela sin familia vinculada después de 14 días
    if exists (select 1 from public.membresias m join public.perfiles_alumno p on p.id = m.perfil_id
               where m.escuela_id = e.id and m.estado = 'activa' and p.familia_id is null
                 and (p.creado_at at time zone 'Europe/Madrid')::date <= v_hoy - 14) then
      nivel := 'media'; tipo := 'familias_sin_vincular'; escuela := e.nombre;
      detalle := format('%s alumnos llevan más de 14 días sin que su familia los vincule (no suman XP)',
        (select count(*) from public.membresias m join public.perfiles_alumno p on p.id = m.perfil_id
         where m.escuela_id = e.id and m.estado = 'activa' and p.familia_id is null
           and (p.creado_at at time zone 'Europe/Madrid')::date <= v_hoy - 14));
      return next;
    end if;
    -- Participa en el ranking pero sin provincia
    if e.participa_ranking and btrim(e.provincia) = '' then
      nivel := 'info'; tipo := 'sin_provincia'; escuela := e.nombre;
      detalle := 'Participa en el ranking pero no tiene provincia: no entra en los rankings de zona';
      return next;
    end if;
    -- Patrones raros de la escuela (los mismos que ve su director)
    for a in select * from public.anomalias(e.id) loop
      nivel := 'media'; tipo := 'patron_raro'; escuela := e.nombre;
      detalle := coalesce(a.grupo || ': ', '') || coalesce(a.entrenador || ': ', '') || a.detalle;
      return next;
    end loop;
  end loop;

  -- Intentos fallidos con códigos en las últimas 24 horas (posibles ataques)
  if (select count(*) from privado.intentos_codigo where creado_at > now() - interval '1 day') >= 30 then
    nivel := 'alta'; tipo := 'codigos_fallidos'; escuela := null;
    detalle := format('%s intentos fallidos con códigos en las últimas 24 horas (de %s cuentas)',
      (select count(*) from privado.intentos_codigo where creado_at > now() - interval '1 day'),
      (select count(distinct persona_id) from privado.intentos_codigo where creado_at > now() - interval '1 day'));
    return next;
  end if;
end;
$$;

-- ============================================================
-- 4. Permisos
-- ============================================================
do $$
declare f text;
begin
  foreach f in array array['public.panel_fundador(integer)', 'public.escuelas_fundador()', 'public.alertas_fundador()'] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
grant execute on all functions in schema privado to authenticated;
revoke execute on all functions in schema privado from anon, public;
