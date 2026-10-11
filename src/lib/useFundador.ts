import { useEffect, useState } from 'react';
import { esFundador } from './api';

// true solo si la persona que ha entrado está en la tabla de fundadores
export function useEsFundador() {
  const [fundador, setFundador] = useState(false);
  useEffect(() => {
    let vigente = true;
    esFundador()
      .then((v) => vigente && setFundador(v))
      .catch(() => {});
    return () => {
      vigente = false;
    };
  }, []);
  return fundador;
}
