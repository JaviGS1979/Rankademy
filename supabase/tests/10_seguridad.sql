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
      when 'founder' then 9 when 'rdir' then 16 when 'rc1' then 17 when 'rc2' then 18 when 'rc3' then 19
      when 'rfam' then 20 when 'rfam2' then 21 when 'rout' then 22 end), 12, '0'))::uuid $$;

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

-- ---------------- Ejercicios y biblioteca (0007) ----------------
-- Dibujos: D1 (cruzado), D1 en espejo izquierda-derecha, D2 (conos)
create function t.d1() returns jsonb language sql immutable as $$
  select '[{"t":"jugador","x":30,"y":100},{"t":"pelota","x":208,"y":42},{"t":"trayecto","de":[38,98],"a":[200,44],"tipo":"bola"}]'::jsonb $$;
create function t.d1_espejo() returns jsonb language sql immutable as $$
  select '[{"t":"jugador","x":210,"y":100},{"t":"pelota","x":32,"y":42},{"t":"trayecto","de":[202,98],"a":[40,44]}]'::jsonb $$;
create function t.d2() returns jsonb language sql immutable as $$
  select '[{"t":"cono","x":120,"y":20},{"t":"cono","x":120,"y":120},{"t":"jugador","x":120,"y":70}]'::jsonb $$;
-- Datos de un ejercicio para publicar_ejercicio
create function t.pub(titulo text, imgs jsonb, jmin int default 4, jmax int default 8, emin int default 8, emax int default 13,
                      vis text default 'publica', escuela uuid default null, original uuid default null, pasos jsonb default '[]')
returns text language sql immutable as $$
  select jsonb_strip_nulls(jsonb_build_object('titulo', titulo, 'imagenes', imgs, 'jugadores_min', jmin, 'jugadores_max', jmax,
    'edad_min', emin, 'edad_max', emax, 'visibilidad', vis, 'escuela_id', escuela, 'original_id', original,
    'pasos', pasos, 'material', '["pelotas","conos"]'::jsonb, 'nivel', 'medio', 'objetivo', 'derecha', 'espacio', 'media'))::text $$;
create table t.ej (nombre text primary key, id uuid);
create function t.ej(n text) returns uuid language sql stable as $$ select id from t.ej where nombre = n $$;
-- Publica como usuario y guarda el id con un nombre
create function t.publica(usr text, nombre text, datos text) returns void language sql as $$
  insert into t.ej values (nombre, t.val(usr, format('select public.publicar_ejercicio(%L::jsonb)::text', datos))::uuid) $$;

select t.publica('coach1', 'Cruzado', t.pub('Cruzado y paralelo', jsonb_build_array(t.d1()), pasos => '["Cruzado, 5 pelotas","Cambio: paralelo","Punto con premio"]'));
select t.ok('coach1 publica un ejercicio en la biblioteca', t.ej('Cruzado') is not null
  and (select autor_id = t.u('coach1') and visibilidad = 'publica' and escuela_id is null and huella is not null
              and cardinality(pasos) = 3 and nivel = 'medio' and material = '{conos,pelotas}'
       from public.ejercicios where id = t.ej('Cruzado'))
  and (select count(*) from public.ejercicio_imagenes where ejercicio_id = t.ej('Cruzado')) = 1);
select t.publica('coach1', 'SecretoA', t.pub('Secreto A', jsonb_build_array(t.d2(), t.d1()), 1, 2, vis => 'escuela', escuela => (select id from cod where esc='A')));
select t.ok('coach1 publica uno "solo mi escuela" con 2 imágenes', t.ej('SecretoA') is not null
  and (select count(*) from public.ejercicio_imagenes where ejercicio_id = t.ej('SecretoA')) = 2);
select t.ok('una familia no publica ejercicios', not t.run('fam1', format('select public.publicar_ejercicio(%L::jsonb)', t.pub('Falso', jsonb_build_array(t.d2()), 1, 2))));
select t.ok('un entrenador pendiente de aprobar no publica', not t.run('coach3', format('select public.publicar_ejercicio(%L::jsonb)', t.pub('Falso', jsonb_build_array(t.d2()), 1, 2))));
select t.ok('no se publica "solo mi escuela" en una escuela ajena', not t.run('coach1', format('select public.publicar_ejercicio(%L::jsonb)',
  t.pub('Intruso', jsonb_build_array(t.d2()), 1, 2, vis => 'escuela', escuela => (select id from cod where esc='B')))));
select t.ok('no se escribe en ejercicios ni imágenes directamente (ni el autor)',
  not t.run('coach1', format($q$insert into public.ejercicios (autor_id, titulo, jugadores_min, jugadores_max) values (%L,'Directo',1,2)$q$, t.u('coach1')))
  and not t.run('coach1', format($q$insert into public.ejercicio_imagenes (ejercicio_id, orden, elementos) values (%L, 3, %L)$q$, t.ej('Cruzado'), t.d2()))
  and not t.run('coach1', format($q$update public.ejercicios set titulo = 'Cambio' where id = %L$q$, t.ej('Cruzado')))
  and not t.run('coach1', format($q$delete from public.ejercicios where id = %L$q$, t.ej('Cruzado'))));

-- Validación del dibujo y de los datos
select t.ok('dibujo: fuera de la pista, tipo desconocido, claves extra, sin elementos o sin imágenes se rechazan',
  not t.run('coach1', format('select public.publicar_ejercicio(%L::jsonb)', t.pub('Malo', '[[{"t":"jugador","x":999,"y":10}]]'::jsonb, 1, 2)))
  and not t.run('coach1', format('select public.publicar_ejercicio(%L::jsonb)', t.pub('Malo', '[[{"t":"dragon","x":9,"y":10}]]'::jsonb, 1, 2)))
  and not t.run('coach1', format('select public.publicar_ejercicio(%L::jsonb)', t.pub('Malo', '[[{"t":"jugador","x":9,"y":10,"svg":"<script>"}]]'::jsonb, 1, 2)))
  and not t.run('coach1', format('select public.publicar_ejercicio(%L::jsonb)', t.pub('Malo', '[[{"t":"trayecto","de":[1,2],"a":["x",3]}]]'::jsonb, 1, 2)))
  and not t.run('coach1', format('select public.publicar_ejercicio(%L::jsonb)', t.pub('Malo', '[[]]'::jsonb, 1, 2)))
  and not t.run('coach1', format('select public.publicar_ejercicio(%L::jsonb)', t.pub('Malo', '[]'::jsonb, 1, 2))));
select t.ok('más de 5 imágenes, 4 pasos, jugadores o edades imposibles se rechazan',
  not t.run('coach1', format('select public.publicar_ejercicio(%L::jsonb)', t.pub('Malo', jsonb_build_array(t.d2(), t.d2(), t.d2(), t.d2(), t.d2(), t.d2()), 1, 2)))
  and not t.run('coach1', format('select public.publicar_ejercicio(%L::jsonb)', t.pub('Malo', jsonb_build_array(t.d2()), 1, 2, pasos => '["a","b","c","d"]')))
  and not t.run('coach1', format('select public.publicar_ejercicio(%L::jsonb)', t.pub('Malo', jsonb_build_array(t.d2()), 6, 2)))
  and not t.run('coach1', format('select public.publicar_ejercicio(%L::jsonb)', t.pub('Malo', jsonb_build_array(t.d2()), 1, 2, 2, 20))));
select t.ok('ninguno de los rechazados quedó guardado', (select count(*) from public.ejercicios) = 2);

-- Duplicados y variantes
select t.ok('buscar_parecidos: el mismo dibujo en espejo, con los mismos jugadores y edad, es 100 % igual',
  t.val('coach2', format('select parecido::text from public.buscar_parecidos(%L::jsonb, 4, 8, 8, 13) where id = %L',
    jsonb_build_array(t.d1_espejo()), t.ej('Cruzado'))) = '100');
select t.ok('buscar_parecidos: un dibujo distinto no aparece', t.cnt('coach2', format(
  'select 1 from public.buscar_parecidos(%L::jsonb, 1, 2, 14, 17)', jsonb_build_array(t.d2()))) = 0);
select t.ok('buscar_parecidos no compara con los ejercicios "solo mi escuela"', t.cnt('coach2', format(
  'select 1 from public.buscar_parecidos(%L::jsonb, 1, 2, 8, 13) where id = %L', jsonb_build_array(t.d2(), t.d1()), t.ej('SecretoA'))) = 0);
select t.ok('una familia no usa buscar_parecidos', not t.run('fam1', format(
  'select * from public.buscar_parecidos(%L::jsonb, 4, 8, 8, 13)', jsonb_build_array(t.d1()))));
select t.ok('no se publica una copia (aunque esté en espejo)', not t.run('coach2', format('select public.publicar_ejercicio(%L::jsonb)',
  t.pub('Mi cruzado', jsonb_build_array(t.d1_espejo())))));
select t.publica('coach2', 'Variante', t.pub('Mi cruzado', jsonb_build_array(t.d1_espejo()), original => t.ej('Cruzado')));
select t.ok('...pero sí como variante del original', (select original_id from public.ejercicios where id = t.ej('Variante')) = t.ej('Cruzado'));
select t.publica('coach2', 'Variante2', t.pub('Mi cruzado 2', jsonb_build_array(t.d1()), original => t.ej('Variante')));
select t.ok('la variante de una variante cuelga del original', (select original_id from public.ejercicios where id = t.ej('Variante2')) = t.ej('Cruzado'));
select t.ok('no hay variantes privadas ni de un ejercicio privado',
  not t.run('coach2', format('select public.publicar_ejercicio(%L::jsonb)', t.pub('Privada', jsonb_build_array(t.d1()), vis => 'escuela',
    escuela => (select id from cod where esc='B'), original => t.ej('Cruzado'))))
  and not t.run('coach2', format('select public.publicar_ejercicio(%L::jsonb)', t.pub('De privado', jsonb_build_array(t.d2()), original => t.ej('SecretoA')))));
select t.publica('coach2', 'Conos', t.pub('Conos en línea', jsonb_build_array(t.d2()), 1, 2, 14, 17));
select t.ok('un ejercicio distinto se publica sin problema', t.ej('Conos') is not null);
select t.publica('coach2', 'SecretoB', t.pub('Secreto B', jsonb_build_array(t.d2()), 1, 2, vis => 'escuela', escuela => (select id from cod where esc='B')));
select t.ok('un ejercicio público nunca guarda la escuela', t.viola_restriccion(format(
  $q$update public.ejercicios set escuela_id = %L where id = %L$q$, (select id from cod where esc='A'), t.ej('Cruzado'))));

-- Biblioteca anónima
select t.ok('biblioteca de coach2: los públicos originales (sin variantes) y los de su escuela',
  t.cnt('coach2', 'select 1 from public.biblioteca()') = 3
  and t.cnt('coach2', format('select 1 from public.biblioteca() where id in (%L, %L, %L)', t.ej('Cruzado'), t.ej('Conos'), t.ej('SecretoB'))) = 3);
select t.ok('biblioteca de coach1: no ve el privado de B', t.cnt('coach1', 'select 1 from public.biblioteca()') = 3
  and t.cnt('coach1', format('select 1 from public.biblioteca() where id = %L', t.ej('SecretoB'))) = 0);
select t.ok('biblioteca: el original muestra sus 2 variantes y si es mío',
  t.val('coach2', format('select variantes::text from public.biblioteca() where id = %L', t.ej('Cruzado'))) = '2'
  and t.val('coach2', format('select es_mio::text from public.biblioteca() where id = %L', t.ej('Cruzado'))) = 'false'
  and t.val('coach1', format('select es_mio::text from public.biblioteca() where id = %L', t.ej('Cruzado'))) = 'true');
select t.ok('biblioteca: no expone al autor ni la escuela', (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname in ('biblioteca', 'buscar_parecidos', 'ejercicios_de_clase')
    and (pg_get_function_result(p.oid) ilike '%autor%' or pg_get_function_result(p.oid) ilike '%escuela%')) = 0);
select t.ok('biblioteca vacía para una familia', t.cnt('fam1', 'select 1 from public.biblioteca()') = 0);
select t.ok('filtros: edad, texto, jugadores, nivel y material',
  t.cnt('coach2', 'select 1 from public.biblioteca(p_edad_min => 14, p_edad_max => 17)') = 1
  and t.cnt('coach2', $q$select 1 from public.biblioteca(p_texto => 'CRUZ')$q$) = 1
  and t.cnt('coach2', $q$select 1 from public.biblioteca(p_texto => '%')$q$) = 0
  and t.cnt('coach2', 'select 1 from public.biblioteca(p_jug_min => 10)') = 0
  and t.cnt('coach2', $q$select 1 from public.biblioteca(p_niveles => array['avanzado'])$q$) = 0
  and t.cnt('coach2', $q$select 1 from public.biblioteca(p_materiales => array['conos'])$q$) = 3);
select t.ok('"mis ejercicios": los míos, también variantes y privados', t.cnt('coach2', 'select 1 from public.biblioteca(p_mios => true)') = 4);
select t.ok('coach2 no lee directamente el ejercicio público de coach1 (ni su autor)',
  t.cnt('coach2', format('select 1 from public.ejercicios where id = %L', t.ej('Cruzado'))) = 0);

-- Detalle
select t.ok('detalle para coach2: datos, pasos, imágenes y variantes, sin autor',
  (select (d ->> 'titulo') = 'Cruzado y paralelo' and jsonb_array_length(d -> 'pasos') = 3
          and jsonb_array_length(d -> 'imagenes') = 1 and jsonb_array_length(d -> 'variantes') = 2
          and (d ->> 'es_mio')::boolean = false and not (d ? 'autor_id') and not (d ? 'escuela_id')
   from (select t.val('coach2', format('select public.detalle_ejercicio(%L)::text', t.ej('Cruzado')))::jsonb d) x));
select t.ok('detalle de una variante: muestra su original y las demás variantes',
  (select (d -> 'original' ->> 'id')::uuid = t.ej('Cruzado') and jsonb_array_length(d -> 'variantes') = 1
   from (select t.val('coach1', format('select public.detalle_ejercicio(%L)::text', t.ej('Variante')))::jsonb d) x));
select t.ok('detalle: nadie de fuera ve el privado; una familia no ve la biblioteca',
  not t.run('coach2', format('select public.detalle_ejercicio(%L)', t.ej('SecretoA')))
  and not t.run('fam2', format('select public.detalle_ejercicio(%L)', t.ej('Cruzado'))));

-- Editar, retirar y borrar
select t.ok('solo el autor edita los textos', not t.run('coach2', format(
  $q$select public.editar_ejercicio(%L, '{"titulo":"Hack"}'::jsonb)$q$, t.ej('Cruzado')))
  and t.run('coach1', format($q$select public.editar_ejercicio(%L, '{"titulo":"Cruzado y paralelo","pasos":["Cruzado","Paralelo"],"material":["pelotas"],"nivel":"medio","objetivo":"derecha","espacio":"media"}'::jsonb)$q$, t.ej('Cruzado'))));
select t.ok('...y el cambio queda guardado', (select cardinality(pasos) = 2 and material = '{pelotas}' from public.ejercicios where id = t.ej('Cruzado')));
select t.ok('editar valida pasos y valores', not t.run('coach1', format(
  $q$select public.editar_ejercicio(%L, '{"titulo":"Cruzado","pasos":["a","b","c","d"]}'::jsonb)$q$, t.ej('Cruzado')))
  and not t.run('coach1', format($q$select public.editar_ejercicio(%L, '{"titulo":"Cruzado","nivel":"experto"}'::jsonb)$q$, t.ej('Cruzado'))));

-- Ejercicios de una clase (sesión 30…01, grupo de coach1 en A, ayer)
select t.ok('coach1 prepara la clase con su público y su privado de A', t.run('coach1', format(
  'select public.guardar_ejercicios_clase(%L, array[%L, %L]::uuid[])', '30000000-0000-0000-0000-000000000001', t.ej('Cruzado'), t.ej('SecretoA'))));
select t.ok('...queda quién los añadió y en qué orden',
  (select bool_and(anadido_por = t.u('coach1')) from public.usos_ejercicio where sesion_id = '30000000-0000-0000-0000-000000000001')
  and (select orden from public.usos_ejercicio where sesion_id = '30000000-0000-0000-0000-000000000001' and ejercicio_id = t.ej('SecretoA')) = 1);
select t.ok('coach2 no prepara clases de A', not t.run('coach2', format(
  'select public.guardar_ejercicios_clase(%L, array[%L]::uuid[])', '30000000-0000-0000-0000-000000000001', t.ej('Cruzado'))));
select t.ok('coach1 no usa el privado de otra escuela', not t.run('coach1', format(
  'select public.guardar_ejercicios_clase(%L, array[%L]::uuid[])', '30000000-0000-0000-0000-000000000001', t.ej('SecretoB'))));
select t.ok('no se repite un ejercicio en la clase', not t.run('coach1', format(
  'select public.guardar_ejercicios_clase(%L, array[%L, %L]::uuid[])', '30000000-0000-0000-0000-000000000001', t.ej('Cruzado'), t.ej('Cruzado'))));
select t.ok('no se escriben usos directamente', not t.run('coach1', format(
  $q$insert into public.usos_ejercicio (sesion_id, ejercicio_id) values ('30000000-0000-0000-0000-000000000001', %L)$q$, t.ej('Conos'))));
select t.ok('el uso cuenta: "usado por 1 entrenador"', t.val('coach2', format(
  'select usado_por::text from public.biblioteca() where id = %L', t.ej('Cruzado'))) = '1');
select t.ok('la familia del alumno ve los ejercicios de su clase (sin autor) y su detalle',
  t.cnt('fam1', $q$select 1 from public.ejercicios_de_clase('30000000-0000-0000-0000-000000000001')$q$) = 2
  and t.run('fam1', format('select public.detalle_ejercicio(%L)', t.ej('SecretoA'))));
select t.ok('otra familia no ve los ejercicios de esa clase', not t.run('fam2',
  $q$select * from public.ejercicios_de_clase('30000000-0000-0000-0000-000000000001')$q$));
select t.ok('no se borra un ejercicio usado o con variantes', not t.run('coach1', format('select public.borrar_ejercicio(%L)', t.ej('Cruzado'))));
select t.ok('solo el autor borra; uno sin usar sí se borra',
  not t.run('coach1', format('select public.borrar_ejercicio(%L)', t.ej('Conos')))
  and t.run('coach2', format('select public.borrar_ejercicio(%L)', t.ej('Conos'))));
select t.ok('...y desaparece con sus imágenes', not exists (select 1 from public.ejercicios where id = t.ej('Conos'))
  and not exists (select 1 from public.ejercicio_imagenes where ejercicio_id = t.ej('Conos')));
select t.ok('coach1 retira su ejercicio: desaparece de la biblioteca pero sigue en la clase',
  t.run('coach1', format('select public.retirar_ejercicio(%L)', t.ej('Cruzado')))
  and t.cnt('coach2', format('select 1 from public.biblioteca() where id = %L', t.ej('Cruzado'))) = 0
  and t.cnt('coach1', $q$select 1 from public.ejercicios_de_clase('30000000-0000-0000-0000-000000000001') where retirado$q$) = 1);
select t.ok('uno retirado se conserva en la clase, pero no se vuelve a añadir',
  t.run('coach1', format('select public.guardar_ejercicios_clase(%L, array[%L, %L]::uuid[])', '30000000-0000-0000-0000-000000000001', t.ej('SecretoA'), t.ej('Cruzado')))
  and t.run('coach1', format('select public.guardar_ejercicios_clase(%L, array[%L]::uuid[])', '30000000-0000-0000-0000-000000000001', t.ej('SecretoA')))
  and not t.run('coach1', format('select public.guardar_ejercicios_clase(%L, array[%L, %L]::uuid[])', '30000000-0000-0000-0000-000000000001', t.ej('SecretoA'), t.ej('Cruzado'))));
select t.ok('solo el autor lo retira, y lo puede devolver a la biblioteca',
  not t.run('coach2', format('select public.retirar_ejercicio(%L, false)', t.ej('Cruzado')))
  and t.run('coach1', format('select public.retirar_ejercicio(%L, false)', t.ej('Cruzado')))
  and t.run('coach1', format('select public.guardar_ejercicios_clase(%L, array[%L, %L]::uuid[])', '30000000-0000-0000-0000-000000000001', t.ej('Cruzado'), t.ej('SecretoA'))));

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

-- Ejercicios privados entre escuelas: dir2 (director de B) es también entrenador en A
insert into public.membresias (persona_id, escuela_id, rol, estado) values (t.u('dir2'), (select id from cod where esc='A'), 'entrenador', 'activa');
select t.ok('quien está en dos escuelas no usa el ejercicio privado de A en una clase de B', not t.run('dir2', format(
  $q$select public.guardar_ejercicios_clase(public.sesion_para('70000000-0000-0000-0000-000000000001', %L), array[%L]::uuid[])$q$,
  current_date - 1, t.ej('SecretoA'))));
select t.ok('...aunque sí lo ve (es de su otra escuela) y sí usa uno público', t.run('dir2', format('select public.detalle_ejercicio(%L)', t.ej('SecretoA')))
  and t.run('dir2', format($q$select public.guardar_ejercicios_clase(public.sesion_para('70000000-0000-0000-0000-000000000001', %L), array[%L]::uuid[])$q$,
  current_date - 1, t.ej('Cruzado'))));
select t.ok('...y su uso cuenta (el de coach1 ya no: borró su cuenta y su uso quedó anónimo)', t.val('coach2', format(
  'select usado_por::text from public.biblioteca() where id = %L', t.ej('Cruzado'))) = '1');
delete from public.membresias where persona_id = t.u('dir2') and escuela_id = (select id from cod where esc='A');

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

-- ---------------- Rankings (0008) ----------------
-- Escenario propio: temporada desde hace 100 días; 5 escuelas (E1-E3 en Huelva, E4 en
-- Sevilla, E5 en Huelva pero sin participar). Mínimo de participantes por escuela: 2.
create or replace function privado.inicio_temporada() returns date language sql stable set search_path = '' as $$ select current_date - 100 $$;
create or replace function privado.minimo_participantes_escuela() returns integer language sql immutable as $$ select 2 $$;
insert into auth.users (id, raw_user_meta_data) select t.u(n), jsonb_build_object('nombre', x) from (values
  ('rdir', 'Rosa Directora'), ('rc1', 'Lucía Martín'), ('rc2', 'Javier Costa'), ('rc3', 'Elena Pinar'),
  ('rfam', 'Familia R'), ('rfam2', 'Familia R2'), ('rout', 'Sin escuela')) v(n, x);
insert into public.escuelas (id, nombre, ciudad, provincia, comunidad, codigo, creada_por, participa_ranking) values
  ('e1000000-0000-0000-0000-000000000001', 'Marismas', 'Huelva', 'Huelva', 'Andalucía', 'RKA-AA2', t.u('rdir'), true),
  ('e1000000-0000-0000-0000-000000000002', 'Costa', 'Punta Umbría', ' huelva', 'Andalucía', 'RKA-AA3', t.u('rdir'), true),
  ('e1000000-0000-0000-0000-000000000003', 'Dunas', 'Matalascañas', 'Huelva', 'Andalucía', 'RKA-AA4', t.u('rdir'), true),
  ('e1000000-0000-0000-0000-000000000004', 'Giralda', 'Sevilla', 'Sevilla', 'Andalucía', 'RKA-AA5', t.u('rdir'), true),
  ('e1000000-0000-0000-0000-000000000005', 'Fuera', 'Lepe', 'Huelva', 'Andalucía', 'RKA-AA6', t.u('rdir'), false);
insert into public.membresias (persona_id, escuela_id, rol, estado) values
  (t.u('rdir'), 'e1000000-0000-0000-0000-000000000001', 'director', 'activa'),
  (t.u('rc1'), 'e1000000-0000-0000-0000-000000000001', 'entrenador', 'activa'),
  (t.u('rc2'), 'e1000000-0000-0000-0000-000000000002', 'entrenador', 'activa'),
  (t.u('rc3'), 'e1000000-0000-0000-0000-000000000003', 'entrenador', 'activa');
create function t.ralumno(p_id uuid, p_fam text, p_nombre text, p_apellidos text, p_edad int, p_escuelas uuid[]) returns void language sql as $$
  insert into public.perfiles_alumno (id, familia_id, nombre, apellidos, anio_nacimiento, nivel, consentimiento_at)
  values (p_id, t.u(p_fam), p_nombre, p_apellidos, extract(year from current_date)::int - p_edad, (case when p_edad <= 7 then 'mini' else 'gamer' end)::public.nivel_alumno, now());
  insert into public.membresias (persona_id, perfil_id, escuela_id, rol, estado)
  select t.u(p_fam), p_id, e, 'alumno', 'activa' from unnest(p_escuelas) e;
$$;
select t.ralumno('a1000000-0000-0000-0000-000000000001', 'rfam', 'Iker', 'López Mora', 10, array['e1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000002']::uuid[]);
select t.ralumno('a1000000-0000-0000-0000-000000000002', 'rfam', 'Noa', 'Ruiz', 12, array['e1000000-0000-0000-0000-000000000001']::uuid[]);
select t.ralumno('a1000000-0000-0000-0000-000000000003', 'rfam', 'Peque', '', 6, array['e1000000-0000-0000-0000-000000000001']::uuid[]);
select t.ralumno('a1000000-0000-0000-0000-000000000004', 'rfam2', 'Alma Sofía', '', 11, array['e1000000-0000-0000-0000-000000000002']::uuid[]);
select t.ralumno('a1000000-0000-0000-0000-000000000005', 'rfam2', 'Carla', 'Vidal', 13, array['e1000000-0000-0000-0000-000000000005']::uuid[]);
update public.perfiles_alumno set participa_ranking = false where id = 'a1000000-0000-0000-0000-000000000002'; -- Noa no quiere salir

-- Grupos (todos con clase el mismo día de la semana que hace 7 días)
insert into public.grupos (id, escuela_id, nombre, dia, hora, entrenador_id, creado_at) values
  ('b1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', 'G1', extract(isodow from current_date - 7)::int, '17:00', t.u('rc1'), (current_date - 22)::timestamp + interval '12 hours'),
  ('b1000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000002', 'G2', extract(isodow from current_date - 7)::int, '17:00', t.u('rc2'), now() - interval '200 days'),
  ('b1000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000003', 'G3', extract(isodow from current_date - 7)::int, '17:00', t.u('rc3'), now() - interval '200 days'),
  ('b1000000-0000-0000-0000-000000000004', 'e1000000-0000-0000-0000-000000000001', 'G4', extract(isodow from current_date - 7)::int, '19:00', null, now() - interval '200 days'),
  ('b1000000-0000-0000-0000-000000000005', 'e1000000-0000-0000-0000-000000000005', 'G5', extract(isodow from current_date - 7)::int, '17:00', null, now() - interval '200 days');
insert into public.inscripciones (perfil_id, grupo_id, desde) values
  ('a1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000001', current_date - 30),
  ('a1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000001', current_date - 30),
  ('a1000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000001', current_date - 30),
  ('a1000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000002', current_date - 60),
  ('a1000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000004', current_date - 60),
  ('a1000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000004', current_date - 60),
  ('a1000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000004', current_date - 60);
-- G1 (rc1): tocaban -21, -14 y -7. -21 y -14 con lista; -7 cancelada.
do $$ begin
  perform t.clase('b1000000-0000-0000-0000-000000000001', 21), t.clase('b1000000-0000-0000-0000-000000000001', 14),
          t.clase('b1000000-0000-0000-0000-000000000001', 7, 'cancelada'), t.clase('b1000000-0000-0000-0000-000000000001', 150);
end $$;
create function t.rses(g text, d int) returns uuid language sql stable as $$
  select id from public.sesiones where grupo_id = ('b1000000-0000-0000-0000-00000000000' || g)::uuid and fecha = current_date - d $$;
-- Asistencias de G1 marcadas por rc1: en -21 Iker y Noa confirmadas, Peque sin confirmar; en -14 Iker confirmada, Noa justificada
insert into public.asistencias (sesion_id, perfil_id, marcada_por, justificada, confirmada_por, confirmada_at) values
  (t.rses('1', 21), 'a1000000-0000-0000-0000-000000000001', t.u('rc1'), false, t.u('rfam'), now()),
  (t.rses('1', 21), 'a1000000-0000-0000-0000-000000000002', t.u('rc1'), false, t.u('rfam'), now()),
  (t.rses('1', 21), 'a1000000-0000-0000-0000-000000000003', t.u('rc1'), false, null, null),
  (t.rses('1', 14), 'a1000000-0000-0000-0000-000000000001', t.u('rc1'), false, t.u('rfam'), now()),
  (t.rses('1', 14), 'a1000000-0000-0000-0000-000000000002', t.u('rc1'), true, null, null);
-- G2 (rc2): 7 clases con lista; G3 (rc3): 1 con lista y 1 planificada; G5 (escuela que no participa): 1
do $$ begin
  perform t.clase('b1000000-0000-0000-0000-000000000002', 7 * k) from generate_series(1, 7) k;
  perform t.clase('b1000000-0000-0000-0000-000000000003', 14), t.clase('b1000000-0000-0000-0000-000000000003', 7, 'planificada');
  perform t.clase('b1000000-0000-0000-0000-000000000005', 14);
end $$;
-- Puntos: Iker 300 + 300 en E1 y 100 en E2 (y 1000 de antes de la temporada); Noa y Peque 300; Alma 450; Carla 999 en E5
insert into public.puntos (perfil_id, escuela_id, sesion_id, valor) values
  ('a1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', t.rses('1', 21), 300),
  ('a1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', t.rses('1', 14), 300),
  ('a1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000001', t.rses('1', 150), 1000),
  ('a1000000-0000-0000-0000-000000000001', 'e1000000-0000-0000-0000-000000000002', t.rses('2', 14), 100),
  ('a1000000-0000-0000-0000-000000000002', 'e1000000-0000-0000-0000-000000000001', t.rses('1', 21), 300),
  ('a1000000-0000-0000-0000-000000000003', 'e1000000-0000-0000-0000-000000000001', t.rses('1', 21), 300),
  ('a1000000-0000-0000-0000-000000000004', 'e1000000-0000-0000-0000-000000000002', t.rses('2', 14), 450),
  ('a1000000-0000-0000-0000-000000000005', 'e1000000-0000-0000-0000-000000000005', t.rses('5', 14), 999);
-- Ejercicios: uno público de rc1 (X1), una variante de rc3 (XV) y uno privado de rc1 (XP)
insert into public.ejercicios (id, autor_id, escuela_id, visibilidad, titulo, jugadores_min, jugadores_max, original_id) values
  ('c1000000-0000-0000-0000-000000000001', t.u('rc1'), null, 'publica', 'X1', 2, 4, null),
  ('c1000000-0000-0000-0000-000000000002', t.u('rc3'), null, 'publica', 'XV', 2, 4, 'c1000000-0000-0000-0000-000000000001'),
  ('c1000000-0000-0000-0000-000000000003', t.u('rc1'), 'e1000000-0000-0000-0000-000000000001', 'escuela', 'XP', 2, 4, null);
-- rc2 usa X1 en sus 7 clases (y la variante en la misma clase de -7): 7 usos de otra escuela = 14, tope 10.
-- rc2 usa el privado: no cuenta. rc1 usa el suyo: no cuenta. rc3 usa la variante en su clase con lista (+2)
-- y X1 en una clase sin lista (no cuenta).
insert into public.usos_ejercicio (sesion_id, ejercicio_id, anadido_por)
select t.rses('2', 7 * k), 'c1000000-0000-0000-0000-000000000001', t.u('rc2') from generate_series(1, 7) k;
insert into public.usos_ejercicio (sesion_id, ejercicio_id, anadido_por) values
  (t.rses('2', 7), 'c1000000-0000-0000-0000-000000000002', t.u('rc2')),
  (t.rses('2', 14), 'c1000000-0000-0000-0000-000000000003', t.u('rc2')),
  (t.rses('1', 21), 'c1000000-0000-0000-0000-000000000001', t.u('rc1')),
  (t.rses('3', 14), 'c1000000-0000-0000-0000-000000000002', t.u('rc3')),
  (t.rses('3', 7), 'c1000000-0000-0000-0000-000000000001', t.u('rc3'));

-- Puntuación de rc1: uso 12 ponderados → 120; constancia 2 de 2 → 1000; alumnos 3 de 5 → 600; total 528
select t.ok('entrenador: uso con peso doble entre escuelas, tope por pareja, sin propios, privados ni clases sin lista',
  (t.val('rfam', format('select public.perfil_entrenador(%L)::text', t.u('rc1')))::jsonb ->> 'uso')::int = 120
  and (t.val('rfam', format('select public.perfil_entrenador(%L)::text', t.u('rc1')))::jsonb ->> 'usos')::int = 8);
select t.ok('entrenador: constancia (las canceladas no cuentan) y asistencia confirmada de sus alumnos (sin justificadas)',
  (t.val('rfam', format('select public.perfil_entrenador(%L)::text', t.u('rc1')))::jsonb ->> 'constancia')::int = 1000
  and (t.val('rfam', format('select public.perfil_entrenador(%L)::text', t.u('rc1')))::jsonb ->> 'alumnos')::int = 600);
select t.ok('entrenador: total 40/30/30 = 528, con nombre público y escuelas',
  (select (d ->> 'puntos')::int = 528 and d ->> 'nombre' = 'Lucía M.' and d -> 'escuelas' = '["Marismas"]'::jsonb and not (d ->> 'es_mio')::boolean
   from (select t.val('rfam', format('select public.perfil_entrenador(%L)::text', t.u('rc1')))::jsonb d) x));
update public.sesiones set estado = 'planificada' where id = t.rses('1', 7);
select t.ok('entrenador: una clase que tocaba sin lista baja la constancia (2 de 3 → 667)',
  (t.val('rc1', format('select public.perfil_entrenador(%L)::text', t.u('rc1')))::jsonb ->> 'constancia')::int = 667);
update public.sesiones set estado = 'cancelada' where id = t.rses('1', 7);
select t.ok('perfil de entrenador: no lo ve quien no está en ninguna escuela', not t.run('rout', format('select public.perfil_entrenador(%L)', t.u('rc1'))));

-- Ranking de alumnos
select t.ok('alumnos, mi escuela: solo puntos de la temporada y de esa escuela; sin Mini ni quien no quiere salir',
  t.cnt('rfam', $q$select 1 from public.ranking_alumnos('e1000000-0000-0000-0000-000000000001')$q$) = 1
  and t.val('rfam', $q$select nombre || '|' || puntos || '|' || es_mio || '|' || posicion || '|' || escuela from public.ranking_alumnos('e1000000-0000-0000-0000-000000000001')$q$) = 'Iker L.|600|true|1|Marismas');
select t.ok('alumnos, provincia: aparece una vez con su total; sin escuelas que no participan ni de otra provincia',
  t.cnt('rfam2', $q$select 1 from public.ranking_alumnos('e1000000-0000-0000-0000-000000000002', 'provincia')$q$) = 2
  and t.val('rfam2', $q$select puntos::text from public.ranking_alumnos('e1000000-0000-0000-0000-000000000002', 'provincia') where nombre = 'Iker L.'$q$) = '700'
  and t.val('rfam2', $q$select nombre || '|' || es_mio from public.ranking_alumnos('e1000000-0000-0000-0000-000000000002', 'provincia') where posicion = 2$q$) = 'Alma S.|true'
  and t.val('rfam2', $q$select escuela from public.ranking_alumnos('e1000000-0000-0000-0000-000000000002', 'provincia') where nombre = 'Iker L.'$q$) = 'Marismas');
select t.ok('alumnos: filtro de edad', t.cnt('rfam2', $q$select 1 from public.ranking_alumnos('e1000000-0000-0000-0000-000000000002', 'provincia', 11, 13)$q$) = 1);
select t.ok('alumnos: el ranking no devuelve identificadores ni apellidos', (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname in ('ranking_alumnos', 'ranking_escuelas')
    and (pg_get_function_result(p.oid) ilike '%perfil%' or pg_get_function_result(p.oid) ilike '%apellido%' or pg_get_function_result(p.oid) ilike '%_id%')) = 0);
select t.ok('alumnos: quien no es de la escuela no ve su ranking; nadie de fuera ve ninguno',
  not t.run('rfam2', $q$select * from public.ranking_alumnos('e1000000-0000-0000-0000-000000000001')$q$)
  and not t.run('rout', $q$select * from public.ranking_alumnos('e1000000-0000-0000-0000-000000000001', 'pais')$q$));
select t.ok('una escuela que no participa no tiene ranking (ni sus alumnos aparecen)',
  t.cnt('rfam2', $q$select 1 from public.ranking_alumnos('e1000000-0000-0000-0000-000000000005')$q$) = 0
  and t.cnt('rfam2', $q$select 1 from public.ranking_alumnos('e1000000-0000-0000-0000-000000000002', 'pais') where nombre = 'Carla V.'$q$) = 0
  and (t.val('rfam2', $q$select public.estado_ranking('e1000000-0000-0000-0000-000000000005')::text$q$)::jsonb ->> 'participa')::boolean = false);
select t.ok('la familia saca a su hijo del ranking', t.rows('rfam',
  $q$update public.perfiles_alumno set participa_ranking = false where id = 'a1000000-0000-0000-0000-000000000001'$q$) = 1);
select t.ok('...y desaparece', t.cnt('rfam', $q$select 1 from public.ranking_alumnos('e1000000-0000-0000-0000-000000000001')$q$) = 0);
update public.perfiles_alumno set participa_ranking = true where id = 'a1000000-0000-0000-0000-000000000001';

-- Zonas con pocas escuelas
select t.ok('estado: 3 escuelas en la provincia (sin importar mayúsculas o espacios), 5 en la comunidad (con la B de Sevilla)',
  (select (d ->> 'escuelas_provincia')::int = 3 and (d ->> 'escuelas_comunidad')::int = 5 and (d ->> 'minimo_escuelas')::int = 3
   from (select t.val('rdir', $q$select public.estado_ranking('e1000000-0000-0000-0000-000000000001')::text$q$)::jsonb d) x));
update public.escuelas set participa_ranking = false where id = 'e1000000-0000-0000-0000-000000000003';
select t.ok('con solo 2 escuelas en la provincia no hay ranking de zona (sí el de la escuela)',
  t.cnt('rfam', $q$select 1 from public.ranking_alumnos('e1000000-0000-0000-0000-000000000001', 'provincia')$q$) = 0
  and t.cnt('rfam', $q$select 1 from public.ranking_entrenadores('e1000000-0000-0000-0000-000000000001', 'provincia')$q$) = 0
  and t.cnt('rfam', $q$select 1 from public.ranking_escuelas('e1000000-0000-0000-0000-000000000001', 'provincia')$q$) = 0
  and t.cnt('rfam', $q$select 1 from public.ranking_alumnos('e1000000-0000-0000-0000-000000000001')$q$) = 1);
update public.escuelas set participa_ranking = true where id = 'e1000000-0000-0000-0000-000000000003';

-- Ranking de entrenadores
select t.ok('entrenadores, provincia: ordenados por puntos, una vez cada uno, y el propio marcado',
  t.cnt('rc2', $q$select 1 from public.ranking_entrenadores('e1000000-0000-0000-0000-000000000002', 'provincia')$q$) = 3
  and t.val('rc2', $q$select nombre || '|' || puntos || '|' || escuela from public.ranking_entrenadores('e1000000-0000-0000-0000-000000000002', 'provincia') where posicion = 1$q$) = 'Lucía M.|528|Marismas'
  and t.val('rc2', $q$select posicion::text from public.ranking_entrenadores('e1000000-0000-0000-0000-000000000002', 'provincia') where es_mio$q$) = '2');
select t.ok('entrenadores, mi escuela', t.cnt('rfam', $q$select 1 from public.ranking_entrenadores('e1000000-0000-0000-0000-000000000001')$q$) = 1);

-- Ranking de escuelas: media de entrenadores y alumnos; E3 (1 participante) no llega al mínimo
select t.ok('escuelas, provincia: solo las que llegan al mínimo, con su media y la mía marcada',
  t.cnt('rdir', $q$select 1 from public.ranking_escuelas('e1000000-0000-0000-0000-000000000001', 'provincia')$q$) = 2
  and t.val('rdir', $q$select nombre || '|' || puntos || '|' || es_mia from public.ranking_escuelas('e1000000-0000-0000-0000-000000000001', 'provincia') where posicion = 1$q$) = 'Marismas|764|true'
  and t.val('rdir', $q$select nombre || '|' || puntos || '|' || es_mia from public.ranking_escuelas('e1000000-0000-0000-0000-000000000001', 'provincia') where posicion = 2$q$) = 'Costa|494|false');
select t.ok('...una familia con hijos en dos escuelas ve marcadas las dos', t.cnt('rfam',
  $q$select 1 from public.ranking_escuelas('e1000000-0000-0000-0000-000000000001', 'provincia') where es_mia$q$) = 2);
select t.ok('escuelas: no hay ranking "de mi escuela"', not t.run('rfam', $q$select * from public.ranking_escuelas('e1000000-0000-0000-0000-000000000001', 'escuela')$q$));

-- Patrones raros (G4: 3 alumnos presentes en sus 6 últimas clases, marcadas por rc1 y sin confirmar)
insert into public.asistencias (sesion_id, perfil_id, marcada_por)
select t.clase('b1000000-0000-0000-0000-000000000004', 7 * k), p, t.u('rc1')
from generate_series(1, 6) k, unnest(array['a1000000-0000-0000-0000-000000000001', 'a1000000-0000-0000-0000-000000000002', 'a1000000-0000-0000-0000-000000000003']::uuid[]) p;
select t.ok('anomalías: el director ve el grupo siempre completo y al entrenador cuyas listas no confirman las familias',
  t.cnt('rdir', $q$select 1 from public.anomalias('e1000000-0000-0000-0000-000000000001') where tipo = 'siempre_completo' and grupo = 'G4'$q$) = 1
  and t.cnt('rdir', $q$select 1 from public.anomalias('e1000000-0000-0000-0000-000000000001') where tipo = 'sin_confirmar' and entrenador = 'Lucía M.'$q$) = 1);
select t.ok('anomalías: G1 no sale (no siempre completo)', t.cnt('rdir', $q$select 1 from public.anomalias('e1000000-0000-0000-0000-000000000001') where grupo = 'G1'$q$) = 0);
select t.ok('anomalías: solo el director (ni entrenadores ni familias)',
  not t.run('rc1', $q$select * from public.anomalias('e1000000-0000-0000-0000-000000000001')$q$)
  and not t.run('rfam', $q$select * from public.anomalias('e1000000-0000-0000-0000-000000000001')$q$));
select t.ok('anónimo: no ejecuta ninguna función de ranking', not has_function_privilege('anon', 'public.ranking_alumnos(uuid,text,integer,integer)', 'execute')
  and not has_function_privilege('anon', 'public.anomalias(uuid)', 'execute'));

select case when bool_and(ok) then 'TODAS LAS PRUEBAS PASAN (' || count(*) || ')'
       else 'HAY FALLOS' end as resultado from t.res;
select n, descr from t.res where not ok order by n;
rollback;
