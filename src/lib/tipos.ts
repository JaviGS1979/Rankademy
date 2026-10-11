// Tipos de las filas que usa la app (subconjunto de supabase/migrations).
export type Rol = 'director' | 'entrenador' | 'alumno';
export type EstadoMembresia = 'pendiente' | 'activa' | 'baja';
export type Nivel = 'mini' | 'gamer';

export type Escuela = {
  id: string;
  nombre: string;
  ciudad: string;
  provincia: string;
  comunidad: string;
  codigo: string;
  participa_ranking: boolean;
};

export type Perfil = {
  id: string;
  nombre: string;
  anio_nacimiento: number;
  nivel: Nivel;
  avatar: string | null;
};

// Membresía con la escuela y, si es de alumno, el perfil
export type MiMembresia = {
  id: string;
  rol: Rol;
  estado: EstadoMembresia;
  perfil_id: string | null;
  escuela: Pick<Escuela, 'id' | 'nombre' | 'ciudad' | 'codigo'>;
  perfil: Pick<Perfil, 'nombre'> | null;
};

export type Solicitud = {
  id: string;
  rol: Rol;
  persona: { nombre: string } | null;
  perfil: Pick<Perfil, 'nombre' | 'anio_nacimiento'> | null;
};

export type Progreso = {
  xp: number; // ganado en total (nivel y ranking)
  saldo: number; // XP disponible para gastar en avatares
  nivel: number;
  xp_en_nivel: number;
  xp_por_nivel: number;
  clases: number;
  racha: number; // días
  siguiente_avatar: { id: string; precio: number; faltan: number } | null;
};

export type GrupoAlumno = {
  id: string;
  nombre: string;
  dia: number;
  hora: string;
  escuela: { nombre: string } | null;
  entrenador: { nombre: string } | null;
};

export type Pendiente = {
  sesion_id: string;
  fecha: string;
  grupo: { nombre: string; hora: string; entrenador: { nombre: string } | null } | null;
};

export type ResultadoConfirmacion = {
  xp_ganados: number;
  xp_total: number;
  nivel_antes: number;
  nivel_despues: number;
  racha: number; // días
  xp_por_nivel: number;
  avatares_nuevos: string[];
};

export type Avatar = { id: string; orden: number; nombre: string; precio_xp: number };

// ---------- Biblioteca de ejercicios ----------
// Elementos del dibujo sobre la pista (viewBox 240 × 140). Mismo formato que valida la base de datos.
export type Punto = [number, number];
export type Elemento =
  | { t: 'jugador' | 'pelota' | 'cono'; x: number; y: number }
  | { t: 'trayecto'; de: Punto; a: Punto; c?: Punto; tipo?: 'bola' | 'carrera' };

export type Nivel_ej = 'inicio' | 'medio' | 'avanzado';
export type Objetivo = 'calentar' | 'derecha' | 'reves' | 'saque' | 'volea' | 'pies';
export type Espacio = 'pista' | 'media' | 'mini';
export type Material = 'pelotas' | 'conos' | 'aros' | 'red';

// Fila de la biblioteca (nunca incluye autor ni escuela)
export type ResumenEjercicio = {
  id: string;
  titulo: string;
  visibilidad: 'publica' | 'escuela';
  original_id: string | null;
  jugadores_min: number;
  jugadores_max: number;
  edad_min: number | null;
  edad_max: number | null;
  nivel: Nivel_ej | null;
  objetivo: Objetivo | null;
  espacio: Espacio | null;
  material: Material[];
  imagenes: number;
  variantes: number;
  usado_por: number;
  es_mio: boolean;
  retirado: boolean;
  dibujo: Elemento[] | null; // primera imagen
  creado_at: string;
};

export type DetalleEjercicio = {
  id: string;
  titulo: string;
  visibilidad: 'publica' | 'escuela';
  jugadores_min: number;
  jugadores_max: number;
  edad_min: number | null;
  edad_max: number | null;
  nivel: Nivel_ej | null;
  objetivo: Objetivo | null;
  espacio: Espacio | null;
  material: Material[];
  pasos: string[];
  es_mio: boolean;
  retirado: boolean;
  usado_por: number;
  imagenes: Elemento[][];
  original: { id: string; titulo: string } | null;
  variantes: { id: string; titulo: string }[];
};

export type Parecido = {
  id: string;
  titulo: string;
  parecido: number; // 0-100
  jugadores_min: number;
  jugadores_max: number;
  edad_min: number | null;
  edad_max: number | null;
  imagenes: number;
  variantes: number;
  usado_por: number;
  dibujo: Elemento[] | null;
};

// Ejercicio de una clase concreta
export type EjercicioClase = {
  id: string;
  titulo: string;
  orden: number;
  jugadores_min: number;
  jugadores_max: number;
  imagenes: number;
  dibujo: Elemento[] | null;
  retirado: boolean;
};

export type ClaseConEjercicios = {
  sesion_id: string;
  fecha: string;
  grupo: { nombre: string; hora: string } | null;
  ejercicios: EjercicioClase[];
};

export type EstadoEscuelaPerfil = { escuela: string; estado: EstadoMembresia };

// ---------- Escuela (director y entrenador) ----------
export type RolStaff = 'director' | 'entrenador';

export type EscuelaStaff = {
  id: string;
  nombre: string;
  ciudad: string;
  codigo: string;
  participa_ranking: boolean;
  rol: RolStaff; // director si lo es en esa escuela, aunque también sea entrenador
};

export type GrupoEscuela = {
  id: string;
  nombre: string;
  dia: number;
  hora: string;
  pista: string;
  entrenador_id: string | null;
  entrenador: { nombre: string } | null;
  alumnos: number;
};

export type EntrenadorEscuela = { membresia_id: string; persona_id: string; nombre: string; grupos: string[] };

export type AlumnoEscuela = {
  membresia_id: string;
  perfil_id: string;
  nombre: string;
  apellidos: string;
  anio_nacimiento: number;
  sin_familia: boolean; // dado de alta por la escuela y aún sin vincular
  grupos: { id: string; nombre: string }[];
};

export type SesionDia = { id: string; grupo_id: string; fecha: string; estado: 'planificada' | 'impartida' | 'cancelada' };

export type EstadoAsistencia = 'presente' | 'justificada' | 'confirmada' | null;

export type FilaLista = {
  perfil_id: string;
  nombre: string;
  apellidos: string;
  avatar: string | null;
  inscrito: boolean;
  estado: EstadoAsistencia;
};
