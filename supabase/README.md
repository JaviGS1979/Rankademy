# Supabase

## Aplicar las migraciones (primera vez)

Atajo: en un proyecto vacío basta con ejecutar `instalar_todo.sql`, que une todas las migraciones en orden (es un archivo generado; las fuentes son las de `migrations/`).

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
| Avatares | 20, cada uno con nombre. 2 gratuitos (Blazira y Drixa); el resto cuesta XP (de 300 a 5.000). Se pagan con el saldo (XP ganado − gastado); el nivel y el ranking no bajan |
| Perfiles Mini (hasta 7 años) | no compran: desbloquean solos los avatares que alcanza su XP ganado |

### Cambiar un precio

En **SQL Editor**:

```sql
update public.avatares set precio_xp = 800 where id = 'av05';
```

Para ver todos: `select id, nombre, precio_xp from public.avatares order by orden;`.

### Cambiar el XP por clase o el coste de un nivel

- XP de una semana, bonus y tope: constantes `v_xp_semana`, `v_bonus_por_semana` y `v_bonus_max` en `confirmar_asistencia`.
- XP por nivel: función `privado.xp_por_nivel()`.

## Horario y lista (0006)

- **Clases según el horario.** Las clases que tocan salen del día de la semana de cada grupo. Una sesión solo puede existir en un día del horario (`sesion_para`), desde 14 días atrás hasta 60 adelante. El día de un grupo no se cambia: otro día = otro grupo. Los grupos se archivan (`archivado_at`), no se borran.
- **Faltas.** Solo cuentan si se pasó lista ese día (clase impartida o con alguna asistencia marcada) y el alumno no estaba. Tampoco cuentan las faltas justificadas, las clases canceladas ni las anteriores a apuntarse. Si la familia no confirma una asistencia en 14 días, cuenta como falta.
- **Pasar lista** (`marcar_asistencia`: presente, justificada o desmarcar): solo el entrenador del grupo y el director, el mismo día o hasta 14 días después, y nunca sobre una asistencia ya confirmada por la familia. `cerrar_lista` deja la clase como impartida.
- **Cancelar** una clase (`cancelar_clase`, `reactivar_clase`) o un día entero de la escuela (`cancelar_dia`, solo el director).
- **Alumnos de la escuela.** El director da de alta alumnos sin cuenta familiar (`alta_alumno`). Cada uno tiene un código de 8 caracteres que solo ve el director (`codigo_alumno`). La familia lo introduce (`vincular_alumno`) y da su consentimiento; hasta entonces no gana XP.
- **Códigos.** Máximo 10 intentos fallidos por hora y persona (de escuela y de alumno).
- **Escrituras cerradas.** Sesiones, asistencias, inscripciones y membresías ya no se escriben directamente: solo con las funciones anteriores, `inscribir`/`desinscribir`, `resolver_membresia` y `dejar_escuela`.

## Biblioteca de ejercicios (0007)

- **Dibujo como datos.** Cada imagen es una lista de elementos sobre la pista (240 × 140): `jugador`, `pelota` y `cono` con `x`, `y`; y `trayecto` con `de`, `a`, opcionalmente `c` (curva) y `tipo` (`bola` o `carrera`). Entre 1 y 40 elementos por imagen y de 1 a 5 imágenes. Se valida en la base de datos: no se guarda nada más (ni SVG ni texto libre).
- **Duplicados.** Cada ejercicio guarda una huella de su dibujo. `buscar_parecidos` compara un dibujo nuevo con los públicos, también en espejo, junto con jugadores y edad (70 % dibujo, 15 % jugadores, 15 % edad). A partir del 75 % se avisa. A partir del 90 % `publicar_ejercicio` no deja publicarlo, salvo como variante (`original_id`). Las variantes cuelgan siempre del original y sus usos suman al original.
- **Anonimato.** `biblioteca()` (con filtros) y `detalle_ejercicio()` nunca devuelven el autor ni la escuela: solo `es_mio`. Un ejercicio público no guarda escuela.
- **Solo mi escuela.** Lo ven el staff de esa escuela y no cuenta para el ranking. Solo se usa en clases de esa escuela, aunque el entrenador esté en varias.
- **Usos.** `guardar_ejercicios_clase` fija los ejercicios (y su orden) de una clase y guarda quién los añadió. "Usado por X entrenadores" cuenta entrenadores distintos en clases no canceladas, contando también las variantes.
- **Cambios del autor.** `editar_ejercicio` solo cambia textos (nombre, pasos, material, nivel, objetivo, espacio). El dibujo, los jugadores, la edad y la visibilidad no cambian. `retirar_ejercicio` lo quita de la biblioteca, pero las clases que lo usaron lo conservan. `borrar_ejercicio` solo funciona si nadie lo ha usado y no tiene variantes.
- **Escrituras cerradas.** Ejercicios, imágenes y usos solo se escriben con estas funciones. Límite: 20 ejercicios al día por persona.

## Rankings (0008)

No hay tablas nuevas: los rankings se calculan al consultarlos, así que se actualizan tras cada lista. Los valores se ajustan en las funciones del principio de la migración.

- **Temporada** (`inicio_temporada`): desde el 1 de septiembre. Lo anterior no cuenta.
- **Alumnos** (`ranking_alumnos`): desde 8 años (`edad_minima_ranking`), si la familia no lo ha desactivado (`perfiles_alumno.participa_ranking`) y su escuela participa. Puntos = XP de la temporada. En "mi escuela", solo el de esa escuela; en provincia, comunidad y país, el total, apareciendo una sola vez. Solo se muestra nombre de pila con inicial ("Iker L."), avatar, escuela y puntos. Filtro por edad.
- **Entrenadores** (`ranking_entrenadores`, `perfil_entrenador`): nota de 0 a 1000.
  - 40 % uso: sus ejercicios públicos (con sus variantes) dados por otros entrenadores en clases con lista. Valen doble si son de otra escuela, con un tope de 10 por pareja de entrenadores (`tope_usos_pareja`) y 10 puntos por uso.
  - 30 % constancia: clases que tocaban según el horario, sin las canceladas, en las que se pasó lista.
  - 30 % alumnos: asistencias confirmadas por las familias frente a los alumnos apuntados (sin faltas justificadas), en clases de hace al menos 7 días.
- **Escuelas** (`ranking_escuelas`): media de 0 a 1000 de sus entrenadores y sus alumnos. Para cada alumno, su XP de la temporada en la escuela frente a 300 por semana. Hace falta un mínimo de 5 participantes (`minimo_participantes_escuela`) y no se muestra cuántos son.
- **Zonas**: provincia y comunidad se comparan sin distinguir mayúsculas ni espacios; hacen falta al menos 3 escuelas participando (`minimo_escuelas_zona`). Los rankings se piden siempre desde una escuela de la que se es miembro aprobado (`estado_ranking` dice si participa, su zona y cuántas escuelas hay). **La provincia y la comunidad de cada escuela las pone el director**: sin ellas, solo hay ranking de la escuela y del país.
- **Patrones raros** (`anomalias`, solo el director): grupos con todos los alumnos presentes en sus 6 últimas clases, y entrenadores con al menos 10 asistencias marcadas de las que las familias confirman menos del 30 %.

## Panel del fundador (0009)

Solo lo usa quien esté en `public.fundadores` (se añade a mano, ver "Fundador" arriba). Nadie puede añadirse desde la app. Devuelve cifras agregadas y, por escuela, su nombre, ciudad y contadores. Nunca datos de un menor ni correos.

- `panel_fundador(p_dias)`: crecimiento (altas por semana durante 12 semanas), actividad (clases con lista, asistencias marcadas y confirmadas), retención (escuelas y entrenadores activos en 14 días, alumnos veteranos activos en 30), biblioteca (públicos, variantes, privados, usos, los 5 más usados) y rankings (escuelas participantes, provincias y si ya tienen ranking).
- `escuelas_fundador()`: el piloto, con una fila por escuela: entrenadores, alumnos, alumnos con familia, grupos, clases y asistencias de las últimas 4 semanas, ejercicios, última clase y solicitudes pendientes.
- `alertas_fundador()`: escuelas con grupos y sin pasar lista en 14 días, escuelas sin grupos tras una semana, solicitudes sin atender más de 7 días, alumnos sin familia vinculada más de 14 días, escuelas en el ranking sin provincia, patrones raros e intentos fallidos con códigos (30 o más en 24 horas).
