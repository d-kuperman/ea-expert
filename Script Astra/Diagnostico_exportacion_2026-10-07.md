# Diagnóstico de la exportación parcial del 7 de octubre de 2026

Se inspeccionaron `EURUSD_AsiaLondonCompression_RunMetadata.csv`, `Daily.csv`, el Journal MQL5 de la instancia `97F295AFA75CC8456BE6B36E382B8947` y el registro de la plataforma.

- Solicitud: 2020-01-01 a 2026-10-06, UTC-3, servidor configurado con offset fijo de 180 minutos.
- Ejecución: empezó a las 09:20:07 y MT5 retiró `SETUP_B` del gráfico a las 09:21:52. El script informó `RunStatus=CANCELLED_PARTIAL`.
- Último día escrito: 2020-05-15. `RowsWritten=136` de 2.471 fechas calendario solicitadas. El archivo tiene 38 fines de semana y 98 laborables marcados `INCOMPLETE_SETUP_M1`.
- En los 98 laborables exportados, `AsiaBars=0`, `LondonBars=0` y `NYBars=0`. Por tanto, los resúmenes de esta ejecución no representan observaciones del mercado: cero setups válidos y cero inválidos, todos desconocidos.
- La instancia tenía `MaxBars=100000`. Para ese tramo más 120 días de warmup, la nueva comprobación estima un mínimo de **3.735.360 posiciones M1**. El límite configurado era insuficiente para acceder a 2020. Aun elevándolo, hay que comprobar que el bróker realmente proporcione el M1 antiguo.
- El registro de la plataforma confirma que el script fue retirado a las 09:21:52, pero no demuestra si el usuario lo detuvo, cambió el gráfico, cerró MT5 u ocurrió otro evento. El código detectó la interrupción mediante `IsStopped()` y cerró la exportación parcial.

La versión 1.01 evita iniciar un estudio así: comprueba `TERMINAL_MAXBARS` y presencia de M1 en semanas próximas a ambos extremos antes de abrir los CSV principales. Su alerta y `Diagnostic.csv` indican el problema concreto. El progreso informa días procesados sobre el total y `RunMetadata` incluye `LastWrittenDate`.

Para repetir el estudio: instalar la versión 1.01, subir **Máx. barras en gráfico** a un valor mayor que 3.735.360 (por ejemplo, 5.000.000), reiniciar MT5 si corresponde, cargar o comprobar el histórico M1 del símbolo, seleccionar un `RunTag` nuevo, y mantener el script y el gráfico abiertos hasta `Research COMPLETE`. Verificar `RunStatus=COMPLETE` y después la cobertura de Daily antes de interpretar los resúmenes.

No se modificaron los CSV parciales existentes. La configuración de 180 minutos es fija; si el servidor cambia de offset en el período, también hay que completar `ServerOffsetSchedule` con la historia correcta del bróker para que las sesiones UTC-3 estén alineadas.
