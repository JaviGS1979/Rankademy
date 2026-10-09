# Supabase

## Aplicar las migraciones (primera vez)

En el panel de Supabase → **SQL Editor** → **New query**. Pega y ejecuta (**Run**), **en este orden**, el contenido de:

1. `migrations/0001_esquema.sql` — tablas
2. `migrations/0002_acceso_rls.sql` — reglas de acceso (RLS)
3. `migrations/0003_funciones.sql` — funciones (crear escuela, unirse con código, confirmar asistencia…)

Cada una debe terminar con "Success. No rows returned". Si falla una, no ejecutes las siguientes y copia el error.

## Fundador

El rol de fundador no se puede asignar desde la app. Tras registrarte, ejecuta en el SQL Editor:

```sql
insert into public.fundadores (persona_id)
select id from auth.users where email = 'tu-correo@ejemplo.com';
```

## Pruebas de seguridad (opcional, en local)

`tests/run.sh` aplica las migraciones sobre un PostgreSQL local vacío (simulando `auth.users`/`auth.uid()` de Supabase) y comprueba aislamiento entre escuelas, familias y roles. No toca tu proyecto de Supabase.
