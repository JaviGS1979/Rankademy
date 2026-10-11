import { supabase } from './supabase';
import { hoyISO } from './fechas';
import type {
  AlumnoEscuela, AmbitoRanking, Anomalia, Avatar, ClaseConEjercicios, DetalleEjercicio, EjercicioClase, Elemento, EntrenadorEscuela, Escuela,
  EscuelaStaff, EstadoEscuelaPerfil, EstadoRanking, FilaAlumnoRanking, FilaEntrenadorRanking, FilaEscuelaRanking, FilaLista, GrupoAlumno, GrupoEscuela, MiMembresia, Nivel, Pendiente, Perfil, Progreso, ResultadoConfirmacion,
  Parecido, PerfilEntrenador, ResumenEjercicio, Rol, RolStaff, SesionDia, Solicitud,
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
export async function crearEscuela(nombre: string, ciudad: string, provincia = '', comunidad = ''): Promise<Escuela> {
  return ok(
    await supabase
      .rpc('crear_escuela', { p_nombre: nombre, p_ciudad: ciudad, p_provincia: provincia, p_comunidad: comunidad })
      .single(),
  ) as Escuela;
}

export async function unirseAEscuela(codigo: string, rol: Exclude<Rol, 'director'>, perfilId?: string) {
  const membresia = ok(
    await supabase.rpc('unirse_a_escuela', {
      p_codigo: codigo,
      p_rol: rol,
      p_perfil: perfilId ?? null,
    }),
  );
  // Con un código que no existe la base de datos devuelve vacío (y cuenta el intento)
  if (!membresia || (typeof membresia === 'object' && !(membresia as { id?: string }).id)) {
    throw new Error('Código de escuela no válido');
  }
}

export async function misMembresias(): Promise<MiMembresia[]> {
  // Solo las propias (y las de mis hijos, que van a mi nombre): el director puede
  // leer las de toda su escuela, pero esas no son "mis escuelas"
  const { data: sesion } = await supabase.auth.getSession();
  const uid = sesion.session?.user.id;
  if (!uid) return [];
  const data = ok(
    await supabase
      .from('membresias')
      .select('id, rol, estado, perfil_id, escuela:escuelas(id, nombre, ciudad, codigo), perfil:perfiles_alumno(nombre)')
      .eq('persona_id', uid)
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
// Mini hasta 7 años (incluidos). Se calcula siempre por el año de nacimiento: así un
// perfil pasa solo de Mini a Gamer al cumplir 8 años.
export function nivelPorAnio(anio: number, hoy = new Date()): Nivel {
  return hoy.getFullYear() - anio <= 7 ? 'mini' : 'gamer';
}

const conNivel = (p: Perfil): Perfil => ({ ...p, nivel: nivelPorAnio(p.anio_nacimiento) });

export async function misPerfiles(): Promise<Perfil[]> {
  const { data: u } = await supabase.auth.getUser();
  if (!u.user) return [];
  const data = ok(
    await supabase
      .from('perfiles_alumno')
      .select('id, nombre, anio_nacimiento, nivel, avatar')
      .eq('familia_id', u.user.id)
      .order('creado_at'),
  ) as Perfil[];
  return data.map(conNivel);
}

export async function crearPerfil(nombre: string, anio: number): Promise<Perfil> {
  const { data: u } = await supabase.auth.getUser();
  if (!u.user) throw new Error('Necesitas iniciar sesión');
  const creado = ok(
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
  return conNivel(creado);
}

// ---------- Alumno ----------
export async function progreso(perfilId: string): Promise<Progreso> {
  return ok(await supabase.rpc('mi_progreso', { p_perfil: perfilId })) as Progreso;
}

export async function gruposDelAlumno(perfilId: string): Promise<GrupoAlumno[]> {
  const data = ok(
    await supabase
      .from('inscripciones')
      .select('grupo:grupos(id, nombre, dia, hora, archivado_at, escuela:escuelas(nombre), entrenador:personas(nombre))')
      .eq('perfil_id', perfilId)
      .is('hasta', null),
  ) as unknown as { grupo: (GrupoAlumno & { archivado_at: string | null }) | null }[];
  return data.map((d) => d.grupo).filter((g): g is GrupoAlumno & { archivado_at: string | null } => !!g && !g.archivado_at);
}

// Estado de las escuelas del perfil (para avisar si aún espera la aprobación)
export async function escuelasDelPerfil(perfilId: string): Promise<EstadoEscuelaPerfil[]> {
  const data = ok(
    await supabase
      .from('membresias')
      .select('estado, escuela:escuelas(id, nombre)')
      .eq('perfil_id', perfilId)
      .neq('estado', 'baja'),
  ) as unknown as { estado: EstadoEscuelaPerfil['estado']; escuela: { id: string; nombre: string } | null }[];
  return data.map((d) => ({ estado: d.estado, id: d.escuela?.id ?? '', escuela: d.escuela?.nombre ?? '' }));
}

// Clases que el entrenador ha marcado y el alumno aún no ha confirmado
export async function pendientesDeConfirmar(perfilId: string): Promise<Pendiente[]> {
  const data = ok(
    await supabase
      .from('asistencias')
      .select('sesion_id, sesion:sesiones(fecha, estado, grupo:grupos(nombre, hora, entrenador:personas(nombre)))')
      .eq('perfil_id', perfilId)
      .is('confirmada_at', null)
      .eq('justificada', false),
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
  return ok(await supabase.from('avatares').select('id, orden, nombre, precio_xp').order('orden')) as Avatar[];
}

export async function avataresDesbloqueados(perfilId: string): Promise<string[]> {
  const data = ok(
    await supabase.from('avatares_desbloqueados').select('avatar').eq('perfil_id', perfilId),
  ) as { avatar: string }[];
  return data.map((d) => d.avatar);
}

export async function comprarAvatar(perfilId: string, avatar: string): Promise<{ saldo: number; precio: number }> {
  return ok(await supabase.rpc('comprar_avatar', { p_perfil: perfilId, p_avatar: avatar })) as { saldo: number; precio: number };
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
      .select('id, fecha, grupo:grupos(nombre, hora)')
      .in('grupo_id', grupos.map((g) => g.id))
      .neq('estado', 'cancelada')
      .gte('fecha', hoyISO())
      .order('fecha', { ascending: true })
      .limit(1),
  ) as unknown as { id: string; fecha: string; grupo: { nombre: string; hora: string } | null }[];
  const s = data[0];
  if (!s) return null;
  return { sesion_id: s.id, fecha: s.fecha, grupo: s.grupo, ejercicios: await ejerciciosDeClase(s.id) };
}

// ---------- Familia: vincular un alumno que la escuela ya inscribió ----------
export async function vincularAlumno(codigo: string, acepto: boolean): Promise<{ perfil_id: string; nombre: string }> {
  const r = ok(await supabase.rpc('vincular_alumno', { p_codigo: codigo, p_acepto: acepto }));
  // Con un código que no existe la base de datos devuelve vacío (y cuenta el intento)
  if (!r || typeof r !== 'object' || !(r as { perfil_id?: string }).perfil_id) {
    throw new Error('Código de alumno no válido');
  }
  return r as { perfil_id: string; nombre: string };
}

// ---------- Director y entrenador ----------
async function miId(): Promise<string | null> {
  const { data } = await supabase.auth.getSession();
  return data.session?.user.id ?? null;
}

export async function miNombre(): Promise<string> {
  const uid = await miId();
  if (!uid) return '';
  const data = ok(await supabase.from('personas').select('nombre').eq('id', uid).maybeSingle()) as { nombre: string } | null;
  return data?.nombre ?? '';
}

// Escuelas donde tengo un rol de director o de entrenador ya aprobado
export async function misEscuelasStaff(): Promise<EscuelaStaff[]> {
  const uid = await miId();
  if (!uid) return [];
  const data = ok(
    await supabase
      .from('membresias')
      .select('rol, escuela:escuelas(id, nombre, ciudad, codigo, participa_ranking, provincia, comunidad)')
      .eq('persona_id', uid)
      .eq('estado', 'activa')
      .in('rol', ['director', 'entrenador'])
      .order('creada_at'),
  ) as unknown as { rol: RolStaff; escuela: Omit<EscuelaStaff, 'rol'> | null }[];
  const porEscuela = new Map<string, EscuelaStaff>();
  for (const d of data) {
    if (!d.escuela) continue;
    const previa = porEscuela.get(d.escuela.id);
    // Si es director y entrenador a la vez, cuenta como director
    if (!previa || d.rol === 'director') porEscuela.set(d.escuela.id, { ...d.escuela, rol: d.rol });
  }
  return [...porEscuela.values()];
}

export async function gruposDeEscuela(escuelaId: string): Promise<GrupoEscuela[]> {
  const grupos = ok(
    await supabase
      .from('grupos')
      .select('id, nombre, dia, hora, pista, entrenador_id, entrenador:personas(nombre)')
      .eq('escuela_id', escuelaId)
      .is('archivado_at', null)
      .order('dia')
      .order('hora'),
  ) as unknown as Omit<GrupoEscuela, 'alumnos'>[];
  if (grupos.length === 0) return [];
  const ins = ok(
    await supabase.from('inscripciones').select('grupo_id').in('grupo_id', grupos.map((g) => g.id)).is('hasta', null),
  ) as { grupo_id: string }[];
  const cuenta = new Map<string, number>();
  for (const i of ins) cuenta.set(i.grupo_id, (cuenta.get(i.grupo_id) ?? 0) + 1);
  return grupos.map((g) => ({ ...g, alumnos: cuenta.get(g.id) ?? 0 }));
}

export async function crearGrupo(g: {
  escuelaId: string; nombre: string; dia: number; hora: string; pista: string; entrenadorId: string | null;
}) {
  ok(
    await supabase.from('grupos').insert({
      escuela_id: g.escuelaId,
      nombre: g.nombre.trim(),
      dia: g.dia,
      hora: g.hora,
      pista: g.pista.trim(),
      entrenador_id: g.entrenadorId,
    }),
  );
}

export async function actualizarGrupo(
  id: string,
  cambios: { nombre?: string; hora?: string; pista?: string; entrenador_id?: string | null; archivado_at?: string },
) {
  const { data, error } = await supabase.from('grupos').update(cambios).eq('id', id).select('id');
  if (error) throw error;
  if (!data || data.length === 0) throw new Error('No se pudo guardar el grupo');
}

export async function entrenadoresDeEscuela(escuelaId: string): Promise<EntrenadorEscuela[]> {
  const [membresias, grupos] = await Promise.all([
    supabase
      .from('membresias')
      .select('id, persona_id, persona:personas(nombre)')
      .eq('escuela_id', escuelaId)
      .eq('rol', 'entrenador')
      .eq('estado', 'activa')
      .order('creada_at'),
    gruposDeEscuela(escuelaId),
  ]);
  const data = ok(membresias) as unknown as { id: string; persona_id: string; persona: { nombre: string } | null }[];
  return data.map((m) => ({
    membresia_id: m.id,
    persona_id: m.persona_id,
    nombre: m.persona?.nombre || 'Sin nombre',
    grupos: grupos.filter((g) => g.entrenador_id === m.persona_id).map((g) => g.nombre),
  }));
}

export async function alumnosDeEscuela(escuelaId: string): Promise<AlumnoEscuela[]> {
  const [membresias, grupos] = await Promise.all([
    supabase
      .from('membresias')
      .select('id, perfil_id, perfil:perfiles_alumno(nombre, apellidos, anio_nacimiento, familia_id)')
      .eq('escuela_id', escuelaId)
      .eq('rol', 'alumno')
      .eq('estado', 'activa'),
    gruposDeEscuela(escuelaId),
  ]);
  const data = ok(membresias) as unknown as {
    id: string;
    perfil_id: string;
    perfil: { nombre: string; apellidos: string | null; anio_nacimiento: number; familia_id: string | null } | null;
  }[];
  const ins = grupos.length
    ? (ok(
        await supabase.from('inscripciones').select('perfil_id, grupo_id').in('grupo_id', grupos.map((g) => g.id)).is('hasta', null),
      ) as { perfil_id: string; grupo_id: string }[])
    : [];
  return data
    .filter((m) => m.perfil)
    .map((m) => ({
      membresia_id: m.id,
      perfil_id: m.perfil_id,
      nombre: m.perfil!.nombre,
      apellidos: m.perfil!.apellidos ?? '',
      anio_nacimiento: m.perfil!.anio_nacimiento,
      sin_familia: m.perfil!.familia_id === null,
      grupos: ins
        .filter((i) => i.perfil_id === m.perfil_id)
        .map((i) => grupos.find((g) => g.id === i.grupo_id))
        .filter((g): g is GrupoEscuela => !!g)
        .map((g) => ({ id: g.id, nombre: g.nombre })),
    }))
    .sort((a, b) => `${a.nombre} ${a.apellidos}`.localeCompare(`${b.nombre} ${b.apellidos}`, 'es'));
}

export async function darDeBaja(membresiaId: string) {
  ok(await supabase.rpc('resolver_membresia', { p_membresia: membresiaId, p_aprobar: false }));
}

export async function altaAlumno(a: {
  escuelaId: string; nombre: string; apellidos: string; anio: number; grupos: string[];
}): Promise<{ perfil_id: string; codigo: string }> {
  return ok(
    await supabase.rpc('alta_alumno', {
      p_escuela: a.escuelaId,
      p_nombre: a.nombre,
      p_apellidos: a.apellidos,
      p_anio: a.anio,
      p_grupos: a.grupos,
    }),
  ) as { perfil_id: string; codigo: string };
}

export async function codigoAlumno(perfilId: string, nuevo = false): Promise<string> {
  return ok(await supabase.rpc('codigo_alumno', { p_perfil: perfilId, p_nuevo: nuevo })) as string;
}

export async function inscribir(perfilId: string, grupoId: string) {
  ok(await supabase.rpc('inscribir', { p_perfil: perfilId, p_grupo: grupoId }));
}

export async function desinscribir(perfilId: string, grupoId: string) {
  ok(await supabase.rpc('desinscribir', { p_perfil: perfilId, p_grupo: grupoId }));
}

export async function ajustarRanking(escuelaId: string, participa: boolean) {
  const { data, error } = await supabase
    .from('escuelas')
    .update({ participa_ranking: participa })
    .eq('id', escuelaId)
    .select('id');
  if (error) throw error;
  if (!data || data.length === 0) throw new Error('No se pudo cambiar el ajuste');
}

// ---------- Clases y lista ----------
export async function sesionesDelDia(grupoIds: string[], fecha: string): Promise<SesionDia[]> {
  if (grupoIds.length === 0) return [];
  return ok(
    await supabase.from('sesiones').select('id, grupo_id, fecha, estado').in('grupo_id', grupoIds).eq('fecha', fecha),
  ) as SesionDia[];
}

export async function sesionPara(grupoId: string, fecha: string): Promise<string> {
  return ok(await supabase.rpc('sesion_para', { p_grupo: grupoId, p_fecha: fecha })) as string;
}

export async function cancelarClase(grupoId: string, fecha: string) {
  ok(await supabase.rpc('cancelar_clase', { p_grupo: grupoId, p_fecha: fecha }));
}

export async function reactivarClase(sesionId: string) {
  ok(await supabase.rpc('reactivar_clase', { p_sesion: sesionId }));
}

export async function cancelarDia(escuelaId: string, fecha: string): Promise<number> {
  return ok(await supabase.rpc('cancelar_dia', { p_escuela: escuelaId, p_fecha: fecha })) as number;
}

export async function cerrarLista(sesionId: string) {
  ok(await supabase.rpc('cerrar_lista', { p_sesion: sesionId }));
}

export async function marcarAsistencia(sesionId: string, perfilId: string, estado: 'presente' | 'justificada' | 'ninguno') {
  ok(await supabase.rpc('marcar_asistencia', { p_sesion: sesionId, p_perfil: perfilId, p_estado: estado }));
}

export async function listaDeClase(sesionId: string): Promise<FilaLista[]> {
  return ok(await supabase.rpc('lista_de_clase', { p_sesion: sesionId })) as FilaLista[];
}

// ---------- Biblioteca de ejercicios ----------
export type FiltrosBiblioteca = {
  texto: string;
  edad: { min: number; max: number } | null;
  niveles: string[];
  objetivos: string[];
  jugMin: number | null;
  jugMax: number | null;
  materiales: string[];
  espacios: string[];
};

export const sinFiltros: FiltrosBiblioteca = {
  texto: '', edad: null, niveles: [], objetivos: [], jugMin: null, jugMax: null, materiales: [], espacios: [],
};

export const hayFiltros = (f: FiltrosBiblioteca) =>
  !!f.edad || f.niveles.length > 0 || f.objetivos.length > 0 || f.jugMin !== null || f.jugMax !== null ||
  f.materiales.length > 0 || f.espacios.length > 0;

export async function bibliotecaEjercicios(
  f: FiltrosBiblioteca,
  opts: { mios?: boolean; limite?: number; desde?: number } = {},
): Promise<ResumenEjercicio[]> {
  return ok(
    await supabase.rpc('biblioteca', {
      p_texto: f.texto.trim() || null,
      p_edad_min: f.edad?.min ?? null,
      p_edad_max: f.edad?.max ?? null,
      p_niveles: f.niveles.length ? f.niveles : null,
      p_objetivos: f.objetivos.length ? f.objetivos : null,
      p_jug_min: f.jugMin,
      p_jug_max: f.jugMax,
      p_materiales: f.materiales.length ? f.materiales : null,
      p_espacios: f.espacios.length ? f.espacios : null,
      p_mios: !!opts.mios,
      p_limite: opts.limite ?? 30,
      p_desde: opts.desde ?? 0,
    }),
  ) as ResumenEjercicio[];
}

export async function detalleEjercicio(id: string): Promise<DetalleEjercicio> {
  return ok(await supabase.rpc('detalle_ejercicio', { p_ejercicio: id })) as DetalleEjercicio;
}

export type DatosEjercicio = {
  titulo: string;
  visibilidad: 'publica' | 'escuela';
  escuelaId: string | null;
  jugMin: number;
  jugMax: number;
  edadMin: number;
  edadMax: number;
  nivel: string | null;
  objetivo: string | null;
  espacio: string | null;
  material: string[];
  pasos: string[];
  imagenes: Elemento[][];
  originalId?: string;
};

export async function buscarParecidos(d: Pick<DatosEjercicio, 'imagenes' | 'jugMin' | 'jugMax' | 'edadMin' | 'edadMax'>): Promise<Parecido[]> {
  return ok(
    await supabase.rpc('buscar_parecidos', {
      p_imagenes: d.imagenes,
      p_jug_min: d.jugMin,
      p_jug_max: d.jugMax,
      p_edad_min: d.edadMin,
      p_edad_max: d.edadMax,
    }),
  ) as Parecido[];
}

export async function publicarEjercicio(d: DatosEjercicio): Promise<string> {
  return ok(
    await supabase.rpc('publicar_ejercicio', {
      p: {
        titulo: d.titulo.trim(),
        visibilidad: d.visibilidad,
        escuela_id: d.visibilidad === 'escuela' ? d.escuelaId : null,
        jugadores_min: d.jugMin,
        jugadores_max: d.jugMax,
        edad_min: d.edadMin,
        edad_max: d.edadMax,
        nivel: d.nivel ?? '',
        objetivo: d.objetivo ?? '',
        espacio: d.espacio ?? '',
        material: d.material,
        pasos: d.pasos.map((p) => p.trim()).filter(Boolean),
        imagenes: d.imagenes,
        original_id: d.originalId ?? null,
      },
    }),
  ) as string;
}

export async function editarEjercicio(
  id: string,
  d: Pick<DatosEjercicio, 'titulo' | 'nivel' | 'objetivo' | 'espacio' | 'material' | 'pasos'>,
) {
  ok(
    await supabase.rpc('editar_ejercicio', {
      p_ejercicio: id,
      p: {
        titulo: d.titulo.trim(),
        nivel: d.nivel ?? '',
        objetivo: d.objetivo ?? '',
        espacio: d.espacio ?? '',
        material: d.material,
        pasos: d.pasos.map((p) => p.trim()).filter(Boolean),
      },
    }),
  );
}

export async function retirarEjercicio(id: string, retirar: boolean) {
  ok(await supabase.rpc('retirar_ejercicio', { p_ejercicio: id, p_retirar: retirar }));
}

export async function borrarEjercicio(id: string) {
  ok(await supabase.rpc('borrar_ejercicio', { p_ejercicio: id }));
}

export async function ejerciciosDeClase(sesionId: string): Promise<EjercicioClase[]> {
  return ok(await supabase.rpc('ejercicios_de_clase', { p_sesion: sesionId })) as EjercicioClase[];
}

export async function guardarEjerciciosClase(sesionId: string, ids: string[]) {
  ok(await supabase.rpc('guardar_ejercicios_clase', { p_sesion: sesionId, p_ejercicios: ids }));
}

// ---------- Rankings ----------
export async function estadoRanking(escuelaId: string): Promise<EstadoRanking> {
  return ok(await supabase.rpc('estado_ranking', { p_escuela: escuelaId })) as EstadoRanking;
}

export async function rankingAlumnos(
  escuelaId: string, ambito: AmbitoRanking, edad: { min: number; max: number } | null,
): Promise<FilaAlumnoRanking[]> {
  return ok(
    await supabase.rpc('ranking_alumnos', {
      p_escuela: escuelaId, p_ambito: ambito, p_edad_min: edad?.min ?? null, p_edad_max: edad?.max ?? null,
    }),
  ) as FilaAlumnoRanking[];
}

export async function rankingEntrenadores(escuelaId: string, ambito: AmbitoRanking): Promise<FilaEntrenadorRanking[]> {
  return ok(await supabase.rpc('ranking_entrenadores', { p_escuela: escuelaId, p_ambito: ambito })) as FilaEntrenadorRanking[];
}

export async function rankingEscuelas(escuelaId: string, ambito: Exclude<AmbitoRanking, 'escuela'>): Promise<FilaEscuelaRanking[]> {
  return ok(await supabase.rpc('ranking_escuelas', { p_escuela: escuelaId, p_ambito: ambito })) as FilaEscuelaRanking[];
}

export async function perfilEntrenador(id: string): Promise<PerfilEntrenador> {
  return ok(await supabase.rpc('perfil_entrenador', { p_persona: id })) as PerfilEntrenador;
}

export async function anomalias(escuelaId: string): Promise<Anomalia[]> {
  return ok(await supabase.rpc('anomalias', { p_escuela: escuelaId })) as Anomalia[];
}

export async function actualizarZona(escuelaId: string, provincia: string, comunidad: string) {
  const { data, error } = await supabase
    .from('escuelas')
    .update({ provincia: provincia.trim(), comunidad: comunidad.trim() })
    .eq('id', escuelaId)
    .select('id');
  if (error) throw error;
  if (!data || data.length === 0) throw new Error('No se pudo guardar la zona');
}
