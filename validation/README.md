# Evidencia de validación

Validación realizada el 6 de octubre de 2026. Los archivos en `synthetic_csv/` contienen **precios artificiales**, no resultados históricos de EURUSD.

- Fuente principal compilado con MetaEditor: **0 errores, 0 warnings**. Ver `../EURUSD_AsiaLondonCompression.compile.log`.
- Pruebas ejecutadas por MT5 en una instancia portátil aislada: `SELF TESTS: ALL PASSED, failures=0`. Ver `MQL5_selftests.log`.
- Para ejecutarlas sin diálogo se compiló una copia del fuente cambiando solamente `RunSelfTestsOnly=true` y suprimiendo `#property script_show_inputs`. La lógica de producción y pruebas fue idéntica.
- El verificador Python comprobó más de mil condiciones sobre CSV, denominadores, clases, incertidumbre, conversiones, esquema y ausencia de APIs de trading/indicadores. Ver `CSV_validation.txt`.
- Salida definitiva: Daily 242 columnas; Summary 125; tablas agrupadas 115; RunMetadata 2.

Casos ejercitados: cinco clases solicitadas y orden ambiguo; igualdad que invalida Londres; fin exclusivo de NY; datos incompletos en Asia y NY; conversión de puntos/pips; incertidumbre de MAE y de stop/target; gaps de entrada; ruptura del extremo contrario después de cada lado; minutos repetidos del reloj del servidor; ATR14/ADR20 previo sin información del día actual; interrupción por día contextual ausente; percentiles; bins y posiciones fuera de Asia; columnas estables también con datos vacíos.

Para repetir la validación de CSV guardados:

```powershell
python .\validate_compression_outputs.py
```

Para volver a ejecutar las pruebas nativas, usar el script en MT5 con `RunSelfTestsOnly=true`; la guía explica la ruta de sus archivos. El directorio temporal de la instancia de validación se elimina de la entrega después de conservar esta evidencia.

No se ejecutó un estudio de varios años contra los datos de tu bróker. Eso requiere configurar el offset histórico y disponer de su histórico M1. Esta validación tampoco demuestra rentabilidad ni confirma la hipótesis de expansión.
