-- Rankademy · Fase 4 · Alumno: XP, nivel, racha por días y avatares con precio
--
-- Reglas (valores iniciales; las constantes están al principio de cada función
-- y los precios en la tabla `avatares`, para ajustarlos sin tocar la app):
--
--  XP
--   * Asistir a todas tus clases de la semana da 300 XP a cualquier alumno.
--     Cada clase vale 300 / (nº de grupos a los que estás apuntado), así que
--     quien va 1 día y quien va 5 compiten en igualdad: la frecuencia depende
--     del plan, no del esfuerzo del niño.
--   * Bonus de racha: +10 % por cada 7 días de racha, hasta +50 %.
--   * Nivel: 1 + XP ganado / 1000. El XP gastado en avatares no baja el nivel.
--
--  Racha (en días)
--   * Días naturales entre la primera y la última clase de una serie sin faltas
--     (una semana perfecta son 7 días, vaya 1 o 5 días a la semana).
--   * No rompen la racha: clases canceladas, faltas justificadas (las marca el
--     entrenador), clases de hoy o aún por confirmar (14 días de plazo) y las
--     clases anteriores a que el alumno se apuntara al grupo.
--   * Sí la rompe una clase programada, pasada, sin asistencia confirmada.
--
--  Avatares
--   * 2 gratuitos (av01 y av08); el resto cuesta XP. Se compran con el saldo
--     (XP ganado − XP gastado). Los perfiles Mini (hasta 7 años) no compran:
--     desbloquean solos los que alcanza su XP ganado.

-- ============================================================
-- Cambios en tablas existentes
-- ============================================================
-- Falta justificada: la marca el entrenador; no da XP ni rompe la racha.
alter table public.asistencias
  add column justificada boolean not null default false,
  add constraint asistencias_justificada_check check (not (justificada and confirmada_at is not null));

-- Desde cuándo está apuntado el alumno al grupo: las clases anteriores no cuentan.
alter table public.inscripciones
  add column desde date not null default ((now() at time zone 'Europe/Madrid')::date);

-- ============================================================
-- Catálogo de avatares
-- ============================================================
create table public.avatares (
  id text primary key,
  orden smallint not null unique,
  nombre text not null check (length(btrim(nombre)) > 0),
  precio_xp integer not null check (precio_xp >= 0)
);

-- Precios iniciales (editables):  update public.avatares set precio_xp = 500 where id = 'av05';
-- Orden: primero los gratuitos y después de menor a mayor precio.
insert into public.avatares (id, orden, nombre, precio_xp) values
  ('av01', 1,  'Blazira', 0),    ('av08', 2,  'Drixa', 0),
  ('av02', 3,  'Bruno', 300),    ('av03', 4,  'Klax', 400),     ('av04', 5,  'Kron', 500),
  ('av05', 6,  'Terrio', 500),   ('av06', 7,  'Nira', 600),     ('av07', 8,  'Ivora', 900),
  ('av09', 9,  'Sael', 1000),    ('av10', 10, 'Zora', 1200),    ('av11', 11, 'Vandara', 1400),
  ('av12', 12, 'Naro', 1500),    ('av13', 13, 'Vexon', 1600),   ('av14', 14, 'Havy', 1800),
  ('av19', 15, 'Lyn', 2000),     ('av15', 16, 'Yvan', 3000),    ('av16', 17, 'Martiny', 3500),
  ('av17', 18, 'Mureno', 4000),  ('av18', 19, 'Yaizy', 4500),   ('av20', 20, 'Zephyr', 5000);

alter table public.avatares enable row level security;
revoke all on public.avatares from anon, authenticated;
grant select on public.avatares to authenticated;
create policy avatares_catalogo on public.avatares for select to authenticated using (true);

-- Lo que costó cada avatar al conseguirlo (0 = gratuito o desbloqueo automático)
alter table public.avatares_desbloqueados
  add column precio_pagado integer not null default 0 check (precio_pagado >= 0);

-- ============================================================
-- Funciones de cálculo (privadas)
-- ============================================================
create function privado.xp_por_nivel()
returns integer language sql immutable set search_path = '' as $$ select 1000; $$;

create function privado.nivel_de_xp(p_xp integer)
returns integer language sql immutable set search_path = '' as $$
  select 1 + greatest(p_xp, 0) / privado.xp_por_nivel();
$$;

-- Perfil Mini: hasta 7 años según el año de nacimiento (no se guarda: cambia solo)
create function privado.es_mini(p_perfil uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce(
    (extract(year from (now() at time zone 'Europe/Madrid'))::integer - p.anio_nacimiento) <= 7, false)
  from public.perfiles_alumno p where p.id = p_perfil;
$$;

create function privado.xp_total(p_perfil uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce(sum(valor), 0)::integer from public.puntos where perfil_id = p_perfil;
$$;

create function privado.xp_gastado(p_perfil uuid)
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce(sum(precio_pagado), 0)::integer from public.avatares_desbloqueados where perfil_id = p_perfil;
$$;

-- Días de la racha actual
create function privado.racha_dias(p_perfil uuid)
returns integer language sql stable security definer set search_path = '' as $$
  with hoy as (select (now() at time zone 'Europe/Madrid')::date as d),
  clases as (
    select s.fecha,
      case
        when a.confirmada_at is not null then 'ok'
        when a.justificada then 'justificada'
        when s.fecha >= (select d from hoy) then 'pendiente'
        when a.sesion_id is not null and s.fecha >= (select d from hoy) - 14 then 'pendiente'
        else 'falta'
      end as estado
    from public.sesiones s
    left join public.inscripciones i on i.grupo_id = s.grupo_id and i.perfil_id = p_perfil
    left join public.asistencias a on a.sesion_id = s.id and a.perfil_id = p_perfil
    where s.estado <> 'cancelada'
      and ((i.perfil_id is not null and s.fecha >= i.desde) or a.perfil_id is not null)
  ), oks as (
    select fecha from clases
    where estado = 'ok'
      and fecha > coalesce((select max(fecha) from clases where estado = 'falta'), date '0001-01-01')
  )
  select coalesce((select (max(fecha) - min(fecha)) + 1 from oks), 0)::integer;
$$;

-- Avatares gratuitos
create function privado.desbloquear_gratis(p_perfil uuid)
returns void language sql security definer set search_path = '' as $$
  insert into public.avatares_desbloqueados (perfil_id, avatar)
  select p_perfil, a.id from public.avatares a where a.precio_xp = 0
  on conflict do nothing;
$$;

-- Perfil Mini: desbloquea solo los avatares que alcanza su XP ganado; devuelve los nuevos
create function privado.desbloquear_mini(p_perfil uuid)
returns text[] language plpgsql security definer set search_path = '' as $$
declare
  v_nuevos text[];
begin
  if not privado.es_mini(p_perfil) then
    return '{}';
  end if;
  with ins as (
    insert into public.avatares_desbloqueados (perfil_id, avatar)
    select p_perfil, a.id from public.avatares a
    where a.precio_xp <= privado.xp_total(p_perfil)
    on conflict do nothing
    returning avatar
  )
  select coalesce(array_agg(avatar order by avatar), '{}') into v_nuevos from ins;
  return v_nuevos;
end;
$$;

-- ============================================================
-- Perfiles nuevos: avatar inicial y gratuitos desbloqueados
-- ============================================================
create function privado.perfil_nuevo()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform privado.desbloquear_gratis(new.id);
  update public.perfiles_alumno set avatar = 'av01' where id = new.id and avatar is null;
  return null;
end;
$$;

create trigger perfiles_alta
  after insert on public.perfiles_alumno
  for each row execute function privado.perfil_nuevo();

-- Perfiles que ya existían
select privado.desbloquear_gratis(id) from public.perfiles_alumno;
update public.perfiles_alumno set avatar = 'av01' where avatar is null;

-- El avatar solo se cambia con elegir_avatar (debe estar desbloqueado):
-- ya no se puede escribir directamente en la tabla.
revoke insert, update on public.perfiles_alumno from authenticated;
grant insert (id, familia_id, persona_id, nombre, anio_nacimiento, nivel, consentimiento_at, participa_ranking)
  on public.perfiles_alumno to authenticated;
grant update (nombre, nivel, participa_ranking) on public.perfiles_alumno to authenticated;

-- ============================================================
-- Confirmar asistencia: da XP, actualiza la racha y desbloquea (Mini)
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
  from public.inscripciones where perfil_id = p_perfil;
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
  v_saldo integer;
  v_clases integer;
  v_sig_id text;
  v_sig_precio integer;
begin
  if (select auth.uid()) is null or not privado.es_mi_perfil(p_perfil) then
    raise exception 'Perfil no encontrado';
  end if;

  v_xp := privado.xp_total(p_perfil);
  v_saldo := v_xp - privado.xp_gastado(p_perfil);
  select count(*)::integer into v_clases
  from public.asistencias where perfil_id = p_perfil and confirmada_at is not null;

  -- El avatar más barato que aún no tiene
  select a.id, a.precio_xp into v_sig_id, v_sig_precio
  from public.avatares a
  where not exists (select 1 from public.avatares_desbloqueados d
                    where d.perfil_id = p_perfil and d.avatar = a.id)
  order by a.precio_xp, a.orden limit 1;

  return jsonb_build_object(
    'xp', v_xp,
    'saldo', v_saldo,
    'nivel', privado.nivel_de_xp(v_xp),
    'xp_en_nivel', v_xp % privado.xp_por_nivel(),
    'xp_por_nivel', privado.xp_por_nivel(),
    'clases', v_clases,
    'racha', privado.racha_dias(p_perfil),
    'siguiente_avatar', case when v_sig_id is null then null
      else jsonb_build_object('id', v_sig_id, 'precio', v_sig_precio,
                              'faltan', greatest(v_sig_precio - v_saldo, 0)) end
  );
end;
$$;

-- ============================================================
-- Conseguir un avatar con XP
-- ============================================================
create function public.comprar_avatar(p_perfil uuid, p_avatar text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_precio integer;
  v_saldo integer;
begin
  if (select auth.uid()) is null or not privado.es_mi_perfil(p_perfil) then
    raise exception 'Perfil no encontrado';
  end if;

  -- Bloquea el perfil para que dos compras a la vez no gasten el mismo XP
  perform 1 from public.perfiles_alumno where id = p_perfil for update;

  if privado.es_mini(p_perfil) then
    raise exception 'Los avatares de los Mini se desbloquean solos al ganar XP';
  end if;
  select precio_xp into v_precio from public.avatares where id = p_avatar;
  if not found then
    raise exception 'Ese avatar no existe';
  end if;
  if exists (select 1 from public.avatares_desbloqueados where perfil_id = p_perfil and avatar = p_avatar) then
    raise exception 'Ya tienes ese avatar';
  end if;

  v_saldo := privado.xp_total(p_perfil) - privado.xp_gastado(p_perfil);
  if v_saldo < v_precio then
    raise exception 'Te faltan % XP para conseguir este avatar', v_precio - v_saldo;
  end if;

  insert into public.avatares_desbloqueados (perfil_id, avatar, precio_pagado)
  values (p_perfil, p_avatar, v_precio);

  return jsonb_build_object('saldo', v_saldo - v_precio, 'precio', v_precio);
end;
$$;

-- ============================================================
-- Elegir avatar (solo entre los que ya tienes)
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
    raise exception 'Todavía no tienes ese avatar';
  end if;
  update public.perfiles_alumno set avatar = p_avatar where id = p_perfil;
end;
$$;

-- ============================================================
-- Permisos
-- ============================================================
revoke execute on function public.confirmar_asistencia(uuid, uuid) from public, anon;
revoke execute on function public.mi_progreso(uuid) from public, anon;
revoke execute on function public.comprar_avatar(uuid, text) from public, anon;
revoke execute on function public.elegir_avatar(uuid, text) from public, anon;
grant execute on function public.confirmar_asistencia(uuid, uuid) to authenticated;
grant execute on function public.mi_progreso(uuid) to authenticated;
grant execute on function public.comprar_avatar(uuid, text) to authenticated;
grant execute on function public.elegir_avatar(uuid, text) to authenticated;
grant execute on all functions in schema privado to authenticated;
revoke execute on all functions in schema privado from anon, public;
