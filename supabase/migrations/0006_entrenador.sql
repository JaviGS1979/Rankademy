-- Rankademy · Fase 5a · Director y entrenador: horario, pasar lista y alumnos de la escuela
--
-- Principios:
--  * Las clases "que tocan" salen del horario del grupo (día de la semana), no de
--    filas creadas a mano: nadie puede inventarse clases ni esconder una falta.
--    Una sesión solo puede existir en un día del horario del grupo.
--  * Una falta solo cuenta si se pasó lista ese día (y el alumno no estaba).
--  * Pasar lista, cancelar clases, inscribir y dar de baja pasan por funciones
--    que comprueban permisos; las escrituras directas en esas tablas se cierran.
--  * Solo el entrenador asignado al grupo y el director pasan lista.
--  * El director puede dar de alta alumnos sin cuenta familiar. La familia los
--    vincula después con un código personal (y da entonces su consentimiento);
--    hasta ese momento el alumno no gana XP ni aparece en rankings.
--  * Los códigos (de escuela y de alumno) tienen un límite de 10 intentos
--    fallidos por hora y persona.

-- ============================================================
-- Utilidades
-- ============================================================
create function privado.hoy()
returns date language sql stable set search_path = '' as $$
  select (now() at time zone 'Europe/Madrid')::date;
$$;

-- Código aleatorio sin I, O, 0 ni 1, con un guion en medio (p. ej. 8 → "K7PA-3QXM")
create function privado.codigo_aleatorio(p_largo integer)
returns text language plpgsql volatile set search_path = '' as $$
declare
  v_alfabeto constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_bytes bytea := uuid_send(gen_random_uuid()) || uuid_send(gen_random_uuid());
  v text := '';
begin
  for i in 0..p_largo - 1 loop
    v := v || substr(v_alfabeto, 1 + (get_byte(v_bytes, i) % length(v_alfabeto)), 1);
    if i = p_largo / 2 - 1 then v := v || '-'; end if;
  end loop;
  return v;
end;
$$;

-- Límite de intentos con códigos: 10 fallos por hora y persona
create table privado.intentos_codigo (
  id bigserial primary key,
  persona_id uuid not null,
  tipo text not null,
  creado_at timestamptz not null default now()
);
create index on privado.intentos_codigo (persona_id, creado_at);
-- Solo la usan las funciones internas; nadie puede leerla desde la app.
alter table privado.intentos_codigo enable row level security;

create function privado.comprobar_intentos()
returns void language plpgsql security definer set search_path = '' as $$
begin
  if (select count(*) from privado.intentos_codigo
      where persona_id = (select auth.uid()) and creado_at > now() - interval '1 hour') >= 10 then
    raise exception 'Demasiados códigos incorrectos. Espera una hora y vuelve a intentarlo.';
  end if;
end;
$$;

create function privado.registrar_intento_fallido(p_tipo text)
returns void language sql security definer set search_path = '' as $$
  insert into privado.intentos_codigo (persona_id, tipo) values ((select auth.uid()), p_tipo);
$$;

-- ============================================================
-- Cambios en tablas
-- ============================================================
-- Grupos: pista opcional y archivo (no se borran: tienen historial)
alter table public.grupos
  add column pista text not null default '' check (length(pista) <= 20),
  add column archivado_at date;

-- Inscripciones: fecha de baja del grupo (null = sigue apuntado)
alter table public.inscripciones
  add column hasta date,
  add constraint inscripciones_fechas_check check (hasta is null or hasta >= desde);

-- Perfiles de alumno dados de alta por la escuela (sin familia todavía)
alter table public.perfiles_alumno
  alter column familia_id drop not null,
  alter column consentimiento_at drop not null,
  add column apellidos text not null default '' check (length(apellidos) <= 60),
  add column codigo_vinculo text unique,
  add column escuela_alta uuid references public.escuelas (id) on delete set null,
  add constraint perfiles_familia_consentimiento_check
    check ((familia_id is null) = (consentimiento_at is null)),
  add constraint perfiles_sin_familia_con_codigo_check
    check (familia_id is not null or codigo_vinculo is not null);

-- Membresía de un alumno sin familia todavía: sin persona
alter table public.membresias
  alter column persona_id drop not null,
  add constraint membresias_persona_check check (rol = 'alumno' or persona_id is not null);

-- El trigger que protege los perfiles admite la vinculación con código
-- (solo la hace la función vincular_alumno: la tabla no deja escribir esas columnas)
create or replace function privado.proteger_perfil()
returns trigger language plpgsql set search_path = '' as $$
begin
  if pg_trigger_depth() > 1 then
    return new;
  end if;
  -- Vinculación: un perfil sin familia pasa a tener familia y consentimiento
  if old.familia_id is null and new.familia_id is not null
     and new.consentimiento_at is not null and new.codigo_vinculo is null then
    return new;
  end if;
  if new.familia_id is distinct from old.familia_id
     or new.persona_id is distinct from old.persona_id
     or new.consentimiento_at is distinct from old.consentimiento_at then
    raise exception 'No se puede cambiar la familia, la cuenta ni el consentimiento de un perfil';
  end if;
  return new;
end;
$$;

-- ============================================================
-- Privilegios: se cierran las escrituras directas sensibles
-- ============================================================
-- Sesiones: solo con sesion_para / cancelar_clase / cerrar_lista
revoke insert, update, delete on public.sesiones from authenticated;
revoke update (fecha, estado) on public.sesiones from authenticated;
drop policy sesiones_crear on public.sesiones;
drop policy sesiones_editar on public.sesiones;
drop policy sesiones_borrar on public.sesiones;

-- Asistencia: solo con marcar_asistencia
revoke insert, delete on public.asistencias from authenticated;
drop policy asistencias_marcar on public.asistencias;
drop policy asistencias_desmarcar on public.asistencias;

-- Inscripciones: solo con inscribir / desinscribir / alta_alumno
revoke insert, delete on public.inscripciones from authenticated;
drop policy inscripciones_crear on public.inscripciones;
drop policy inscripciones_borrar on public.inscripciones;

-- Membresías: solo con resolver_membresia / dejar_escuela
revoke update (estado) on public.membresias from authenticated;
revoke update on public.membresias from authenticated;
drop policy membresias_director on public.membresias;
drop policy membresias_baja on public.membresias;

-- Grupos: el día y la escuela no cambian (otro día = otro grupo); no se borran
revoke insert, update, delete on public.grupos from authenticated;
grant insert (id, escuela_id, nombre, dia, hora, pista, entrenador_id) on public.grupos to authenticated;
grant update (nombre, hora, pista, entrenador_id, archivado_at) on public.grupos to authenticated;
drop policy grupos_borrar on public.grupos;

-- Perfiles: el código de vinculación no lo lee nadie directamente (solo el
-- director, con codigo_alumno), para que nadie se apropie de un alumno
revoke select on public.perfiles_alumno from authenticated;
grant select (id, familia_id, persona_id, nombre, apellidos, anio_nacimiento, nivel, avatar,
              participa_ranking, consentimiento_at, creado_at, escuela_alta)
  on public.perfiles_alumno to authenticated;
revoke insert (id, familia_id, persona_id, nombre, anio_nacimiento, nivel, consentimiento_at, participa_ranking)
  on public.perfiles_alumno from authenticated;
grant insert (id, familia_id, persona_id, nombre, apellidos, anio_nacimiento, nivel, consentimiento_at, participa_ranking)
  on public.perfiles_alumno to authenticated;
grant update (apellidos) on public.perfiles_alumno to authenticated;

-- ============================================================
-- Funciones auxiliares de horario
-- ============================================================
-- La fecha es un día de clase del grupo (su día de la semana, mientras existía)
create function privado.es_dia_de_clase(p_grupo uuid, p_fecha date)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.grupos g
    where g.id = p_grupo
      and extract(isodow from p_fecha) = g.dia
      and p_fecha >= (g.creado_at at time zone 'Europe/Madrid')::date
      and (g.archivado_at is null or p_fecha <= g.archivado_at)
  );
$$;

-- Tras una baja: cierra las inscripciones del alumno o quita al entrenador de sus grupos
create function privado.efectos_baja(p_membresia uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  m public.membresias;
  v_hoy date := privado.hoy();
begin
  select * into m from public.membresias where id = p_membresia;
  if m.perfil_id is not null then
    delete from public.inscripciones i using public.grupos g
    where g.id = i.grupo_id and g.escuela_id = m.escuela_id and i.perfil_id = m.perfil_id and i.desde >= v_hoy;
    update public.inscripciones i set hasta = v_hoy - 1
    from public.grupos g
    where g.id = i.grupo_id and g.escuela_id = m.escuela_id and i.perfil_id = m.perfil_id and i.hasta is null;
  end if;
  if m.rol = 'entrenador' then
    update public.grupos set entrenador_id = null
    where escuela_id = m.escuela_id and entrenador_id = m.persona_id;
  end if;
end;
$$;

-- Inscribe (o reinscribe) a un alumno en un grupo de la escuela indicada
create function privado.inscribir_interno(p_perfil uuid, p_grupo uuid, p_escuela uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  g public.grupos;
begin
  select * into g from public.grupos where id = p_grupo;
  if not found or g.escuela_id <> p_escuela then
    raise exception 'Grupo no válido';
  end if;
  if g.archivado_at is not null then
    raise exception 'El grupo % está archivado', g.nombre;
  end if;
  insert into public.inscripciones (perfil_id, grupo_id, desde, hasta)
  values (p_perfil, p_grupo, privado.hoy(), null)
  on conflict (perfil_id, grupo_id) do update
    set desde = case when public.inscripciones.hasta is null then public.inscripciones.desde else excluded.desde end,
        hasta = null;
end;
$$;

-- Las familias solo ven los grupos en los que su hijo sigue apuntado
create or replace function privado.inscrito_en_grupo(p_grupo uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.inscripciones i
    join public.perfiles_alumno p on p.id = i.perfil_id
    join public.grupos g on g.id = i.grupo_id
    join public.membresias m
      on m.perfil_id = p.id and m.escuela_id = g.escuela_id and m.estado = 'activa'
    where i.grupo_id = p_grupo
      and i.hasta is null
      and (p.familia_id = (select auth.uid()) or p.persona_id = (select auth.uid()))
  );
$$;

-- ============================================================
-- Racha: clases esperadas según el horario
-- ============================================================
create or replace function privado.racha_dias(p_perfil uuid)
returns integer language sql stable security definer set search_path = '' as $$
  with hoy as (select privado.hoy() as d),
  -- Días en que al alumno le tocaba clase: el día de la semana de cada grupo,
  -- desde que se apuntó (y existía el grupo) hasta hoy o su baja
  esperadas as (
    select g.id as grupo_id, f::date as fecha
    from public.inscripciones i
    join public.grupos g on g.id = i.grupo_id
    cross join hoy
    cross join lateral generate_series(
      greatest(i.desde, (g.creado_at at time zone 'Europe/Madrid')::date)::timestamp,
      least(coalesce(i.hasta, hoy.d), coalesce(g.archivado_at, hoy.d), hoy.d)::timestamp,
      interval '1 day') as f
    where i.perfil_id = p_perfil
      and extract(isodow from f) = g.dia
  ),
  sesiones as (
    select s.id, s.grupo_id, s.fecha, s.estado,
      (s.estado = 'impartida' or exists (select 1 from public.asistencias x where x.sesion_id = s.id)) as con_lista
    from public.sesiones s
    where s.grupo_id in (select grupo_id from esperadas)
  ),
  clases as (
    select e.fecha,
      case
        when s.estado = 'cancelada' then 'neutra'
        when a.confirmada_at is not null then 'ok'
        when a.justificada then 'neutra'
        when e.fecha >= (select d from hoy) then 'neutra'                          -- hoy: aún no
        when a.sesion_id is not null and e.fecha >= (select d from hoy) - 14 then 'neutra'  -- falta confirmar
        when a.sesion_id is not null then 'falta'                                  -- sin confirmar a tiempo
        when coalesce(s.con_lista, false) then 'falta'                             -- se pasó lista y no estaba
        else 'neutra'                                                              -- no se pasó lista
      end as estado
    from esperadas e
    left join sesiones s on s.grupo_id = e.grupo_id and s.fecha = e.fecha
    left join public.asistencias a on a.sesion_id = s.id and a.perfil_id = p_perfil
    union all
    -- Clases fuera de su horario (otro grupo, recuperación) confirmadas
    select s.fecha, 'ok'
    from public.asistencias a
    join public.sesiones s on s.id = a.sesion_id
    where a.perfil_id = p_perfil and a.confirmada_at is not null
      and not exists (select 1 from esperadas e where e.grupo_id = s.grupo_id and e.fecha = s.fecha)
  ),
  oks as (
    select fecha from clases
    where estado = 'ok'
      and fecha > coalesce((select max(fecha) from clases where estado = 'falta'), date '0001-01-01')
  )
  select coalesce((select (max(fecha) - min(fecha)) + 1 from oks), 0)::integer;
$$;

-- ============================================================
-- Funciones existentes que cambian
-- ============================================================
-- Unirse con código: límite de intentos fallidos. Con un código que no existe
-- devuelve null (la app muestra "Código de escuela no válido").
create or replace function public.unirse_a_escuela(
  p_codigo text,
  p_rol public.rol_membresia,
  p_perfil uuid default null
)
returns public.membresias
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_escuela uuid;
  v_membresia public.membresias;
begin
  if v_uid is null then
    raise exception 'Necesitas iniciar sesión';
  end if;
  perform privado.comprobar_intentos();
  if p_rol = 'director' then
    raise exception 'El director crea la escuela, no se une a ella';
  end if;
  if (p_rol = 'alumno') <> (p_perfil is not null) then
    raise exception 'Un alumno se une con su perfil; un entrenador, sin perfil';
  end if;
  if p_perfil is not null and not privado.es_mi_perfil(p_perfil) then
    raise exception 'Ese perfil no es tuyo';
  end if;

  select e.id into v_escuela
  from public.escuelas e
  where e.codigo = upper(btrim(coalesce(p_codigo, '')));
  if v_escuela is null then
    -- Se registra el intento y se devuelve null (un error desharía el registro)
    perform privado.registrar_intento_fallido('escuela');
    return null;
  end if;

  select * into v_membresia
  from public.membresias m
  where m.escuela_id = v_escuela and m.rol = p_rol
    and ((p_perfil is null and m.persona_id = v_uid and m.perfil_id is null)
         or m.perfil_id = p_perfil);

  if found then
    -- Si estaba de baja, vuelve a pedir acceso
    if v_membresia.estado = 'baja' then
      update public.membresias set estado = 'pendiente'
      where id = v_membresia.id returning * into v_membresia;
    end if;
    return v_membresia;
  end if;

  insert into public.membresias (persona_id, perfil_id, escuela_id, rol, estado)
  values (v_uid, p_perfil, v_escuela, p_rol, 'pendiente')
  returning * into v_membresia;
  return v_membresia;
end;
$$;


-- XP: las clases semanales son los grupos en los que sigue apuntado
create or replace function public.confirmar_asistencia(p_sesion uuid, p_perfil uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_hoy date := (now() at time zone 'Europe/Madrid')::date;
  v_sesion public.sesiones;
  v_escuela uuid;
  v_dias_para_confirmar constant integer := 14;
  v_xp_semana constant integer := 300;      -- XP de una semana completa
  v_bonus_por_semana constant numeric := 0.10;
  v_bonus_max constant integer := 5;        -- hasta +50 %
  v_clases_semana integer;
  v_racha integer;
  v_xp_antes integer;
  v_ganados integer;
  v_nuevos text[];
begin
  if v_uid is null or not privado.es_mi_perfil(p_perfil) then
    raise exception 'Perfil no encontrado';
  end if;

  select * into v_sesion from public.sesiones where id = p_sesion;
  if not found then
    raise exception 'No hay ninguna asistencia pendiente de confirmar';
  end if;
  if v_sesion.estado = 'cancelada' then
    raise exception 'Esta clase se canceló';
  end if;
  if v_sesion.fecha > v_hoy then
    raise exception 'Solo se puede confirmar una clase cuando ya ha sido';
  end if;
  if v_sesion.fecha < v_hoy - v_dias_para_confirmar then
    raise exception 'El plazo para confirmar esta clase ha terminado';
  end if;

  v_escuela := privado.escuela_de_sesion(p_sesion);
  if not privado.perfil_en_escuela(p_perfil, v_escuela) then
    raise exception 'No hay ninguna asistencia pendiente de confirmar';
  end if;

  v_xp_antes := privado.xp_total(p_perfil);

  update public.asistencias
  set confirmada_por = v_uid, confirmada_at = now()
  where sesion_id = p_sesion and perfil_id = p_perfil
    and confirmada_at is null and not justificada;
  if not found then
    raise exception 'No hay ninguna asistencia pendiente de confirmar';
  end if;

  -- XP: el presupuesto semanal se reparte entre las clases a las que estás apuntado
  select greatest(count(*), 1)::integer into v_clases_semana
  from public.inscripciones i
  join public.grupos g on g.id = i.grupo_id
  where i.perfil_id = p_perfil and i.hasta is null and g.archivado_at is null;
  v_racha := privado.racha_dias(p_perfil);
  v_ganados := round(
    (v_xp_semana::numeric / v_clases_semana)
    * (1 + least(v_racha / 7, v_bonus_max) * v_bonus_por_semana)
  )::integer;

  insert into public.puntos (perfil_id, escuela_id, sesion_id, valor)
  values (p_perfil, v_escuela, p_sesion, v_ganados)
  on conflict (perfil_id, sesion_id) do nothing;

  v_nuevos := privado.desbloquear_mini(p_perfil);

  return jsonb_build_object(
    'xp_ganados', v_ganados,
    'xp_total', v_xp_antes + v_ganados,
    'nivel_antes', privado.nivel_de_xp(v_xp_antes),
    'nivel_despues', privado.nivel_de_xp(v_xp_antes + v_ganados),
    'racha', v_racha,
    'xp_por_nivel', privado.xp_por_nivel(),
    'avatares_nuevos', to_jsonb(v_nuevos)
  );
end;
$$;


-- ============================================================
-- Clases: crear (en un día del horario), cancelar, reactivar, cerrar lista
-- ============================================================
-- Devuelve la sesión del grupo en esa fecha, creándola si hace falta.
-- Solo en días de clase del grupo, desde 14 días atrás hasta 60 días adelante.
create function public.sesion_para(p_grupo uuid, p_fecha date)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_hoy date := privado.hoy();
  v_id uuid;
begin
  if (select auth.uid()) is null or not privado.puede_gestionar_grupo(p_grupo) then
    raise exception 'Grupo no encontrado';
  end if;
  if not privado.es_dia_de_clase(p_grupo, p_fecha) then
    raise exception 'Ese día no hay clase de este grupo';
  end if;
  if p_fecha < v_hoy - 14 or p_fecha > v_hoy + 60 then
    raise exception 'Fecha fuera de plazo';
  end if;

  insert into public.sesiones (grupo_id, fecha, creada_por)
  values (p_grupo, p_fecha, (select auth.uid()))
  on conflict (grupo_id, fecha) do nothing;
  select id into v_id from public.sesiones where grupo_id = p_grupo and fecha = p_fecha;
  return v_id;
end;
$$;

create function public.cancelar_clase(p_grupo uuid, p_fecha date)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_id uuid := public.sesion_para(p_grupo, p_fecha);
begin
  if exists (select 1 from public.asistencias where sesion_id = v_id and confirmada_at is not null) then
    raise exception 'Hay asistencias ya confirmadas por las familias: no se puede cancelar';
  end if;
  delete from public.asistencias where sesion_id = v_id;
  update public.sesiones set estado = 'cancelada' where id = v_id;
  return v_id;
end;
$$;

create function public.reactivar_clase(p_sesion uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.sesiones;
begin
  select * into s from public.sesiones where id = p_sesion;
  if not found or not privado.puede_gestionar_grupo(s.grupo_id) then
    raise exception 'Clase no encontrada';
  end if;
  if s.fecha < privado.hoy() - 14 then
    raise exception 'Fecha fuera de plazo';
  end if;
  update public.sesiones set estado = 'planificada' where id = p_sesion and estado = 'cancelada';
end;
$$;

-- Festivo: cancela todas las clases de la escuela en esa fecha (salvo las que ya
-- tengan asistencias confirmadas). Devuelve cuántas canceló.
create function public.cancelar_dia(p_escuela uuid, p_fecha date)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  g record;
  n integer := 0;
begin
  if not privado.es_director(p_escuela) then
    raise exception 'Solo el director puede cancelar el día';
  end if;
  for g in
    select id from public.grupos
    where escuela_id = p_escuela and privado.es_dia_de_clase(id, p_fecha)
  loop
    begin
      perform public.cancelar_clase(g.id, p_fecha);
      n := n + 1;
    exception when raise_exception then
      null; -- con asistencias confirmadas: se deja como está
    end;
  end loop;
  return n;
end;
$$;

-- "Confirmar lista": la clase queda como impartida
create function public.cerrar_lista(p_sesion uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.sesiones;
begin
  select * into s from public.sesiones where id = p_sesion;
  if not found or not privado.puede_gestionar_grupo(s.grupo_id) then
    raise exception 'Clase no encontrada';
  end if;
  if s.estado = 'cancelada' then
    raise exception 'Esta clase está cancelada';
  end if;
  if s.fecha > privado.hoy() then
    raise exception 'Todavía no ha llegado el día de esta clase';
  end if;
  update public.sesiones set estado = 'impartida' where id = p_sesion;
end;
$$;

-- ============================================================
-- Pasar lista
-- ============================================================
-- p_estado: 'presente', 'justificada' (falta justificada) o 'ninguno' (desmarcar)
create function public.marcar_asistencia(p_sesion uuid, p_perfil uuid, p_estado text)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  s public.sesiones;
  v_hoy date := privado.hoy();
  v_confirmada timestamptz;
begin
  if p_estado not in ('presente', 'justificada', 'ninguno') then
    raise exception 'Estado no válido';
  end if;
  select * into s from public.sesiones where id = p_sesion;
  if not found or not privado.puede_gestionar_grupo(s.grupo_id) then
    raise exception 'Clase no encontrada';
  end if;
  if s.estado = 'cancelada' then
    raise exception 'Esta clase está cancelada';
  end if;
  if s.fecha > v_hoy then
    raise exception 'Todavía no ha llegado el día de esta clase';
  end if;
  if s.fecha < v_hoy - 14 then
    raise exception 'Ya no se puede cambiar la lista de esta clase';
  end if;
  if not privado.perfil_en_escuela(p_perfil, privado.escuela_de_grupo(s.grupo_id)) then
    raise exception 'Ese alumno no es de esta escuela';
  end if;
  if p_estado = 'justificada' and not exists (
    select 1 from public.inscripciones i
    where i.perfil_id = p_perfil and i.grupo_id = s.grupo_id
      and i.desde <= s.fecha and (i.hasta is null or i.hasta >= s.fecha)
  ) then
    raise exception 'Solo se justifica la falta de un alumno del grupo';
  end if;

  select confirmada_at into v_confirmada
  from public.asistencias where sesion_id = p_sesion and perfil_id = p_perfil;
  if v_confirmada is not null then
    raise exception 'La familia ya confirmó esta asistencia: no se puede cambiar';
  end if;

  if p_estado = 'ninguno' then
    delete from public.asistencias where sesion_id = p_sesion and perfil_id = p_perfil;
  else
    insert into public.asistencias (sesion_id, perfil_id, marcada_por, justificada)
    values (p_sesion, p_perfil, (select auth.uid()), p_estado = 'justificada')
    on conflict (sesion_id, perfil_id) do update
      set justificada = excluded.justificada, marcada_por = excluded.marcada_por, marcada_at = now();
  end if;
  return p_estado;
end;
$$;

-- Lista de una clase: alumnos apuntados ese día más los añadidos, con su estado
create function public.lista_de_clase(p_sesion uuid)
returns table (
  perfil_id uuid,
  nombre text,
  apellidos text,
  avatar text,
  inscrito boolean,
  estado text
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
  if not found or not privado.es_staff(privado.escuela_de_grupo(s.grupo_id)) then
    raise exception 'Clase no encontrada';
  end if;
  return query
  with apuntados as (
    select i.perfil_id from public.inscripciones i
    where i.grupo_id = s.grupo_id and i.desde <= s.fecha and (i.hasta is null or i.hasta >= s.fecha)
  ), todos as (
    select ap.perfil_id from apuntados ap
    union
    select a.perfil_id from public.asistencias a where a.sesion_id = p_sesion
  )
  select p.id, p.nombre, p.apellidos, p.avatar,
    exists (select 1 from apuntados ap where ap.perfil_id = p.id),
    case
      when a.confirmada_at is not null then 'confirmada'
      when a.justificada then 'justificada'
      when a.sesion_id is not null then 'presente'
      else null
    end
  from todos t
  join public.perfiles_alumno p on p.id = t.perfil_id
  left join public.asistencias a on a.sesion_id = p_sesion and a.perfil_id = p.id
  order by p.nombre, p.apellidos;
end;
$$;

-- ============================================================
-- Alumnos de la escuela
-- ============================================================
-- El director da de alta a un alumno sin cuenta familiar
create function public.alta_alumno(
  p_escuela uuid,
  p_nombre text,
  p_apellidos text,
  p_anio integer,
  p_grupos uuid[] default '{}'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_edad integer := extract(year from privado.hoy())::integer - p_anio;
  v_codigo text;
  v_perfil uuid;
  g uuid;
begin
  if (select auth.uid()) is null or not privado.es_director(p_escuela) then
    raise exception 'Solo el director puede inscribir alumnos';
  end if;
  if length(btrim(coalesce(p_nombre, ''))) = 0 then
    raise exception 'El nombre es obligatorio';
  end if;
  if p_anio is null or v_edad < 3 or v_edad > 17 then
    raise exception 'El año debe corresponder a una edad de 3 a 17 años';
  end if;

  loop
    v_codigo := privado.codigo_aleatorio(8);
    exit when not exists (select 1 from public.perfiles_alumno where codigo_vinculo = v_codigo);
  end loop;

  insert into public.perfiles_alumno
    (familia_id, nombre, apellidos, anio_nacimiento, nivel, consentimiento_at, codigo_vinculo, escuela_alta)
  values
    (null, btrim(p_nombre), btrim(coalesce(p_apellidos, '')), p_anio,
     case when v_edad <= 7 then 'mini'::public.nivel_alumno else 'gamer'::public.nivel_alumno end,
     null, v_codigo, p_escuela)
  returning id into v_perfil;

  insert into public.membresias (persona_id, perfil_id, escuela_id, rol, estado)
  values (null, v_perfil, p_escuela, 'alumno', 'activa');

  foreach g in array coalesce(p_grupos, '{}') loop
    perform privado.inscribir_interno(v_perfil, g, p_escuela);
  end loop;

  return jsonb_build_object('perfil_id', v_perfil, 'codigo', v_codigo);
end;
$$;

-- Código para que la familia vincule a un alumno dado de alta por la escuela
-- (solo lo ve el director). p_nuevo = true genera uno nuevo.
create function public.codigo_alumno(p_perfil uuid, p_nuevo boolean default false)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_codigo text;
begin
  if (select auth.uid()) is null or not exists (
    select 1 from public.membresias m
    where m.perfil_id = p_perfil and m.estado <> 'baja' and privado.es_director(m.escuela_id)
  ) then
    raise exception 'Alumno no encontrado';
  end if;
  select codigo_vinculo into v_codigo from public.perfiles_alumno where id = p_perfil;
  if v_codigo is null then
    raise exception 'Este alumno ya está vinculado a su familia';
  end if;
  if p_nuevo then
    loop
      v_codigo := privado.codigo_aleatorio(8);
      exit when not exists (select 1 from public.perfiles_alumno where codigo_vinculo = v_codigo);
    end loop;
    update public.perfiles_alumno set codigo_vinculo = v_codigo where id = p_perfil;
  end if;
  return v_codigo;
end;
$$;

-- La familia vincula al alumno con su código y da su consentimiento
create function public.vincular_alumno(p_codigo text, p_acepto boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_limpio text := upper(regexp_replace(coalesce(p_codigo, ''), '[^A-Za-z0-9]', '', 'g'));
  v_perfil public.perfiles_alumno;
begin
  if v_uid is null then
    raise exception 'Necesitas iniciar sesión';
  end if;
  if not coalesce(p_acepto, false) then
    raise exception 'Hace falta tu consentimiento como adulto responsable';
  end if;
  perform privado.comprobar_intentos();

  select * into v_perfil from public.perfiles_alumno
  where length(v_limpio) = 8 and codigo_vinculo = substr(v_limpio, 1, 4) || '-' || substr(v_limpio, 5, 4);
  if not found then
    perform privado.registrar_intento_fallido('alumno');
    return null;
  end if;

  update public.perfiles_alumno
  set familia_id = v_uid, consentimiento_at = now(), codigo_vinculo = null
  where id = v_perfil.id;
  update public.membresias set persona_id = v_uid where perfil_id = v_perfil.id and persona_id is null;

  return jsonb_build_object('perfil_id', v_perfil.id, 'nombre', v_perfil.nombre);
end;
$$;

create function public.inscribir(p_perfil uuid, p_grupo uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_escuela uuid := privado.escuela_de_grupo(p_grupo);
begin
  if (select auth.uid()) is null or v_escuela is null or not privado.es_director(v_escuela) then
    raise exception 'Grupo no encontrado';
  end if;
  if not privado.perfil_en_escuela(p_perfil, v_escuela) then
    raise exception 'El alumno no es de esta escuela';
  end if;
  perform privado.inscribir_interno(p_perfil, p_grupo, v_escuela);
end;
$$;

create function public.desinscribir(p_perfil uuid, p_grupo uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_escuela uuid := privado.escuela_de_grupo(p_grupo);
  v_hoy date := privado.hoy();
begin
  if (select auth.uid()) is null or v_escuela is null or not privado.es_director(v_escuela) then
    raise exception 'Grupo no encontrado';
  end if;
  -- Apuntado hoy mismo: no hay historial que guardar
  delete from public.inscripciones where perfil_id = p_perfil and grupo_id = p_grupo and desde >= v_hoy;
  update public.inscripciones set hasta = v_hoy - 1
  where perfil_id = p_perfil and grupo_id = p_grupo and hasta is null;
end;
$$;

-- ============================================================
-- Membresías: aprobar / dar de baja (director) y dejar la escuela (uno mismo)
-- ============================================================
create or replace function public.resolver_membresia(p_membresia uuid, p_aprobar boolean)
returns public.membresias
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_m public.membresias;
begin
  select * into v_m from public.membresias where id = p_membresia;
  if not found or not privado.es_director(v_m.escuela_id) then
    raise exception 'Solicitud no encontrada';
  end if;
  if v_m.rol = 'director' then
    raise exception 'No se puede cambiar la membresía de un director';
  end if;

  update public.membresias
  set estado = case when p_aprobar then 'activa'::public.estado_membresia
                    else 'baja'::public.estado_membresia end
  where id = p_membresia
  returning * into v_m;
  if not p_aprobar then
    perform privado.efectos_baja(p_membresia);
  end if;
  return v_m;
end;
$$;

create function public.dejar_escuela(p_membresia uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  m public.membresias;
begin
  select * into m from public.membresias where id = p_membresia;
  if not found or not (m.persona_id = (select auth.uid()) or privado.es_mi_perfil(m.perfil_id)) then
    raise exception 'No encontrada';
  end if;
  if m.rol = 'director' and m.estado = 'activa' and (
    select count(*) from public.membresias
    where escuela_id = m.escuela_id and rol = 'director' and estado = 'activa'
  ) <= 1 then
    raise exception 'Eres el único director de la escuela: no puedes dejarla';
  end if;
  update public.membresias set estado = 'baja' where id = p_membresia;
  perform privado.efectos_baja(p_membresia);
end;
$$;

-- ============================================================
-- Permisos
-- ============================================================
do $$
declare f text;
begin
  foreach f in array array[
    'public.sesion_para(uuid, date)', 'public.cancelar_clase(uuid, date)', 'public.reactivar_clase(uuid)',
    'public.cancelar_dia(uuid, date)', 'public.cerrar_lista(uuid)', 'public.marcar_asistencia(uuid, uuid, text)',
    'public.lista_de_clase(uuid)', 'public.alta_alumno(uuid, text, text, integer, uuid[])',
    'public.codigo_alumno(uuid, boolean)', 'public.vincular_alumno(text, boolean)',
    'public.inscribir(uuid, uuid)', 'public.desinscribir(uuid, uuid)', 'public.dejar_escuela(uuid)',
    'public.resolver_membresia(uuid, boolean)', 'public.unirse_a_escuela(text, public.rol_membresia, uuid)',
    'public.confirmar_asistencia(uuid, uuid)'
  ] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
grant execute on all functions in schema privado to authenticated;
revoke execute on all functions in schema privado from anon, public;
