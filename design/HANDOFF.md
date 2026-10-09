# Rankademy — traspaso del diseño a código

Este paquete contiene el diseño del MVP (38 pantallas de 390×844) en HTML estático, para usarlo como referencia visual al construir la app. `index.html` lista las pantallas en orden; ábrelo en un navegador. Los enlaces entre pantallas muestran la navegación prevista. La especificación original del producto está en `ESPECIFICACION-ORIGINAL.md`.

## Estructura
- `pages/` — una pantalla por archivo (referencia visual, no código de producción).
- `assets/rankademy.css` — estilos compartidos: clases `.s .btn .card .rk .tab .seg .chip .tag .av .bar .tile .ex .step`, etc.
- `assets/court.svg` — pista de tenis; el ejercicio se dibuja encima con un SVG de viewBox 240×140.
- `assets/avatars/` — 18 avatares (miniaturas `av01–av18`) y 2 versiones grandes en cuerpo completo (`hero-*`).
- `canvas.json` — orden y título de las pantallas.

## Sistema visual
- Colores: lima `#C8E63A`, azul `#2446F0`, tinta `#0F1D2E`, naranja `#C2410C`, grises `#46566B`, `#B6C2D0`, `#DCE2E9`; fondo Mini `#F6FAD9`.
- Tipografías: Barlow Condensed (titulares y números, 700/800) y Figtree (texto).
- Reglas: objetivos táctiles de 44 px como mínimo, sin emojis, textos en español, contraste alto. Respetar "reducir movimiento".
- Wordmark: "Rank" en blanco y "ademy" en lima, siempre junto y en una línea.

## Roles
Director, Entrenador y Alumno. El alumno tiene tres variantes: Mini (3-7 años, casi sin texto, botones grandes), Gamer (8-18) y familia (un adulto gestiona perfiles de sus hijos).

## Reglas de negocio acordadas
1. **Una cuenta por persona, varias escuelas.** La escuela es una membresía (se une con un código tipo A7K-29Q y el director aprueba). Selector de escuela en Inicio del entrenador, Horario y Ranking. Racha, avatares y logros pertenecen a la persona.
2. **Puntos por clases.** Cada escuela suma solo las clases hechas en ella. En los rankings de provincia, comunidad y país la persona aparece una sola vez, con su total. Alerta si dos clases coinciden en hora.
3. **Grupos = un día + una hora**, con nombre libre elegido por el director. Un alumno puede estar en varios grupos. Un entrenador puede no tener grupo.
4. **Asistencia en dos pasos.** El entrenador pasa lista (y puede añadir alumnos de la lista completa de la escuela); el alumno o su familia la confirma en su perfil, y solo entonces recibe XP y logros.
5. **Ejercicios.** Sin duración; rango de jugadores "entre X y Y". Se dibujan sobre una pista, con varias imágenes por ejercicio. Los de la biblioteca son anónimos. Al subir, se detectan duplicados (comparación del dibujo, también en espejo, más jugadores y edad): se ofrece "usar el existente" o "publicar como variante". Los usos de las variantes se suman al original, y el crédito es de quien lo subió primero. Opción "Solo mi escuela" (privado, no cuenta para el ranking).
6. **Rankings.** Alumnos: mi escuela, provincia, comunidad, país. Escuelas: provincial, autonómico, nacional (sin mostrar nº de alumnos ni entrenadores). Entrenadores: uso de sus ejercicios 40 %, constancia 30 %, progreso de alumnos 30 %. Participar en el ranking es opcional.

## Modelo de datos sugerido
persona · escuela · membresía (persona, escuela, rol, estado) · perfil_alumno (familia → hijos) · grupo (escuela, nombre, día, hora, entrenador?) · inscripción (alumno, grupo) · sesión (grupo, fecha) · asistencia (sesión, alumno, marcada_por_entrenador, confirmada_por_alumno) · ejercicio (autor, visibilidad, imágenes[], jugadores_min, jugadores_max, edad, huella, original_id?) · uso_ejercicio (sesión, ejercicio) · puntos (persona, escuela, sesión, valor) · avatar_desbloqueado · logro.

## Animaciones
Definidas con CSS en cada pantalla (arranque, inicio del alumno, avatares, progreso, rankings, resumen de clase). En las pantallas de diseño se repiten en bucle para poder verlas; en la app deben ejecutarse una vez.

## Sensación de app nativa (requisito)
La app debe sentirse nativa, no una web dentro de un móvil. Por eso: React Native con Expo (componentes nativos reales), nunca WebView ni PWA.
- **Navegación:** React Navigation / Expo Router con pila nativa (transiciones y gesto de volver deslizando desde el borde) y barra de pestañas inferior nativa. Las pantallas de `pages/` son solo diseño: no copiar el HTML ni los enlaces `<a>`.
- **Zonas seguras:** respetar notch, barra de estado e indicador de inicio (`SafeAreaView`). Las pantallas del diseño no dibujan barra de estado a propósito.
- **Animaciones a 60 fps** con Reanimated (y Lottie para confeti, llama y desbloqueos), ejecutadas en el hilo de la interfaz. Las animaciones CSS del diseño son solo una guía de ritmo y de qué se mueve.
- **Hápticos** (expo-haptics): al confirmar asistencia, desbloquear avatar, subir de nivel y al marcar en "Pasar lista".
- **Gestos y listas:** pull-to-refresh, listas virtualizadas (`FlatList`/`FlashList`), deslizar para acciones (por ejemplo "Baja"), hojas inferiores para filtros y selectores.
- **Teclado y formularios:** el teclado correcto por campo (numérico para el año, mayúsculas para el código de escuela), la pantalla sube con el teclado y autocompletado del sistema.
- **Estados:** esqueletos de carga en lugar de ruedas, y estados vacíos y de error en cada pantalla. Funcionar sin conexión al menos para ver el horario y la lista de la clase.
- **Sistema:** icono, pantalla de arranque nativa, tamaño de letra del sistema (Dynamic Type), modo oscuro, notificaciones push (clase de mañana, confirma tu asistencia) y accesibilidad (VoiceOver/TalkBack, etiquetas, objetivos de 44 pt).
- **Rendimiento:** imágenes optimizadas y en caché (expo-image); los avatares en cuerpo completo en el tamaño justo para cada pantalla.

## Propuesta de stack
React Native + Expo (probar en el móvil con Expo Go) y Supabase (Auth, Postgres con RLS por escuela, Storage). No se recomienda una PWA: no logra la sensación nativa que se busca.

## Orden de construcción sugerido
1. Proyecto Expo, tema (colores, fuentes, componentes base) y navegación por rol.
2. Esquema de base de datos y reglas de acceso.
3. Registro, "Soy…", código de escuela y Mis escuelas.
4. Inicio del alumno (Mini y Gamer), confirmar asistencia, progreso y avatares.
5. Director (panel, personas, grupos) y entrenador (horario, pasar lista, preparar clase).
6. Biblioteca, editor de ejercicios con detección de duplicados y modo pista.
7. Rankings, animaciones y pulido.

## Primer mensaje para Claude Code
> Lee HANDOFF.md y ESPECIFICACION-ORIGINAL.md, y abre index.html para ver las pantallas. Crea un proyecto Expo con TypeScript y navegación nativa (Expo Router) y el tema de assets/rankademy.css, y reproduce primero el flujo de arranque, "Soy…" y registro. Antes de escribir código, propón la estructura de carpetas y el esquema de base de datos.
