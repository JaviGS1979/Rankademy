import { Text } from 'react-native';
import { Screen } from './Screen';
import { colors, fonts } from '@/theme';

// Marcador de pantallas que se construyen en fases posteriores.
export function Placeholder({ title, fase }: { title: string; fase: string }) {
  return (
    <Screen back title={title}>
      <Text style={{ fontFamily: fonts.body, fontSize: 16, color: colors.ink2 }}>
        Esta pantalla se construye en la {fase}.
      </Text>
    </Screen>
  );
}
