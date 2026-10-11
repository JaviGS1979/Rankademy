import { useLocalSearchParams, useRouter } from 'expo-router';
import { DetalleVista } from '@/features/biblioteca/DetalleVista';

// Un ejercicio de mi clase (solo lectura: el alumno no ve quién lo subió ni puede cambiarlo)
export default function EjercicioAlumno() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  return <DetalleVista id={id} abrir={(otro) => router.push({ pathname: '/alumno/ejercicio', params: { id: otro } })} />;
}
