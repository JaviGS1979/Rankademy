import { usePerfiles } from '@/lib/perfil';
import InicioGamer from '@/features/alumno/InicioGamer';
import InicioMini from '@/features/alumno/InicioMini';

export default function InicioAlumno() {
  const { activo } = usePerfiles();
  if (!activo) return null;
  return activo.nivel === 'mini' ? <InicioMini perfil={activo} /> : <InicioGamer perfil={activo} />;
}
