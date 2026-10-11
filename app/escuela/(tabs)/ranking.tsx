import { useRouter } from 'expo-router';
import { SelectorEscuela } from '@/features/escuela/SelectorEscuela';
import { RankingVista } from '@/features/ranking/RankingVista';
import { useEscuela } from '@/lib/escuela';

export default function RankingEscuela() {
  const router = useRouter();
  const { actual, esDirector } = useEscuela();
  if (!actual) return null;
  return (
    <RankingVista
      key={actual.id}
      escuelaId={actual.id}
      selector={<SelectorEscuela />}
      esDirector={esDirector}
      alAbrirPerfil={(id) => router.push({ pathname: '/escuela/perfil-entrenador', params: { id } })}
      alAbrirComo={() => router.push('/escuela/como-se-puntua')}
      alAbrirPanel={() => router.push('/escuela/panel')}
    />
  );
}
