-- Pruebas de seguridad (RLS y funciones) para ejecutar en local con PostgreSQL.
-- Requiere antes: tests/00_simular_supabase.sql + las 3 migraciones.
-- Uso:  psql -d rk_test -v ON_ERROR_STOP=1 -f supabase/tests/10_seguridad.sql
\set ON_ERROR_STOP on
begin;

create schema t;
create table t.res (n serial, ok boolean, descr text);

create function t.u(n text) returns uuid language sql immutable as $$
  select ('00000000-0000-0000-0000-' || lpad(to_hex(
    case n when 'dir1' then 1 when 'dir2' then 2 when 'coach1' then 3 when 'coach2' then 4
      when 'coach3' then 5 when 'fam1' then 6 when 'fam2' then 7 when 'out' then 8
      when 'founder' then 9 end), 12, '0'))::uuid $$;

-- Ejecuta sql como usuario autenticado (o 'anon') y devuelve el nº de filas del resultado
create function t.cnt(usr text, q text) returns bigint language plpgsql as $$
declare n bigint;
begin
  if usr = 'anon' then execute 'set local role anon';
  else
    perform set_config('request.jwt.claim.sub', t.u(usr)::text, true);
    execute 'set local role authenticated';
  end if;
  execute 'select count(*) from (' || q || ') s' into n;
  execute 'reset role';
  return n;
exception when others then
  execute 'reset role';
  raise;
end $$;

-- Ejecuta una orden (insert/update/rpc) como usuario; true si no falla
create function t.run(usr text, q text) returns boolean language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', t.u(usr)::text, true);
  execute 'set local role authenticated';
  execute q;
  execute 'reset role';
  return true;
-- Solo se aceptan los errores esperados de una operación denegada; cualquier
-- otro (sintaxis, columna inexistente…) hace fallar el script, para que una
-- prueba negativa nunca pase por un error en la propia prueba.
exception when insufficient_privilege or raise_exception or integrity_constraint_violation then
  execute 'reset role';
  return false;
end $$;

-- Igual, pero devuelve las filas afectadas (para update/delete bloqueados por RLS)
create function t.rows(usr text, q text) returns bigint language plpgsql as $$
declare n bigint;
begin
  perform set_config('request.jwt.claim.sub', t.u(usr)::text, true);
  execute 'set local role authenticated';
  execute 'with x as (' || q || ' returning 1) select count(*) from x' into n;
  execute 'reset role';
  return n;
-- Solo se aceptan los errores esperados de una operación denegada; cualquier
-- otro (sintaxis, columna inexistente…) hace fallar el script, para que una
-- prueba negativa nunca pase por un error en la propia prueba.
exception when insufficient_privilege or raise_exception or integrity_constraint_violation then
  execute 'reset role';
  return -1;
end $$;

-- Devuelve el primer valor (texto) de una consulta ejecutada como usuario
create function t.val(usr text, q text) returns text language plpgsql as $$
declare v text;
begin
  perform set_config('request.jwt.claim.sub', t.u(usr)::text, true);
  execute 'set local role authenticated';
  execute q into v;
  execute 'reset role';
  return v;
exception when others then
  execute 'reset role';
  raise;
end $$;

-- true si la consulta, ejecutada como anónimo, falla (permiso denegado)
create function t.anon_denegado(q text) returns boolean language plpgsql as $$
begin
  execute 'set local role anon';
  execute q;
  execute 'reset role';
  return false;
exception when insufficient_privilege then
  execute 'reset role';
  return true;
end $$;

-- true si la orden (como administrador) falla por una restricción de la tabla
create function t.viola_restriccion(q text) returns boolean language plpgsql as $$
begin
  execute q;
  return false;
exception when check_violation or not_null_violation or unique_violation or foreign_key_violation then
  return true;
end $$;

-- true si la consulta, como usuario, se rechaza por falta de permiso (p. ej. una columna)
create function t.denegado(usr text, q text) returns boolean language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', t.u(usr)::text, true);
  execute 'set local role authenticated';
  execute q;
  execute 'reset role';
  return false;
exception when insufficient_privilege then
  execute 'reset role';
  return true;
end $$;

create function t.ok(descr text, cond boolean) returns void language sql as $$
  insert into t.res (ok, descr) values (coalesce(cond, false), descr) $$;

-- ---------------- Datos de partida ----------------
insert into auth.users (id, raw_user_meta_data)
select t.u(n), jsonb_build_object('nombre', n)
from unnest(array['dir1','dir2','coach1','coach2','coach3','fam1','fam2','out','founder']) n;
insert into public.fundadores values (t.u('founder'));

-- Escuelas (por la función, como en la app)
create temp table cod (esc text, codigo text, id uuid);
grant all on cod to authenticated;
do $$ begin
  perform set_config('request.jwt.claim.sub', t.u('dir1')::text, true);
  set local role authenticated;
  insert into cod select 'A', codigo, id from public.crear_escuela('Escuela A', 'Madrid', 'Madrid', 'Madrid');
  reset role;
  perform set_config('request.jwt.claim.sub', t.u('dir2')::text, true);
  set local role authenticated;
  insert into cod select 'B', codigo, id from public.crear_escuela('Escuela B', 'Sevilla', 'Sevilla', 'Andalucía');
  reset role;
end $$;

select t.ok('el código tiene formato AAA-999 sin I/O/0/1',
  (select bool_and(codigo ~ '^[A-HJ-NP-Z2-9]{3}-[A-HJ-NP-Z2-9]{3}$') from cod));

-- Perfiles de hijo (los crean las familias)
select t.ok('fam1 crea el perfil de su hijo', t.run('fam1', format(
  $q$insert into public.perfiles_alumno (id, familia_id, nombre, anio_nacimiento, nivel, consentimiento_at)
     values ('10000000-0000-0000-0000-000000000001', %L, 'Hijo1', 2016, 'gamer', now())$q$, t.u('fam1'))));
select t.ok('fam2 crea el perfil de su hijo', t.run('fam2', format(
  $q$insert into public.perfiles_alumno (id, familia_id, nombre, anio_nacimiento, nivel, consentimiento_at)
     values ('10000000-0000-0000-0000-000000000002', %L, 'Hijo2', 2015, 'gamer', now())$q$, t.u('fam2'))));

-- Solicitudes de unión
select t.ok('coach1 pide unirse a A', t.run('coach1',
  format($q$select public.unirse_a_escuela(%L, 'entrenador')$q$, (select codigo from cod where esc='A'))));
select t.ok('coach2 pide unirse a B', t.run('coach2',
  format($q$select public.unirse_a_escuela(%L, 'entrenador')$q$, (select codigo from cod where esc='B'))));
select t.ok('coach3 pide unirse a A', t.run('coach3',
  format($q$select public.unirse_a_escuela(%L, 'entrenador')$q$, (select codigo from cod where esc='A'))));
select t.ok('hijo1 pide unirse a A', t.run('fam1',
  format($q$select public.unirse_a_escuela(%L, 'alumno', '10000000-0000-0000-0000-000000000001')$q$, (select codigo from cod where esc='A'))));
select t.ok('hijo2 pide unirse a B', t.run('fam2',
  format($q$select public.unirse_a_escuela(%L, 'alumno', '10000000-0000-0000-0000-000000000002')$q$, (select codigo from cod where esc='B'))));

-- ---------------- Acceso: unirse y aprobar ----------------
select t.ok('código inválido: no une a nadie (devuelve vacío)', t.run('out', $q$select public.unirse_a_escuela('ZZZ-999', 'entrenador')$q$)
  and t.val('out', $q$select (public.unirse_a_escuela('ZZZ-998', 'entrenador')).id::text$q$) is null
  and not exists (select 1 from public.membresias where persona_id = t.u('out')));
select t.ok('no se puede unir como director', not t.run('out',
  format($q$select public.unirse_a_escuela(%L, 'director')$q$, (select codigo from cod where esc='A'))));
select t.ok('alumno sin perfil rechazado', not t.run('out',
  format($q$select public.unirse_a_escuela(%L, 'alumno')$q$, (select codigo from cod where esc='A'))));
select t.ok('no se puede usar el perfil de otra familia', not t.run('out',
  format($q$select public.unirse_a_escuela(%L, 'alumno', '10000000-0000-0000-0000-000000000001')$q$, (select codigo from cod where esc='A'))));
select t.ok('unirse dos veces no duplica', t.run('coach1',
  format($q$select public.unirse_a_escuela(%L, 'entrenador')$q$, (select codigo from cod where esc='A')))
  and (select count(*) from public.membresias where persona_id = t.u('coach1')) = 1);

select t.ok('coach pendiente no ve nada de la escuela (grupos/membresías)',
  t.cnt('coach3', 'select 1 from public.membresias where escuela_id = (select id from cod where esc=''A'') and persona_id <> ' || quote_literal(t.u('coach3'))) = 0);

select t.ok('un entrenador NO puede aprobar solicitudes', not t.run('coach1',
  format($q$select public.resolver_membresia(%L, true)$q$,
    (select id from public.membresias where persona_id = t.u('coach3')))));
select t.ok('el director de OTRA escuela no puede aprobar', not t.run('dir2',
  format($q$select public.resolver_membresia(%L, true)$q$,
    (select id from public.membresias where persona_id = t.u('coach3')))));
select t.ok('nadie se auto-aprueba por update directo',
  t.rows('coach3', format($q$update public.membresias set estado='activa' where persona_id=%L$q$, t.u('coach3'))) <= 0);
select t.ok('coach3 sigue pendiente',
  (select estado from public.membresias where persona_id = t.u('coach3')) = 'pendiente');

select t.ok('dir1 aprueba coach1', t.run('dir1', format($q$select public.resolver_membresia(%L, true)$q$,
  (select id from public.membresias where persona_id = t.u('coach1')))));
select t.ok('dir1 aprueba hijo1', t.run('dir1', format($q$select public.resolver_membresia(%L, true)$q$,
  (select id from public.membresias where perfil_id = '10000000-0000-0000-0000-000000000001'))));
select t.ok('dir2 aprueba coach2', t.run('dir2', format($q$select public.resolver_membresia(%L, true)$q$,
  (select id from public.membresias where persona_id = t.u('coach2')))));
select t.ok('dir2 aprueba hijo2', t.run('dir2', format($q$select public.resolver_membresia(%L, true)$q$,
  (select id from public.membresias where perfil_id = '10000000-0000-0000-0000-000000000002'))));

-- ---------------- Aislamiento entre escuelas y roles ----------------
select t.ok('anónimo: sin acceso a escuelas', t.anon_denegado('select 1 from public.escuelas'));
select t.ok('anónimo: sin acceso a perfiles de alumno', t.anon_denegado('select 1 from public.perfiles_alumno'));
select t.ok('anónimo: sin acceso a puntos', t.anon_denegado('select 1 from public.puntos'));
select t.ok('anónimo: sin acceso a ejercicios', t.anon_denegado('select 1 from public.ejercicios'));

select t.ok('extraño ve 0 escuelas', t.cnt('out', 'select 1 from public.escuelas') = 0);
select t.ok('extraño ve 0 perfiles', t.cnt('out', 'select 1 from public.perfiles_alumno') = 0);
select t.ok('extraño ve 0 membresías', t.cnt('out', 'select 1 from public.membresias') = 0);
select t.ok('dir1 ve solo su escuela', t.cnt('dir1', 'select 1 from public.escuelas') = 1);
select t.ok('dir1 no ve la escuela B', t.cnt('dir1', format('select 1 from public.escuelas where id = %L', (select id from cod where esc='B'))) = 0);
select t.ok('fam1 ve solo a su hijo', t.cnt('fam1', 'select 1 from public.perfiles_alumno') = 1);
select t.ok('fam2 no ve al hijo1', t.cnt('fam2', 'select 1 from public.perfiles_alumno where nombre = ''Hijo1''') = 0);
select t.ok('coach1 (staff de A) ve al hijo1', t.cnt('coach1', 'select 1 from public.perfiles_alumno where nombre = ''Hijo1''') = 1);
select t.ok('coach2 (staff de B) NO ve al hijo1', t.cnt('coach2', 'select 1 from public.perfiles_alumno where nombre = ''Hijo1''') = 0);
select t.ok('dir2 NO ve al hijo1', t.cnt('dir2', 'select 1 from public.perfiles_alumno where nombre = ''Hijo1''') = 0);

select t.ok('no se crea una escuela por insert directo', not t.run('out',
  format($q$insert into public.escuelas (nombre, codigo, creada_por) values ('Falsa','AAA-222',%L)$q$, t.u('out'))));
select t.ok('no se crea una membresía por insert directo', not t.run('out',
  format($q$insert into public.membresias (persona_id, escuela_id, rol, estado) values (%L, %L, 'director', 'activa')$q$,
    t.u('out'), (select id from cod where esc='A'))));
select t.ok('dir1 no edita la escuela B', t.rows('dir1',
  format($q$update public.escuelas set nombre='Hack' where id=%L$q$, (select id from cod where esc='B'))) = 0);
select t.ok('dir1 edita su escuela', t.rows('dir1',
  format($q$update public.escuelas set ciudad='Getafe' where id=%L$q$, (select id from cod where esc='A'))) = 1);
select t.ok('no se cambia el código por update', not t.run('dir1',
  format($q$update public.escuelas set codigo='AAA-222' where id=%L$q$, (select id from cod where esc='A'))));

-- personas: nombres visibles solo entre miembros de la misma escuela
select t.ok('fam1 ve el nombre del entrenador de su escuela', t.cnt('fam1', format('select 1 from public.personas where id=%L', t.u('coach1'))) = 1);
select t.ok('fam1 NO ve al entrenador de otra escuela', t.cnt('fam1', format('select 1 from public.personas where id=%L', t.u('coach2'))) = 0);
select t.ok('fam1 NO ve a fam2', t.cnt('fam1', format('select 1 from public.personas where id=%L', t.u('fam2'))) = 0);
select t.ok('coach1 ve a la familia de su alumno', t.cnt('coach1', format('select 1 from public.personas where id=%L', t.u('fam1'))) = 1);
select t.ok('fam1 solo cambia su propio nombre', t.rows('fam1', format($q$update public.personas set nombre='X' where id=%L$q$, t.u('fam2'))) = 0);

-- perfiles
select t.ok('no se cambia la familia de un perfil', not t.run('fam1',
  format($q$update public.perfiles_alumno set familia_id=%L where nombre='Hijo1'$q$, t.u('fam2'))));
select t.ok('fam2 no puede crear perfil a nombre de fam1', not t.run('fam2', format(
  $q$insert into public.perfiles_alumno (familia_id, nombre, anio_nacimiento, nivel, consentimiento_at)
     values (%L, 'Intruso', 2015, 'gamer', now())$q$, t.u('fam1'))));
select t.ok('fam2 no borra al hijo1', t.rows('fam2', $q$delete from public.perfiles_alumno where nombre='Hijo1'$q$) = 0);

-- fundador
select t.ok('fundador se identifica', t.cnt('founder', 'select 1 from public.fundadores') = 1);
select t.ok('otro usuario no ve la tabla de fundadores', t.cnt('fam1', 'select 1 from public.fundadores') = 0);
select t.ok('nadie se hace fundador', not t.run('fam1', format('insert into public.fundadores values (%L)', t.u('fam1'))));
select t.ok('fundador NO ve escuelas ajenas ni menores (sin acceso directo)',
  t.cnt('founder', 'select 1 from public.perfiles_alumno') = 0);

-- ---------------- Grupos, sesiones y asistencia ----------------
select t.ok('coach1 no crea grupos (solo el director)', not t.run('coach1', format(
  $q$insert into public.grupos (escuela_id, nombre, dia, hora, entrenador_id) values (%L,'G',1,'17:00',%L)$q$, (select id from cod where esc='A'), t.u('coach1'))));
select t.ok('dir1 no asigna un entrenador de otra escuela', not t.run('dir1', format(
  $q$insert into public.grupos (escuela_id, nombre, dia, hora, entrenador_id) values (%L,'G',1,'17:00',%L)$q$, (select id from cod where esc='A'), t.u('coach2'))));
select t.ok('dir1 no asigna un entrenador pendiente', not t.run('dir1', format(
  $q$insert into public.grupos (escuela_id, nombre, dia, hora, entrenador_id) values (%L,'G',1,'17:00',%L)$q$, (select id from cod where esc='A'), t.u('coach3'))));
-- El grupo tiene clase el día de la semana de AYER (así "ayer" es un día de clase)
select t.ok('dir1 crea un grupo con coach1', t.run('dir1', format(
  $q$insert into public.grupos (id, escuela_id, nombre, dia, hora, entrenador_id) values ('20000000-0000-0000-0000-000000000001',%L,'Lunes tarde',%s,'17:00',%L)$q$,
  (select id from cod where esc='A'), extract(isodow from current_date - 1)::int, t.u('coach1'))));
select t.ok('no se fija la fecha de creación de un grupo (no se pueden inventar clases pasadas)', not t.run('dir1', format(
  $q$insert into public.grupos (escuela_id, nombre, dia, hora, creado_at) values (%L,'Viejo',1,'17:00', now() - interval '1 year')$q$, (select id from cod where esc='A'))));
-- Preparación: el grupo existe desde hace tiempo
update public.grupos set creado_at = now() - interval '200 days' where id = '20000000-0000-0000-0000-000000000001';
select t.ok('dir1 inscribe al hijo1', t.run('dir1',
  $q$select public.inscribir('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001')$q$));
select t.ok('no se inscribe por insert directo', not t.run('dir1',
  $q$insert into public.inscripciones (perfil_id, grupo_id) values ('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001')$q$));
select t.ok('dir1 no inscribe a alumnos de otra escuela', not t.run('dir1',
  $q$select public.inscribir('10000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001')$q$));
select t.ok('un entrenador no inscribe alumnos', not t.run('coach1',
  $q$select public.inscribir('10000000-0000-0000-0000-000000000001','20000000-0000-0000-0000-000000000001')$q$));
select t.ok('fam1 ve el grupo de su hijo', t.cnt('fam1', 'select 1 from public.grupos') = 1);
select t.ok('fam2 no ve grupos de A', t.cnt('fam2', 'select 1 from public.grupos where nombre = ''Lunes tarde''') = 0);
select t.ok('coach3 pendiente no ve grupos', t.cnt('coach3', 'select 1 from public.grupos') = 0);
select t.ok('el día de un grupo no se cambia', not t.run('dir1',
  $q$update public.grupos set dia = 7 where id = '20000000-0000-0000-0000-000000000001'$q$));
select t.ok('un grupo no se borra', not t.run('dir1',
  $q$delete from public.grupos where id = '20000000-0000-0000-0000-000000000001'$q$));

select t.ok('coach2 no crea sesión en el grupo de A', not t.run('coach2', format(
  $q$select public.sesion_para('20000000-0000-0000-0000-000000000001', %L)$q$, current_date - 1)));
select t.ok('fam1 no crea sesiones', not t.run('fam1', format(
  $q$select public.sesion_para('20000000-0000-0000-0000-000000000001', %L)$q$, current_date - 1)));
select t.ok('nadie crea sesiones por insert directo', not t.run('coach1', format(
  $q$insert into public.sesiones (grupo_id, fecha, creada_por) values ('20000000-0000-0000-0000-000000000001',%L,%L)$q$, current_date - 1, t.u('coach1'))));
select t.ok('no se crea una clase en un día que no es del horario', not t.run('coach1', format(
  $q$select public.sesion_para('20000000-0000-0000-0000-000000000001', %L)$q$, current_date)));
select t.ok('no se crea una clase de hace más de 14 días', not t.run('coach1', format(
  $q$select public.sesion_para('20000000-0000-0000-0000-000000000001', %L)$q$, current_date - 22)));
select t.ok('no se crea una clase a más de 60 días vista', not t.run('coach1', format(
  $q$select public.sesion_para('20000000-0000-0000-0000-000000000001', %L)$q$, current_date - 1 + 63)));
select t.ok('coach1 crea la sesión de su grupo', t.run('coach1', format(
  $q$select public.sesion_para('20000000-0000-0000-0000-000000000001', %L)$q$, current_date - 1)));
select t.ok('pedirla otra vez devuelve la misma sesión (no duplica)', t.run('coach1', format(
  $q$select public.sesion_para('20000000-0000-0000-0000-000000000001', %L)$q$, current_date - 1))
  and (select count(*) from public.sesiones where grupo_id = '20000000-0000-0000-0000-000000000001') = 1);
-- Preparación: id fijo para referirse a ella en el resto de pruebas
update public.sesiones set id = '30000000-0000-0000-0000-000000000001'
where grupo_id = '20000000-0000-0000-0000-000000000001' and fecha = current_date - 1;

select t.ok('coach2 no pasa lista en A', not t.run('coach2',
  $q$select public.marcar_asistencia('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','presente')$q$));
select t.ok('no se marca a un alumno de otra escuela', not t.run('coach1',
  $q$select public.marcar_asistencia('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000002','presente')$q$));
select t.ok('no se pasa lista por insert directo', not t.run('coach1', format(
  $q$insert into public.asistencias (sesion_id, perfil_id, marcada_por) values ('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001',%L)$q$, t.u('coach1'))));
select t.ok('un estado desconocido se rechaza', not t.run('coach1',
  $q$select public.marcar_asistencia('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','confirmada')$q$));
select t.ok('coach1 pasa lista a hijo1', t.run('coach1',
  $q$select public.marcar_asistencia('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','presente')$q$));
select t.ok('queda registrado quién pasó lista', (select marcada_por from public.asistencias where sesion_id='30000000-0000-0000-0000-000000000001') = t.u('coach1'));
select t.ok('el director también puede pasar lista (desmarcar y volver a marcar)', t.run('dir1',
  $q$select public.marcar_asistencia('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','ninguno')$q$)
  and t.run('dir1', $q$select public.marcar_asistencia('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','presente')$q$));

select t.ok('sin confirmar no hay puntos', (select count(*) from public.puntos) = 0);
select t.ok('el entrenador no confirma por el alumno', not t.run('coach1',
  $q$select public.confirmar_asistencia('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001')$q$));
select t.ok('otra familia no confirma', not t.run('fam2',
  $q$select public.confirmar_asistencia('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001')$q$));
select t.ok('el entrenador no puede editar asistencia por update', not t.run('coach1',
  $q$update public.asistencias set confirmada_por = (select auth.uid()), confirmada_at = now()$q$));
select t.ok('fam1 confirma la asistencia de su hijo', t.run('fam1',
  $q$select public.confirmar_asistencia('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001')$q$));
select t.ok('ahora hay 300 puntos (XP) de la escuela A', (select valor from public.puntos where escuela_id = (select id from cod where esc='A')) = 300);
select t.ok('confirmar dos veces no da más puntos', not t.run('fam1',
  $q$select public.confirmar_asistencia('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001')$q$)
  and (select count(*) from public.puntos) = 1);
select t.ok('no se desmarca una asistencia confirmada', not t.run('coach1',
  $q$select public.marcar_asistencia('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','ninguno')$q$)
  and t.rows('coach1', $q$delete from public.asistencias$q$) <= 0
  and (select count(*) from public.asistencias where confirmada_at is not null) = 1);
select t.ok('ni se convierte en falta justificada', not t.run('coach1',
  $q$select public.marcar_asistencia('30000000-0000-0000-0000-000000000001','10000000-0000-0000-0000-000000000001','justificada')$q$));
select t.ok('fam1 ve sus puntos', t.cnt('fam1', 'select 1 from public.puntos') = 1);
select t.ok('fam2 no ve puntos ajenos', t.cnt('fam2', 'select 1 from public.puntos') = 0);
select t.ok('coach1 ve los puntos de su escuela', t.cnt('coach1', 'select 1 from public.puntos') = 1);
select t.ok('coach2 no ve puntos de A', t.cnt('coach2', 'select 1 from public.puntos') = 0);
select t.ok('nadie escribe puntos directamente', not t.run('fam1',
  $q$insert into public.puntos (perfil_id, escuela_id, sesion_id, valor) select perfil_id, (select id from cod where esc='A'), sesion_id, 9999 from public.asistencias$q$));

-- ---------------- Ejercicios y biblioteca ----------------
select t.ok('coach1 sube un ejercicio público', t.run('coach1', format(
  $q$insert into public.ejercicios (id, autor_id, titulo, jugadores_min, jugadores_max) values ('40000000-0000-0000-0000-000000000001',%L,'Volea cruzada',2,4)$q$, t.u('coach1'))));
select t.ok('coach1 sube uno solo para su escuela', t.run('coach1', format(
  $q$insert into public.ejercicios (id, autor_id, escuela_id, visibilidad, titulo, jugadores_min, jugadores_max) values ('40000000-0000-0000-0000-000000000002',%L,%L,'escuela','Secreto A',1,2)$q$, t.u('coach1'), (select id from cod where esc='A'))));
select t.ok('no se sube a nombre de otro', not t.run('coach1', format(
  $q$insert into public.ejercicios (autor_id, titulo, jugadores_min, jugadores_max) values (%L,'Falso',1,2)$q$, t.u('coach2'))));
select t.ok('una familia no sube ejercicios', not t.run('fam1', format(
  $q$insert into public.ejercicios (autor_id, titulo, jugadores_min, jugadores_max) values (%L,'Falso',1,2)$q$, t.u('fam1'))));
select t.ok('no se publica "solo mi escuela" de una escuela ajena', not t.run('coach2', format(
  $q$insert into public.ejercicios (autor_id, escuela_id, visibilidad, titulo, jugadores_min, jugadores_max) values (%L,%L,'escuela','Intruso',1,2)$q$, t.u('coach2'), (select id from cod where esc='A'))));
select t.ok('imágenes: solo el autor las añade', t.run('coach1',
  $q$insert into public.ejercicio_imagenes (ejercicio_id, orden, dibujo) values ('40000000-0000-0000-0000-000000000001',0,'<svg/>')$q$)
  and not t.run('coach2', $q$insert into public.ejercicio_imagenes (ejercicio_id, orden, dibujo) values ('40000000-0000-0000-0000-000000000001',1,'<svg/>')$q$));

select t.ok('biblioteca: coach2 ve el público pero NO el de escuela',
  t.cnt('coach2', 'select 1 from public.biblioteca_ejercicios()') = 1
  and t.cnt('coach2', 'select 1 from public.biblioteca_ejercicios() where titulo = ''Secreto A''') = 0);
select t.ok('biblioteca: no expone al autor', (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
       where n.nspname='public' and p.proname='biblioteca_ejercicios'
         and pg_get_function_result(p.oid) ilike '%autor%') = 0);
select t.ok('biblioteca vacía para una familia', t.cnt('fam1', 'select 1 from public.biblioteca_ejercicios()') = 0);
select t.ok('coach2 no lee ejercicios ajenos directamente', t.cnt('coach2', 'select 1 from public.ejercicios') = 0);
select t.ok('coach2 ve las imágenes de un ejercicio público; fam2 no ve ninguna',
  t.cnt('coach2', 'select 1 from public.ejercicio_imagenes') = 1
  and t.cnt('fam2', 'select 1 from public.ejercicio_imagenes') = 0);
select t.ok('dir1 ve el de su escuela', t.cnt('dir1', 'select 1 from public.ejercicios where titulo = ''Secreto A''') = 1);
select t.ok('coach2 no edita ni borra el ejercicio de coach1',
  t.rows('coach2', $q$update public.ejercicios set titulo='Hack' where id='40000000-0000-0000-0000-000000000001'$q$) = 0
  and t.rows('coach2', $q$delete from public.ejercicios where id='40000000-0000-0000-0000-000000000001'$q$) = 0);

select t.ok('coach1 usa su ejercicio en la sesión', t.run('coach1',
  $q$insert into public.usos_ejercicio values ('30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001')$q$));
select t.ok('coach2 no añade usos a sesiones de A', not t.run('coach2',
  $q$insert into public.usos_ejercicio values ('30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000001')$q$));
select t.ok('coach2 sube uno privado en B', t.run('coach2', format(
  $q$insert into public.ejercicios (id, autor_id, escuela_id, visibilidad, titulo, jugadores_min, jugadores_max) values ('40000000-0000-0000-0000-000000000003',%L,%L,'escuela','Secreto B',1,2)$q$, t.u('coach2'), (select id from cod where esc='B'))));
select t.ok('coach1 no usa en su sesión el privado de otra escuela', not t.run('coach1',
  $q$insert into public.usos_ejercicio values ('30000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000003')$q$));
select t.ok('fam1 ve el ejercicio que usa la clase de su hijo', t.cnt('fam1', 'select 1 from public.ejercicios') = 1);
select t.ok('fam2 no lo ve', t.cnt('fam2', 'select 1 from public.ejercicios') = 0);
select t.ok('el uso se suma en la biblioteca', t.val('coach2', 'select usos from public.biblioteca_ejercicios() where titulo = ''Volea cruzada''') = '1');

-- ---------------- Funciones de sistema ----------------
select t.ok('anónimo no ejecuta crear_escuela', (
  select not has_function_privilege('anon', 'public.crear_escuela(text,text,text,text)', 'execute')));
select t.ok('anónimo no ejecuta confirmar_asistencia', (
  select not has_function_privilege('anon', 'public.confirmar_asistencia(uuid,uuid)', 'execute')));
select t.ok('anónimo sin acceso a tablas', (
  select not bool_or(has_table_privilege('anon', c.oid, 'select'))
  from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r'));
select t.ok('todas las tablas públicas tienen RLS', (
  select bool_and(c.relrowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public' and c.relkind='r'));

-- ---------------- Consultas de la app (Fase 3: Mis escuelas) ----------------
-- La app filtra "Mis escuelas" por persona_id: el director puede leer las membresías
-- de toda su escuela, y sin ese filtro vería las de los demás como propias.
select t.ok('app: el director lee también membresías ajenas de su escuela (por eso la app filtra por persona)',
  t.cnt('dir1', format('select 1 from public.membresias where persona_id <> %L', t.u('dir1'))) > 0
  and t.cnt('dir1', format('select 1 from public.membresias where persona_id = %L', t.u('dir1'))) = 1);
-- Equivalen a src/lib/api.ts: misMembresias() y solicitudesPendientes()
select t.ok('app: el director ve su membresía con la escuela y su código',
  t.val('dir1', $q$select e.codigo from public.membresias m join public.escuelas e on e.id = m.escuela_id
                   where m.rol = 'director' and m.estado <> 'baja'$q$) = (select codigo from cod where esc='A'));
select t.ok('app: el director ve el nombre de quien pide entrar (pendiente)',
  t.val('dir1', format($q$select p.nombre from public.membresias m join public.personas p on p.id = m.persona_id
                   where m.escuela_id = %L and m.estado = 'pendiente'$q$, (select id from cod where esc='A'))) = 'coach3');
select t.ok('app: la familia ve la membresía de su hijo con el nombre de escuela y del hijo',
  t.val('fam1', $q$select e.nombre || '/' || pf.nombre from public.membresias m
                   join public.escuelas e on e.id = m.escuela_id
                   join public.perfiles_alumno pf on pf.id = m.perfil_id$q$) = 'Escuela A/Hijo1');
select t.ok('app: un pendiente ve el nombre de la escuela pero no su lista de miembros',
  t.cnt('coach3', 'select 1 from public.escuelas') = 1
  and t.cnt('coach3', 'select 1 from public.membresias') = 1);
select t.ok('app: el entrenador ve las solicitudes de su escuela',
  t.cnt('coach1', format($q$select 1 from public.membresias where escuela_id = %L and estado = 'pendiente'$q$, (select id from cod where esc='A'))) = 1);
select t.ok('app: el entrenador no puede aprobarlas', not t.run('coach1', format($q$select public.resolver_membresia(%L, true)$q$,
  (select id from public.membresias where persona_id = t.u('coach3')))));

-- ---------------- Alumno (0005): XP, avatares con precio ----------------
-- (se ejecuta antes de la baja de hijo1 de las pruebas de 0004)
select t.ok('app: mi_progreso da XP, saldo, nivel, racha (días) y clases',
  (select (t.val('fam1', $q$select public.mi_progreso('10000000-0000-0000-0000-000000000001')::text$q$)::jsonb ->> 'xp')::int) = 300
  and (t.val('fam1', $q$select public.mi_progreso('10000000-0000-0000-0000-000000000001')::text$q$)::jsonb ->> 'saldo')::int = 300
  and (t.val('fam1', $q$select public.mi_progreso('10000000-0000-0000-0000-000000000001')::text$q$)::jsonb ->> 'nivel')::int = 1
  and (t.val('fam1', $q$select public.mi_progreso('10000000-0000-0000-0000-000000000001')::text$q$)::jsonb ->> 'racha')::int = 1
  and (t.val('fam1', $q$select public.mi_progreso('10000000-0000-0000-0000-000000000001')::text$q$)::jsonb ->> 'clases')::int = 1);
select t.ok('una clase de un alumno con un solo grupo da 300 XP', (select valor from public.puntos where perfil_id='10000000-0000-0000-0000-000000000001') = 300);
select t.ok('app: otra familia no ve el progreso ajeno', not t.run('fam2',
  $q$select public.mi_progreso('10000000-0000-0000-0000-000000000001')$q$));
select t.ok('el perfil tiene avatar inicial y solo los 2 gratuitos',
  (select avatar from public.perfiles_alumno where id='10000000-0000-0000-0000-000000000001') = 'av01'
  and (select string_agg(avatar, ',' order by avatar) from public.avatares_desbloqueados where perfil_id='10000000-0000-0000-0000-000000000001') = 'av01,av08');
select t.ok('app: el catálogo tiene 20 avatares con nombre y precio, y solo 2 gratis',
  t.cnt('fam1', 'select 1 from public.avatares') = 20 and t.cnt('fam1', 'select 1 from public.avatares where precio_xp = 0') = 2
  and t.cnt('fam1', 'select 1 from public.avatares where nombre is null or nombre = $$$$') = 0
  and (select count(distinct nombre) from public.avatares) = 20 and (select count(distinct orden) from public.avatares) = 20);
select t.ok('anónimo: sin acceso al catálogo', t.anon_denegado('select 1 from public.avatares'));
select t.ok('el nivel sube cada 1000 XP', privado.nivel_de_xp(0) = 1 and privado.nivel_de_xp(999) = 1
  and privado.nivel_de_xp(1000) = 2 and privado.nivel_de_xp(4000) = 5);

select t.ok('se elige un avatar gratuito', t.run('fam1',
  $q$select public.elegir_avatar('10000000-0000-0000-0000-000000000001','av08')$q$));
select t.ok('...y queda guardado', (select avatar from public.perfiles_alumno where id='10000000-0000-0000-0000-000000000001') = 'av08');
select t.ok('no se elige un avatar que no se tiene', not t.run('fam1',
  $q$select public.elegir_avatar('10000000-0000-0000-0000-000000000001','av18')$q$));
select t.ok('no se elige avatar del perfil ajeno', not t.run('fam2',
  $q$select public.elegir_avatar('10000000-0000-0000-0000-000000000001','av01')$q$));
select t.ok('el avatar no se cambia por update directo', not t.run('fam1',
  $q$update public.perfiles_alumno set avatar = 'av18' where nombre = 'Hijo1'$q$));
select t.ok('el avatar no se fija al crear un perfil', not t.run('fam1', format(
  $q$insert into public.perfiles_alumno (familia_id, nombre, anio_nacimiento, nivel, consentimiento_at, avatar)
     values (%L, 'Otro', 2016, 'gamer', now(), 'av18')$q$, t.u('fam1'))));

-- Comprar con XP: Hijo1 tiene 300 XP
select t.ok('no se compra un avatar que cuesta más que el saldo', not t.run('fam1',
  $q$select public.comprar_avatar('10000000-0000-0000-0000-000000000001','av03')$q$));
select t.ok('otra familia no compra por el perfil ajeno', not t.run('fam2',
  $q$select public.comprar_avatar('10000000-0000-0000-0000-000000000001','av02')$q$));
select t.ok('no se compra un avatar que no existe', not t.run('fam1',
  $q$select public.comprar_avatar('10000000-0000-0000-0000-000000000001','av99')$q$));
select t.ok('se compra un avatar de 300 XP con 300 XP', t.run('fam1',
  $q$select public.comprar_avatar('10000000-0000-0000-0000-000000000001','av02')$q$));
select t.ok('...el saldo baja a 0 pero el XP ganado y el nivel no',
  (t.val('fam1', $q$select public.mi_progreso('10000000-0000-0000-0000-000000000001')::text$q$)::jsonb ->> 'saldo')::int = 0
  and (t.val('fam1', $q$select public.mi_progreso('10000000-0000-0000-0000-000000000001')::text$q$)::jsonb ->> 'xp')::int = 300
  and (select precio_pagado from public.avatares_desbloqueados where perfil_id='10000000-0000-0000-0000-000000000001' and avatar='av02') = 300);
select t.ok('no se compra dos veces el mismo avatar', not t.run('fam1',
  $q$select public.comprar_avatar('10000000-0000-0000-0000-000000000001','av02')$q$));
select t.ok('el avatar comprado ya se puede elegir', t.run('fam1',
  $q$select public.elegir_avatar('10000000-0000-0000-0000-000000000001','av02')$q$));
select t.ok('no se escribe directamente en los avatares conseguidos', not t.run('fam1',
  $q$insert into public.avatares_desbloqueados (perfil_id, avatar) values ('10000000-0000-0000-0000-000000000001','av18')$q$));

-- Perfil nuevo (de la edad que sea): recibe avatar inicial y los 2 gratuitos
select t.ok('la familia crea un perfil nuevo', t.run('fam1', format(
  $q$insert into public.perfiles_alumno (familia_id, nombre, anio_nacimiento, nivel, consentimiento_at)
     values (%L, 'Nuevo', 2016, 'gamer', now())$q$, t.u('fam1'))));
select t.ok('...y recibe avatar inicial y los 2 gratuitos',
  (select avatar from public.perfiles_alumno where nombre='Nuevo') = 'av01'
  and (select count(*) from public.avatares_desbloqueados d join public.perfiles_alumno p on p.id=d.perfil_id where p.nombre='Nuevo') = 2);

-- ---------------- Revisión (0004) ----------------
-- Integridad de puntos
select t.ok('no se borra una clase que ya dio puntos', not t.run('coach1',
  $q$delete from public.sesiones where id='30000000-0000-0000-0000-000000000001'$q$)
  and (select count(*) from public.puntos) = 1);
select t.ok('no se borra un grupo con clases que dieron puntos', not t.run('dir1',
  $q$delete from public.grupos where id='20000000-0000-0000-0000-000000000001'$q$));
select t.ok('una sesión no se mueve de grupo', not t.run('coach1',
  $q$update public.sesiones set grupo_id = gen_random_uuid()$q$));
select t.ok('una sesión no se edita directamente', not t.run('coach1',
  $q$update public.sesiones set estado='impartida' where id='30000000-0000-0000-0000-000000000001'$q$));
select t.ok('coach2 no cierra la lista de A', not t.run('coach2',
  $q$select public.cerrar_lista('30000000-0000-0000-0000-000000000001')$q$));
select t.ok('el entrenador cierra la lista (clase impartida)', t.run('coach1',
  $q$select public.cerrar_lista('30000000-0000-0000-0000-000000000001')$q$));
select t.ok('...y queda como impartida', (select estado from public.sesiones where id='30000000-0000-0000-0000-000000000001') = 'impartida');
select t.ok('no se cancela una clase con asistencias confirmadas', not t.run('coach1', format(
  $q$select public.cancelar_clase('20000000-0000-0000-0000-000000000001', %L)$q$, current_date - 1)));

-- Ventana de confirmación
-- Preparación (como administrador): una clase futura, una antigua y una cancelada, con
-- asistencia marcada, para comprobar que la familia no puede confirmarlas
insert into public.sesiones (id, grupo_id, fecha, estado) values
  ('30000000-0000-0000-0000-000000000002','20000000-0000-0000-0000-000000000001', current_date + 6, 'planificada'),
  ('30000000-0000-0000-0000-000000000003','20000000-0000-0000-0000-000000000001', current_date - 29, 'planificada'),
  ('30000000-0000-0000-0000-000000000004','20000000-0000-0000-0000-000000000001', current_date - 8, 'cancelada');
insert into public.asistencias (sesion_id, perfil_id, marcada_por)
select s, '10000000-0000-0000-0000-000000000001', t.u('coach1') from unnest(array[
  '30000000-0000-0000-0000-000000000002','30000000-0000-0000-0000-000000000003',
  '30000000-0000-0000-0000-000000000004']::uuid[]) s;
select t.ok('el entrenador no marca una clase futura', not t.run('coach1',
  $q$select public.marcar_asistencia('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001','presente')$q$));
select t.ok('el entrenador no cambia la lista pasados 14 días', not t.run('coach1',
  $q$select public.marcar_asistencia('30000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001','ninguno')$q$));
select t.ok('el entrenador no marca en una clase cancelada', not t.run('coach1',
  $q$select public.marcar_asistencia('30000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000001','presente')$q$));
select t.ok('no se confirma una clase futura', not t.run('fam1',
  $q$select public.confirmar_asistencia('30000000-0000-0000-0000-000000000002','10000000-0000-0000-0000-000000000001')$q$));
select t.ok('no se confirma pasado el plazo', not t.run('fam1',
  $q$select public.confirmar_asistencia('30000000-0000-0000-0000-000000000003','10000000-0000-0000-0000-000000000001')$q$));
select t.ok('no se confirma una clase cancelada', not t.run('fam1',
  $q$select public.confirmar_asistencia('30000000-0000-0000-0000-000000000004','10000000-0000-0000-0000-000000000001')$q$));
select t.ok('ninguna de esas dio puntos', (select count(*) from public.puntos) = 1);

-- Ejercicios y longitudes
select t.ok('no se asocia un ejercicio público a una escuela ajena', not t.run('coach1', format(
  $q$insert into public.ejercicios (autor_id, escuela_id, titulo, jugadores_min, jugadores_max) values (%L,%L,'Ajeno',1,2)$q$,
  t.u('coach1'), (select id from cod where esc='B'))));
select t.ok('nombre demasiado largo rechazado', t.rows('fam1',
  format($q$update public.personas set nombre = repeat('x', 200) where id=%L$q$, t.u('fam1'))) = -1);
select t.ok('el nombre del registro se recorta a 80', (select length(nombre) from public.personas where id = t.u('dir1')) <= 80);

-- Tras la baja, la familia deja de ver el grupo
select t.ok('la baja no se hace por update directo', not t.run('fam1',
  $q$update public.membresias set estado='baja' where perfil_id='10000000-0000-0000-0000-000000000001'$q$));
select t.ok('fam2 no da de baja al hijo de fam1', not t.run('fam2', format(
  $q$select public.dejar_escuela(%L)$q$, (select id from public.membresias where perfil_id='10000000-0000-0000-0000-000000000001'))));
select t.ok('fam1 da de baja a su hijo', t.run('fam1', format(
  $q$select public.dejar_escuela(%L)$q$, (select id from public.membresias where perfil_id='10000000-0000-0000-0000-000000000001'))));
select t.ok('...y sus inscripciones quedan cerradas', not exists (
  select 1 from public.inscripciones where perfil_id='10000000-0000-0000-0000-000000000001' and hasta is null));
select t.ok('tras la baja, fam1 ya no ve el grupo ni sus sesiones',
  t.cnt('fam1', 'select 1 from public.grupos') = 0
  and t.cnt('fam1', 'select 1 from public.sesiones') = 0);
select t.ok('tras la baja, fam1 sigue viendo sus puntos (son suyos)', t.cnt('fam1', 'select 1 from public.puntos') = 1);
select t.ok('fam1 no se reactiva sola', t.rows('fam1',
  $q$update public.membresias set estado='activa' where perfil_id='10000000-0000-0000-0000-000000000001'$q$) <= 0);

-- Perfil: la familia sigue sin poder cambiar la cuenta vinculada
select t.ok('la familia no vincula otra cuenta al perfil', not t.run('fam1', format(
  $q$update public.perfiles_alumno set persona_id=%L where nombre='Hijo1'$q$, t.u('out'))));

-- Borrado de cuenta (al final: cambia los datos)
insert into auth.users (id, raw_user_meta_data) values
  ('00000000-0000-0000-0000-0000000000c1', '{"nombre":"teen"}');
insert into public.perfiles_alumno (id, familia_id, persona_id, nombre, anio_nacimiento, nivel, consentimiento_at)
values ('10000000-0000-0000-0000-000000000009', t.u('fam2'), '00000000-0000-0000-0000-0000000000c1', 'Teen', 2011, 'gamer', now());
delete from auth.users where id = '00000000-0000-0000-0000-0000000000c1';
select t.ok('se borra la cuenta propia de un alumno; el perfil familiar sigue',
  (select persona_id from public.perfiles_alumno where id='10000000-0000-0000-0000-000000000009') is null);
delete from auth.users where id = t.u('coach1');
select t.ok('se borra la cuenta de un entrenador que pasó lista y subió ejercicios',
  not exists (select 1 from public.personas where id = t.u('coach1'))
  and (select count(*) from public.ejercicios where autor_id is null) = 2
  and not exists (select 1 from public.asistencias where marcada_por = t.u('coach1'))
  and exists (select 1 from public.asistencias where sesion_id='30000000-0000-0000-0000-000000000001')
  and (select count(*) from public.puntos) = 1);
delete from auth.users where id = t.u('dir1');
select t.ok('se borra la cuenta de un director; la escuela sigue',
  (select creada_por from public.escuelas where id = (select id from cod where esc='A')) is null);
delete from auth.users where id = t.u('fam1');
select t.ok('se borra la cuenta de una familia y con ella los datos del menor',
  not exists (select 1 from public.perfiles_alumno where id='10000000-0000-0000-0000-000000000001')
  and (select count(*) from public.puntos) = 0
  and not exists (select 1 from public.asistencias where perfil_id='10000000-0000-0000-0000-000000000001'));

-- ---------------- Racha por días, XP según el plan y perfiles Mini (0005 + 0006) ----------------
-- Datos nuevos, todos de fam2 (que no se borra antes). Escuela A.
-- Los grupos 1 y 2 tienen clase el día de la semana de HOY; el 3, otro día.
insert into public.grupos (id, escuela_id, nombre, dia, hora, creado_at) values
  ('50000000-0000-0000-0000-000000000001', (select id from cod where esc='A'), 'Grupo 1', extract(isodow from current_date)::int, '17:00', now() - interval '200 days'),
  ('50000000-0000-0000-0000-000000000002', (select id from cod where esc='A'), 'Grupo 2', extract(isodow from current_date)::int, '18:00', now() - interval '200 days'),
  ('50000000-0000-0000-0000-000000000003', (select id from cod where esc='A'), 'Grupo 3', extract(isodow from current_date + 1)::int, '17:00', now() - interval '200 days');
create function t.alumno(p_id uuid, p_nombre text, p_edad int) returns void language sql as $$
  insert into public.perfiles_alumno (id, familia_id, nombre, anio_nacimiento, nivel, consentimiento_at)
  values (p_id, t.u('fam2'), p_nombre, extract(year from current_date)::int - p_edad, 'gamer', now());
  insert into public.membresias (persona_id, perfil_id, escuela_id, rol, estado)
  values (t.u('fam2'), p_id, (select id from cod where esc='A'), 'alumno', 'activa');
$$;
-- Clase del grupo hace d días (múltiplo de 7), con lista pasada (impartida)
create function t.clase(p_grupo uuid, p_dias int, p_estado public.estado_sesion default 'impartida') returns uuid language sql as $$
  insert into public.sesiones (grupo_id, fecha, estado) values (p_grupo, current_date - p_dias, p_estado)
  on conflict (grupo_id, fecha) do update set estado = excluded.estado returning id;
$$;
create function t.asiste(p_sesion uuid, p_perfil uuid, p_confirmada boolean default true, p_justificada boolean default false) returns void language sql as $$
  insert into public.asistencias (sesion_id, perfil_id, marcada_por, justificada, confirmada_por, confirmada_at)
  values (p_sesion, p_perfil, t.u('dir2'), p_justificada,
          case when p_confirmada then t.u('fam2') end, case when p_confirmada then now() end);
$$;

-- Otro alumno del grupo 1, para "pasar lista" sin que esté P2
select t.alumno('60000000-0000-0000-0000-000000000007', 'Otro', 12);

-- P2: grupo 1 desde hace 54 días → clases esperadas: -49, -42, -35, -28, -21, -14, -7 y hoy
select t.alumno('60000000-0000-0000-0000-000000000002', 'Racha', 12);
insert into public.inscripciones (perfil_id, grupo_id, desde) values ('60000000-0000-0000-0000-000000000002', '50000000-0000-0000-0000-000000000001', current_date - 54);
select t.asiste(t.clase('50000000-0000-0000-0000-000000000001', 49), '60000000-0000-0000-0000-000000000002');
select t.asiste(t.clase('50000000-0000-0000-0000-000000000001', 42), '60000000-0000-0000-0000-000000000002', false, true); -- falta justificada
select t.asiste(t.clase('50000000-0000-0000-0000-000000000001', 35), '60000000-0000-0000-0000-000000000002');
select t.clase('50000000-0000-0000-0000-000000000001', 28, 'cancelada');                                                   -- cancelada
-- -21: no se pasó lista (no hay sesión)
select t.asiste(t.clase('50000000-0000-0000-0000-000000000001', 14), '60000000-0000-0000-0000-000000000002');
select t.asiste(t.clase('50000000-0000-0000-0000-000000000001', 7), '60000000-0000-0000-0000-000000000002');
-- Clase anterior a apuntarse, con lista pasada y sin él: no cuenta
select t.asiste(t.clase('50000000-0000-0000-0000-000000000001', 56), '60000000-0000-0000-0000-000000000007', false);
select t.ok('racha: 7 semanas sin faltas = 43 días; no la rompen una falta justificada, una clase cancelada, un día sin lista ni clases anteriores a apuntarse',
  privado.racha_dias('60000000-0000-0000-0000-000000000002') = 43);

-- Se pasa lista el día -21 sin él: ahora es una falta
select t.asiste(t.clase('50000000-0000-0000-0000-000000000001', 21), '60000000-0000-0000-0000-000000000007', false);
select t.ok('racha: una falta (lista pasada sin él) la corta: solo cuentan -14 y -7 → 8 días',
  privado.racha_dias('60000000-0000-0000-0000-000000000002') = 8);

-- Presente pero la familia no confirmó en 14 días: cuenta como falta
select t.alumno('60000000-0000-0000-0000-000000000006', 'SinConfirmar', 12);
insert into public.inscripciones (perfil_id, grupo_id, desde) values ('60000000-0000-0000-0000-000000000006', '50000000-0000-0000-0000-000000000001', current_date - 30);
select t.asiste(t.clase('50000000-0000-0000-0000-000000000001', 28, 'impartida'), '60000000-0000-0000-0000-000000000006');
select t.asiste(t.clase('50000000-0000-0000-0000-000000000001', 21), '60000000-0000-0000-0000-000000000006', false);
select t.asiste(t.clase('50000000-0000-0000-0000-000000000001', 14), '60000000-0000-0000-0000-000000000006');
select t.asiste(t.clase('50000000-0000-0000-0000-000000000001', 7), '60000000-0000-0000-0000-000000000006', false);
select t.ok('racha: presente sin confirmar >14 días rompe; dentro del plazo no (queda solo -14 → 1 día)',
  privado.racha_dias('60000000-0000-0000-0000-000000000006') = 1);

-- XP según el plan: P3 en 3 grupos → cada clase vale 100 XP (300/3), sin racha
select t.alumno('60000000-0000-0000-0000-000000000003', 'TresDias', 12);
insert into public.inscripciones (perfil_id, grupo_id) select '60000000-0000-0000-0000-000000000003', id from public.grupos where id::text like '50000000%';
select t.asiste(t.clase('50000000-0000-0000-0000-000000000002', 0, 'planificada'), '60000000-0000-0000-0000-000000000003', false);
select t.ok('XP: el alumno de 3 grupos confirma la clase de hoy', t.run('fam2', format(
  $q$select public.confirmar_asistencia(%L,'60000000-0000-0000-0000-000000000003')$q$,
  (select id from public.sesiones where grupo_id='50000000-0000-0000-0000-000000000002' and fecha=current_date))));
select t.ok('...y gana 100 XP (300 / 3 clases a la semana)', (select valor from public.puntos where perfil_id='60000000-0000-0000-0000-000000000003') = 100);

-- XP con bonus de racha: P4 (solo grupo 2) con 4 semanas confirmadas confirma la quinta
select t.alumno('60000000-0000-0000-0000-000000000004', 'Bonus', 12);
insert into public.inscripciones (perfil_id, grupo_id, desde) values ('60000000-0000-0000-0000-000000000004', '50000000-0000-0000-0000-000000000002', current_date - 30);
select t.asiste(t.clase('50000000-0000-0000-0000-000000000002', d), '60000000-0000-0000-0000-000000000004') from unnest(array[28, 21, 14, 7]) d;
select t.asiste((select id from public.sesiones where grupo_id='50000000-0000-0000-0000-000000000002' and fecha=current_date), '60000000-0000-0000-0000-000000000004', false);
select t.ok('XP: confirma con una racha de 29 días', t.run('fam2', format(
  $q$select public.confirmar_asistencia(%L,'60000000-0000-0000-0000-000000000004')$q$,
  (select id from public.sesiones where grupo_id='50000000-0000-0000-0000-000000000002' and fecha=current_date))));
select t.ok('...gana 420 XP (300 + 40 % por 4 semanas de racha)', (select valor from public.puntos where perfil_id='60000000-0000-0000-0000-000000000004') = 420);

-- Perfil Mini (5 años): no compra; desbloquea solo según su XP ganado
insert into public.perfiles_alumno (id, familia_id, nombre, anio_nacimiento, nivel, consentimiento_at)
values ('60000000-0000-0000-0000-000000000005', t.u('fam2'), 'Pequeño', extract(year from current_date)::int - 5, 'mini', now());
select t.ok('un Mini no puede comprar avatares', not t.run('fam2',
  $q$select public.comprar_avatar('60000000-0000-0000-0000-000000000005','av02')$q$));
insert into public.puntos (perfil_id, escuela_id, sesion_id, valor) values ('60000000-0000-0000-0000-000000000005', (select id from cod where esc='A'),
  (select id from public.sesiones where grupo_id='50000000-0000-0000-0000-000000000002' and fecha=current_date), 600);
select privado.desbloquear_mini('60000000-0000-0000-0000-000000000005') is not null;
select t.ok('un Mini desbloquea solo los avatares que alcanza su XP (hasta 600 XP)',
  (select count(*) from public.avatares_desbloqueados where perfil_id='60000000-0000-0000-0000-000000000005')
    = (select count(*) from public.avatares where precio_xp <= 600)
  and (select sum(precio_pagado) from public.avatares_desbloqueados where perfil_id='60000000-0000-0000-0000-000000000005') = 0);
select t.ok('...sin gastar XP (el saldo sigue entero)',
  (t.val('fam2', $q$select public.mi_progreso('60000000-0000-0000-0000-000000000005')::text$q$)::jsonb ->> 'saldo')::int = 600);

-- ---------------- Director y entrenador (0006), en la escuela B ----------------
select t.ok('dir2 crea un grupo con coach2 (clase el día de la semana de ayer)', t.run('dir2', format(
  $q$insert into public.grupos (id, escuela_id, nombre, dia, hora, entrenador_id, pista) values ('70000000-0000-0000-0000-000000000001',%L,'Grupo B',%s,'17:00',%L,'Pista 2')$q$,
  (select id from cod where esc='B'), extract(isodow from current_date - 1)::int, t.u('coach2'))));
update public.grupos set creado_at = now() - interval '200 days' where id = '70000000-0000-0000-0000-000000000001';

-- Alta de alumno por la escuela
create temp table alta (j jsonb);
select t.ok('un entrenador no da de alta alumnos', not t.run('coach2', format(
  $q$select public.alta_alumno(%L, 'Lola', 'Ruiz Paz', %s)$q$, (select id from cod where esc='B'), extract(year from current_date)::int - 10)));
select t.ok('no se da de alta con una edad fuera de 3-17', not t.run('dir2', format(
  $q$select public.alta_alumno(%L, 'Mayor', '', %s)$q$, (select id from cod where esc='B'), extract(year from current_date)::int - 20)));
select t.ok('no se inscribe en un grupo de otra escuela', not t.run('dir2', format(
  $q$select public.alta_alumno(%L, 'Lola', '', %s, array['50000000-0000-0000-0000-000000000001']::uuid[])$q$, (select id from cod where esc='B'), extract(year from current_date)::int - 10)));
insert into alta select t.val('dir2', format(
  $q$select public.alta_alumno(%L, 'Lola', 'Ruiz Paz', %s, array['70000000-0000-0000-0000-000000000001']::uuid[])::text$q$,
  (select id from cod where esc='B'), extract(year from current_date)::int - 10))::jsonb;
select t.ok('el director da de alta a una alumna sin familia, con código de 8 caracteres',
  (select j ->> 'codigo' from alta) ~ '^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$'
  and (select familia_id is null and consentimiento_at is null and apellidos = 'Ruiz Paz' from public.perfiles_alumno where id = (select (j ->> 'perfil_id')::uuid from alta))
  and exists (select 1 from public.membresias where perfil_id = (select (j ->> 'perfil_id')::uuid from alta) and estado = 'activa' and persona_id is null)
  and exists (select 1 from public.inscripciones where perfil_id = (select (j ->> 'perfil_id')::uuid from alta) and grupo_id = '70000000-0000-0000-0000-000000000001'));
select t.ok('el entrenador la ve en su escuela, pero no su código de vinculación',
  t.cnt('coach2', format('select 1 from public.perfiles_alumno where id = %L', (select j ->> 'perfil_id' from alta))) = 1
  and t.denegado('coach2', 'select codigo_vinculo from public.perfiles_alumno'));
select t.ok('el entrenador no obtiene el código con la función', not t.run('coach2', format(
  $q$select public.codigo_alumno(%L)$q$, (select j ->> 'perfil_id' from alta))));
select t.ok('el director sí ve el código', t.val('dir2', format(
  $q$select public.codigo_alumno(%L)$q$, (select j ->> 'perfil_id' from alta))) = (select j ->> 'codigo' from alta));
select t.ok('el director genera un código nuevo y el viejo deja de valer', t.val('dir2', format(
  $q$select public.codigo_alumno(%L, true)$q$, (select j ->> 'perfil_id' from alta))) <> (select j ->> 'codigo' from alta));

-- Pasar lista a la alumna de la escuela (aún sin familia)
select t.ok('coach2 pasa lista a la alumna en la clase de ayer', t.run('coach2', format(
  $q$select public.marcar_asistencia(public.sesion_para('70000000-0000-0000-0000-000000000001', %L), %L, 'presente')$q$,
  current_date - 1, (select j ->> 'perfil_id' from alta))));
select t.ok('no se justifica la falta de quien no estaba apuntado ese día', not t.run('coach2', format(
  $q$select public.marcar_asistencia(public.sesion_para('70000000-0000-0000-0000-000000000001', %L), %L, 'justificada')$q$,
  current_date - 1, (select j ->> 'perfil_id' from alta))));
select t.ok('lista de la clase: el entrenador ve a la alumna como presente',
  t.val('coach2', format($q$select estado from public.lista_de_clase(public.sesion_para('70000000-0000-0000-0000-000000000001', %L)) where perfil_id = %L$q$,
    current_date - 1, (select j ->> 'perfil_id' from alta))) = 'presente');
select t.ok('una familia no ve la lista de la clase', not t.run('fam2', format(
  $q$select * from public.lista_de_clase((select id from public.sesiones where grupo_id = '70000000-0000-0000-0000-000000000001' and fecha = %L))$q$, current_date - 1)));
select t.ok('sin familia vinculada nadie puede confirmar su asistencia', not t.run('fam2', format(
  $q$select public.confirmar_asistencia((select id from public.sesiones where grupo_id = '70000000-0000-0000-0000-000000000001' and fecha = %L), %L)$q$,
  current_date - 1, (select j ->> 'perfil_id' from alta))));

-- Vinculación por la familia
select t.ok('vincular exige el consentimiento', not t.run('fam2', $q$select public.vincular_alumno('AAAA-AAAA', false)$q$));
select t.ok('el código viejo no vincula (devuelve vacío)', t.val('fam2', format(
  $q$select public.vincular_alumno(%L, true)::text$q$, (select j ->> 'codigo' from alta))) is null);
select t.ok('fam2 vincula a la alumna con el código actual (sin guion y en minúsculas también vale)', t.val('fam2', format(
  $q$select public.vincular_alumno(%L, true)::text$q$,
  lower(replace((select codigo_vinculo from public.perfiles_alumno where id = (select (j ->> 'perfil_id')::uuid from alta)), '-', '')))) is not null);
select t.ok('...ahora es de fam2, con consentimiento, y el código ya no existe',
  (select familia_id = t.u('fam2') and consentimiento_at is not null and codigo_vinculo is null
   from public.perfiles_alumno where id = (select (j ->> 'perfil_id')::uuid from alta))
  and (select persona_id from public.membresias where perfil_id = (select (j ->> 'perfil_id')::uuid from alta)) = t.u('fam2'));
select t.ok('fam2 ya puede confirmar la asistencia de ayer', t.run('fam2', format(
  $q$select public.confirmar_asistencia((select id from public.sesiones where grupo_id = '70000000-0000-0000-0000-000000000001' and fecha = %L), %L)$q$,
  current_date - 1, (select j ->> 'perfil_id' from alta))));

-- Límite de intentos con códigos (founder no ha fallado ninguno)
select t.ok('10 códigos incorrectos se aceptan (devuelven vacío)',
  (select bool_and(t.run('founder', $q$select public.vincular_alumno('ZZZZ-ZZZZ', true)$q$)) from generate_series(1, 10)));
select t.ok('el siguiente intento se bloquea durante una hora (alumno y escuela)',
  not t.run('founder', $q$select public.vincular_alumno('ZZZZ-ZZZZ', true)$q$)
  and not t.run('founder', $q$select public.unirse_a_escuela('ZZZ-999', 'entrenador')$q$));
select t.ok('nadie lee el registro de intentos', t.denegado('founder', 'select * from privado.intentos_codigo'));

-- Cancelar clases y festivos
select t.ok('no se cancela una clase con asistencias confirmadas', not t.run('coach2', format(
  $q$select public.cancelar_clase('70000000-0000-0000-0000-000000000001', %L)$q$, current_date - 1)));
select t.ok('coach2 cancela la clase de la semana que viene', t.run('coach2', format(
  $q$select public.cancelar_clase('70000000-0000-0000-0000-000000000001', %L)$q$, current_date + 6)));
select t.ok('...queda cancelada', (select estado from public.sesiones where grupo_id = '70000000-0000-0000-0000-000000000001' and fecha = current_date + 6) = 'cancelada');
select t.ok('...y se reactiva', t.run('coach2', format(
  $q$select public.reactivar_clase((select id from public.sesiones where grupo_id = '70000000-0000-0000-0000-000000000001' and fecha = %L))$q$, current_date + 6)));
select t.ok('...vuelve a estar planificada', (select estado from public.sesiones where grupo_id = '70000000-0000-0000-0000-000000000001' and fecha = current_date + 6) = 'planificada');
select t.ok('un entrenador no cancela un día entero (festivo)', not t.run('coach2', format(
  $q$select public.cancelar_dia(%L, %L)$q$, (select id from cod where esc='B'), current_date + 13)));
select t.ok('el director cancela el día festivo (1 clase)', t.val('dir2', format(
  $q$select public.cancelar_dia(%L, %L)::text$q$, (select id from cod where esc='B'), current_date + 13)) = '1');
select t.ok('...y la clase de ese día queda cancelada', (select estado from public.sesiones where grupo_id = '70000000-0000-0000-0000-000000000001' and fecha = current_date + 13) = 'cancelada');

-- Inscripciones y bajas
select t.ok('el director desinscribe a la alumna', t.run('dir2', format(
  $q$select public.desinscribir(%L, '70000000-0000-0000-0000-000000000001')$q$, (select j ->> 'perfil_id' from alta))));
select t.ok('...se apuntó hoy, así que se borra (no hay historial que guardar)', not exists (select 1 from public.inscripciones where perfil_id = (select (j ->> 'perfil_id')::uuid from alta)));
select t.ok('y la vuelve a inscribir', t.run('dir2', format(
  $q$select public.inscribir(%L, '70000000-0000-0000-0000-000000000001')$q$, (select j ->> 'perfil_id' from alta))));
select t.ok('el director la da de baja de la escuela', t.run('dir2', format(
  $q$select public.resolver_membresia(%L, false)$q$, (select id from public.membresias where perfil_id = (select (j ->> 'perfil_id')::uuid from alta)))));
select t.ok('...y se cierran sus inscripciones', not exists (select 1 from public.inscripciones where perfil_id = (select (j ->> 'perfil_id')::uuid from alta) and hasta is null));
select t.ok('el único director no puede dejar la escuela', not t.run('dir2', format(
  $q$select public.dejar_escuela(%L)$q$, (select id from public.membresias where persona_id = t.u('dir2') and rol = 'director'))));
select t.ok('nadie deja la escuela por otro', not t.run('fam2', format(
  $q$select public.dejar_escuela(%L)$q$, (select id from public.membresias where persona_id = t.u('coach2') and rol = 'entrenador'))));
select t.ok('coach2 deja la escuela', t.run('coach2', format(
  $q$select public.dejar_escuela(%L)$q$, (select id from public.membresias where persona_id = t.u('coach2') and rol = 'entrenador'))));
select t.ok('...y su grupo se queda sin entrenador', (select entrenador_id from public.grupos where id = '70000000-0000-0000-0000-000000000001') is null);
select t.ok('...y ya no puede pasar lista', not t.run('coach2', format(
  $q$select public.sesion_para('70000000-0000-0000-0000-000000000001', %L)$q$, current_date - 1)));
select t.ok('el director archiva el grupo', t.rows('dir2',
  $q$update public.grupos set archivado_at = current_date where id = '70000000-0000-0000-0000-000000000001'$q$) = 1);
select t.ok('...y en un grupo archivado no se crean clases futuras ni se inscribe', not t.run('dir2', format(
  $q$select public.sesion_para('70000000-0000-0000-0000-000000000001', %L)$q$, current_date + 6))
  and not t.run('dir2', format($q$select public.inscribir(%L, '70000000-0000-0000-0000-000000000001')$q$, '10000000-0000-0000-0000-000000000002')));

select case when bool_and(ok) then 'TODAS LAS PRUEBAS PASAN (' || count(*) || ')'
       else 'HAY FALLOS' end as resultado from t.res;
select n, descr from t.res where not ok order by n;
rollback;
