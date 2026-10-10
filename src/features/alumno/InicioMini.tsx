import { Pressable, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { useRouter } from 'expo-router';
import { Aviso, Cargando, Icon, Screen } from '@/components';
import { Ficha, Pop } from '@/components/Alumno';
import { Heroe } from '@/components/Heroe';
import type { Perfil } from '@/lib/tipos';
import { useAlumno } from '@/lib/useAlumno';
import { colors, fonts } from '@/theme';
import { useConfirmar } from './confirmar';

// Perfil Mini (3-7 años): casi sin texto, iconos y botones grandes.
export default function InicioMini({ perfil }: { perfil: Perfil }) {
  const router = useRouter();
  const { height } = useWindowDimensions();
  const { datos, error, refrescando, refrescar, cargar } = useAlumno(perfil.id);
  const { confirmar, confirmando, error: errorConfirmar } = useConfirmar(perfil, cargar);
  const alto = Math.min(660, Math.round(height * 0.7));

  if (!datos) {
    return (
      <Screen scroll={false}>
        <Aviso texto={error} />
        {!error && <Cargando />}
      </Screen>
    );
  }
  const { progreso: p, proxima, pendientes, avatares } = datos;
  const pendiente = pendientes[0];

  return (
    <Screen scroll refreshing={refrescando} onRefresh={refrescar} sinMargen>
      <Heroe avatar={perfil.avatar} height={alto} fondo="#A65F3A">
        <View style={styles.cabecera}>
          <Text style={styles.hola} accessibilityRole="header">{`¡Hola,\n${perfil.nombre}!`}</Text>
          <Pop>
            <Pressable accessibilityRole="button" accessibilityLabel="Cambiar de perfil" onPress={() => router.push('/selector-perfil')} style={styles.cambiar}>
              <Icon name="user" size={28} />
            </Pressable>
          </Pop>
        </View>

        <Pop delay={200} style={[styles.pos, { left: 12, top: 190 }]}>
          <Ficha etiqueta={`Racha de ${p.racha} semanas`} ancho={88} alto={96}>
            <Icon name="flame" size={34} color="#FF8A4C" fill="#FF8A4C" />
            <Text style={styles.num}>{p.racha}</Text>
          </Ficha>
        </Pop>
        <Pop delay={400} style={[styles.pos, { right: 12, top: 190 }]}>
          <Ficha etiqueta={`Mis premios: ${avatares}`} fondo={colors.lime} ancho={88} alto={96} onPress={() => router.push('/alumno/avatares')}>
            <Icon name="star" size={44} color={colors.ink} />
            <Text style={[styles.num, { color: colors.ink, fontSize: 30 }]}>{avatares}</Text>
          </Ficha>
        </Pop>

        <Pop delay={700} style={styles.proxima}>
          <View style={styles.proximaIcono}>
            <Icon name="calendar" size={40} color={colors.ink} />
          </View>
          <View style={{ flex: 1 }} accessible accessibilityLabel={proxima ? `Próxima clase: ${proxima.etiqueta}` : 'Sin clase'}>
            <Text style={styles.dia}>{proxima ? proxima.etiqueta.split(' ')[0] : '—'}</Text>
            <Text style={styles.hora}>{proxima ? proxima.etiqueta.split(' ')[1] : ''}</Text>
          </View>
        </Pop>
      </Heroe>

      <View style={styles.botones}>
        <Aviso texto={error ?? errorConfirmar} />
        {pendiente && (
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Sí, estuve en clase"
            disabled={!!confirmando}
            onPress={() => confirmar(pendiente.sesion_id)}
            style={[styles.boton, { backgroundColor: colors.lime, borderColor: colors.orange, borderWidth: 3, minHeight: 72, opacity: confirmando ? 0.6 : 1 }]}
          >
            <Icon name="check" size={32} color={colors.ink} strokeWidth={3.5} />
            <Text style={[styles.botonText, { color: colors.ink, fontSize: 22 }]}>¿Estuviste ayer?</Text>
          </Pressable>
        )}
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Ver ejercicios"
          onPress={() => router.push('/alumno/ejercicios')}
          style={[styles.boton, { backgroundColor: colors.blue, borderColor: colors.blue, minHeight: 80 }]}
        >
          <Icon name="play" size={32} color={colors.white} fill={colors.white} />
          <Text style={[styles.botonText, { fontSize: 26 }]}>Ver ejercicios</Text>
        </Pressable>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  cabecera: { position: 'absolute', left: 20, right: 16, top: 28, flexDirection: 'row', alignItems: 'center', gap: 12 },
  hola: { flex: 1, fontFamily: fonts.display, fontSize: 42, lineHeight: 40, color: colors.white, textTransform: 'uppercase' },
  cambiar: { width: 52, height: 52, borderRadius: 26, backgroundColor: colors.white, alignItems: 'center', justifyContent: 'center' },
  pos: { position: 'absolute' },
  num: { fontFamily: fonts.display, fontSize: 52, lineHeight: 52, color: colors.white },
  proxima: {
    position: 'absolute', left: 16, right: 16, bottom: 16, flexDirection: 'row', alignItems: 'center', gap: 16,
    backgroundColor: colors.ink, borderRadius: 24, paddingVertical: 14, paddingHorizontal: 18,
  },
  proximaIcono: { width: 64, height: 64, borderRadius: 20, backgroundColor: colors.lime, alignItems: 'center', justifyContent: 'center' },
  dia: { fontFamily: fonts.display, fontSize: 30, lineHeight: 30, color: colors.lime, textTransform: 'uppercase' },
  hora: { fontFamily: fonts.bodyBold, fontSize: 20, color: colors.white },
  botones: { padding: 20, gap: 12, width: '100%', maxWidth: 480, alignSelf: 'center' },
  boton: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 14, borderRadius: 24, paddingHorizontal: 20 },
  botonText: { fontFamily: fonts.bodyBold, color: colors.white },
});
