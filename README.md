# Rankademy

App móvil (iOS, Android y web) con el ranking de las escuelas de tenis.
Expo (React Native) + TypeScript + Expo Router; backend en Supabase.

- `design/` — diseño original (38 pantallas HTML), `HANDOFF.md` y `ESPECIFICACION-ORIGINAL.md`. Abre `design/index.html` para verlas.
- `app/` — rutas (Expo Router).
- `src/theme` — tokens de color y tipografía (de `design/assets/rankademy.css`).
- `src/components` — componentes base.

## Desarrollo

```bash
npm install
npx expo start        # Expo Go en el móvil; pulsa "w" para web
npx tsc --noEmit      # comprobación de tipos
```

## Configuración

Copia `.env.example` a `.env` con la URL y la clave pública de Supabase. La base de datos y el acceso por correo se configuran según `supabase/README.md`.

## Estado

- Fase 1: proyecto Expo, tema y pantallas de arranque.
- Fase 2: esquema de Supabase, reglas de acceso (RLS) y pruebas de seguridad.
- Fase 3: registro e inicio de sesión con código por correo, crear escuela, unirse con código, añadir hijo, Mis escuelas y aprobación de solicitudes.
