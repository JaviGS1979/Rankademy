import { StyleSheet, Text, View } from 'react-native';
import { Button, Chip } from '@/components';
import { hayFiltros, sinFiltros, type FiltrosBiblioteca } from '@/lib/api';
import { colors, fonts } from '@/theme';
import { EDADES, ESPACIOS, MATERIALES, NIVELES, OBJETIVOS } from './constantes';
import { Stepper } from './Stepper';

type Props = { filtros: FiltrosBiblioteca; onChange: (f: FiltrosBiblioteca) => void };

const alterna = (lista: string[], id: string) => (lista.includes(id) ? lista.filter((x) => x !== id) : [...lista, id]);

// Filtros de la biblioteca: edad, nivel, objetivo, nº de jugadores, material y espacio
export function PanelFiltros({ filtros, onChange }: Props) {
  const poner = (p: Partial<FiltrosBiblioteca>) => onChange({ ...filtros, ...p });
  return (
    <View style={styles.panel}>
      <Grupo etiqueta="Edad">
        {EDADES.map((e) => (
          <Chip
            key={e.id}
            texto={e.id}
            on={filtros.edad?.min === e.min}
            onPress={() => poner({ edad: filtros.edad?.min === e.min ? null : { min: e.min, max: e.max } })}
          />
        ))}
      </Grupo>
      <Grupo etiqueta="Nivel">
        {NIVELES.map((n) => (
          <Chip key={n.id} texto={n.label} on={filtros.niveles.includes(n.id)} onPress={() => poner({ niveles: alterna(filtros.niveles, n.id) })} />
        ))}
      </Grupo>
      <Grupo etiqueta="Objetivo">
        {OBJETIVOS.map((n) => (
          <Chip key={n.id} texto={n.label} on={filtros.objetivos.includes(n.id)} onPress={() => poner({ objetivos: alterna(filtros.objetivos, n.id) })} />
        ))}
      </Grupo>
      <View style={{ gap: 6 }}>
        <Text style={styles.label}>Nº de jugadores</Text>
        <View style={styles.entre}>
          <Text style={styles.texto}>Entre</Text>
          <Stepper
            label="jugadores mínimo"
            value={filtros.jugMin ?? 1}
            min={1}
            max={filtros.jugMax ?? 30}
            onChange={(v) => poner({ jugMin: v })}
          />
          <Text style={styles.texto}>y</Text>
          <Stepper
            label="jugadores máximo"
            value={filtros.jugMax ?? 30}
            min={filtros.jugMin ?? 1}
            max={30}
            onChange={(v) => poner({ jugMax: v })}
          />
        </View>
        {(filtros.jugMin !== null || filtros.jugMax !== null) && (
          <Button label="Cualquier número" variant="ghost" small onPress={() => poner({ jugMin: null, jugMax: null })} />
        )}
      </View>
      <Grupo etiqueta="Material">
        {MATERIALES.map((n) => (
          <Chip key={n.id} texto={n.label} on={filtros.materiales.includes(n.id)} onPress={() => poner({ materiales: alterna(filtros.materiales, n.id) })} />
        ))}
      </Grupo>
      <Grupo etiqueta="Espacio">
        {ESPACIOS.map((n) => (
          <Chip key={n.id} texto={n.label} on={filtros.espacios.includes(n.id)} onPress={() => poner({ espacios: alterna(filtros.espacios, n.id) })} />
        ))}
      </Grupo>
      {hayFiltros(filtros) && <Button label="Limpiar filtros" variant="ghost" small onPress={() => onChange({ ...sinFiltros, texto: filtros.texto })} />}
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
  panel: { gap: 14, backgroundColor: colors.card, borderWidth: 1, borderColor: colors.line, borderRadius: 20, padding: 16 },
  label: { fontFamily: fonts.bodyBold, fontSize: 12, letterSpacing: 0.96, textTransform: 'uppercase', color: colors.ink2 },
  fila: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  entre: { flexDirection: 'row', alignItems: 'center', gap: 8, flexWrap: 'wrap' },
  texto: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink },
});
