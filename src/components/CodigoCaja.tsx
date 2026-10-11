import { Platform, Pressable, Share, StyleSheet, Text, View } from 'react-native';
import { colors, fonts } from '@/theme';
import { avisar } from '@/lib/avisar';
import { Icon } from './Icon';

type Props = {
  etiqueta: string;
  codigo: string;
  // Texto que se envía al compartir
  mensaje: string;
  tituloAviso?: string;
};

// Código grande sobre fondo oscuro con botón de compartir (escuela y alumno)
export function CodigoCaja({ etiqueta, codigo, mensaje, tituloAviso = 'Código' }: Props) {
  const compartir = async () => {
    if (Platform.OS === 'web' && !(navigator as Navigator & { share?: unknown }).share) {
      return avisar(tituloAviso, mensaje);
    }
    try {
      await Share.share({ message: mensaje });
    } catch {
      avisar(tituloAviso, mensaje);
    }
  };
  return (
    <View style={styles.caja}>
      <View style={{ flex: 1 }}>
        <Text style={styles.label}>{etiqueta}</Text>
        <Text style={styles.codigo} accessibilityLabel={`Código ${codigo.replace('-', ' ').split('').join(' ')}`} selectable>
          {codigo}
        </Text>
      </View>
      <Pressable accessibilityRole="button" accessibilityLabel="Compartir código" onPress={compartir} style={styles.compartir}>
        <Icon name="share" color={colors.ink} />
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  caja: { flexDirection: 'row', alignItems: 'center', gap: 12, backgroundColor: colors.ink, borderRadius: 16, padding: 14 },
  label: { fontFamily: fonts.bodyBold, fontSize: 12, letterSpacing: 0.96, textTransform: 'uppercase', color: colors.muted },
  codigo: { fontFamily: fonts.display, fontSize: 34, letterSpacing: 4, color: colors.lime },
  compartir: { width: 48, height: 48, borderRadius: 14, backgroundColor: colors.lime, alignItems: 'center', justifyContent: 'center' },
});
