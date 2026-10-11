# Rankademy

App móvil (iOS, Android y web) con el ranking de las escuelas de tenis.
Expo (React Native) + TypeScript + Expo Router; backend en Supabase.

- `design/` — diseño original (38 pantallas HTML), `HANDOFF.md` y `ESPECIFICACION-ORIGINAL.md`. Abre `design/index.html` para verlas.
- `app/` — rutas (Expo Router).
- `src/theme` — tokens de color y tipografía (de `design/assets/rankademy.css`).
- `src/components` — componentes base.
- `assets/avatares/` — avatares: `avNN.jpg` (miniatura 220×220) y `hero-NN.jpg` (cuerpo completo 780×1036); los nombres están en la tabla `avatares` de la base de datos. Tras añadir imágenes, `npm run avatares`.

## Desarrollo

```bash
npm install
npx expo start        # Expo Go en el móvil; pulsa "w" para web
npx tsc --noEmit      # comprobación de tipos
npm test              # pruebas de las fechas de clase
npm run avatares      # actualiza los avatares a partir de assets/avatares/ e informa de los que faltan
supabase/tests/run.sh # pruebas de seguridad de la base de datos (PostgreSQL local)
```

## Configuración

Copia `.env.example` a `.env` con la URL y la clave pública de Supabase. La base de datos y el acceso por correo se configuran según `supabase/README.md`.

## Estado

- Fase 1: proyecto Expo, tema y pantallas de arranque.
- Fase 2: esquema de Supabase, reglas de acceso (RLS) y pruebas de seguridad.
- Fase 3: registro e inicio de sesión con código por correo, crear escuela, unirse con código, añadir hijo, Mis escuelas y aprobación de solicitudes.
- Fase 5a: base de datos de director y entrenador (horario, pasar lista, alumnos de la escuela con código para la familia).
- Fase 5b: pantallas del director y del entrenador: Hoy, Horario, grupos, pasar lista, preparar clase (cancelar y reactivar), Personas, inscribir alumno con código y vincular alumno desde la familia. Los ejercicios de la clase llegan con la biblioteca (Fase 6).
- Fase 8b: panel del fundador (resumen con crecimiento, actividad, retención, biblioteca y rankings, con gráficas de 12 semanas; piloto por escuela; alertas). Solo lo ve quien está en la tabla de fundadores.
- Fase 8a: base de datos del panel del fundador (resumen, piloto por escuela y alertas), solo para el fundador.
- Fase 7b: pantallas de los rankings (alumnos, entrenadores y escuelas por escuela, provincia, comunidad y país), perfil público del entrenador, "Cómo se puntúa", avisos de escuela que no participa y zona con pocas escuelas, provincia y comunidad en el panel de la escuela, "Mi posición" del entrenador y patrones raros para el director.
- Fase 7a: base de datos de los rankings (alumnos, entrenadores, escuelas, zonas, perfil de entrenador y patrones raros).
- Fase 6b: pantallas de la biblioteca: cuadrícula con búsqueda y filtros, detalle con imágenes y pasos, editor para dibujar sobre la pista, aviso de ejercicio parecido (usar el existente o publicar como variante), mis ejercicios, ejercicios de cada clase, modo pista (pantalla siempre encendida y copia sin conexión) y los ejercicios de la clase en el perfil del alumno.
- Fase 6a: base de datos de la biblioteca (dibujo validado, duplicados en espejo, variantes, biblioteca anónima con filtros, ejercicios de cada clase).
- Fase 4: selector de perfil, inicio Mini y Gamer, confirmar asistencia, resumen tras la clase, progreso, avatares y ejercicios de la clase.
