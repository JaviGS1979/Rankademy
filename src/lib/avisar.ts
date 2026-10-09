import { Alert, Platform } from 'react-native';

// Alert de React Native no hace nada en web: allí se usa window.alert.
export function avisar(titulo: string, texto: string) {
  if (Platform.OS === 'web') window.alert(`${titulo}\n\n${texto}`);
  else Alert.alert(titulo, texto);
}

export function confirmar(titulo: string, texto: string, accion: string, onSi: () => void) {
  if (Platform.OS === 'web') {
    if (window.confirm(`${titulo}\n\n${texto}`)) onSi();
    return;
  }
  Alert.alert(titulo, texto, [
    { text: 'Cancelar', style: 'cancel' },
    { text: accion, style: 'destructive', onPress: onSi },
  ]);
}
