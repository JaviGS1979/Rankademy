# Supabase

## Aplicar las migraciones (primera vez)

En el panel de Supabase → **SQL Editor** → **New query**. Pega y ejecuta (**Run**), **en este orden**, el contenido de:

1. `migrations/0001_esquema.sql` — tablas
2. `migrations/0002_acceso_rls.sql` — reglas de acceso (RLS)
3. `migrations/0003_funciones.sql` — funciones (crear escuela, unirse con código, confirmar asistencia…)
4. `migrations/0004_revision.sql` — correcciones de la revisión (borrado de cuenta, historial de puntos, plazos de confirmación…)

Si ya ejecutaste 0001-0003, ejecuta solo la 0004.

Cada una debe terminar con "Success. No rows returned". Si falla una, no ejecutes las siguientes y copia el error.

## Fundador

El rol de fundador no se puede asignar desde la app. Tras registrarte, ejecuta en el SQL Editor:

```sql
insert into public.fundadores (persona_id)
select id from auth.users where email = 'tu-correo@ejemplo.com';
```

## Pruebas de seguridad (opcional, en local)

`tests/run.sh` aplica las migraciones sobre un PostgreSQL local vacío (simulando `auth.users`/`auth.uid()` de Supabase) y comprueba aislamiento entre escuelas, familias y roles. No toca tu proyecto de Supabase.

## Al añadir tablas nuevas

Supabase concede por defecto acceso a las tablas nuevas de `public` a `anon` y `authenticated`. Cada migración que cree una tabla debe:

1. `alter table … enable row level security;`
2. `revoke all on … from anon, authenticated;` y conceder solo lo necesario.
3. Añadir sus pruebas en `tests/10_seguridad.sql` (hay una prueba que falla si alguna tabla de `public` no tiene RLS).
