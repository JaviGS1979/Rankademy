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

Las constantes están al principio de las funciones de `migrations/0005_alumno.sql` y los precios en la tabla `avatares`, para ajustarlos sin tocar la app.

| Regla | Valor inicial |
|---|---|
| XP de una semana completa | 300 (se reparte entre las clases a las que está apuntado el alumno: 1 clase/semana = 300 por clase; 3 = 100; 5 = 60) |
| Bonus de racha | +10 % por cada 7 días de racha, hasta +50 % |
| Nivel | 1 + XP ganado / 1000 |
| Racha | días naturales entre la primera y la última clase de una serie sin faltas. No la rompen clases canceladas, faltas justificadas, clases de hoy o por confirmar (14 días de plazo) ni clases anteriores a apuntarse al grupo |
| Avatares | 2 gratuitos (`av01`, `av08`); el resto cuesta XP. Se pagan con el saldo (XP ganado − gastado); el nivel y el ranking no bajan |
| Perfiles Mini (hasta 7 años) | no compran: desbloquean solos los avatares que alcanza su XP ganado |

### Cambiar un precio

En **SQL Editor**:

```sql
update public.avatares set precio_xp = 800 where id = 'av05';
```

Para ver todos: `select id, precio_xp from public.avatares order by orden;`.

### Cambiar el XP por clase o el coste de un nivel

- XP de una semana, bonus y tope: constantes `v_xp_semana`, `v_bonus_por_semana` y `v_bonus_max` en `confirmar_asistencia`.
- XP por nivel: función `privado.xp_por_nivel()`.
