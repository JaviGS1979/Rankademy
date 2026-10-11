import { useLocalSearchParams, useRouter } from 'expo-router';
import { DetalleVista } from '@/features/biblioteca/DetalleVista';

export default function Ejercicio() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  return <DetalleVista id={id} staff abrir={(otro) => router.push({ pathname: '/escuela/ejercicio', params: { id: otro } })} />;
}
