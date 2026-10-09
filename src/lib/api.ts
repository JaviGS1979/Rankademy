import { supabase } from './supabase';
import type { Escuela, MiMembresia, Nivel, Perfil, Rol, Solicitud } from './tipos';

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
      .select('id, nombre, anio_nacimiento, nivel')
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
      .select('id, nombre, anio_nacimiento, nivel')
      .single(),
  ) as Perfil;
}
