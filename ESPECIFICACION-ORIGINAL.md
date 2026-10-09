# Rankademy — Descripción completa del MVP

## 1. Resumen en una frase
Rankademy es una app móvil donde las escuelas de tenis compiten en un ranking de **entrenadores**, **alumnos** y **escuelas**. Para participar, los entrenadores y los alumnos de cada escuela deben tener la app. La app incluye lo mínimo de gestión de clases (sesiones y pasar lista) y una **biblioteca de ejercicios en vídeo** muy fácil de usar en pista.

## 2. Problema y propuesta de valor
- Las apps de gestión de escuelas de tenis ya existen. **No existe un ranking de entrenadores y alumnos entre escuelas.**
- Para el alumno: ver su progreso, su racha y su posición, y desbloquear avatares por asistir.
- Para el entrenador: reconocimiento público por la calidad de su trabajo y acceso a una biblioteca de ejercicios compartida.
- Para el director: visibilidad de su escuela y captación de alumnos, sin tener que cambiar de herramienta.
- Efecto red: cuantas más escuelas, más vale estar dentro.

## 3. Roles de usuario
1. **Director de escuela:** crea la escuela, comparte el código, decide si participa en el ranking.
2. **Entrenador:** imparte clases, usa y sube ejercicios, pasa lista.
3. **Familia:** cuenta de un adulto responsable que gestiona uno o varios perfiles de hijos.
4. **Alumno:** perfil dentro de la cuenta familiar (Mini 3-7, Gamer 8-13, Junior 14-17). A partir de 14 años puede tener cuenta propia.
5. (Fuera del MVP) Alumno adulto +18 y administrador de plataforma.

## 4. Principio de diseño: máxima sencillez
- Registro en un solo paso con **máximo 3 campos** (código de escuela, nombre, correo), o acceso con Apple o Google.
- Un niño nunca crea cuenta propia por debajo de 14 años: la familia crea la suya y añade perfiles de hijos (nombre y año de nacimiento).
- Cada pantalla tiene **una acción principal**.
- Botones grandes, poco texto, iconos claros. Español como idioma principal.

## 5. Niveles de alumno
| Nivel | Edad | Experiencia |
|---|---|---|
| Mini | 3-7 | Sin necesidad de leer. Iconos y pictogramas grandes, pegatinas, racha. **Sin ranking.** |
| Gamer | 8-13 | Modo gamer: XP, racha, skills, avatares coleccionables, posición en el ranking. |
| Junior | 14-17 | Mismo modo, con aspecto más sobrio. Puede tener cuenta propia. |

## 6. Pantallas del MVP (29)

### Comunes
1. **Arranque:** logotipo y entrada.
2. **Soy…:** director / entrenador / familia.
3. **Registro en un paso:** código de escuela + nombre + correo, o Apple / Google.

### Director
4. **Crear escuela:** nombre, ciudad, logo. Genera un código único.
5. **Panel:** código para compartir, nº de entrenadores y alumnos, posición de la escuela.
6. **Entrenadores y alumnos:** lista, alta y baja.
7. **Participar en el ranking:** interruptor para activar o desactivar.

### Familia y alumno
8. **Añadir hijo:** nombre y año de nacimiento.
9. **Selector de perfil.**
10. **Inicio Mini (3-7):** próxima clase, pegatinas, racha, todo con iconos grandes.
11. **Inicio Gamer (8-18):** próxima clase, racha, mi posición.
12. **Mi progreso:** skills y nivel.
13. **Avatares:** colección, desbloqueo por asistencia.
14. **Mis ejercicios:** los ejercicios de mi clase en vídeo.
15. **Resumen tras la clase:** XP ganado, racha, subida de nivel.

### Entrenador
16. **Inicio:** sesiones de hoy y mi posición en el ranking.
17. **Mis grupos y alumnos.**
18. **Crear sesión:** elegir ejercicios de la biblioteca, grupo y fecha.
19. **Pasar lista:** un toque por alumno.

### Biblioteca (pieza clave)
20. **Biblioteca:** cuadrícula de tarjetas con vídeo corto en bucle, nombre, edad y duración.
21. **Filtros rápidos:** edad, nivel, objetivo, nº de jugadores, material, espacio.
22. **Detalle del ejercicio:** vídeo arriba, diagrama de pista, máximo 3 pasos con iconos, material, variaciones, "usado por X entrenadores".
23. **Modo pista:** pantalla completa, texto muy grande, manejo con una mano, funciona sin conexión.
24. **Subir ejercicio:** grabar vídeo, elegir plantilla de pista, rellenar 3 campos.

### Ranking
25. **Ranking de alumnos:** desde 8 años; filtro por escuela o zona y por edad.
26. **Ranking de entrenadores:** por escuela o zona.
27. **Ranking de escuelas.**
28. **Perfil público de entrenador:** posición, desglose de puntos, ejercicios más usados.
29. **Cómo se puntúa:** explicación simple.

### Estados especiales
- Ranking vacío o "aún no hay suficientes escuelas en tu zona".
- Escuela que no participa en el ranking.
- Onboarding de 2-3 pasos en el primer uso de cada rol.

## 7. Flujos principales
**Alta de escuela:** el director se registra, crea la escuela y recibe un código. Lo comparte con sus entrenadores y con las familias.

**Entrenador:** entra con el código, crea un grupo, añade alumnos (o los alumnos se unen con el código), crea una sesión con ejercicios de la biblioteca y, al terminar, pasa lista.

**Familia:** se registra con el código, añade a sus hijos, elige perfil, ve la próxima clase, la racha y la posición.

**Pasar lista:** el entrenador toca a cada alumno presente. Al confirmar, cada alumno recibe XP, se actualiza su racha y suben sus skills según los ejercicios de la sesión. La familia puede ver la asistencia registrada.

## 8. Reglas de puntuación (valores iniciales, ajustables)
**Alumno (desde 8 años):** puntos por clase asistida, bonus por racha y puntos por subida de nivel de skill. El ranking premia la **constancia**; el nivel de juego queda para una fase posterior con partidos verificados.

**Entrenador:**
- 40 % — uso real de sus ejercicios por otros entrenadores. Solo cuenta cuando el ejercicio se incluye en una sesión que se imparte y se pasa lista. Pesa el doble si el entrenador pertenece a otra escuela. Hay un tope de puntos por pareja de entrenadores para evitar acuerdos entre ellos.
- 30 % — constancia: sesiones planificadas e impartidas con lista pasada.
- 30 % — asistencia y progreso de sus alumnos frente a lo esperado.

**Escuela:** media de las puntuaciones de sus entrenadores y alumnos, con un mínimo de participantes para aparecer.

**Antitrampas:** la lista pasada por el entrenador es visible para la familia; se marcan patrones anómalos (por ejemplo, 100 % de asistencia siempre).

## 9. Datos principales (modelo)
- **Escuela:** id, nombre, ciudad, logo, código, participa_en_ranking.
- **Usuario:** id, rol, nombre, correo, escuela(s).
- **Alumno (perfil):** id, nombre, año de nacimiento, nivel (Mini/Gamer/Junior), cuenta familiar, escuela, XP, racha, skills, avatares.
- **Grupo:** id, escuela, entrenador, alumnos, horario.
- **Ejercicio:** id, autor, título, vídeo, diagrama, pasos (máx. 3), material, edad, nivel, objetivo, nº jugadores, espacio, variaciones.
- **Sesión:** id, grupo, fecha, ejercicios.
- **Asistencia:** sesión, alumno, presente, confirmado_por.
- **Puntuación:** entidad (alumno / entrenador / escuela), periodo, puntos, desglose.

## 10. Permisos
- Director: ve y gestiona solo su escuela.
- Entrenador: ve sus grupos, sube y usa ejercicios, pasa lista a sus grupos.
- Familia: ve solo a sus hijos.
- Rankings: se muestran nombre o alias, posición y puntos. No se muestran datos de contacto. Los menores aparecen solo con nombre de pila o alias y avatar, nunca con foto real.

## 11. Privacidad y menores
- Consentimiento de la familia obligatorio para cualquier perfil de menor, aceptado al añadirlo.
- Datos mínimos de los menores.
- Opción de no aparecer en rankings públicos.
- Baja de cuenta y borrado de datos disponibles para la familia.
- (Revisar el texto legal con asesor antes del lanzamiento.)

## 12. Diseño visual
- Identidad propia, independiente de otros productos. Estilo deportivo, limpio, alegre para niños y sobrio para entrenadores y directores.
- Mobile-first, pensado para usar con una mano y al aire libre (contraste alto, texto grande).
- Modo Mini con pictogramas y sin texto necesario.
- Biblioteca: el vídeo manda sobre el texto. Un ejercicio debe entenderse en 5 segundos. Si hay más de tres líneas de texto, sobra.

## 13. Fuera del MVP
Pagos, facturas, horarios avanzados, sorteos, mensajes, partidos verificados y liga, versión de adultos, valoraciones entre entrenadores, valoraciones de familias.

## 14. Criterios de éxito del MVP
- Una escuela completa (director + entrenadores + alumnos) está dentro en menos de 10 minutos.
- Un entrenador crea una sesión y pasa lista en menos de 2 minutos.
- Un entrenador entiende un ejercicio de la biblioteca en menos de 5 segundos.
- Los rankings se actualizan tras cada lista.
- Piloto: 5-6 escuelas de una misma zona con ranking local.

## 15. Orden de construcción recomendado
1. Registro, escuelas y códigos.
2. Grupos, sesiones y pasar lista.
3. Biblioteca de ejercicios (ver, filtrar, subir, modo pista).
4. XP, racha y avatares.
5. Rankings y perfil público de entrenador.
6. Estados vacíos y onboarding.
