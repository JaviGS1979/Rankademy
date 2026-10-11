// Ejecutar con: node --test src/lib/errores.test.ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { codigoAlumnoValido, codigoValido, normalizarCodigo, normalizarCodigoAlumno } from './errores.ts';

test('código de alumno: se formatea mientras se escribe', () => {
  assert.equal(normalizarCodigoAlumno('k7pa'), 'K7PA');
  assert.equal(normalizarCodigoAlumno('k7pa3'), 'K7PA-3');
  assert.equal(normalizarCodigoAlumno('k7pa-3qxm extra'), 'K7PA-3QXM');
  assert.equal(normalizarCodigoAlumno('  k7pa 3qxm '), 'K7PA-3QXM');
});

test('código de alumno: solo el alfabeto sin I, O, 0 ni 1', () => {
  assert.ok(codigoAlumnoValido('K7PA-3QXM'));
  assert.ok(!codigoAlumnoValido('K7PA3QXM'));
  assert.ok(!codigoAlumnoValido('K7PA-3QX'));
  assert.ok(!codigoAlumnoValido('K7PA-3Q0M'));
  assert.ok(!codigoAlumnoValido('K7PA-3QIM'));
});

test('el código de escuela sigue igual', () => {
  assert.equal(normalizarCodigo('tt9l9f'), 'TT9-L9F');
  assert.ok(codigoValido('TT9-L9F'));
  assert.ok(!codigoAlumnoValido('TT9-L9F'));
});
