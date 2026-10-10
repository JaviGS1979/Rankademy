import { useCallback, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect } from 'expo-router';
import { Image } from 'expo-image';
import * as Haptics from 'expo-haptics';
import { Aviso, Card, Cargando, Icon, Screen } from '@/components';
import { avataresDesbloqueados, catalogoAvatares, comprarAvatar, elegirAvatar, progreso } from '@/lib/api';
import { avisar, confirmar } from '@/lib/avisar';
import { miniaturas } from '@/lib/avatares';
import { mensajeError } from '@/lib/errores';
import { usePerfiles } from '@/lib/perfil';
import type { Avatar, Progreso } from '@/lib/tipos';
import { colors, fonts } from '@/theme';

// Gamer: cada avatar muestra su precio en XP y se consigue con el saldo.
// Mini: sin textos ni compras; los avatares se desbloquean solos al ganar XP.
export default function Avatares() {
  const { activo, recargar } = usePerfiles();
  const mini = activo?.nivel === 'mini';
  const [catalogo, setCatalogo] = useState<Avatar[] | null>(null);
  const [mios, setMios] = useState<Set<string>>(new Set());
  const [prog, setProg] = useState<Progreso | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [ocupado, setOcupado] = useState(false);

  const cargar = useCallback(async () => {
    if (!activo) return;
    try {
      const [c, m, p] = await Promise.all([catalogoAvatares(), avataresDesbloqueados(activo.id), progreso(activo.id)]);
      setCatalogo(c);
      setMios(new Set(m));
      setProg(p);
      setError(null);
    } catch (e) {
      setError(mensajeError(e));
    }
  }, [activo]);

  useFocusEffect(
    useCallback(() => {
      cargar();
    }, [cargar]),
  );

  const elegir = async (id: string) => {
    if (!activo || ocupado) return;
    setOcupado(true);
    try {
      await elegirAvatar(activo.id, id);
      Haptics.selectionAsync().catch(() => {});
      await recargar();
    } catch (e) {
      setError(mensajeError(e));
    } finally {
      setOcupado(false);
    }
  };

  const comprar = (a: Avatar) => {
    if (!activo || !prog || ocupado) return;
    setError(null);
    if (prog.saldo < a.precio_xp) {
      avisar('Aún no llegas', `Te faltan ${a.precio_xp - prog.saldo} XP para conseguir este avatar. Sigue asistiendo a clase.`);
      return;
    }
    confirmar(
      'Conseguir avatar',
      `¿Quieres conseguir este avatar por ${a.precio_xp} XP? Te quedarán ${prog.saldo - a.precio_xp} XP.`,
      'Conseguir',
      async () => {
        setOcupado(true);
        try {
          await comprarAvatar(activo.id, a.id);
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
          await cargar();
        } catch (e) {
          setError(mensajeError(e));
        } finally {
          setOcupado(false);
        }
      },
      false,
    );
  };

  const sig = prog?.siguiente_avatar;

  return (
    <Screen back title="Avatares" subtitle={mini ? undefined : 'Consíguelos con tus XP.'}>
      <Aviso texto={error} />
      {!catalogo && !error && <Cargando />}

      {!mini && prog && (
        <View style={styles.saldo} accessible accessibilityLabel={`Tienes ${prog.saldo} XP para gastar`}>
          <Icon name="star" size={28} color={colors.lime} fill={colors.lime} />
          <Text style={styles.saldoNum}>{prog.saldo}</Text>
          <Text style={styles.saldoTexto}>XP para gastar</Text>
        </View>
      )}

      <View style={styles.rejilla}>
        {catalogo?.map((a) => {
          const mio = mios.has(a.id);
          const enUso = (activo?.avatar ?? 'av01') === a.id;
          const alcanza = !!prog && prog.saldo >= a.precio_xp;
          const etiqueta = mio
            ? enUso ? `Avatar ${a.orden}, en uso` : `Elegir avatar ${a.orden}`
            : mini ? `Avatar ${a.orden} bloqueado` : `Avatar ${a.orden}, ${a.precio_xp} XP${alcanza ? ', puedes conseguirlo' : ''}`;
          return (
            <Pressable
              key={a.id}
              accessibilityRole="button"
              accessibilityLabel={etiqueta}
              accessibilityState={{ disabled: ocupado || (!mio && mini), selected: enUso }}
              disabled={ocupado || enUso || (!mio && mini)}
              onPress={() => (mio ? elegir(a.id) : comprar(a))}
              style={[styles.celda, enUso && styles.enUso, !mio && !mini && alcanza && styles.puedes]}
            >
              <Image source={miniaturas[a.id]} contentFit="cover" style={[styles.img, !mio && { opacity: 0.35 }]} />
              {!mio && (
                <View style={styles.candado}>
                  <Icon name="lock" size={20} color={colors.ink} />
                </View>
              )}
              {mini ? (
                enUso && (
                  <View style={styles.marca}>
                    <Icon name="check" size={20} color={colors.ink} strokeWidth={3.5} />
                  </View>
                )
              ) : (
                <View style={[styles.pie, mio ? (enUso ? { backgroundColor: colors.lime } : { backgroundColor: colors.blueLight }) : alcanza ? { backgroundColor: colors.lime } : { backgroundColor: colors.line }]}>
                  {mio ? (
                    <Text style={styles.pieTexto}>{enUso ? 'En uso' : 'Elegir'}</Text>
                  ) : (
                    <Text style={styles.pieTexto}>{a.precio_xp} XP</Text>
                  )}
                </View>
              )}
            </Pressable>
          );
        })}
      </View>

      {!mini && sig && (
        <Card style={{ borderColor: colors.blue }}>
          <Text style={styles.proximo}>
            {sig.faltan > 0
              ? `Te faltan ${sig.faltan} XP para el siguiente avatar.`
              : '¡Ya tienes XP para conseguir un avatar nuevo!'}
          </Text>
        </Card>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  saldo: { flexDirection: 'row', alignItems: 'center', gap: 10, backgroundColor: colors.ink, borderRadius: 18, paddingVertical: 12, paddingHorizontal: 16 },
  saldoNum: { fontFamily: fonts.display, fontSize: 36, lineHeight: 36, color: colors.lime },
  saldoTexto: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.white },
  rejilla: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  celda: { width: '31%', flexGrow: 1, minWidth: 96, borderRadius: 18, borderWidth: 2, borderColor: colors.line, backgroundColor: colors.white, padding: 6, gap: 6 },
  enUso: { borderColor: colors.lime, borderWidth: 3 },
  puedes: { borderColor: colors.lime },
  img: { width: '100%', aspectRatio: 1, borderRadius: 12 },
  candado: { position: 'absolute', top: 12, right: 12, backgroundColor: colors.white, borderRadius: 12, padding: 4 },
  marca: { position: 'absolute', top: 12, right: 12, backgroundColor: colors.lime, borderRadius: 12, padding: 4 },
  pie: { minHeight: 28, borderRadius: 999, alignItems: 'center', justifyContent: 'center' },
  pieTexto: { fontFamily: fonts.bodyBold, fontSize: 13, color: colors.ink },
  proximo: { fontFamily: fonts.bodySemi, fontSize: 15, color: colors.ink },
});
