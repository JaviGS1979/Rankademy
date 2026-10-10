import { Pressable, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { useRouter } from 'expo-router';
import { Aviso, Button, Card, Cargando, Icon, Screen, Tag } from '@/components';
import { BarraXp, Ficha, Pop } from '@/components/Alumno';
import { Heroe } from '@/components/Heroe';
import { etiquetaSesion, horaCorta, nombreDia } from '@/lib/fechas';
import type { Perfil } from '@/lib/tipos';
import { useAlumno } from '@/lib/useAlumno';
import { colors, fonts, type as t } from '@/theme';
import { useConfirmar } from './confirmar';

export default function InicioGamer({ perfil }: { perfil: Perfil }) {
  const router = useRouter();
  const { height } = useWindowDimensions();
  const { datos, error, refrescando, refrescar, cargar } = useAlumno(perfil.id);
  const { confirmar, confirmando, error: errorConfirmar } = useConfirmar(perfil, cargar);
  const alto = Math.min(600, Math.round(height * 0.62));

  if (!datos) {
    return (
      <Screen scroll={false}>
        <Aviso texto={error} />
        {!error && <Cargando />}
      </Screen>
    );
  }
  const { progreso: p, proxima, pendientes, grupos, escuelas } = datos;
  const esperando = escuelas.some((e) => e.estado === 'pendiente');

  return (
    <Screen scroll refreshing={refrescando} onRefresh={refrescar} sinMargen>
      <Heroe avatar={perfil.avatar} height={alto}>
        <View style={styles.cabecera}>
          <View style={{ flex: 1 }}>
            <Text style={[styles.etiqueta, { color: colors.lime }]}>Nivel {p.nivel}</Text>
            <Text style={[t.h1, { color: colors.white }]} numberOfLines={1}>{perfil.nombre}</Text>
          </View>
          <Pop>
            <Pressable accessibilityRole="button" accessibilityLabel="Cambiar de perfil" onPress={() => router.push('/selector-perfil')} style={styles.cambiar}>
              <Icon name="user" />
            </Pressable>
          </Pop>
        </View>

        <Pop delay={150} style={[styles.fichaPos, { left: 12, top: 150 }]}>
          <Ficha etiqueta={`Nivel ${p.nivel}`}>
            <Text style={[styles.num, { color: colors.lime, fontSize: 34 }]}>{p.nivel}</Text>
            <Text style={styles.ficha}>Nivel</Text>
          </Ficha>
        </Pop>
        <Pop delay={300} style={[styles.fichaPos, { left: 12, top: 226 }]}>
          <Ficha etiqueta={`Racha de ${p.racha} días`}>
            <Icon name="flame" size={26} color="#FF8A4C" fill="#FF8A4C" />
            <Text style={[styles.num, { fontSize: 30 }]}>{p.racha}</Text>
            <Text style={styles.ficha}>{p.racha === 1 ? 'día' : 'días'}</Text>
          </Ficha>
        </Pop>
        <Pop delay={450} style={[styles.fichaPos, { right: 12, top: 150 }]}>
          <Ficha etiqueta={`${p.clases} clases`} fondo={colors.lime}>
            <Text style={[styles.num, { fontSize: 34, color: colors.ink }]}>{p.clases}</Text>
            <Text style={[styles.ficha, { color: colors.ink, fontFamily: fonts.bodyHeavy }]}>Clases</Text>
          </Ficha>
        </Pop>
        <Pop delay={600} style={[styles.fichaPos, { right: 12, top: 226 }]}>
          <Ficha etiqueta="Avatares" onPress={() => router.push('/alumno/avatares')}>
            <Icon name="user" size={32} color={colors.lime} />
            <Text style={styles.ficha}>Avatares</Text>
          </Ficha>
        </Pop>

        <View style={styles.pie}>
          <View style={styles.fila}>
            <View style={{ flex: 1 }}>
              <Text style={[styles.etiqueta, { color: colors.muted }]}>
                {proxima ? `Próxima clase · ${proxima.grupo.nombre}` : 'Próxima clase'}
              </Text>
              <Text style={[styles.num, { fontSize: 40, color: colors.white }]}>
                {proxima ? proxima.etiqueta : 'Sin clase'}
              </Text>
            </View>
          </View>
          <BarraXp valor={p.xp_en_nivel / p.xp_por_nivel} />
          <View style={[styles.fila, { justifyContent: 'space-between' }]}>
            <Text style={styles.xp}>{p.xp} XP</Text>
            <Text style={styles.xp}>Nivel {p.nivel + 1}: {p.nivel * p.xp_por_nivel} XP</Text>
          </View>
        </View>
      </Heroe>

      <View style={styles.cuerpo}>
        <Aviso texto={error ?? errorConfirmar} />

        {pendientes.slice(0, 3).map((x) => (
          <Card key={x.sesion_id} style={styles.pendiente}>
            <View style={styles.fila}>
              <View style={{ flex: 1 }}>
                <Text style={styles.titulo}>Confirma tu asistencia</Text>
                <Text style={styles.mut}>
                  Clase de {etiquetaSesion(x.fecha).toLowerCase()}
                  {x.grupo ? ` · ${horaCorta(x.grupo.hora)}` : ''}
                  {x.grupo?.entrenador ? ` · ${x.grupo.entrenador.nombre}` : ''}
                </Text>
              </View>
              <Tag texto="Pendiente" tipo="naranja" />
            </View>
            <Button label="Sí, estuve en clase" variant="lime" small onPress={() => confirmar(x.sesion_id)} cargando={confirmando === x.sesion_id} />
          </Card>
        ))}

        {esperando && (
          <Card>
            <Text style={styles.titulo}>Esperando a la escuela</Text>
            <Text style={styles.mut}>
              El director aún tiene que aprobar tu acceso
              {escuelas.find((e) => e.estado === 'pendiente')?.escuela ? ` a ${escuelas.find((e) => e.estado === 'pendiente')!.escuela}` : ''}.
            </Text>
          </Card>
        )}

        <Card>
          <Text style={styles.label}>Mis clases</Text>
          {grupos.length === 0 ? (
            <Text style={styles.mut}>Cuando tu escuela te apunte a un grupo, tus clases aparecerán aquí.</Text>
          ) : (
            grupos.map((g) => (
              <View key={g.id} style={[styles.fila, { justifyContent: 'space-between' }]}>
                <Text style={styles.titulo}>{g.nombre}</Text>
                <Text style={styles.mut}>{nombreDia(g.dia)} · {horaCorta(g.hora)}</Text>
              </View>
            ))
          )}
        </Card>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  cabecera: { position: 'absolute', left: 20, right: 16, top: 24, flexDirection: 'row', alignItems: 'center', gap: 12 },
  cambiar: { width: 48, height: 48, borderRadius: 24, backgroundColor: colors.white, alignItems: 'center', justifyContent: 'center' },
  etiqueta: { fontFamily: fonts.bodyBold, fontSize: 12, letterSpacing: 0.96, textTransform: 'uppercase' },
  fichaPos: { position: 'absolute' },
  num: { fontFamily: fonts.display, color: colors.white, lineHeight: 36 },
  ficha: { fontFamily: fonts.bodyBold, fontSize: 12, color: colors.white },
  pie: { position: 'absolute', left: 16, right: 16, bottom: 14, gap: 8 },
  fila: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  xp: { fontFamily: fonts.bodyBold, fontSize: 13, color: colors.muted },
  cuerpo: { padding: 20, gap: 12, width: '100%', maxWidth: 480, alignSelf: 'center' },
  pendiente: { borderColor: colors.orange, borderWidth: 2 },
  titulo: { fontFamily: fonts.bodyHeavy, fontSize: 16, color: colors.ink },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  label: { fontFamily: fonts.bodyBold, fontSize: 12, letterSpacing: 0.96, textTransform: 'uppercase', color: colors.ink2 },
});
