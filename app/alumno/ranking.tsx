import { Text } from 'react-native';
import { Card, Icon, Screen } from '@/components';
import { colors, fonts, type as t } from '@/theme';

// El ranking se construye en una fase posterior.
export default function Ranking() {
  return (
    <Screen title="Ranking">
      <Card>
        <Icon name="trophy" size={40} color={colors.blue} />
        <Text style={t.h3}>Muy pronto</Text>
        <Text style={{ fontFamily: fonts.body, fontSize: 15, color: colors.ink2 }}>
          Cuando haya suficientes escuelas en tu zona verás aquí tu posición. Sigue asistiendo a clase para sumar XP.
        </Text>
      </Card>
    </Screen>
  );
}
