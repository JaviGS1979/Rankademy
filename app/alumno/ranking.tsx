import { useEffect, useState } from 'react';
import { ScrollView, Text } from 'react-native';
import { useRouter } from 'expo-router';
import { Card, Cargando, Chip, Screen } from '@/components';
import { RankingVista } from '@/features/ranking/RankingVista';
import { escuelasDelPerfil } from '@/lib/api';
import { usePerfiles } from '@/lib/perfil';
import type { EstadoEscuelaPerfil } from '@/lib/tipos';
import { colors, fonts, type as t } from '@/theme';

// Ranking del alumno: elige la escuela (si el perfil está en varias) y enseña el de su zona
export default function RankingAlumno() {
  const router = useRouter();
  const { activo } = usePerfiles();
  const [escuelas, setEscuelas] = useState<EstadoEscuelaPerfil[] | null>(null);
  const [eleccion, setEleccion] = useState<string | null>(null);

  useEffect(() => {
    if (!activo) return;
    setEscuelas(null);
    setEleccion(null);
    escuelasDelPerfil(activo.id)
      .then((l) => setEscuelas(l.filter((e) => e.estado === 'activa' && e.id)))
      .catch(() => setEscuelas([]));
  }, [activo]);

  if (!escuelas) {
    return (
      <Screen title="Ranking">
        <Cargando />
      </Screen>
    );
  }
  if (escuelas.length === 0) {
    return (
      <Screen title="Ranking">
        <Card>
          <Text style={t.h3}>Aún no estás en una escuela</Text>
          <Text style={{ fontFamily: fonts.body, fontSize: 15, color: colors.ink2 }}>
            Cuando el director apruebe tu entrada, verás aquí tu posición.
          </Text>
        </Card>
      </Screen>
    );
  }
  const escuela = escuelas.find((e) => e.id === eleccion) ?? escuelas[0];
  return (
    <RankingVista
      key={escuela.id}
      escuelaId={escuela.id}
      selector={
        escuelas.length > 1 ? (
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }} accessibilityRole="radiogroup">
            {escuelas.map((e) => (
              <Chip key={e.id} texto={e.escuela} on={e.id === escuela.id} onPress={() => setEleccion(e.id)} />
            ))}
          </ScrollView>
        ) : null
      }
      alAbrirPerfil={(id) => router.push({ pathname: '/alumno/perfil-entrenador', params: { id } })}
      alAbrirComo={() => router.push('/alumno/como-se-puntua')}
    />
  );
}
