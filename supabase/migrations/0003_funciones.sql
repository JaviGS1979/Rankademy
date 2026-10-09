-- Rankademy · Fase 2 · Funciones de la aplicación (RPC)
--
-- Las operaciones sensibles no se escriben directamente en las tablas:
-- pasan por estas funciones, que comprueban quién llama y qué puede hacer.

-- ============================================================
-- Crear escuela (el que llama pasa a ser director)
-- ============================================================
create function public.crear_escuela(
  p_nombre text,
  p_ciudad text default '',
  p_provincia text default '',
  p_comunidad text default ''
)
returns public.escuelas
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  -- Sin 0/O/1/I para evitar confusiones al dictar el código
  v_alfabeto constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_codigo text;
  v_bytes bytea;
  v_escuela public.escuelas;
begin
  if v_uid is null then
    raise exception 'Necesitas iniciar sesión';
  end if;
  if length(btrim(coalesce(p_nombre, ''))) = 0 then
    raise exception 'El nombre de la escuela es obligatorio';
  end if;

  loop
    -- Aleatoriedad criptográfica sin depender de pgcrypto
    v_bytes := uuid_send(gen_random_uuid());
    v_codigo := '';
    for i in 0..5 loop
      v_codigo := v_codigo
        || substr(v_alfabeto, 1 + (get_byte(v_bytes, i) % length(v_alfabeto)), 1);
      if i = 2 then v_codigo := v_codigo || '-'; end if;
    end loop;
    exit when not exists (select 1 from public.escuelas where codigo = v_codigo);
  end loop;

  insert into public.escuelas (nombre, ciudad, provincia, comunidad, codigo, creada_por)
  values (btrim(p_nombre), btrim(p_ciudad), btrim(p_provincia), btrim(p_comunidad),
          v_codigo, v_uid)
  returning * into v_escuela;

  insert into public.membresias (persona_id, escuela_id, rol, estado)
  values (v_uid, v_escuela.id, 'director', 'activa');

  return v_escuela;
end;
$$;

-- ============================================================
-- Unirse a una escuela con su código (el director debe aprobar)
-- ============================================================
create function public.unirse_a_escuela(
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
    raise exception 'Código de escuela no válido';
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

-- ============================================================
-- Aprobar o rechazar una solicitud (solo el director)
-- ============================================================
create function public.resolver_membresia(p_membresia uuid, p_aprobar boolean)
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
  return v_m;
end;
$$;

-- ============================================================
-- Confirmar asistencia (alumno o familia) → da los puntos
-- ============================================================
-- Valor inicial por clase; ajustable.
create function public.confirmar_asistencia(p_sesion uuid, p_perfil uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_escuela uuid;
  v_puntos constant integer := 10;
begin
  if v_uid is null or not privado.es_mi_perfil(p_perfil) then
    raise exception 'Perfil no encontrado';
  end if;

  update public.asistencias
  set confirmada_por = v_uid, confirmada_at = now()
  where sesion_id = p_sesion and perfil_id = p_perfil and confirmada_at is null;
  if not found then
    raise exception 'No hay ninguna asistencia pendiente de confirmar';
  end if;

  v_escuela := privado.escuela_de_sesion(p_sesion);
  insert into public.puntos (perfil_id, escuela_id, sesion_id, valor)
  values (p_perfil, v_escuela, p_sesion, v_puntos)
  on conflict (perfil_id, sesion_id) do nothing;

  return v_puntos;
end;
$$;

-- ============================================================
-- Biblioteca pública: lista anónima (sin autor) con el total de usos
-- ============================================================
-- Los usos de las variantes se suman al ejercicio original.
create function public.biblioteca_ejercicios()
returns table (
  id uuid,
  titulo text,
  jugadores_min smallint,
  jugadores_max smallint,
  edad_min smallint,
  edad_max smallint,
  original_id uuid,
  usos bigint,
  creado_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select e.id, e.titulo, e.jugadores_min, e.jugadores_max, e.edad_min, e.edad_max,
         e.original_id,
         (select count(*) from public.usos_ejercicio u
          join public.ejercicios v on v.id = u.ejercicio_id
          where v.id = e.id or v.original_id = e.id) as usos,
         e.creado_at
  from public.ejercicios e
  where e.visibilidad = 'publica'
    and privado.es_staff_en_alguna();
$$;

-- ============================================================
-- Permisos: solo usuarios con sesión
-- ============================================================
revoke execute on function public.crear_escuela(text, text, text, text) from public, anon;
revoke execute on function public.unirse_a_escuela(text, public.rol_membresia, uuid) from public, anon;
revoke execute on function public.resolver_membresia(uuid, boolean) from public, anon;
revoke execute on function public.confirmar_asistencia(uuid, uuid) from public, anon;
revoke execute on function public.biblioteca_ejercicios() from public, anon;
revoke execute on function public.nueva_persona() from public, anon, authenticated;

grant execute on function public.crear_escuela(text, text, text, text) to authenticated;
grant execute on function public.unirse_a_escuela(text, public.rol_membresia, uuid) to authenticated;
grant execute on function public.resolver_membresia(uuid, boolean) to authenticated;
grant execute on function public.confirmar_asistencia(uuid, uuid) to authenticated;
grant execute on function public.biblioteca_ejercicios() to authenticated;
