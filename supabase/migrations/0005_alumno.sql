-- Rankademy · Fase 4 · Alumno: XP, nivel, racha y avatares
--
-- Reglas (valores iniciales, todas en este archivo para poder ajustarlas):
--  * XP por clase confirmada: 100, más 10 por cada semana de racha por encima
--    de la primera, hasta +50.
--  * Nivel: 1 + XP / 250 (cada nivel cuesta 250 XP).
--  * Racha: semanas seguidas (lunes a domingo) con al menos una clase
--    confirmada. Sigue viva si la última semana con clase es la actual o la
--    anterior.
--  * Avatares: los 4 primeros son gratuitos; del 5 al 15 se desbloquean por
--    número de clases confirmadas y los 3 últimos por racha.

-- ============================================================
-- Catálogo de avatares
-- ============================================================
create table public.avatares (
  id text primary key,
  orden smallint not null unique,
  clases_min integer check (clases_min >= 0),
  racha_min integer check (racha_min > 0),
  check (clases_min is not null or racha_min is not null)
);

insert into public.avatares (id, orden, clases_min, racha_min) values
  ('av01', 1, 0, null), ('av02', 2, 0, null), ('av03', 3, 0, null), ('av04', 4, 0, null),
  ('av05', 5, 5, null), ('av06', 6, 8, null), ('av07', 7, 10, null), ('av08', 8, 15, null),
  ('av09', 9, 20, null), ('av10', 10, 25, null), ('av11', 11, 30, null), ('av12', 12, 35, null),
  ('av13', 13, 40, null), ('av14', 14, 45, null), ('av15', 15, 50, null),
  ('av16', 16, null, 10), ('av17', 17, null, 20), ('av18', 18, null, 50);

alter table public.avatares enable row level security;
revoke all on public.avatares from anon, authenticated;
grant select on public.avatares to authenticated;
create policy avatares_catalogo on public.avatares for select to authenticated using (true);

-- ============================================================
-- Funciones de cálculo (privadas)
-- ============================================================
create function privado.nivel_de_xp(p_xp integer)
returns integer language sql immutable set search_path = '' as $$
  select 1 + greatest(p_xp, 0) / 250;
$$;

-- Semanas seguidas con clase confirmada
create function privado.racha_semanas(p_perfil uuid)
returns integer language sql stable security definer set search_path = '' as $$
  with semanas as (
    select distinct date_trunc('week', s.fecha)::date as w
    from public.asistencias a
    join public.sesiones s on s.id = a.sesion_id
    where a.perfil_id = p_perfil and a.confirmada_at is not null
  ), numeradas as (
    select w, w - (row_number() over (order by w))::integer * 7 as grupo from semanas
  ), islas as (
    select count(*) as n, max(w) as ultima from numeradas group by grupo
  )
  select coalesce((
    select n::integer from islas
    where ultima >= date_trunc('week', (now() at time zone 'Europe/Madrid')::date)::date - 7
    order by ultima desc limit 1
  ), 0);
$$;

create function privado.xp_total(p_perfil uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce(sum(valor), 0)::integer from public.puntos where perfil_id = p_perfil;
$$;

-- Desbloquea los avatares que ya le corresponden y devuelve los nuevos
create function privado.desbloquear_avatares(p_perfil uuid)
returns text[] language plpgsql security definer set search_path = '' as $$
declare
  v_clases integer;
  v_racha integer;
  v_nuevos text[];
begin
  select count(*)::integer into v_clases
  from public.asistencias where perfil_id = p_perfil and confirmada_at is not null;
  v_racha := privado.racha_semanas(p_perfil);

  with ins as (
    insert into public.avatares_desbloqueados (perfil_id, avatar)
    select p_perfil, a.id from public.avatares a
    where (a.clases_min is not null and v_clases >= a.clases_min)
       or (a.racha_min is not null and v_racha >= a.racha_min)
    on conflict do nothing
    returning avatar
  )
  select coalesce(array_agg(avatar order by avatar), '{}') into v_nuevos from ins;
  return v_nuevos;
end;
$$;

-- ============================================================
-- Perfiles nuevos: avatar inicial y los gratuitos desbloqueados
-- ============================================================
create function privado.perfil_nuevo()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform privado.desbloquear_avatares(new.id);
  update public.perfiles_alumno set avatar = 'av01' where id = new.id and avatar is null;
  return null;
end;
$$;

create trigger perfiles_alta
  after insert on public.perfiles_alumno
  for each row execute function privado.perfil_nuevo();

-- Perfiles que ya existían
select privado.desbloquear_avatares(id) from public.perfiles_alumno;
update public.perfiles_alumno set avatar = 'av01' where avatar is null;

-- El avatar solo se cambia con elegir_avatar (debe estar desbloqueado):
-- ya no se puede escribir directamente en la tabla.
revoke insert, update on public.perfiles_alumno from authenticated;
grant insert (id, familia_id, persona_id, nombre, anio_nacimiento, nivel, consentimiento_at, participa_ranking)
  on public.perfiles_alumno to authenticated;
grant update (nombre, nivel, participa_ranking) on public.perfiles_alumno to authenticated;

-- ============================================================
-- Confirmar asistencia: da XP, actualiza racha y desbloquea avatares
-- ============================================================
drop function public.confirmar_asistencia(uuid, uuid);

create function public.confirmar_asistencia(p_sesion uuid, p_perfil uuid)
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
  v_xp_base constant integer := 100;
  v_xp_por_semana_de_racha constant integer := 10;
  v_xp_max_bonus constant integer := 50;
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
  where sesion_id = p_sesion and perfil_id = p_perfil and confirmada_at is null;
  if not found then
    raise exception 'No hay ninguna asistencia pendiente de confirmar';
  end if;

  v_racha := privado.racha_semanas(p_perfil);
  v_ganados := v_xp_base + least(greatest(v_racha - 1, 0) * v_xp_por_semana_de_racha, v_xp_max_bonus);

  insert into public.puntos (perfil_id, escuela_id, sesion_id, valor)
  values (p_perfil, v_escuela, p_sesion, v_ganados)
  on conflict (perfil_id, sesion_id) do nothing;

  v_nuevos := privado.desbloquear_avatares(p_perfil);

  return jsonb_build_object(
    'xp_ganados', v_ganados,
    'xp_total', v_xp_antes + v_ganados,
    'nivel_antes', privado.nivel_de_xp(v_xp_antes),
    'nivel_despues', privado.nivel_de_xp(v_xp_antes + v_ganados),
    'racha', v_racha,
    'avatares_nuevos', to_jsonb(v_nuevos)
  );
end;
$$;

-- ============================================================
-- Progreso del alumno (para Inicio, Progreso y Avatares)
-- ============================================================
create function public.mi_progreso(p_perfil uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_xp integer;
  v_clases integer;
  v_proximo integer;
begin
  if (select auth.uid()) is null or not privado.es_mi_perfil(p_perfil) then
    raise exception 'Perfil no encontrado';
  end if;

  v_xp := privado.xp_total(p_perfil);
  select count(*)::integer into v_clases
  from public.asistencias where perfil_id = p_perfil and confirmada_at is not null;

  -- Clases que faltan para el siguiente avatar de los que se ganan por clases
  select min(a.clases_min) - v_clases into v_proximo
  from public.avatares a
  where a.clases_min is not null and a.clases_min > v_clases
    and not exists (select 1 from public.avatares_desbloqueados d
                    where d.perfil_id = p_perfil and d.avatar = a.id);

  return jsonb_build_object(
    'xp', v_xp,
    'nivel', privado.nivel_de_xp(v_xp),
    'xp_en_nivel', v_xp % 250,
    'xp_por_nivel', 250,
    'clases', v_clases,
    'racha', privado.racha_semanas(p_perfil),
    'clases_para_siguiente_avatar', v_proximo
  );
end;
$$;

-- ============================================================
-- Elegir avatar (solo entre los desbloqueados)
-- ============================================================
create function public.elegir_avatar(p_perfil uuid, p_avatar text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (select auth.uid()) is null or not privado.es_mi_perfil(p_perfil) then
    raise exception 'Perfil no encontrado';
  end if;
  if not exists (select 1 from public.avatares_desbloqueados
                 where perfil_id = p_perfil and avatar = p_avatar) then
    raise exception 'Todavía no has desbloqueado ese avatar';
  end if;
  update public.perfiles_alumno set avatar = p_avatar where id = p_perfil;
end;
$$;

-- ============================================================
-- Permisos
-- ============================================================
revoke execute on function public.confirmar_asistencia(uuid, uuid) from public, anon;
revoke execute on function public.mi_progreso(uuid) from public, anon;
revoke execute on function public.elegir_avatar(uuid, text) from public, anon;
grant execute on function public.confirmar_asistencia(uuid, uuid) to authenticated;
grant execute on function public.mi_progreso(uuid) to authenticated;
grant execute on function public.elegir_avatar(uuid, text) to authenticated;
grant execute on all functions in schema privado to authenticated;
revoke execute on all functions in schema privado from anon, public;
