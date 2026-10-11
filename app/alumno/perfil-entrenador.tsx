import { useLocalSearchParams } from 'expo-router';
import { PerfilEntrenadorVista } from '@/features/ranking/PerfilEntrenadorVista';

export default function PerfilEntrenadorAlumno() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <PerfilEntrenadorVista id={id} />;
}
