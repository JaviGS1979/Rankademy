import { StyleSheet, Text, View } from 'react-native';
import { Aviso, Card, Cargando, Icon, Screen } from '@/components';
import { BarraXp } from '@/components/Alumno';
import { usePerfiles } from '@/lib/perfil';
import { useAlumno } from '@/lib/useAlumno';
import { colors, fonts, type as t } from '@/theme';

export default function Progreso() {
  const { activo } = usePerfiles();
  const { datos, error, refrescando, refrescar } = useAlumno(activo?.id ?? null);
  const p = datos?.progreso;

  return (
    <Screen title="Mi progreso" refreshing={refrescando} onRefresh={refrescar}>
      <Aviso texto={error} />
      {!p && !error && <Cargando />}
      {p && (
        <>
          <View style={styles.nivel}>
            <Text style={styles.etiqueta}>Nivel</Text>
            <Text style={styles.nivelNum}>{p.nivel}</Text>
            <BarraXp valor={p.xp_en_nivel / p.xp_por_nivel} />
            <Text style={styles.xp}>{p.xp_en_nivel} / {p.xp_por_nivel} XP</Text>
            <Text style={styles.falta}>
              Te faltan {p.xp_por_nivel - p.xp_en_nivel} XP para el nivel {p.nivel + 1}
            </Text>
          </View>

          <View style={styles.fila}>
            <Card style={styles.dato}>
              <Icon name="flame" size={28} color="#FF8A4C" fill="#FF8A4C" />
              <Text style={styles.datoNum}>{p.racha}</Text>
              <Text style={styles.datoTexto}>{p.racha === 1 ? 'semana de racha' : 'semanas de racha'}</Text>
            </Card>
            <Card style={styles.dato}>
              <Icon name="check" size={28} color={colors.blue} strokeWidth={3} />
              <Text style={styles.datoNum}>{p.clases}</Text>
              <Text style={styles.datoTexto}>{p.clases === 1 ? 'clase asistida' : 'clases asistidas'}</Text>
            </Card>
          </View>

          <Card>
            <Text style={t.h3}>Skills</Text>
            <Text style={styles.mut}>
              Derecha, revés, saque, volea, juego de pies y táctica subirán con los ejercicios de tus clases.
              Llegan en la próxima actualización.
            </Text>
          </Card>
        </>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  nivel: { backgroundColor: colors.ink, borderRadius: 24, padding: 20, gap: 10 },
  etiqueta: { fontFamily: fonts.bodyBold, fontSize: 12, letterSpacing: 0.96, textTransform: 'uppercase', color: colors.muted },
  nivelNum: { fontFamily: fonts.display, fontSize: 96, lineHeight: 96, color: colors.lime },
  xp: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.white },
  falta: { fontFamily: fonts.body, fontSize: 14, color: colors.muted },
  fila: { flexDirection: 'row', gap: 12 },
  dato: { flex: 1, alignItems: 'flex-start', gap: 6 },
  datoNum: { fontFamily: fonts.display, fontSize: 44, lineHeight: 44, color: colors.ink },
  datoTexto: { fontFamily: fonts.bodySemi, fontSize: 14, color: colors.ink2 },
  mut: { fontFamily: fonts.body, fontSize: 15, color: colors.ink2, lineHeight: 21 },
});
