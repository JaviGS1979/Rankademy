-- Rankademy · Fase 2 · Revisión de seguridad e integridad
-- Se ejecuta después de 0001-0003. Corrige problemas encontrados al revisarlas.

-- ============================================================
-- 1. Borrado de cuenta (derecho de supresión)
-- ============================================================
-- Antes, borrar la cuenta de un director, de un entrenador que pasó lista o
-- del autor de un ejercicio fallaba por claves foráneas sin ON DELETE.
-- Ahora la cuenta se borra y esos registros quedan sin autor (anónimos).

alter table public.escuelas alter column creada_por drop not null;
alter table public.escuelas drop constraint escuelas_creada_por_fkey,
  add constraint escuelas_creada_por_fkey foreign key (creada_por)
    references public.personas (id) on delete set null;

alter table public.ejercicios alter column autor_id drop not null;
alter table public.ejercicios drop constraint ejercicios_autor_id_fkey,
  add constraint ejercicios_autor_id_fkey foreign key (autor_id)
    references public.personas (id) on delete set null;

alter table public.asistencias alter column marcada_por drop not null;
alter table public.asistencias drop constraint asistencias_marcada_por_fkey,
  add constraint asistencias_marcada_por_fkey foreign key (marcada_por)
    references public.personas (id) on delete set null;
alter table public.asistencias drop constraint asistencias_confirmada_por_fkey,
  add constraint asistencias_confirmada_por_fkey foreign key (confirmada_por)
    references public.personas (id) on delete set null;
-- La confirmación la determina confirmada_at; quien confirmó puede borrarse.
alter table public.asistencias drop constraint asistencias_check,
  add constraint asistencias_confirmacion_check
    check (confirmada_por is null or confirmada_at is not null);

-- Antes, el trigger que protege los perfiles impedía que se borrara la cuenta
-- propia de un alumno de 14+ (el borrado pone persona_id a NULL). Las acciones
-- en cascada se ejecutan como triggers anidados: se permiten.
create or replace function privado.proteger_perfil()
returns trigger language plpgsql set search_path = '' as $$
begin
  if pg_trigger_depth() > 1 then
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
-- 2. Historial de puntos protegido
-- ============================================================
-- Antes, borrar una sesión (o un grupo) borraba en cascada las asistencias
-- confirmadas y los puntos ganados. Ahora no se puede borrar una clase que ya
-- dio puntos; se marca como cancelada si hace falta.
alter table public.puntos drop constraint puntos_sesion_id_fkey,
  add constraint puntos_sesion_id_fkey foreign key (sesion_id)
    references public.sesiones (id) on delete no action;

-- Una sesión no se puede mover a otro grupo (lo que movería sus puntos).
revoke update on public.sesiones from authenticated;
grant update (fecha, estado) on public.sesiones to authenticated;

-- ============================================================
-- 3. Confirmar asistencia solo de clases reales y recientes
-- ============================================================
-- Antes se podían confirmar sesiones futuras o canceladas, lo que permitía
-- inflar puntos creando clases con fechas arbitrarias.
create or replace function public.confirmar_asistencia(p_sesion uuid, p_perfil uuid)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_hoy date := (now() at time zone 'Europe/Madrid')::date;
  v_sesion public.sesiones;
  v_escuela uuid;
  v_puntos constant integer := 10;
  v_dias_para_confirmar constant integer := 14;
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
  -- El alumno debe seguir siendo de la escuela
  if not privado.perfil_en_escuela(p_perfil, v_escuela) then
    raise exception 'No hay ninguna asistencia pendiente de confirmar';
  end if;

  update public.asistencias
  set confirmada_por = v_uid, confirmada_at = now()
  where sesion_id = p_sesion and perfil_id = p_perfil and confirmada_at is null;
  if not found then
    raise exception 'No hay ninguna asistencia pendiente de confirmar';
  end if;

  insert into public.puntos (perfil_id, escuela_id, sesion_id, valor)
  values (p_perfil, v_escuela, p_sesion, v_puntos)
  on conflict (perfil_id, sesion_id) do nothing;

  return v_puntos;
end;
$$;

-- ============================================================
-- 4. Tras una baja, la familia deja de ver el grupo
-- ============================================================
-- Antes, una familia dada de baja seguía viendo el grupo, sus sesiones y sus
-- ejercicios porque la inscripción no se comprobaba contra la membresía.
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
      and (p.familia_id = (select auth.uid()) or p.persona_id = (select auth.uid()))
  );
$$;

-- ============================================================
-- 5. Un ejercicio solo puede asociarse a una escuela propia
-- ============================================================
-- Antes, un ejercicio público podía llevar el escuela_id de cualquier escuela.
drop policy ejercicios_crear on public.ejercicios;
create policy ejercicios_crear on public.ejercicios for insert to authenticated
  with check (
    autor_id = (select auth.uid())
    and privado.es_staff_en_alguna()
    and (escuela_id is null or privado.es_staff(escuela_id))
  );
drop policy ejercicios_editar on public.ejercicios;
create policy ejercicios_editar on public.ejercicios for update to authenticated
  using (autor_id = (select auth.uid()))
  with check (autor_id = (select auth.uid())
              and (escuela_id is null or privado.es_staff(escuela_id)));

-- ============================================================
-- 6. Límites de longitud (evita textos enormes en nombres)
-- ============================================================
alter table public.personas add constraint personas_nombre_largo check (length(nombre) <= 80);
alter table public.perfiles_alumno add constraint perfiles_nombre_largo check (length(nombre) <= 40);
alter table public.escuelas add constraint escuelas_nombre_largo check (length(nombre) <= 80);
alter table public.grupos add constraint grupos_nombre_largo check (length(nombre) <= 60);
alter table public.ejercicios add constraint ejercicios_titulo_largo check (length(titulo) <= 80);
alter table public.ejercicio_imagenes add constraint imagenes_dibujo_largo check (length(dibujo) <= 200000);

-- El nombre del registro viene del cliente: se recorta.
create or replace function public.nueva_persona()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.personas (id, nombre)
  values (new.id, left(btrim(coalesce(new.raw_user_meta_data ->> 'nombre', '')), 80));
  return new;
end;
$$;

-- ============================================================
-- 7. Rendimiento de las reglas de acceso
-- ============================================================
-- Varias políticas buscan membresías por perfil_id.
create index if not exists membresias_perfil_idx on public.membresias (perfil_id);
create index if not exists grupos_entrenador_idx on public.grupos (entrenador_id);
