import { useEffect, useRef, useState } from 'react';
import { StyleSheet, Text } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Aviso, Button, Field, Screen } from '@/components';
import { enviarCodigo, unirseAEscuela, verificarCodigo } from '@/lib/api';
import { mensajeError } from '@/lib/errores';
import { useSesion } from '@/lib/sesion';
import { colors, fonts } from '@/theme';

const ESPERA_REENVIO = 60;

export default function Verificar() {
  const router = useRouter();
  const p = useLocalSearchParams<{ correo: string; nombre?: string; rol?: string; codigo?: string }>();
  const [otp, setOtp] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [info, setInfo] = useState<string | null>(null);
  const [enviando, setEnviando] = useState(false);
  const [espera, setEspera] = useState(ESPERA_REENVIO);
  const [verificado, setVerificado] = useState(false);
  const { session } = useSesion();
  const continuado = useRef(false);

  useEffect(() => {
    if (espera <= 0) return;
    const t = setTimeout(() => setEspera((s) => s - 1), 1000);
    return () => clearTimeout(t);
  }, [espera]);

  const verificar = async () => {
    setError(null);
    if (!/^\d{6,10}$/.test(otp)) return setError('Escribe el código de 6 cifras del correo.');
    setEnviando(true);
    try {
      await verificarCodigo(p.correo, otp);
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success).catch(() => {});
      setVerificado(true);
    } catch (e) {
      setEnviando(false);
      setError(mensajeError(e));
    }
  };

  // Se continúa cuando la sesión ya está activa en la app (y las pantallas
  // privadas ya existen): completar lo que la persona eligió en "Soy…".
  useEffect(() => {
    if (!verificado || !session || continuado.current) return;
    continuado.current = true;
    (async () => {
      try {
        if (p.rol === 'director') {
          router.replace('/crear-escuela');
        } else if (p.rol === 'alumno' && p.codigo) {
          router.replace({ pathname: '/anadir-hijo', params: { codigo: p.codigo } });
        } else if (p.rol === 'entrenador' && p.codigo) {
          await unirseAEscuela(p.codigo, 'entrenador');
          router.replace('/inicio');
        } else {
          router.replace('/inicio');
        }
      } catch (e) {
        // La cuenta ya existe; falló el código de escuela: se puede reintentar
        router.replace({ pathname: '/anadir-escuela', params: { error: mensajeError(e), codigo: p.codigo ?? '' } });
      }
    })();
  }, [verificado, session, p.rol, p.codigo, router]);

  const reenviar = async () => {
    setError(null);
    setInfo(null);
    try {
      await enviarCodigo(p.correo, { crear: !!p.rol, nombre: p.nombre });
      setEspera(ESPERA_REENVIO);
      setInfo('Te hemos enviado un código nuevo.');
    } catch (e) {
      setError(mensajeError(e));
    }
  };

  return (
    <Screen back title={'Revisa tu\ncorreo'}>
      <Text style={styles.texto}>
        Hemos enviado un código a <Text style={styles.correo}>{p.correo}</Text>. Puede tardar un minuto; mira también en spam.
      </Text>
      <Field
        label="Código"
        code
        placeholder="000000"
        value={otp}
        onChangeText={(v) => setOtp(v.replace(/\D/g, '').slice(0, 10))}
        keyboardType="number-pad"
        autoComplete="one-time-code"
        textContentType="oneTimeCode"
        returnKeyType="go"
        onSubmitEditing={verificar}
        autoFocus
      />
      <Aviso texto={error} />
      <Aviso texto={info} tipo="info" />
      <Button label="Confirmar" variant="lime" onPress={verificar} cargando={enviando} />
      <Button
        label={espera > 0 ? `Reenviar código (${espera} s)` : 'Reenviar código'}
        variant="ghost"
        onPress={reenviar}
        disabled={espera > 0}
      />
    </Screen>
  );
}

const styles = StyleSheet.create({
  texto: { fontFamily: fonts.body, fontSize: 16, color: colors.ink2, lineHeight: 22 },
  correo: { fontFamily: fonts.bodyBold, color: colors.ink },
});
