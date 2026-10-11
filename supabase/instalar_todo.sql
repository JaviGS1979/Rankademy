-- Rankademy · INSTALACIÓN COMPLETA (0001 a 0005)
-- Archivo generado: une las migraciones de migrations/ en orden. Pégalo entero en
-- Supabase → SQL Editor → Run, SOLO en un proyecto vacío (primera instalación).
-- Si ya ejecutaste 0001-0004, ejecuta solo migrations/0005_alumno.sql.


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
