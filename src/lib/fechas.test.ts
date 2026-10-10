// Ejecutar con: node --test src/lib/fechas.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { etiquetaDia, etiquetaSesion, hoyISO, proximaClase, proximaOcurrencia } from './fechas.ts';

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
