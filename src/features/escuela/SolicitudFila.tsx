import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Icon } from '@/components';
import { confirmar } from '@/lib/avisar';
import type { Rol, Solicitud } from '@/lib/tipos';
import { colors, fonts } from '@/theme';

const nombreRol: Record<Rol, string> = { director: 'Director', entrenador: 'Entrenador', alumno: 'Alumno' };

// Solicitud de entrada a la escuela: el director la aprueba o la rechaza
export function SolicitudFila({ s, onResolver }: { s: Solicitud; onResolver: (s: Solicitud, aprobar: boolean) => void }) {
  const quien = s.perfil
    ? `${s.perfil.nombre} · ${new Date().getFullYear() - s.perfil.anio_nacimiento} años`
    : s.persona?.nombre || 'Sin nombre';
  const detalle = s.perfil ? `Alumno · familia de ${s.persona?.nombre || '—'}` : nombreRol[s.rol];
  return (
    <View style={styles.solicitud}>
      <View style={{ flex: 1, gap: 2 }}>
        <Text style={styles.nombre}>{quien}</Text>
        <Text style={styles.mut}>Pide entrar · {detalle}</Text>
      </View>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Rechazar a ${quien}`}
        onPress={() => confirmar('Rechazar solicitud', `¿Rechazar a ${quien}?`, 'Rechazar', () => onResolver(s, false))}
        style={[styles.accion, { borderColor: colors.line }]}
      >
        <Icon name="close" color={colors.ink2} />
      </Pressable>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={`Aprobar a ${quien}`}
        onPress={() => onResolver(s, true)}
        style={[styles.accion, { backgroundColor: colors.lime, borderColor: colors.lime }]}
      >
        <Icon name="check" color={colors.ink} strokeWidth={3} />
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  solicitud: {
    flexDirection: 'row', alignItems: 'center', gap: 10, backgroundColor: colors.card,
    borderWidth: 1, borderColor: colors.line, borderRadius: 16, padding: 12,
  },
  nombre: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  accion: { width: 44, height: 44, borderRadius: 12, borderWidth: 2, alignItems: 'center', justifyContent: 'center' },
});
