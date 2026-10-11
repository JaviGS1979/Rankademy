import { StyleSheet, Text, View } from 'react-native';
import { Chip, Field } from '@/components';
import { colors, fonts } from '@/theme';
import { ESPACIOS, MATERIALES, MAX_PASOS, NIVELES, OBJETIVOS } from './constantes';

export type Textos = {
  titulo: string;
  nivel: string | null;
  objetivo: string | null;
  espacio: string | null;
  material: string[];
  pasos: string[];
};

type Props = { valor: Textos; onChange: (v: Textos) => void };

// Los campos de texto de un ejercicio: nombre, nivel, objetivo, espacio, material y hasta 3 pasos.
// Los usa el editor ("Nuevo ejercicio") y "Editar ejercicio".
export function CamposEjercicio({ valor, onChange }: Props) {
  const poner = (p: Partial<Textos>) => onChange({ ...valor, ...p });
  const alterna = (id: string) =>
    poner({ material: valor.material.includes(id) ? valor.material.filter((m) => m !== id) : [...valor.material, id] });
  // Pulsar la opción ya elegida la quita
  const unica = (campo: 'nivel' | 'objetivo' | 'espacio', id: string) => poner({ [campo]: valor[campo] === id ? null : id });

  return (
    <View style={{ gap: 16 }}>
      <Field label="Nombre" placeholder="Nombre del ejercicio" value={valor.titulo} onChangeText={(titulo) => poner({ titulo })} maxLength={80} />

      <Grupo etiqueta="Nivel (opcional)">
        {NIVELES.map((n) => (
          <Chip key={n.id} texto={n.label} on={valor.nivel === n.id} onPress={() => unica('nivel', n.id)} />
        ))}
      </Grupo>
      <Grupo etiqueta="Objetivo (opcional)">
        {OBJETIVOS.map((n) => (
          <Chip key={n.id} texto={n.label} on={valor.objetivo === n.id} onPress={() => unica('objetivo', n.id)} />
        ))}
      </Grupo>
      <Grupo etiqueta="Espacio (opcional)">
        {ESPACIOS.map((n) => (
          <Chip key={n.id} texto={n.label} on={valor.espacio === n.id} onPress={() => unica('espacio', n.id)} />
        ))}
      </Grupo>
      <Grupo etiqueta="Material (opcional)">
        {MATERIALES.map((n) => (
          <Chip key={n.id} texto={n.label} on={valor.material.includes(n.id)} onPress={() => alterna(n.id)} />
        ))}
      </Grupo>

      <View style={{ gap: 8 }}>
        <Text style={styles.label}>Pasos (opcional, máximo {MAX_PASOS})</Text>
        {Array.from({ length: Math.min(MAX_PASOS, valor.pasos.length + 1) }).map((_, i) => (
          <Field
            key={i}
            label={`Paso ${i + 1}`}
            placeholder={i === 0 ? 'Ej. Cruzado, 5 pelotas' : 'Siguiente paso'}
            value={valor.pasos[i] ?? ''}
            maxLength={60}
            onChangeText={(t) => {
              const pasos = Array.from({ length: Math.max(valor.pasos.length, i + 1) }, (_, j) => (j === i ? t : (valor.pasos[j] ?? '')));
              // Los pasos vacíos del final se quitan para ofrecer siempre uno nuevo
              while (pasos.length && pasos[pasos.length - 1] === '') pasos.pop();
              poner({ pasos });
            }}
          />
        ))}
      </View>
    </View>
  );
}

function Grupo({ etiqueta, children }: { etiqueta: string; children: React.ReactNode }) {
  return (
    <View style={{ gap: 6 }}>
      <Text style={styles.label}>{etiqueta}</Text>
      <View style={styles.fila}>{children}</View>
    </View>
  );
}

const styles = StyleSheet.create({
  label: { fontFamily: fonts.bodyBold, fontSize: 14, color: colors.ink },
  fila: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
});
