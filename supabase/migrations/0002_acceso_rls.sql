-- Rankademy · Fase 2 · Reglas de acceso (RLS)
--
-- Principios:
--  * Todo está cerrado por defecto: sin política no se ve ni se escribe nada.
--  * El rol anónimo (sin sesión) no accede a ninguna tabla.
--  * Cada persona ve lo suyo; el director gestiona solo su escuela; el
--    entrenador ve su escuela; la familia ve solo a sus hijos.
--  * Las escrituras sensibles (crear escuela, unirse con código, aprobar,
--    confirmar asistencia, dar puntos) pasan por funciones de 0003, nunca
--    por escritura directa.

-- ============================================================
-- Funciones auxiliares (esquema privado, no expuesto por la API)
-- ============================================================
create schema if not exists privado;
revoke all on schema privado from public;
grant usage on schema privado to authenticated;

-- Todas son SECURITY DEFINER con search_path vacío para poder
-- consultar las tablas sin entrar en bucle con sus propias políticas.

create function privado.es_miembro(p_escuela uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.membresias m
    where m.escuela_id = p_escuela
      and m.persona_id = (select auth.uid())
      and m.estado in ('pendiente', 'activa')
  );
$$;

create function privado.es_director(p_escuela uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.membresias m
    where m.escuela_id = p_escuela
      and m.persona_id = (select auth.uid())
      and m.rol = 'director' and m.estado = 'activa'
  );
$$;

-- Director o entrenador activo de la escuela
create function privado.es_staff(p_escuela uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.membresias m
    where m.escuela_id = p_escuela
      and m.persona_id = (select auth.uid())
      and m.rol in ('director', 'entrenador') and m.estado = 'activa'
  );
$$;

create function privado.es_staff_en_alguna()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.membresias m
    where m.persona_id = (select auth.uid())
      and m.rol in ('director', 'entrenador') and m.estado = 'activa'
  );
$$;

create function privado.es_entrenador_de(p_persona uuid, p_escuela uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.membresias m
    where m.escuela_id = p_escuela and m.persona_id = p_persona
      and m.rol = 'entrenador' and m.estado = 'activa'
  );
$$;

-- El perfil es de mi familia o es mi propia cuenta
create function privado.es_mi_perfil(p_perfil uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.perfiles_alumno p
    where p.id = p_perfil
      and (p.familia_id = (select auth.uid()) or p.persona_id = (select auth.uid()))
  );
$$;

-- El perfil pertenece (pendiente o activo) a una escuela donde soy staff
create function privado.perfil_visible_staff(p_perfil uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.membresias m
    where m.perfil_id = p_perfil
      and m.estado in ('pendiente', 'activa')
      and privado.es_staff(m.escuela_id)
  );
$$;

create function privado.perfil_en_escuela(p_perfil uuid, p_escuela uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.membresias m
    where m.perfil_id = p_perfil and m.escuela_id = p_escuela
      and m.estado = 'activa'
  );
$$;

create function privado.escuela_de_grupo(p_grupo uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select g.escuela_id from public.grupos g where g.id = p_grupo;
$$;

create function privado.escuela_de_sesion(p_sesion uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select g.escuela_id
  from public.sesiones s join public.grupos g on g.id = s.grupo_id
  where s.id = p_sesion;
$$;

create function privado.grupo_de_sesion(p_sesion uuid)
returns uuid language sql stable security definer set search_path = '' as $$
  select s.grupo_id from public.sesiones s where s.id = p_sesion;
$$;

-- Alguno de mis perfiles está inscrito en el grupo
create function privado.inscrito_en_grupo(p_grupo uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.inscripciones i
    join public.perfiles_alumno p on p.id = i.perfil_id
    where i.grupo_id = p_grupo
      and (p.familia_id = (select auth.uid()) or p.persona_id = (select auth.uid()))
  );
$$;

-- Director de la escuela, o el entrenador asignado al grupo
create function privado.puede_gestionar_grupo(p_grupo uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.grupos g
    where g.id = p_grupo
      and (privado.es_director(g.escuela_id)
           or (g.entrenador_id = (select auth.uid())
               and privado.es_staff(g.escuela_id)))
  );
$$;

create function privado.es_autor_de(p_ejercicio uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.ejercicios e
    where e.id = p_ejercicio and e.autor_id = (select auth.uid())
  );
$$;

-- Quién puede ver un ejercicio (para sus imágenes y para usarlo en una sesión):
--  * su autor;
--  * cualquier entrenador/director, si es público;
--  * los miembros de la escuela, si es "solo mi escuela";
--  * el alumno cuyo grupo lo usa en una sesión.
create function privado.puede_ver_ejercicio(p_ejercicio uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.ejercicios e
    where e.id = p_ejercicio
      and (
        e.autor_id = (select auth.uid())
        or (e.visibilidad = 'publica' and privado.es_staff_en_alguna())
        or (e.visibilidad = 'escuela' and privado.es_staff(e.escuela_id))
        or exists (
          select 1 from public.usos_ejercicio u
          join public.sesiones s on s.id = u.sesion_id
          where u.ejercicio_id = e.id
            and privado.inscrito_en_grupo(s.grupo_id)
        )
      )
  );
$$;

-- Lectura DIRECTA de la tabla ejercicios (incluye autor_id): solo el autor,
-- la escuela si es "solo mi escuela" y la clase que lo usa. Los ejercicios
-- públicos de otros se consultan por biblioteca_ejercicios(), que es anónima.
create function privado.puede_leer_ejercicio(p_ejercicio uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.ejercicios e
    where e.id = p_ejercicio
      and (
        e.autor_id = (select auth.uid())
        or (e.visibilidad = 'escuela' and privado.es_staff(e.escuela_id))
        or exists (
          select 1 from public.usos_ejercicio u
          join public.sesiones s on s.id = u.sesion_id
          where u.ejercicio_id = e.id
            and privado.inscrito_en_grupo(s.grupo_id)
        )
      )
  );
$$;

-- Ver el nombre de otra persona: yo mismo; o compartimos escuela y alguno de
-- los dos es staff (el staff ve a sus miembros; los miembros ven a su staff).
create function privado.puede_ver_persona(p_persona uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_persona = (select auth.uid())
  or exists (
    select 1
    from public.membresias otra
    join public.membresias yo
      on yo.escuela_id = otra.escuela_id
     and yo.persona_id = (select auth.uid())
     and yo.estado = 'activa'
    where otra.persona_id = p_persona
      and otra.estado in ('pendiente', 'activa')
      and (
        yo.rol in ('director', 'entrenador')
        or (otra.rol in ('director', 'entrenador') and otra.estado = 'activa')
      )
  );
$$;

grant execute on all functions in schema privado to authenticated;
revoke execute on all functions in schema privado from anon, public;

-- ============================================================
-- Privilegios de tabla: nada para anónimos; lo mínimo para autenticados
-- ============================================================
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;

grant select on public.personas, public.fundadores, public.perfiles_alumno,
  public.escuelas, public.membresias, public.grupos, public.inscripciones,
  public.sesiones, public.asistencias, public.ejercicios,
  public.ejercicio_imagenes, public.usos_ejercicio, public.puntos,
  public.avatares_desbloqueados, public.logros
  to authenticated;

grant update (nombre) on public.personas to authenticated;
grant insert, update, delete on public.perfiles_alumno to authenticated;
grant update (nombre, ciudad, provincia, comunidad, logo_url, participa_ranking)
  on public.escuelas to authenticated;
-- Solo se puede cambiar el estado (aprobar, dar de baja); el resto no.
grant update (estado) on public.membresias to authenticated;
grant insert, update, delete on public.grupos to authenticated;
grant insert, delete on public.inscripciones to authenticated;
grant insert, update, delete on public.sesiones to authenticated;
-- La asistencia se marca (insert) o se desmarca (delete); la confirmación
-- pasa por la función confirmar_asistencia.
grant insert, delete on public.asistencias to authenticated;
grant insert, update, delete on public.ejercicios to authenticated;
grant insert, update, delete on public.ejercicio_imagenes to authenticated;
grant insert, delete on public.usos_ejercicio to authenticated;

-- ============================================================
-- Activar RLS en todas las tablas
-- ============================================================
alter table public.personas enable row level security;
alter table public.fundadores enable row level security;
alter table public.perfiles_alumno enable row level security;
alter table public.escuelas enable row level security;
alter table public.membresias enable row level security;
alter table public.grupos enable row level security;
alter table public.inscripciones enable row level security;
alter table public.sesiones enable row level security;
alter table public.asistencias enable row level security;
alter table public.ejercicios enable row level security;
alter table public.ejercicio_imagenes enable row level security;
alter table public.usos_ejercicio enable row level security;
alter table public.puntos enable row level security;
alter table public.avatares_desbloqueados enable row level security;
alter table public.logros enable row level security;

-- ============================================================
-- Políticas
-- ============================================================

-- personas
create policy personas_ver on public.personas for select to authenticated
  using (privado.puede_ver_persona(id));
create policy personas_editar on public.personas for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- fundadores: solo se puede comprobar uno mismo
create policy fundadores_yo on public.fundadores for select to authenticated
  using (persona_id = (select auth.uid()));

-- perfiles_alumno
create policy perfiles_ver on public.perfiles_alumno for select to authenticated
  using (familia_id = (select auth.uid())
         or persona_id = (select auth.uid())
         or privado.perfil_visible_staff(id));
create policy perfiles_crear on public.perfiles_alumno for insert to authenticated
  with check (familia_id = (select auth.uid())
              and (persona_id is null or persona_id = (select auth.uid())));
create policy perfiles_editar on public.perfiles_alumno for update to authenticated
  using (familia_id = (select auth.uid()) or persona_id = (select auth.uid()))
  with check (familia_id = (select auth.uid()) or persona_id = (select auth.uid()));
create policy perfiles_borrar on public.perfiles_alumno for delete to authenticated
  using (familia_id = (select auth.uid()));

-- escuelas (crear = función crear_escuela)
create policy escuelas_ver on public.escuelas for select to authenticated
  using (privado.es_miembro(id));
create policy escuelas_editar on public.escuelas for update to authenticated
  using (privado.es_director(id)) with check (privado.es_director(id));

-- membresías (unirse y aprobar = funciones; aquí solo leer y cambiar estado)
create policy membresias_ver on public.membresias for select to authenticated
  using (persona_id = (select auth.uid())
         or privado.es_mi_perfil(perfil_id)
         or privado.es_staff(escuela_id));
create policy membresias_director on public.membresias for update to authenticated
  using (privado.es_director(escuela_id)) with check (privado.es_director(escuela_id));
-- Cada persona (o su familia) puede darse de baja, pero no reactivarse
create policy membresias_baja on public.membresias for update to authenticated
  using (persona_id = (select auth.uid()) or privado.es_mi_perfil(perfil_id))
  with check (estado = 'baja');

-- grupos
create policy grupos_ver on public.grupos for select to authenticated
  using (privado.es_staff(escuela_id) or privado.inscrito_en_grupo(id));
create policy grupos_crear on public.grupos for insert to authenticated
  with check (privado.es_director(escuela_id)
              and (entrenador_id is null
                   or privado.es_entrenador_de(entrenador_id, escuela_id)));
create policy grupos_editar on public.grupos for update to authenticated
  using (privado.es_director(escuela_id))
  with check (privado.es_director(escuela_id)
              and (entrenador_id is null
                   or privado.es_entrenador_de(entrenador_id, escuela_id)));
create policy grupos_borrar on public.grupos for delete to authenticated
  using (privado.es_director(escuela_id));

-- inscripciones
create policy inscripciones_ver on public.inscripciones for select to authenticated
  using (privado.es_staff(privado.escuela_de_grupo(grupo_id))
         or privado.es_mi_perfil(perfil_id));
create policy inscripciones_crear on public.inscripciones for insert to authenticated
  with check (privado.es_director(privado.escuela_de_grupo(grupo_id))
              and privado.perfil_en_escuela(perfil_id, privado.escuela_de_grupo(grupo_id)));
create policy inscripciones_borrar on public.inscripciones for delete to authenticated
  using (privado.es_director(privado.escuela_de_grupo(grupo_id)));

-- sesiones
create policy sesiones_ver on public.sesiones for select to authenticated
  using (privado.es_staff(privado.escuela_de_grupo(grupo_id))
         or privado.inscrito_en_grupo(grupo_id));
create policy sesiones_crear on public.sesiones for insert to authenticated
  with check (privado.puede_gestionar_grupo(grupo_id)
              and creada_por = (select auth.uid()));
create policy sesiones_editar on public.sesiones for update to authenticated
  using (privado.puede_gestionar_grupo(grupo_id))
  with check (privado.puede_gestionar_grupo(grupo_id));
create policy sesiones_borrar on public.sesiones for delete to authenticated
  using (privado.puede_gestionar_grupo(grupo_id));

-- asistencias: el entrenador marca; la confirmación es una función
create policy asistencias_ver on public.asistencias for select to authenticated
  using (privado.es_staff(privado.escuela_de_sesion(sesion_id))
         or privado.es_mi_perfil(perfil_id));
create policy asistencias_marcar on public.asistencias for insert to authenticated
  with check (
    marcada_por = (select auth.uid())
    and confirmada_por is null and confirmada_at is null
    and privado.puede_gestionar_grupo(privado.grupo_de_sesion(sesion_id))
    and privado.perfil_en_escuela(perfil_id, privado.escuela_de_sesion(sesion_id))
  );
create policy asistencias_desmarcar on public.asistencias for delete to authenticated
  using (confirmada_at is null
         and privado.puede_gestionar_grupo(privado.grupo_de_sesion(sesion_id)));

-- ejercicios (la biblioteca pública se lista por la vista anónima de 0003)
create policy ejercicios_ver on public.ejercicios for select to authenticated
  using (privado.puede_leer_ejercicio(id));
create policy ejercicios_crear on public.ejercicios for insert to authenticated
  with check (
    autor_id = (select auth.uid())
    and privado.es_staff_en_alguna()
    and (visibilidad = 'publica' or privado.es_staff(escuela_id))
  );
create policy ejercicios_editar on public.ejercicios for update to authenticated
  using (autor_id = (select auth.uid()))
  with check (autor_id = (select auth.uid())
              and (visibilidad = 'publica' or privado.es_staff(escuela_id)));
create policy ejercicios_borrar on public.ejercicios for delete to authenticated
  using (autor_id = (select auth.uid()));

create policy imagenes_ver on public.ejercicio_imagenes for select to authenticated
  using (privado.puede_ver_ejercicio(ejercicio_id));
create policy imagenes_escribir on public.ejercicio_imagenes for insert to authenticated
  with check (privado.es_autor_de(ejercicio_id));
create policy imagenes_editar on public.ejercicio_imagenes for update to authenticated
  using (privado.es_autor_de(ejercicio_id)) with check (privado.es_autor_de(ejercicio_id));
create policy imagenes_borrar on public.ejercicio_imagenes for delete to authenticated
  using (privado.es_autor_de(ejercicio_id));

-- usos de ejercicio en una sesión
create policy usos_ver on public.usos_ejercicio for select to authenticated
  using (privado.es_staff(privado.escuela_de_sesion(sesion_id))
         or privado.inscrito_en_grupo(privado.grupo_de_sesion(sesion_id)));
create policy usos_crear on public.usos_ejercicio for insert to authenticated
  with check (privado.puede_gestionar_grupo(privado.grupo_de_sesion(sesion_id))
              and privado.puede_ver_ejercicio(ejercicio_id));
create policy usos_borrar on public.usos_ejercicio for delete to authenticated
  using (privado.puede_gestionar_grupo(privado.grupo_de_sesion(sesion_id)));

-- puntos, avatares y logros: solo lectura (los escriben las funciones)
create policy puntos_ver on public.puntos for select to authenticated
  using (privado.es_mi_perfil(perfil_id) or privado.es_staff(escuela_id));
create policy avatares_ver on public.avatares_desbloqueados for select to authenticated
  using (privado.es_mi_perfil(perfil_id));
create policy logros_ver on public.logros for select to authenticated
  using (privado.es_mi_perfil(perfil_id));

-- ============================================================
-- Datos inmutables de los perfiles de alumno
-- ============================================================
create function privado.proteger_perfil()
returns trigger language plpgsql set search_path = '' as $$
begin
  if new.familia_id is distinct from old.familia_id
     or new.persona_id is distinct from old.persona_id
     or new.consentimiento_at is distinct from old.consentimiento_at then
    raise exception 'No se puede cambiar la familia, la cuenta ni el consentimiento de un perfil';
  end if;
  return new;
end;
$$;

create trigger perfiles_inmutables
  before update on public.perfiles_alumno
  for each row execute function privado.proteger_perfil();
