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
