import { StyleSheet, Text, View } from 'react-native';
import { Card, Icon, Screen, Tag } from '@/components';
import { colors, fonts } from '@/theme';

// Explicación sencilla de cómo se calculan los rankings
export function ComoSePuntuaVista() {
  return (
    <Screen back title={'Cómo se\npuntúa'}>
      <Card>
        <View style={styles.fila}>
          <Tag texto="Alumnos" tipo="lima" />
          <Text style={styles.mut}>Desde 8 años</Text>
        </View>
        <Text style={styles.titulo}>Premia la constancia.</Text>
        <Text style={styles.mut}>
          Puntos (XP) por cada clase a la que vas, con un bonus si no faltas varias semanas seguidas. Cuentan los de la temporada, desde el 1 de septiembre. Los Mini no salen en el ranking, y cada familia puede elegir no aparecer.
        </Text>
      </Card>

      <Card>
        <Tag texto="Entrenadores" tipo="azul" />
        <Barra etiqueta="Uso de sus ejercicios" peso={40} />
        <Text style={styles.mut}>Cuenta cuando otro entrenador lo da en clase y pasa lista. Vale doble si es de otra escuela, con un tope por pareja de entrenadores.</Text>
        <Barra etiqueta="Constancia" peso={30} />
        <Text style={styles.mut}>Las clases que le tocaban según el horario y en las que pasó lista.</Text>
        <Barra etiqueta="Asistencia y progreso" peso={30} />
        <Text style={styles.mut}>Las asistencias de sus alumnos que las familias confirman.</Text>
      </Card>

      <Card>
        <Tag texto="Escuelas" tipo="naranja" />
        <Text style={styles.titulo}>La media de sus entrenadores y alumnos.</Text>
        <Text style={styles.mut}>Necesitan un mínimo de participantes para aparecer y hacen falta varias escuelas en la zona.</Text>
      </Card>

      <View style={styles.escudo}>
        <Icon name="check" color={colors.blue} />
        <Text style={[styles.mut, { flex: 1 }]}>La lista que pasa el entrenador la ve la familia, y se revisan los patrones raros.</Text>
      </View>
    </Screen>
  );
}

function Barra({ etiqueta, peso }: { etiqueta: string; peso: number }) {
  return (
    <View style={{ gap: 4 }} accessible accessibilityLabel={`${etiqueta}: ${peso} %`}>
      <View style={styles.pesoFila}>
        <Text style={styles.titulo}>{etiqueta}</Text>
        <Text style={styles.peso}>{peso}%</Text>
      </View>
      <View style={styles.pista}>
        <View style={[styles.relleno, { width: `${peso}%` }]} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  fila: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  titulo: { fontFamily: fonts.bodyBold, fontSize: 16, color: colors.ink },
  mut: { fontFamily: fonts.body, fontSize: 14, color: colors.ink2 },
  pesoFila: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'baseline' },
  peso: { fontFamily: fonts.display, fontSize: 24, color: colors.ink },
  pista: { height: 8, borderRadius: 4, backgroundColor: colors.line, overflow: 'hidden' },
  relleno: { height: 8, borderRadius: 4, backgroundColor: colors.blue },
  escudo: { flexDirection: 'row', gap: 12, alignItems: 'center', paddingVertical: 4 },
});
