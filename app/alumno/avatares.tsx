import { useCallback, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useFocusEffect } from 'expo-router';
import { Image } from 'expo-image';
import * as Haptics from 'expo-haptics';
import { Aviso, Card, Cargando, Icon, Screen } from '@/components';
import { avataresDesbloqueados, catalogoAvatares, elegirAvatar, progreso } from '@/lib/api';
import { miniaturas } from '@/lib/avatares';
import { mensajeError } from '@/lib/errores';
import { usePerfiles } from '@/lib/perfil';
import type { Avatar, Progreso } from '@/lib/tipos';
import { colors, fonts } from '@/theme';

export default function Avatares() {
  const { activo, recargar } = usePerfiles();
  const [catalogo, setCatalogo] = useState<Avatar[] | null>(null);
  const [mios, setMios] = useState<Set<string>>(new Set());
  const [prog, setProg] = useState<Progreso | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [eligiendo, setEligiendo] = useState<string | null>(null);

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
    if (!activo) return;
    setEligiendo(id);
    try {
      await elegirAvatar(activo.id, id);
      Haptics.selectionAsync().catch(() => {});
      await recargar();
    } catch (e) {
      setError(mensajeError(e));
    } finally {
      setEligiendo(null);
    }
  };

  const faltan = prog?.clases_para_siguiente_avatar;

  return (
    <Screen back title="Avatares" subtitle="Desbloquéalos asistiendo a clase.">
      <Aviso texto={error} />
      {!catalogo && !error && <Cargando />}
      <View style={styles.rejilla}>
        {catalogo?.map((a) => {
          const libre = mios.has(a.id);
          const enUso = (activo?.avatar ?? 'av01') === a.id;
          const requisito = a.clases_min !== null && a.clases_min > 0 ? `${a.clases_min} clases` : a.racha_min ? `Racha ${a.racha_min}` : '';
          return (
            <Pressable
              key={a.id}
              accessibilityRole="button"
              accessibilityLabel={libre ? (enUso ? `Avatar ${a.orden}, en uso` : `Elegir avatar ${a.orden}`) : `Avatar ${a.orden} bloqueado: ${requisito}`}
              accessibilityState={{ disabled: !libre, selected: enUso }}
              disabled={!libre || enUso || !!eligiendo}
              onPress={() => elegir(a.id)}
              style={[styles.celda, enUso && styles.enUso]}
            >
              <Image source={miniaturas[a.id]} contentFit="cover" style={[styles.img, !libre && { opacity: 0.25 }]} />
              {!libre ? (
                <View style={styles.bloqueo}>
                  <Icon name="lock" size={22} color={colors.ink} />
                  <Text style={styles.requisito}>{requisito}</Text>
                </View>
              ) : (
                <View style={[styles.estado, enUso && { backgroundColor: colors.lime }]}>
                  <Text style={styles.estadoText}>{enUso ? 'En uso' : 'Elegir'}</Text>
                </View>
              )}
            </Pressable>
          );
        })}
      </View>
      {faltan !== null && faltan !== undefined && (
        <Card style={{ borderColor: colors.blue }}>
          <Text style={styles.proximo}>
            Próximo: {faltan} {faltan === 1 ? 'clase más' : 'clases más'} para desbloquear el siguiente.
          </Text>
        </Card>
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  rejilla: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  celda: { width: '31%', flexGrow: 1, minWidth: 96, aspectRatio: 0.9, borderRadius: 18, borderWidth: 2, borderColor: colors.line, backgroundColor: colors.white, padding: 6, alignItems: 'center', gap: 6 },
  enUso: { borderColor: colors.lime, borderWidth: 3 },
  img: { width: '100%', flex: 1, borderRadius: 12 },
  bloqueo: { ...(StyleSheet.absoluteFill as object), alignItems: 'center', justifyContent: 'center', gap: 2 },
  requisito: { fontFamily: fonts.bodyBold, fontSize: 12, color: colors.ink },
  estado: { alignSelf: 'stretch', minHeight: 26, borderRadius: 999, backgroundColor: colors.blueLight, alignItems: 'center', justifyContent: 'center' },
  estadoText: { fontFamily: fonts.bodyBold, fontSize: 12, color: colors.ink },
  proximo: { fontFamily: fonts.bodySemi, fontSize: 15, color: colors.ink },
});
