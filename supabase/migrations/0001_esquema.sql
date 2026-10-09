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
