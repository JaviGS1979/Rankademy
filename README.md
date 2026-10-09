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

## Estado

Fase 1: proyecto Expo, tema y flujo Arranque → Soy… → Registro. Siguiente: esquema de Supabase y RLS (Fase 2).
