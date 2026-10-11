// Genera src/lib/avatares.ts a partir de las imágenes de assets/avatares/ y dice qué falta.
//   npm run avatares
//
// Convención de nombres (NN = número del avatar, con dos cifras, del 01 al 20):
//   avNN.jpg     miniatura, 220×220 px (la usan el selector, la rejilla de avatares, etc.)
//   hero-NN.jpg  imagen grande en cuerpo completo, 780×1036 px (formato 3:4), para el inicio
//
// Si un avatar no tiene hero-NN.jpg la app muestra su miniatura dentro de un círculo.
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const raiz = join(dirname(fileURLToPath(import.meta.url)), '..');
const carpeta = join(raiz, 'assets', 'avatares');
const TOTAL = 20;
const MINIATURA = [220, 220];
const HEROE = [780, 1036];

const archivos = new Set(readdirSync(carpeta));
const num = (n) => String(n).padStart(2, '0');

// Lee el tamaño de un JPEG sin dependencias
function tamano(ruta) {
  const b = readFileSync(ruta);
  if (b[0] !== 0xff || b[1] !== 0xd8) return null;
  let i = 2;
  while (i < b.length) {
    if (b[i] !== 0xff) return null;
    const marca = b[i + 1];
    const largo = b.readUInt16BE(i + 2);
    if (marca >= 0xc0 && marca <= 0xcf && ![0xc4, 0xc8, 0xcc].includes(marca)) {
      return [b.readUInt16BE(i + 7), b.readUInt16BE(i + 5)];
    }
    i += 2 + largo;
  }
  return null;
}

const informe = [];
const miniaturas = [];
const heroes = [];
for (let n = 1; n <= TOTAL; n++) {
  const id = `av${num(n)}`;
  const mini = `${id}.jpg`;
  const hero = `hero-${num(n)}.jpg`;
  const linea = { id, mini: archivos.has(mini), hero: archivos.has(hero), avisos: [] };
  if (linea.mini) {
    miniaturas.push(id);
    const t = tamano(join(carpeta, mini));
    if (!t) linea.avisos.push(`${mini} no es un JPG válido`);
    else if (t[0] !== MINIATURA[0] || t[1] !== MINIATURA[1]) linea.avisos.push(`${mini} mide ${t[0]}×${t[1]} (ideal ${MINIATURA.join('×')})`);
  }
  if (linea.hero) {
    heroes.push(id);
    const t = tamano(join(carpeta, hero));
    if (!t) linea.avisos.push(`${hero} no es un JPG válido`);
    else if (Math.abs(t[0] / t[1] - HEROE[0] / HEROE[1]) > 0.02) linea.avisos.push(`${hero} mide ${t[0]}×${t[1]}: la proporción debería ser 3:4 (ideal ${HEROE.join('×')})`);
    else if (t[0] < HEROE[0] * 0.8) linea.avisos.push(`${hero} mide ${t[0]}×${t[1]}: es pequeña, se verá borrosa (ideal ${HEROE.join('×')})`);
  }
  informe.push(linea);
}

const fuera = [...archivos].filter((f) => !/^(av\d{2}|hero-\d{2})\.jpg$/.test(f));

const salida = `// GENERADO por scripts/avatares.mjs (npm run avatares). No editar a mano.
import type { ImageSourcePropType } from 'react-native';

// Miniaturas de los avatares (220×220)
export const miniaturas: Record<string, ImageSourcePropType> = {
${miniaturas.map((id) => `  ${id}: require('../../assets/avatares/${id}.jpg'),`).join('\n')}
};

// Imágenes en cuerpo completo (780×1036). Para los avatares que no aparecen aquí
// se usa la miniatura dentro de un círculo (ver components/Heroe).
export const heroes: Record<string, ImageSourcePropType> = {
${heroes.map((id) => `  ${id}: require('../../assets/avatares/hero-${id.slice(2)}.jpg'),`).join('\n')}
};

export const AVATAR_INICIAL = 'av01';
`;
writeFileSync(join(raiz, 'src', 'lib', 'avatares.ts'), salida);

console.log('Avatar  Miniatura  Imagen grande');
for (const l of informe) console.log(`${l.id}    ${l.mini ? '   ✓     ' : '   FALTA '}   ${l.hero ? '   ✓' : '   FALTA (se usará la miniatura)'}`);
const avisos = informe.flatMap((l) => l.avisos);
if (avisos.length) console.log('\nAvisos:\n' + avisos.map((a) => ' - ' + a).join('\n'));
if (fuera.length) console.log('\nArchivos ignorados por no seguir el nombre avNN.jpg / hero-NN.jpg:\n' + fuera.map((f) => ' - ' + f).join('\n'));
console.log(`\n${heroes.length} de ${TOTAL} avatares con imagen grande. Archivo src/lib/avatares.ts actualizado.`);
if (miniaturas.length < TOTAL) process.exitCode = 1;
