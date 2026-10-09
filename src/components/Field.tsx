import { StyleSheet, Text, TextInput, View, type TextInputProps } from 'react-native';
import { colors, fonts, radius, touch } from '@/theme';

type Props = TextInputProps & { label: string; code?: boolean };

// Campo de texto de 56 pt. `code` aplica el estilo del código de escuela (A7K-29Q).
export function Field({ label, code, style, ...rest }: Props) {
  return (
    <View style={styles.field}>
      <Text style={styles.label}>{label}</Text>
      <TextInput
        accessibilityLabel={label}
        placeholderTextColor={colors.ink2}
        style={[styles.input, code && styles.code, style]}
        {...rest}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  field: { gap: 6 },
  label: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink },
  input: {
    height: touch.btn,
    borderWidth: 2,
    borderColor: colors.line,
    borderRadius: radius.field,
    paddingHorizontal: 16,
    fontFamily: fonts.body,
    fontSize: 17,
    backgroundColor: colors.white,
    color: colors.ink,
  },
  code: {
    fontFamily: fonts.display,
    fontSize: 28,
    letterSpacing: 3.4,
    textTransform: 'uppercase',
  },
});
