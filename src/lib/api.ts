import { supabase } from './supabase';
import { hoyISO } from './fechas';
import type {
  Avatar, ClaseConEjercicios, Escuela, EstadoEscuelaPerfil, GrupoAlumno, MiMembresia, Nivel, Pendiente,
  Perfil, Progreso, ResultadoConfirmacion, Rol, Solicitud,
} from './tipos';

function ok<T>(r: { data: T; error: unknown }): T {
  if (r.error) throw r.error;
  return r.data;
}

// ---------- Acceso con código por correo (sin contraseña) ----------
export async function enviarCodigo(correo: string, opts: { crear: boolean; nombre?: string }) {
  ok(
    await supabase.auth.signInWithOtp({
      email: correo.trim().toLowerCase(),
      options: {
        shouldCreateUser: opts.crear,
        data: opts.nombre ? { nombre: opts.nombre.trim() } : undefined,
      },
    }),
  );
}

export async function verificarCodigo(correo: string, codigo: string) {
  ok(
    await supabase.auth.verifyOtp({
      email: correo.trim().toLowerCase(),
      token: codigo.trim(),
      type: 'email',
    }),
  );
}

export async function cerrarSesion() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
}

// ---------- Escuelas y membresías ----------
export async function crearEscuela(nombre: string, ciudad: string): Promise<Escuela> {
  return ok(
    await supabase.rpc('crear_escuela', { p_nombre: nombre, p_ciudad: ciudad }).single(),
  ) as Escuela;
}

export async function unirseAEscuela(codigo: string, rol: Exclude<Rol, 'director'>, perfilId?: string) {
  ok(
    await supabase.rpc('unirse_a_escuela', {
      p_codigo: codigo,
      p_rol: rol,
      p_perfil: perfilId ?? null,
    }),
  );
}

export async function misMembresias(): Promise<MiMembresia[]> {
  const data = ok(
    await supabase
      .from('membresias')
      .select('id, rol, estado, perfil_id, escuela:escuelas(id, nombre, ciudad, codigo), perfil:perfiles_alumno(nombre)')
      .neq('estado', 'baja')
      .order('creada_at'),
  );
  return data as unknown as MiMembresia[];
}

export async function solicitudesPendientes(escuelaId: string): Promise<Solicitud[]> {
  const data = ok(
    await supabase
      .from('membresias')
      .select('id, rol, persona:personas(nombre), perfil:perfiles_alumno(nombre, anio_nacimiento)')
      .eq('escuela_id', escuelaId)
      .eq('estado', 'pendiente')
      .order('creada_at'),
  );
  return data as unknown as Solicitud[];
}

export async function resolverSolicitud(membresiaId: string, aprobar: boolean) {
  ok(await supabase.rpc('resolver_membresia', { p_membresia: membresiaId, p_aprobar: aprobar }));
}

// ---------- Perfiles de hijos ----------
export function nivelPorAnio(anio: number, hoy = new Date()): Nivel {
  return hoy.getFullYear() - anio <= 7 ? 'mini' : 'gamer';
}

export async function misPerfiles(): Promise<Perfil[]> {
  const { data: u } = await supabase.auth.getUser();
  if (!u.user) return [];
  return ok(
    await supabase
      .from('perfiles_alumno')
      .select('id, nombre, anio_nacimiento, nivel, avatar')
      .eq('familia_id', u.user.id)
      .order('creado_at'),
  ) as Perfil[];
}

export async function crearPerfil(nombre: string, anio: number): Promise<Perfil> {
  const { data: u } = await supabase.auth.getUser();
  if (!u.user) throw new Error('Necesitas iniciar sesión');
  return ok(
    await supabase
      .from('perfiles_alumno')
      .insert({
        familia_id: u.user.id,
        nombre: nombre.trim(),
        anio_nacimiento: anio,
        nivel: nivelPorAnio(anio),
        consentimiento_at: new Date().toISOString(),
      })
      .select('id, nombre, anio_nacimiento, nivel, avatar')
      .single(),
  ) as Perfil;
}

// ---------- Alumno ----------
export async function progreso(perfilId: string): Promise<Progreso> {
  return ok(await supabase.rpc('mi_progreso', { p_perfil: perfilId })) as Progreso;
}

export async function gruposDelAlumno(perfilId: string): Promise<GrupoAlumno[]> {
  const data = ok(
    await supabase
      .from('inscripciones')
      .select('grupo:grupos(id, nombre, dia, hora, escuela:escuelas(nombre), entrenador:personas(nombre))')
      .eq('perfil_id', perfilId),
  ) as unknown as { grupo: GrupoAlumno | null }[];
  return data.map((d) => d.grupo).filter((g): g is GrupoAlumno => !!g);
}

// Estado de las escuelas del perfil (para avisar si aún espera la aprobación)
export async function escuelasDelPerfil(perfilId: string): Promise<EstadoEscuelaPerfil[]> {
  const data = ok(
    await supabase
      .from('membresias')
      .select('estado, escuela:escuelas(nombre)')
      .eq('perfil_id', perfilId)
      .neq('estado', 'baja'),
  ) as unknown as { estado: EstadoEscuelaPerfil['estado']; escuela: { nombre: string } | null }[];
  return data.map((d) => ({ estado: d.estado, escuela: d.escuela?.nombre ?? '' }));
}

// Clases que el entrenador ha marcado y el alumno aún no ha confirmado
export async function pendientesDeConfirmar(perfilId: string): Promise<Pendiente[]> {
  const data = ok(
    await supabase
      .from('asistencias')
      .select('sesion_id, sesion:sesiones(fecha, estado, grupo:grupos(nombre, hora, entrenador:personas(nombre)))')
      .eq('perfil_id', perfilId)
      .is('confirmada_at', null),
  ) as unknown as {
    sesion_id: string;
    sesion: { fecha: string; estado: string; grupo: Pendiente['grupo'] } | null;
  }[];
  const hoy = hoyISO();
  return data
    .filter((d) => d.sesion && d.sesion.estado !== 'cancelada' && d.sesion.fecha <= hoy)
    .map((d) => ({ sesion_id: d.sesion_id, fecha: d.sesion!.fecha, grupo: d.sesion!.grupo }))
    .sort((a, b) => b.fecha.localeCompare(a.fecha));
}

export async function confirmarAsistencia(sesionId: string, perfilId: string): Promise<ResultadoConfirmacion> {
  return ok(
    await supabase.rpc('confirmar_asistencia', { p_sesion: sesionId, p_perfil: perfilId }),
  ) as ResultadoConfirmacion;
}

export async function catalogoAvatares(): Promise<Avatar[]> {
  return ok(await supabase.from('avatares').select('id, orden, clases_min, racha_min').order('orden')) as Avatar[];
}

export async function avataresDesbloqueados(perfilId: string): Promise<string[]> {
  const data = ok(
    await supabase.from('avatares_desbloqueados').select('avatar').eq('perfil_id', perfilId),
  ) as { avatar: string }[];
  return data.map((d) => d.avatar);
}

export async function elegirAvatar(perfilId: string, avatar: string) {
  ok(await supabase.rpc('elegir_avatar', { p_perfil: perfilId, p_avatar: avatar }));
}

// Ejercicios de la próxima clase (o de la de hoy) de los grupos del alumno
export async function ejerciciosDeLaClase(perfilId: string): Promise<ClaseConEjercicios | null> {
  const grupos = await gruposDelAlumno(perfilId);
  if (grupos.length === 0) return null;
  const data = ok(
    await supabase
      .from('sesiones')
      .select(
        `id, fecha, grupo:grupos(nombre, hora),
         usos:usos_ejercicio(ejercicio:ejercicios(id, titulo, jugadores_min, jugadores_max,
           autor:personas(nombre), imagenes:ejercicio_imagenes(id)))`,
      )
      .in('grupo_id', grupos.map((g) => g.id))
      .neq('estado', 'cancelada')
      .gte('fecha', hoyISO())
      .order('fecha', { ascending: true })
      .limit(1),
  ) as unknown as {
    id: string;
    fecha: string;
    grupo: { nombre: string; hora: string } | null;
    usos: { ejercicio: (Omit<ClaseConEjercicios['ejercicios'][number], 'imagenes'> & { imagenes: unknown[] }) | null }[];
  }[];
  const s = data[0];
  if (!s) return null;
  return {
    sesion_id: s.id,
    fecha: s.fecha,
    grupo: s.grupo,
    ejercicios: s.usos
      .map((u) => u.ejercicio)
      .filter((e): e is NonNullable<typeof e> => !!e)
      .map((e) => ({ ...e, imagenes: e.imagenes.length })),
  };
}
