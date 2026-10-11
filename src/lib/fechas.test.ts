// Ejecutar con: node --test src/lib/fechas.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  deISO, diaSemana, fechaCorta, etiquetaDia, etiquetaFecha, etiquetaSesion, horaValida, hoyISO, ocurrenciasDelGrupo, porcentaje, proximaClase,
  proximaOcurrencia,
} from './fechas.ts';

// Miércoles 7 oct 2026, 12:00 (hora local)
const ahora = new Date(2026, 9, 7, 12, 0);

test('clase de hoy que aún no ha empezado', () => {
  const c = proximaOcurrencia(3, '17:00:00', ahora);
  assert.equal(c.getDate(), 7);
  assert.equal(etiquetaDia(c, ahora), 'Hoy');
});

test('clase de hoy que ya empezó pasa a la semana siguiente', () => {
  const c = proximaOcurrencia(3, '10:00:00', ahora);
  assert.equal(c.getDate(), 14);
});

test('mañana y un día de la semana', () => {
  assert.equal(etiquetaDia(proximaOcurrencia(4, '17:00:00', ahora), ahora), 'Mañana');
  assert.equal(etiquetaDia(proximaOcurrencia(1, '17:00:00', ahora), ahora), 'Lunes');
});

test('el domingo es el día 7', () => {
  const c = proximaOcurrencia(7, '10:00:00', ahora);
  assert.equal(c.getDay(), 0);
  assert.equal(c.getDate(), 11);
});

test('elige la clase más próxima entre varios grupos', () => {
  const r = proximaClase(
    [
      { id: 'a', nombre: 'Lunes', dia: 1, hora: '17:00:00' },
      { id: 'b', nombre: 'Jueves', dia: 4, hora: '18:30:00' },
    ],
    ahora,
  );
  assert.equal(r?.grupo.id, 'b');
  assert.equal(r?.etiqueta, 'Mañana 18:30');
});

test('sin grupos no hay próxima clase', () => {
  assert.equal(proximaClase([], ahora), null);
});

test('etiquetas de sesión', () => {
  assert.equal(etiquetaSesion('2026-10-06', ahora), 'Ayer');
  assert.equal(etiquetaSesion('2026-10-07', ahora), 'Hoy');
  assert.equal(etiquetaSesion('2026-10-05', ahora), 'Lunes 5');
  assert.equal(hoyISO(ahora), '2026-10-07');
});

test('fechas de un grupo: dos antes, la de hoy o la próxima y dos después', () => {
  // Hoy es miércoles 7: un grupo de miércoles incluye hoy
  assert.deepEqual(ocurrenciasDelGrupo(3, ahora), ['2026-09-23', '2026-09-30', '2026-10-07', '2026-10-14', '2026-10-21']);
  // Un grupo de lunes: la próxima es el 12 y las anteriores el 5 y el 28/9
  assert.deepEqual(ocurrenciasDelGrupo(1, ahora), ['2026-09-28', '2026-10-05', '2026-10-12', '2026-10-19', '2026-10-26']);
});

test('nunca se ofrece una fecha de más de 14 días atrás', () => {
  const limite = new Date(2026, 9, 7);
  limite.setDate(limite.getDate() - 14);
  for (let dia = 1; dia <= 7; dia++) {
    for (const f of ocurrenciasDelGrupo(dia, ahora)) {
      assert.ok(deISO(f) >= limite, `${f} (día ${dia})`);
      assert.equal(diaSemana(deISO(f)), dia);
    }
  }
});

test('etiquetas de fecha', () => {
  assert.equal(etiquetaFecha('2026-10-08', ahora), 'Mañana');
  assert.equal(etiquetaFecha('2026-10-07', ahora), 'Hoy');
  assert.equal(etiquetaFecha('2026-10-12', ahora), 'Lunes 12');
});

test('hora válida', () => {
  assert.equal(horaValida('17:00'), '17:00');
  assert.equal(horaValida('9:30'), '09:30');
  assert.equal(horaValida('1730'), '17:30');
  assert.equal(horaValida('17.30'), '17:30');
  assert.equal(horaValida('24:00'), null);
  assert.equal(horaValida('17:75'), null);
  assert.equal(horaValida('tarde'), null);
});

test('fecha corta y porcentaje', () => {
  assert.equal(fechaCorta('2026-10-05'), '5 oct');
  assert.equal(fechaCorta('2026-01-30'), '30 ene');
  assert.equal(porcentaje(1, 3), 33);
  assert.equal(porcentaje(2, 3), 67);
  assert.equal(porcentaje(5, 0), 0);
});
