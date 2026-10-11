-- Rankademy · INSTALACIÓN COMPLETA (0001 a 0007)
-- Archivo generado: une las migraciones de migrations/ en orden. Pégalo entero en
-- Supabase → SQL Editor → Run, SOLO en un proyecto vacío (primera instalación).
-- Si ya ejecutaste 0001-0006, ejecuta solo migrations/0007_biblioteca.sql.


-- >>>>> migrations/0001_esquema.sql
-- Rankademy · Fase 2 · Esquema base
-- Ejecutar en orden: 0001 (esquema) → 0002 (acceso/RLS) → 0003 (funciones).

-- ============================================================
-- Tipos
-- ============================================================
create type public.rol_membresia as enum ('director', 'entrenador', 'alumno');
create type public.estado_membresia as enum ('pendiente', 'activa', 'baja');
create type public.nivel_alumno as enum ('mini', 'gamer');
create type public.visibilidad_ejercicio as enum ('publica', 'escuela');
create type public.estado_sesion as enum ('planificada', 'impartida', 'cancelada');

-- ============================================================
-- Personas
-- ============================================================
-- Una cuenta por persona. El correo vive en auth.users (no se duplica aquí
-- para no exponerlo a otros usuarios).
create table public.personas (
  id uuid primary key references auth.users (id) on delete cascade,
  nombre text not null default '',
  creada_at timestamptz not null default now()
);

-- Fundador de la plataforma (dashboard). Sin políticas de escritura:
-- solo se rellena a mano desde el panel de Supabase.
create table public.fundadores (
  persona_id uuid primary key references public.personas (id) on delete cascade
);

-- Perfil de alumno: un hijo gestionado por un adulto (familia), o una cuenta
-- propia (persona_id) a partir de los 14 años.
create table public.perfiles_alumno (
  id uuid primary key default gen_random_uuid(),
  familia_id uuid not null references public.personas (id) on delete cascade,
  persona_id uuid unique references public.personas (id) on delete set null,
  nombre text not null check (length(btrim(nombre)) > 0),
  anio_nacimiento smallint not null
    check (anio_nacimiento between 1900 and 2100),
  nivel public.nivel_alumno not null,
  avatar text,
  participa_ranking boolean not null default true,
  -- Consentimiento de la familia, obligatorio para cualquier perfil de menor
  consentimiento_at timestamptz not null,
  creado_at timestamptz not null default now()
);
create index on public.perfiles_alumno (familia_id);

-- ============================================================
-- Escuelas y membresías
-- ============================================================
create table public.escuelas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null check (length(btrim(nombre)) > 0),
  ciudad text not null default '',
  provincia text not null default '',
  comunidad text not null default '',
  pais text not null default 'ES',
  logo_url text,
  codigo text not null unique,
  participa_ranking boolean not null default true,
  creada_por uuid not null references public.personas (id),
  creada_at timestamptz not null default now()
);

-- La escuela es una membresía: se une con el código y el director aprueba.
-- Los adultos (director, entrenador, familia) tienen perfil_id nulo;
-- un alumno se une a través de su perfil.
create table public.membresias (
  id uuid primary key default gen_random_uuid(),
  persona_id uuid not null references public.personas (id) on delete cascade,
  perfil_id uuid references public.perfiles_alumno (id) on delete cascade,
  escuela_id uuid not null references public.escuelas (id) on delete cascade,
  rol public.rol_membresia not null,
  estado public.estado_membresia not null default 'pendiente',
  creada_at timestamptz not null default now(),
  check ((rol = 'alumno') = (perfil_id is not null))
);
create unique index membresias_adulto_uq
  on public.membresias (escuela_id, persona_id, rol) where perfil_id is null;
create unique index membresias_perfil_uq
  on public.membresias (escuela_id, perfil_id) where perfil_id is not null;
create index on public.membresias (persona_id);

-- ============================================================
-- Grupos, sesiones y asistencia
-- ============================================================
-- Grupo = un día + una hora, con nombre libre elegido por el director.
create table public.grupos (
  id uuid primary key default gen_random_uuid(),
  escuela_id uuid not null references public.escuelas (id) on delete cascade,
  nombre text not null check (length(btrim(nombre)) > 0),
  dia smallint not null check (dia between 1 and 7), -- 1 = lunes
  hora time not null,
  entrenador_id uuid references public.personas (id) on delete set null,
  creado_at timestamptz not null default now()
);
create index on public.grupos (escuela_id);

create table public.inscripciones (
  perfil_id uuid not null references public.perfiles_alumno (id) on delete cascade,
  grupo_id uuid not null references public.grupos (id) on delete cascade,
  primary key (perfil_id, grupo_id)
);
create index on public.inscripciones (grupo_id);

create table public.sesiones (
  id uuid primary key default gen_random_uuid(),
  grupo_id uuid not null references public.grupos (id) on delete cascade,
  fecha date not null,
  estado public.estado_sesion not null default 'planificada',
  creada_por uuid references public.personas (id) on delete set null,
  unique (grupo_id, fecha)
);

-- Asistencia en dos pasos: la marca el entrenador y la confirma el alumno o
-- su familia. Solo entonces hay XP y logros.
create table public.asistencias (
  sesion_id uuid not null references public.sesiones (id) on delete cascade,
  perfil_id uuid not null references public.perfiles_alumno (id) on delete cascade,
  marcada_por uuid not null references public.personas (id),
  marcada_at timestamptz not null default now(),
  confirmada_por uuid references public.personas (id),
  confirmada_at timestamptz,
  primary key (sesion_id, perfil_id),
  check ((confirmada_por is null) = (confirmada_at is null))
);
create index on public.asistencias (perfil_id);

-- ============================================================
-- Ejercicios
-- ============================================================
create table public.ejercicios (
  id uuid primary key default gen_random_uuid(),
  autor_id uuid not null references public.personas (id),
  escuela_id uuid references public.escuelas (id) on delete cascade,
  visibilidad public.visibilidad_ejercicio not null default 'publica',
  titulo text not null check (length(btrim(titulo)) > 0),
  jugadores_min smallint not null check (jugadores_min >= 1),
  jugadores_max smallint not null,
  edad_min smallint,
  edad_max smallint,
  -- Huella del dibujo (también en espejo) para detectar duplicados al subir
  huella text,
  -- Si es variante, apunta al ejercicio original (el crédito es del primero)
  original_id uuid references public.ejercicios (id) on delete set null,
  creado_at timestamptz not null default now(),
  check (jugadores_max >= jugadores_min),
  check (edad_max is null or edad_min is null or edad_max >= edad_min),
  check (visibilidad = 'publica' or escuela_id is not null)
);
create index on public.ejercicios (autor_id);
create index on public.ejercicios (huella);
create index on public.ejercicios (original_id);

-- Varias imágenes por ejercicio; el dibujo es un SVG (viewBox 240×140)
-- sobre la pista.
create table public.ejercicio_imagenes (
  id uuid primary key default gen_random_uuid(),
  ejercicio_id uuid not null references public.ejercicios (id) on delete cascade,
  orden smallint not null default 0,
  dibujo text not null,
  unique (ejercicio_id, orden)
);

create table public.usos_ejercicio (
  sesion_id uuid not null references public.sesiones (id) on delete cascade,
  ejercicio_id uuid not null references public.ejercicios (id) on delete cascade,
  primary key (sesion_id, ejercicio_id)
);
create index on public.usos_ejercicio (ejercicio_id);

-- ============================================================
-- Puntos, avatares y logros (pertenecen a la persona/perfil)
-- ============================================================
-- Cada escuela suma solo las clases hechas en ella. En los rankings
-- territoriales el alumno aparece una vez, con su total.
create table public.puntos (
  id uuid primary key default gen_random_uuid(),
  perfil_id uuid not null references public.perfiles_alumno (id) on delete cascade,
  escuela_id uuid not null references public.escuelas (id) on delete cascade,
  sesion_id uuid not null references public.sesiones (id) on delete cascade,
  valor integer not null check (valor >= 0),
  creado_at timestamptz not null default now(),
  unique (perfil_id, sesion_id)
);
create index on public.puntos (escuela_id);

create table public.avatares_desbloqueados (
  perfil_id uuid not null references public.perfiles_alumno (id) on delete cascade,
  avatar text not null,
  desbloqueado_at timestamptz not null default now(),
  primary key (perfil_id, avatar)
);

create table public.logros (
  perfil_id uuid not null references public.perfiles_alumno (id) on delete cascade,
  logro text not null,
  logrado_at timestamptz not null default now(),
  primary key (perfil_id, logro)
);

-- ============================================================
-- Alta automática de la persona al registrarse
-- ============================================================
create function public.nueva_persona()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.personas (id, nombre)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'nombre', ''));
  return new;
end;
$$;

create trigger al_crear_usuario
  after insert on auth.users
  for each row execute function public.nueva_persona();

-- >>>>> migrations/0002_acceso_rls.sql
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

-- >>>>> migrations/0003_funciones.sql
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

-- >>>>> migrations/0004_revision.sql
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

-- >>>>> migrations/0005_alumno.sql
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

-- >>>>> migrations/0006_entrenador.sql
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

-- >>>>> migrations/0007_biblioteca.sql
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
