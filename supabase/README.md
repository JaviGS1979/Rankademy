# Supabase

## Aplicar las migraciones (primera vez)

Atajo: en un proyecto vacío basta con ejecutar `instalar_todo.sql`, que une las cinco migraciones en orden (es un archivo generado; las fuentes son las de `migrations/`).

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

## Acceso por correo con código (Fase 3)

La app entra sin contraseña: Supabase envía un **código de 6 cifras** al correo. Por defecto Supabase envía un enlace, no un código, así que hay que cambiar dos plantillas:

**Authentication → Emails → Templates**, en **Confirm signup** y en **Magic Link**, sustituye el contenido por:

```html
<h2>Tu código de Rankademy</h2>
<p>Escribe este código en la app:</p>
<p style="font-size:32px;font-weight:bold;letter-spacing:6px">{{ .Token }}</p>
<p>Caduca en una hora. Si no lo has pedido, ignora este correo.</p>
```

El servidor de correo incluido en Supabase es solo para pruebas: envía pocos correos por hora y únicamente a direcciones del equipo del proyecto. Antes de invitar a otras personas hay que configurar un SMTP propio (Authentication → Emails → SMTP Settings; por ejemplo Resend o Brevo).

## Reglas del alumno (0005)

Todas están en `migrations/0005_alumno.sql`, para poder ajustarlas en un solo sitio:

| Regla | Valor inicial |
|---|---|
| XP por clase confirmada | 100, más 10 por cada semana de racha por encima de la primera (máx. +50) |
| Nivel | 1 + XP / 250 |
| Racha | semanas seguidas (lunes a domingo) con al menos una clase confirmada; sigue viva si la última es la semana actual o la anterior |
| Avatares | 4 gratuitos; del 5 al 15 por clases confirmadas (5, 8, 10, 15, 20 … 50); 16-18 por racha (10, 20, 50 semanas) |

Para cambiar el XP por clase o el coste de un nivel, edita `confirmar_asistencia` y `nivel_de_xp`/`mi_progreso` (el 250 aparece en esas dos funciones).
