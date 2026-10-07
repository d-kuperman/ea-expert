# INFORME EURUSD · ASIA / LONDON COMPRESSION

Fecha del análisis: 7 de octubre de 2026. Histórico: 1 de enero de 2020–6 de octubre de 2026.

Fuente principal: los nueve CSV de `Estadísticas script Astra`. Se consultó el código del script únicamente para interpretar las métricas y auditar sus fórmulas. No se modificaron los CSV ni se creó un EA. Los decimales de las tablas usan punto para facilitar su cotejo con los archivos.

## 1. Resumen ejecutivo

**Conclusión general: NO HAY EVIDENCIA DE EDGE explotable demostrado con estos CSV.** Hay evidencia estadística de que la posición del precio anticipa el primer extremo tocado. Eso no acredita una expectativa positiva después de entrar en la ruptura.

| Pregunta | Respuesta |
| --- | --- |
| A. ¿Existe ventaja? | No se demuestra rentabilidad. Hay 152 setups con NY completo, 137 primeras rupturas y muchos escenarios TP/SL sin resolución al cierre. Ninguno de los 21 modelos base presenta una cota inferior de expectativa positiva en el conjunto completo. |
| B. ¿Menor compresión anticipa mayor expansión? | No aparece una relación monotónica favorable. CompressionRatio frente a MFE en pips: Spearman **0.072**, p=0.401. Frente al rango NY/Asia: **+0.376**, en sentido contrario al argumento de que un ratio menor debe producir más expansión relativa. |
| C. ¿Puede anticiparse mejor la dirección? | Sí, el primer lado tocado: elegir el extremo más cercano al precio de las 08:00 acierta **101/137 = 73.72%**, frente a 51.09% de elegir siempre Low en esta muestra. No es un winrate de trading. |
| D. ¿Variable más importante? | **Price0800Position** para el primer lado. ATR/ADR y AsiaRange para el tamaño del rango NY, con limitaciones de cobertura del contexto. |
| E. ¿Expansión típica? | MFE del primer breakout: **mediana 16.0 pips**, P25–P75 **7.6–34.1**, media 24.24. Mediana normalizada **0.441×Asia**. El rango completo NY tiene mediana 49.75 pips y es otra medida. |
| F. ¿Principal fallo? | Retorno dentro de Asia en al menos **130/137 = 94.89%** de las primeras rupturas; MAE mediana 16.0 pips. Un retorno no equivale necesariamente a stop, pero contradice la idea de una ruptura habitualmente limpia. |
| G. ¿Combinación especialmente prometedora? | Ninguna con muestra suficiente. La celda más poblada del cruce compresión×precio tiene solo **13 setups**. Compresión <0.30: **0 casos**. |
| H. ¿Robustez temporal? | La predicción del primer lado persiste: **72.00% inicial / 75.81% final**. La expectativa de la configuración elegida en el tramo inicial empeora en el final. La frecuencia también cambia mucho en 2025–2026. |
| I. ¿Avanzar hacia un EA? | **No hacia un EA operativo todavía.** Sí tiene sentido una fase limitada de validación con horarios verificados, ticks/Bid-Ask y cierre a las 14:00 registrado. No hay base para una optimización extensa. |

El control que más debilita la hipótesis original es comparar el setup con los días sin contención: NY promedia **54.32 frente a 52.29 pips**, diferencia **+2.03 pips**, IC95% bootstrap **[−2.40, +6.52]**. La expansión normalizada es incluso menor: **1.416 frente a 2.009×Asia**. No puede atribuirse esa diferencia a causalidad: los setups seleccionan rangos Asia mayores y el grupo inválido es heterogéneo.

**Condiciones de validez del informe:** los agrupados tienen una discrepancia de borde explicada por un único día; el servidor fue convertido con UTC+3 fijo sin calendario histórico; el contexto ATR/ADR es parcial; y faltan cierres de operaciones pendientes. Estas limitaciones se detallan antes de interpretar los resultados.

## 2. Calidad y período de los datos

### Inventario y población

La carpeta indicada en el pedido como `/Estadisticas script Asia` no existe con ese nombre. Se localizaron los nueve nombres exactos requeridos en **`Estadísticas script Astra`**. Se analizaron esos archivos conjuntamente. El prefijo común es `EURUSD_AsiaLondonCompression_`.

| Archivo | Filas | Columnas | Celdas vacías | NaN/Inf literales |
| --- | --- | --- | --- | --- |
| ByCompression.csv | 8 | 115 | 188 | 0 |
| ByLondonPosition.csv | 5 | 115 | 102 | 0 |
| ByPrice0800Position.csv | 7 | 115 | 187 | 0 |
| ByVolatility.csv | 18 | 115 | 360 | 0 |
| ByWeekday.csv | 5 | 115 | 5 | 0 |
| CompressionPriceCross.csv | 58 | 115 | 2807 | 0 |
| Daily.csv | 2471 | 242 | 211608 | 0 |
| RunMetadata.csv | 49 | 2 | 1 | 0 |
| Summary.csv | 1 | 125 | 1 | 0 |


RunMetadata declara versión **1.01**, estado **COMPLETE**, 2,471 filas escritas, fecha final 2026-10-06 y fuente OHLC M1 del broker. La fecha de generación es 2026-10-07 13:04:13–13:04:14 UTC. Esto identifica la ejecución, no certifica la corrección del histórico del broker.

| Estado | Días |
| --- | ---: |
| Días calendario | 2471 |
| Fines de semana, excluidos de operativa | 706 |
| Lunes a viernes | 1765 |
| Setup evaluable | 1724 |
| Setup válido | 155 |
| Setup inválido | 1569 |
| Setup desconocido por cobertura M1 incompleta | 41 |
| Filas con setup evaluable pero NY incompleto | 17 |
| De las anteriores: válidos / inválidos | 3 / 14 |
| Válidos con NY completo usados en resultados | 152 |
| Inválidos con NY completo usados como control | 1555 |

Hay **58 días laborables con cobertura incompleta**: 41 de setup y 17 de NY, categorías excluyentes en DataStatus. No se clasifican los 41 desconocidos como inválidos. Los tres válidos sin NY completo son **2021-01-26, 2021-05-31 y 2021-06-18**. No se imputa su resultado.

### Vacíos, anomalías y cálculos

Daily tiene 211,608 celdas vacías y 2,431 filas con algún campo vacío. **Eso no significa que existan 2,431 días inutilizables:** muchos campos solo aplican si hubo ruptura de un lado, retorno, o contexto previo suficiente. Los fines de semana también generan campos estructuralmente vacíos. Se distingue ausencia de dato de cero.

Se ejecutaron **191 comprobaciones** de estructura, unidades, identidades, tiempos, clasificación y estados. Pasan 190 directamente; el cotejo global de agrupados detecta la discrepancia de borde descrita abajo, que queda enteramente explicada al reconstruir el cálculo binario. No se encontraron fechas duplicadas, filas completas duplicadas, huecos en el calendario de filas, cabeceras repetidas, filas con longitud incorrecta, números no finitos ni literales NaN/Inf o errores de división. Los NaN en el análisis son la representación interna de vacíos del CSV.

Se verificaron: símbolo y UTCOffset, día de semana, barras esperadas 480/240/360, aritmética de barras faltantes, rangos high−low, pip=0.0001 y point=0.00001, CompressionRatio, posición de Londres y de las 08:00, normalización de NY, MFE/MAE y cotas por lado, SL A/B/C, igualdad entre el primer lado y las métricas genéricas, marcas temporales y los 42 estados R por fila. No hay AsiaRange cero en días evaluables, precios observados no positivos, rangos negativos ni MAE inferior superior a su cota alta. No hay MAE superior cero entre las rupturas válidas: el ratio MFE/MAE no requiere dividir por cero aquí.

Las posiciones fuera de [0,1] o distancias negativas en **días inválidos** no son errores: Londres o el precio pueden estar fuera de Asia. No se trasladan esas observaciones al conjunto válido. Los 152 válidos completos tienen el precio de las 08:00 dentro de Asia. No hay gaps de entrada señalados en sus rupturas High/Low.

### Reconciliación contra Daily

| Archivo | Filas | Valores numéricos cotejados | Vacíos cotejados | Diferencias literales |
| --- | --- | --- | --- | --- |
| Summary | 1 | 123 | 0 | 0 |
| ByCompression | 8 | 724 | 180 | 183 |
| ByLondonPosition | 5 | 468 | 97 | 0 |
| ByPrice0800Position | 7 | 611 | 180 | 0 |
| CompressionPriceCross | 58 | 3747 | 2807 | 186 |
| ByWeekday | 5 | 565 | 0 | 0 |
| ByVolatility | 18 | 1674 | 360 | 0 |


**Discrepancia única de origen:** el **2024-09-10**, AsiaRange=21.0 pips y LondonRange=16.8 pips. Daily imprime CompressionRatio=**0.80000000**; al calcular desde precios en coma flotante se obtiene **0.7999999999999577**. El script lo agrega a [0.70,0.80), mientras el CSV publicado lo coloca, literalmente, en [0.80,1.00].

Esto produce **183 diferencias numéricas en ByCompression y 186 en CompressionPriceCross**, todas derivadas de mover ese único día. ByCompression informa N=39/19 en los dos últimos buckets; Daily publicado da **38/20**. Reconstruyendo el cociente binario desde los precios, **desaparecen las 369 diferencias** dentro de tolerancia absoluta 2×10⁻⁷. No hay discrepancia en los totales ni en Summary, posiciones, weekday o volatilidad. El informe usa la clasificación del **Daily publicado**; no corrige los originales.

### Horarios, cobertura y lo que no puede certificarse

El código ancla Asia 20:00 del día anterior–04:00, Londres 04:00–08:00 y NY 08:00–14:00 en UTC−3, inicio inclusivo y fin exclusivo. No hay solapamiento entre ventanas. FirstBreakTime y MFETime son horas de apertura de velas M1, no tiempos de tick. El precio 08:00 es la apertura de la vela, no un fill ejecutado.

**ServerUTCOffsetMinutes=180 y ServerOffsetSchedule vacío durante 2020–2026.** Si el servidor cambió entre UTC+2 y UTC+3, los segmentos afectados están desplazados una hora. No se conoce aquí el broker ni su calendario histórico y no puede confirmarse ni descartarse ese desplazamiento. Los horarios exportados son internamente coherentes con la configuración, lo cual no valida su correspondencia con UTC real. Además, estas ventanas fijas no siguen automáticamente los cambios de horario estacional de las plazas Londres/Nueva York.

La documentación oficial aclara que TimeGMT tiene un comportamiento particular dentro del Strategy Tester y no permite por sí solo certificar el histórico del offset: [MQL5, TimeGMT](https://www.mql5.com/en/docs/dateandtime/timegmt). Para este análisis prevalece la configuración explícita de RunMetadata.

**ATR/ADR:** 150 setups completos tienen ContextQuality=`OBSERVED_M1_PARTIAL` y 2 `INSUFFICIENT`; ninguno `FULL_M1`. La mediana de la cobertura mínima de los 20 días previos es **74.65%**. Parte puede deberse a cierres semanales/feriados dentro del día UTC−3, no necesariamente a pérdida de cotizaciones. Aun así son rangos observados parciales, y no se certifica equivalencia con un ATR/ADR calculado sobre días completos convencionales. El código usa solo días previos, sin incluir el día actual; sus valores exactos no se reconstruyen desde estos CSV porque falta el OHLC diario previo completo y el warmup M1.

La auditoría de identidades no sustituye una comparación con las barras/ticks originales, ausentes aquí. No puede comprobar por completo precios, extremos, secuencia intrabar ni condiciones de ejecución. Los **SHA-256 de los nueve CSV coinciden antes y después** del análisis.

## 3. Frecuencia del setup

El setup aparece en **155/1724 días evaluables = 8.99%**, IC95% Wilson **7.73%–10.43%**. Son 8.78% de los 1765 lunes–viernes y 6.27% de los días calendario. Los tres denominadores responden a preguntas distintas; para frecuencia condicionada a datos suficientes se usa 1724.

| Año | Lun-vie | Evaluables | Desconocidos | Válidos | Inválidos | NY completo | Válidos% | IC95 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2020 | 262 | 256 | 6 | 22 | 234 | 22 | 8.59 | 5.74–12.67 |
| 2021 | 261 | 251 | 10 | 17 | 234 | 14 | 6.77 | 4.27–10.58 |
| 2022 | 260 | 250 | 10 | 18 | 232 | 18 | 7.20 | 4.60–11.09 |
| 2023 | 260 | 253 | 7 | 17 | 236 | 17 | 6.72 | 4.24–10.50 |
| 2024 | 262 | 258 | 4 | 15 | 243 | 15 | 5.81 | 3.55–9.37 |
| 2025 | 261 | 259 | 2 | 40 | 219 | 40 | 15.44 | 11.55–20.35 |
| 2026 | 199 | 197 | 2 | 26 | 171 | 26 | 13.20 | 9.17–18.64 |


**Setups válidos por mes calendario:**

| Año | Ene | Feb | Mar | Abr | May | Jun | Jul | Ago | Sep | Oct | Nov | Dic |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2020 | 0 | 3 | 5 | 1 | 0 | 1 | 2 | 0 | 3 | 2 | 1 | 4 |
| 2021 | 2 | 0 | 1 | 2 | 2 | 1 | 0 | 3 | 0 | 3 | 3 | 0 |
| 2022 | 1 | 2 | 2 | 4 | 0 | 2 | 1 | 0 | 1 | 1 | 1 | 3 |
| 2023 | 2 | 2 | 1 | 3 | 0 | 1 | 1 | 0 | 2 | 1 | 2 | 2 |
| 2024 | 2 | 1 | 0 | 2 | 2 | 1 | 2 | 1 | 1 | 1 | 0 | 2 |
| 2025 | 1 | 4 | 2 | 7 | 6 | 4 | 8 | 1 | 1 | 1 | 2 | 3 |
| 2026 | 5 | 4 | 2 | 2 | 2 | 3 | 4 | 1 | 2 | 1 | — | — |


Octubre de 2026 solo incluye hasta el día 6; noviembre y diciembre no forman parte del estudio. Se observan **82 meses**, con media **1.89 setups por mes**, y **13 meses sin ninguno**. La frecuencia anualizada global es aproximadamente **22.9 setups/año**, aunque mezcla regímenes y un año parcial. La mediana de separación entre setups es **11 días calendario**, P90=37.4 y máximo=82 días.

La tasa sube de aproximadamente 6%–9% en 2020–2024 a 15.44% en 2025 y 13.20% en 2026. No conviene extrapolar una frecuencia constante. Un solo par ofrece pocas observaciones y filtrar por dos o tres variables la reduce mucho más. La operativa manual podría ser ocasional; la velocidad de validación estadística de un EA sería baja.

## 4. Comportamiento general de NY

En los 152 setups completos hay **137 días con alguna ruptura (90.13%)**, 15 sin ruptura y 28 con ambos lados alcanzados. El script define ruptura como **tocar o superar** el extremo, usando `>=`/`<=`. No exige cierre fuera ni margen de penetración. La contención de Londres sí es estricta: tocar el extremo invalida el setup.

| Magnitud | Válidos N=152 | Inválidos N=1555 | Diferencia de medias e IC95% |
| --- | ---: | ---: | --- |
| NYRange media, pips | 54.32 | 52.29 | +2.03; [−2.40, +6.52] |
| NYRange mediana, pips | 49.75 | 45.60 | Descriptiva |
| NYRange/Asia media | 1.416 | 2.009 | −0.593; [−0.726, −0.454] |
| NYRange/Asia mediana | 1.272 | 1.715 | Descriptiva |
| AsiaRange media, pips | 44.04 | 29.76 | +14.28; [10.36, 18.70] |

Intervalos bootstrap percentil, 10,000 remuestreos por día, semilla fija. No son una prueba causal ni corrigen por todas las diferencias de composición. La selección de días con Londres contenido favorece Asia grande; dividir NY por Asia no elimina automáticamente ese sesgo.

| Año | N válido | N inválido | NY válido media | NY inválido media | Norm válido | Norm inválido |
| --- | --- | --- | --- | --- | --- | --- |
| 2020 | 22 | 231 | 65.55 | 55.95 | 1.13 | 1.99 |
| 2021 | 14 | 225 | 40.04 | 42.44 | 1.30 | 1.90 |
| 2022 | 18 | 231 | 65.19 | 71.25 | 1.43 | 1.99 |
| 2023 | 17 | 235 | 62.54 | 55.19 | 2.01 | 2.19 |
| 2024 | 15 | 243 | 35.00 | 43.36 | 1.46 | 2.30 |
| 2025 | 40 | 219 | 59.58 | 54.25 | 1.46 | 1.81 |
| 2026 | 26 | 171 | 42.67 | 40.92 | 1.23 | 1.80 |


El rango NY absoluto es mayor en algunos años y menor en otros; el cociente NY/Asia de los válidos es menor que el control en **los siete años**. La evidencia no respalda que la mera contención genere una expansión NY excepcional frente a días ordinarios. No se afirma que sea imposible hallar una subestrategia rentable: la hipótesis amplia no queda demostrada.

## 5. Dirección del breakout

| Clase | N | % de 152 |
| --- | --- | --- |
| HIGH_ONLY | 53 | 34.87 |
| LOW_ONLY | 56 | 36.84 |
| HIGH_THEN_LOW | 14 | 9.21 |
| LOW_THEN_HIGH | 14 | 9.21 |
| NO_BREAK | 15 | 9.87 |
| BOTH_ORDER_AMBIGUOUS | 0 | 0.00 |


High first: **67/152 = 44.08%**. Low first: **70/152 = 46.05%**. Ambos lados: **28/152 = 18.42%**, IC95% 13.06%–25.34%. Sin ruptura: **15/152 = 9.87%**, IC95% 6.07%–15.64%. Ambos lados es una categoría superpuesta al primer lado, por lo que no deben sumarse esas tasas.

Condicionando a una primera ruptura conocida: High **67/137 = 48.91%**, Low **70/137 = 51.09%**. IC95% para High: **40.68%–57.19%**; test binomial bilateral frente a 50%: **p=0.864**. **No hay sesgo direccional global significativo.**

No hay orden inicial ambiguo entre los válidos completos. Eso no elimina las ambigüedades posteriores TP/SL o de retorno dentro de la vela de entrada.

## 6. Magnitud de expansión

Se separan tres conceptos:

1. **NYRange:** máximo−mínimo de toda la ventana, incluye recorrido anterior al breakout y no equivale a beneficio capturable.
2. **MFE del primer breakout:** máxima distancia favorable desde AsiaHigh/AsiaLow hasta las 14:00, después de ese primer contacto. Se calcula en 137 días y no se asigna cero a los 15 sin ruptura.
3. **Expansión normalizada:** MFE/AsiaRange. `MFE_PctAsia` es exactamente ese ratio multiplicado por 100; no constituye una tercera señal independiente.

La expansión típica del primer breakout es **16.0 pips**, no la media de 24.24. El 50% central está entre **7.6 y 34.1 pips**; P90=56.84, P95=68.74 y máximo=125.2. Movimientos de 70–125 pips pertenecen a la cola, no al caso normal.

Los **7 mayores MFE** (5.11% de 137) aportan **19.42%** de la suma total de MFE. Sin ellos la media cae a **20.59 pips**; recortando 13 observaciones de cada extremo, la media es **20.49 pips**. La mediana es más representativa que la media o el máximo. Estas sumas de excursiones no son PnL de una estrategia.

El cociente normalizado mediano del primer breakout es **0.441×Asia**, con P25=0.166 y P75=0.889. Una Asia mayor no garantiza más pips después de tocar su límite.

## 7. MFE

Las series High y Low incluyen **todas las rupturas de cada lado**, también cuando ese lado fue el segundo del día. Por eso N High=81 y N Low=84 suman 165 eventos en 137 días con ruptura; no son 165 días independientes.

| Lado | Unidad | N | Media | Mediana | DE | P25 | P50 | P75 | P90 | P95 | Máximo |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Primero | Pips | 137 | 24.24 | 16.00 | 23.75 | 7.60 | 16.00 | 34.10 | 56.84 | 68.74 | 125.20 |
| Primero | PctAsia | 137 | 68.92 | 44.14 | 73.86 | 16.60 | 44.14 | 88.93 | 158.99 | 241.83 | 375.49 |
| High | Pips | 81 | 21.57 | 13.10 | 23.10 | 5.90 | 13.10 | 28.30 | 49.50 | 68.30 | 115.60 |
| High | PctAsia | 81 | 61.22 | 42.64 | 71.36 | 15.24 | 42.64 | 73.88 | 139.71 | 195.77 | 375.49 |
| Low | Pips | 84 | 23.48 | 16.65 | 22.33 | 7.83 | 16.65 | 31.90 | 50.58 | 66.00 | 125.20 |
| Low | PctAsia | 84 | 68.92 | 45.02 | 69.39 | 21.89 | 45.02 | 96.96 | 161.28 | 214.94 | 307.62 |


`PctAsia` significa porcentaje del rango asiático; 100 equivale a 1×Asia. Para expresar cualquier percentil anterior en expansión normalizada, se divide por 100. Por ejemplo, High mediana=**0.4264×Asia** y Low=**0.4502×Asia**; las medias son 0.6122 y 0.6892 respectivamente.

No interpretar la diferencia Low−High como una ventaja corta demostrada: hay observaciones emparejadas, orden distinto, tamaños moderados y resultados anuales cambiantes. La MFE se mide hasta el final de NY, incluso si una entrada hipotética habría tocado SL antes. No sirve por sí sola para computar aciertos a 1R/2R.

## 8. MAE

**La MAE principal es una cota superior**, porque el mínimo/máximo de la vela inicial podría haber ocurrido antes de la entrada. El script también exporta una cota inferior. En **23/137** primeras rupturas ambas difieren. Además, MAE abarca toda la ventana posterior hasta las 14:00, incluso después de haber alcanzado un eventual TP: no es específicamente el retroceso antes del MFE.

| Lado | Métrica | Unidad | N | Media | Mediana | DE | P25 | P50 | P75 | P90 | P95 | Máximo |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Primero | MAE | Pips | 137 | 21.83 | 16.00 | 18.64 | 7.80 | 16.00 | 31.90 | 43.86 | 61.00 | 88.10 |
| Primero | MAE | PctAsia | 137 | 60.47 | 47.47 | 54.18 | 16.60 | 47.47 | 83.99 | 135.85 | 165.35 | 300.68 |
| Primero | MAELower | Pips | 137 | 21.11 | 15.10 | 19.17 | 6.00 | 15.10 | 31.90 | 43.86 | 61.00 | 88.10 |
| Primero | MAELower | PctAsia | 137 | 58.14 | 43.18 | 55.43 | 14.20 | 43.18 | 81.42 | 135.85 | 165.35 | 300.68 |
| High | MAE | Pips | 81 | 23.86 | 19.70 | 20.09 | 9.40 | 19.70 | 32.10 | 48.40 | 65.40 | 88.10 |
| High | MAE | PctAsia | 81 | 67.91 | 56.60 | 59.31 | 21.99 | 56.60 | 86.97 | 146.72 | 167.70 | 300.68 |
| High | MAELower | Pips | 81 | 23.18 | 19.70 | 20.66 | 8.20 | 19.70 | 32.10 | 48.40 | 65.40 | 88.10 |
| High | MAELower | PctAsia | 81 | 65.56 | 52.60 | 60.93 | 19.16 | 52.60 | 86.97 | 146.72 | 167.70 | 300.68 |
| Low | MAE | Pips | 84 | 18.60 | 12.40 | 17.36 | 5.78 | 12.40 | 26.38 | 41.82 | 56.88 | 82.90 |
| Low | MAE | PctAsia | 84 | 53.78 | 36.51 | 51.61 | 13.96 | 36.51 | 78.18 | 129.14 | 163.04 | 248.20 |
| Low | MAELower | Pips | 84 | 17.97 | 11.95 | 17.72 | 4.38 | 11.95 | 26.38 | 41.82 | 56.88 | 82.90 |
| Low | MAELower | PctAsia | 84 | 51.99 | 33.90 | 52.32 | 13.49 | 33.90 | 77.18 | 129.14 | 163.04 | 248.20 |


Para el primer breakout, MAE superior mediana=**16.0 pips**, P75=31.9, P90=43.86 y P95=61.0. La cota inferior mediana es 15.1 pips. La similitud entre MFE mediana y MAE mediana debilita una supuesta asimetría automática.

### MFE / MAE por observación

| Lado | N | Media | Mediana | DE | P25 | P75 | P90 | P95 | Máximo |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Primero | 137 | 5.66 | 0.84 | 19.47 | 0.25 | 4.29 | 16.65 | 20.79 | 217.00 |
| High | 81 | 5.53 | 0.67 | 24.44 | 0.21 | 2.77 | 6.21 | 17.36 | 217.00 |
| Low | 84 | 4.51 | 1.19 | 7.16 | 0.36 | 4.88 | 15.78 | 20.51 | 33.55 |


Se divide por la **MAE superior**, por lo que es la versión conservadora del cociente. No hay denominadores cero en estas series. La **MAE inferior sí vale cero en 7 primeras rupturas** (4 eventos High y 4 Low en las series por lado, que también incluyen segundas rupturas); dividir por ella produciría ratios indefinidos o infinitos, que no se imputan ni se incorporan a la media. La media del primer cociente con MAE superior es **5.66**, pero su mediana es **0.843** y el máximo **217**. Un denominador muy pequeño produce ratios extremos; la media no representa una relación beneficio/riesgo ejecutable. Solo **65/137 = 47.45%** tienen MFE mayor que MAE superior. El ratio de las medias, 24.24/21.83=1.11, tampoco es la media de ratios ni una expectativa.

### ¿Quienes alcanzan 1R–3R tienen poco MAE?

R se define por el riesgo de cada modelo y el lado del primer breakout. Las siguientes son agrupaciones por excursión máxima, **seleccionadas después de observar el futuro**, no probabilidades de ganar.

| Modelo | MFE al menos R | N | MAE mediana R | MAE<0.5R% | MAE<1R% |
| --- | --- | --- | --- | --- | --- |
| A | 1 | 52 | 0.31 | 63.46 | 82.69 |
| A | 2 | 20 | 0.31 | 60.00 | 80.00 |
| A | 3 | 8 | 0.62 | 50.00 | 62.50 |
| B | 1 | 64 | 0.43 | 54.69 | 68.75 |
| B | 2 | 29 | 0.45 | 55.17 | 68.97 |
| B | 3 | 15 | 0.38 | 53.33 | 60.00 |
| C | 1 | 44 | 0.21 | 70.45 | 88.64 |
| C | 2 | 15 | 0.21 | 60.00 | 93.33 |
| C | 3 | 7 | 0.69 | 42.86 | 85.71 |


Hay cierta asimetría en el subconjunto que acaba expandiéndose, pero la mayoría de las colas tiene N<20. En B, de los 64 casos con MFE≥1R solo 68.75% mantienen MAE de toda la ventana por debajo de 1R. Un MAE≥1R puede ocurrir antes o después de un TP; esa tabla no identifica la secuencia. Para resolverla se usan exclusivamente los estados R exportados cuando son inequívocos.

## 9. Fakeouts

Se distinguen **retorno dentro de Asia** y **recorrido de ambos extremos**. La primera definición es muy sensible: basta observar precio estrictamente dentro; no requiere cerrar la operación con pérdida ni un rechazo de cierta profundidad.

Retorno confirmado: **130/137 = 94.89%**, IC95% Wilson 89.83%–97.50%. Hay otros **7 casos ambiguos**, de modo que la frecuencia descriptiva queda entre **94.89% y 100%**; este intervalo de identificación no es un IC estadístico. Ningún caso tiene ausencia de retorno demostrada por OHLC.

| Clase | N | MFE media | MFE mediana | MAE media | Norm mediana | Min break med | Fake mínimo% |
| --- | --- | --- | --- | --- | --- | --- | --- |
| HIGH_ONLY | 53 | 27.21 | 19.00 | 17.82 | 0.52 | 90.00 | 92.45 |
| HIGH_THEN_LOW | 14 | 10.30 | 6.35 | 49.71 | 0.19 | 32.50 | 100.00 |
| LOW_ONLY | 56 | 27.76 | 19.80 | 13.21 | 0.65 | 90.00 | 94.64 |
| LOW_THEN_HIGH | 14 | 12.91 | 11.10 | 43.61 | 0.30 | 61.00 | 100.00 |
| NO_BREAK | 15 | — | — | — | — | — | — |


High→Low: **14 días**; MFE del primer lado mediana **6.35 pips**. Low→High: **14 días**; mediana **11.10 pips**. Cada muestra es muy poco confiable por separado. Esas MFE son máximos hasta las 14:00, **no el avance exclusivamente anterior a la primera reversión**. El precio puede volver a expandirse más tarde. Los CSV no contienen MFE recortada al instante de retorno ni la trayectoria necesaria para reconstruirla.

En 130 retornos confirmados, tiempo desde breakout al primer retorno **cierto**: P50=**1 minuto**, P75=2.75, P90=16.1 y P95=47.5; máximo 241. La mediana no es tiempo de tick: los retornos en la misma vela valen cero minutos y la posible primera vuelta intrabar puede preceder al retorno cierto registrado.

Los desgloses de compresión, posición y horario que siguen incluyen retorno cierto y ambos lados. La cota alta de retorno es 100% en todos los grupos con rupturas. El precio en [0.80,1.00] muestra 37.5% de ambos lados, pero **N=16**, insuficiente para imponer un filtro. Las rupturas antes de las 09:00 tienen más ambos lados que las tardías, parcialmente porque disponen de más tiempo para recorrerlos.

El retorno casi universal justifica estudiar una entrada confirmada o un retest. **No demuestra que esperar mejore el PnL**, ni justifica hacer fade automáticamente: los retornos pueden ser breves y preceder a una continuación ganadora.

## 10. CompressionRatio

CompressionRatio=LondonRange/AsiaRange. Las tablas se recalculan desde Daily publicado, con el cambio de un caso del bucket [0.70,0.80) al [0.80,1.00] documentado en la auditoría.

| Grupo | N | N primer breakout | High first % | Low first % | Ambos % | Sin ruptura % |
| --- | --- | --- | --- | --- | --- | --- |
| [0.00,0.20) | 0 | 0 | — | — | — | — |
| [0.20,0.30) | 0 | 0 | — | — | — | — |
| [0.30,0.40) | 8 | 5 | 50.00 | 12.50 | 0.00 | 37.50 |
| [0.40,0.50) | 24 | 22 | 37.50 | 54.17 | 12.50 | 8.33 |
| [0.50,0.60) | 30 | 27 | 63.33 | 26.67 | 16.67 | 10.00 |
| [0.60,0.70) | 32 | 27 | 31.25 | 53.12 | 18.75 | 15.62 |
| [0.70,0.80) | 38 | 36 | 42.11 | 52.63 | 26.32 | 5.26 |
| [0.80,1.00] | 20 | 20 | 45.00 | 55.00 | 20.00 | 0.00 |


MFE/MAE en pips, normalización en veces Asia y tiempo en minutos. N de estas métricas = `N primer breakout` de la tabla anterior.

| Grupo | MFE media | MFE mediana | MAE media | MAE mediana | MFE/Asia media | MFE/Asia mediana | Min hasta ruptura P50 | Retorno cierto % |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [0.00,0.20) | — | — | — | — | — | — | — | — |
| [0.20,0.30) | — | — | — | — | — | — | — | — |
| [0.30,0.40) | 46.46 | 43.00 | 13.82 | 5.40 | 0.64 | 0.74 | 77.00 | 100.00 |
| [0.40,0.50) | 31.20 | 16.65 | 16.90 | 17.00 | 0.86 | 0.35 | 83.00 | 95.45 |
| [0.50,0.60) | 15.06 | 11.40 | 26.09 | 20.90 | 0.35 | 0.22 | 125.00 | 92.59 |
| [0.60,0.70) | 23.82 | 15.50 | 22.38 | 21.20 | 0.63 | 0.40 | 98.00 | 100.00 |
| [0.70,0.80) | 23.21 | 16.80 | 23.55 | 15.75 | 0.76 | 0.67 | 77.00 | 88.89 |
| [0.80,1.00] | 25.84 | 20.55 | 19.66 | 18.50 | 0.92 | 0.65 | 62.00 | 100.00 |


**No hay relación monotónica que favorezca una compresión más baja.** Las medianas de MFE para los buckets con datos son 43.0, 16.65, 11.4, 15.5, 16.8 y 20.55 pips; la primera procede de apenas **5 rupturas entre 8 setups**. La mediana normalizada tampoco decrece de manera ordenada al aumentar el ratio.

| Y | N | rho | p | p Holm |
| --- | --- | --- | --- | --- |
| FirstBreakMFE_Pips | 137 | 0.07 | 0.4009 | 1.0000 |
| norm | 137 | 0.19 | 0.0226 | 0.5650 |
| FirstBreakMAE_Pips | 137 | 0.08 | 0.3791 | 1.0000 |
| NYRangePips | 152 | 0.03 | 0.7251 | 1.0000 |
| NYRangeToAsiaRange | 152 | 0.38 | 0.0001 | 0.0038 |
| HIGH first conditional | 137 | -0.11 | 0.2190 | 1.0000 |


La relación con NYRange/Asia es **positiva**, consistente en ambos tramos temporales. Eso va contra la forma más simple de la hipótesis. Además, CompressionRatio y NYRange/Asia comparten denominador: una correlación entre ratios no prueba un mecanismo de compresión/expansión. La relación con MFE en pips es prácticamente nula. La correlación MFE/Asia positiva de 0.194 deja de ser significativa al corregir múltiples pruebas.

Un filtro amplio <0.50 contiene **32 setups / 27 rupturas**, media MFE **34.03 pips y mediana 18.0**; se conserva solo como hipótesis exploratoria. No se convierte retrospectivamente el bucket 0.30–0.40, con N=8, en un umbral óptimo. No existen observaciones <0.30 con NY completo.

## 11. LondonMidPosition

Baseline sobre 152 setups: High first=44.08%, Low first=46.05%. Las diferencias siguientes son puntos porcentuales frente a esos baselines y **mantienen sin ruptura en el denominador**.

| Grupo | N | High% | ΔHigh pp | IC95 High% | Low% | ΔLow pp | IC95 Low% | Both% | No% |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [0.00,0.20) | 0 | — | — | — | — | — | — | — | — |
| [0.20,0.40) | 34 | 20.59 | -23.49 | 10.35–36.80 | 67.65 | 21.59 | 50.84–80.87 | 17.65 | 11.76 |
| [0.40,0.60) | 87 | 43.68 | -0.40 | 33.74–54.15 | 45.98 | -0.08 | 35.90–56.40 | 18.39 | 10.34 |
| [0.60,0.80) | 29 | 68.97 | 24.89 | 50.77–82.72 | 24.14 | -21.91 | 12.22–42.11 | 20.69 | 6.90 |
| [0.80,1.00] | 2 | 100.00 | 55.92 | 34.24–100.00 | 0.00 | -46.05 | 0.00–65.76 | 0.00 | 0.00 |


| Grupo | MFE media | MFE mediana | MAE media | MAE mediana | MFE/Asia media | MFE/Asia mediana | Min hasta ruptura P50 | Retorno cierto % |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [0.00,0.20) | — | — | — | — | — | — | — | — |
| [0.20,0.40) | 25.93 | 14.80 | 19.57 | 12.70 | 0.61 | 0.38 | 85.50 | 96.67 |
| [0.40,0.60) | 24.49 | 18.45 | 22.90 | 21.15 | 0.79 | 0.62 | 79.50 | 94.87 |
| [0.60,0.80) | 18.61 | 11.40 | 22.61 | 15.10 | 0.47 | 0.34 | 111.00 | 92.59 |
| [0.80,1.00] | 65.20 | 65.20 | 3.30 | 3.30 | 0.90 | 0.90 | 45.50 | 100.00 |


Londres bajo [0.20,0.40): Low first **23/34=67.65%**, +21.59 pp; Londres alto [0.60,0.80): High first **20/29=68.97%**, +24.89 pp. Ambos son exploratorios por tamaño. El 100% del bucket superior corresponde a **2 casos** y se descarta como evidencia operable.

La regla simple «mitad superior→High; mitad inferior→Low» acierta **87/137=63.50%** entre rupturas, IC95% 55.18%–71.09%, +12.41 pp frente al lado global más frecuente. Spearman con High primero: **0.338**, p por permutación≤0.0001, Holm=0.0038. La asociación existe, pero es menor que la del precio de las 08:00.

El centro de Londres no puede tomar cualquier posición dada una compresión: para un rango contenido, su posición queda entre CompressionRatio/2 y 1−CompressionRatio/2. Parte de la concentración central es geometría, y posición/compresión no son variables independientes. No se ha demostrado información incremental de LondonMidPosition una vez conocido el precio de las 08:00; añadir ambos filtros sin validación penaliza complejidad.

## 12. Price0800Position

| Grupo | N | High% | ΔHigh pp | IC95 High% | Low% | ΔLow pp | IC95 Low% | Both% | No% |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [0.00,0.20) | 17 | 11.76 | -32.31 | 3.29–34.34 | 82.35 | 36.30 | 58.97–93.81 | 11.76 | 5.88 |
| [0.20,0.40) | 36 | 13.89 | -30.19 | 6.08–28.66 | 75.00 | 28.95 | 58.93–86.25 | 25.00 | 11.11 |
| [0.40,0.60) | 48 | 50.00 | 5.92 | 36.39–63.61 | 37.50 | -8.55 | 25.22–51.64 | 14.58 | 12.50 |
| [0.60,0.80) | 35 | 65.71 | 21.64 | 49.15–79.17 | 25.71 | -20.34 | 14.16–42.07 | 11.43 | 8.57 |
| [0.80,1.00] | 16 | 81.25 | 37.17 | 56.99–93.41 | 12.50 | -33.55 | 3.50–36.02 | 37.50 | 6.25 |
| BELOW_ASIA | 0 | — | — | — | — | — | — | — | — |
| ABOVE_ASIA | 0 | — | — | — | — | — | — | — | — |


| Grupo | MFE media | MFE mediana | MAE media | MAE mediana | MFE/Asia media | MFE/Asia mediana | Min hasta ruptura P50 | Retorno cierto % |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [0.00,0.20) | 17.61 | 11.65 | 20.11 | 21.25 | 0.46 | 0.37 | 50.00 | 100.00 |
| [0.20,0.40) | 31.57 | 21.05 | 21.22 | 16.70 | 0.91 | 0.58 | 79.50 | 96.88 |
| [0.40,0.60) | 26.47 | 19.60 | 20.97 | 13.50 | 0.80 | 0.66 | 94.50 | 88.10 |
| [0.60,0.80) | 20.05 | 16.90 | 18.84 | 15.00 | 0.59 | 0.45 | 94.50 | 96.88 |
| [0.80,1.00] | 18.39 | 11.30 | 33.73 | 33.40 | 0.37 | 0.39 | 4.00 | 100.00 |
| BELOW_ASIA | — | — | — | — | — | — | — | — |
| ABOVE_ASIA | — | — | — | — | — | — | — | — |


Precio 0.00–0.20: Low first **14/17=82.35%**, +36.30 pp frente al baseline de todos los setups. Precio 0.80–1.00: High first **13/16=81.25%**, +37.17 pp. **Ambas muestras N<20 son muy poco confiables para calibrar un porcentaje preciso.** Condicionando a que haya breakout: 14/16=87.50% Low en el extremo inferior y 13/15=86.67% High en el superior. No se deben mezclar estos porcentajes con los de la tabla.

La asociación no depende solo de extremos pequeños: la regla de la mitad del rango reúne **137 rupturas**, acierta 101 (73.72%, IC95% 65.78%–80.37%) y mejora **22.63 pp** al baseline Low=51.09%. En los 152 días completos hay 101 aciertos, 36 primeros lados contrarios y 15 sin ruptura: 66.45% de todos los días producen el primer lado previsto. Los últimos no equivalen a trades perdedores si la entrada requiere breakout.

Spearman precio→High first **0.529**, p por permutación≤0.0001, Holm=0.0038. La comparación exacta de los dos extremos entre rupturas tiene Fisher p≈0.000049, pero sus tamaños siguen siendo reducidos. El test confirma asociación, no precisión del 80% futuro.

**Contraargumento esencial:** el extremo cercano requiere menos recorrido. En un modelo ideal sin deriva y sin límite de tiempo, la probabilidad de llegar al máximo antes que al mínimo es proporcional a la posición inicial. Como diagnóstico ilustrativo, usar p(High)=posición ofrece Brier=**0.181**, frente a **0.250** de una probabilidad constante estimada en el tramo inicial. El acierto esperado del extremo cercano bajo ese modelo sería aproximadamente **69.59%**, bastante próximo al 73.72% observado. Ese modelo no está validado para FX ni para la ventana finita; se usa para mostrar que un alto porcentaje puede surgir de la geometría **sin alpha de continuación**.

Los extremos no ofrecen mayor MFE: medianas de 11.65 y 11.30 pips, frente a 16.0 global. En el extremo alto, MAE media=33.73 pips frente a MFE media=18.39. La posición predice principalmente **qué barrera se toca primero**, no una expansión mayor después de tocarla.

## 13. Compression × Price0800Position

Se revisaron las **56 celdas básicas** y las dos combinaciones especiales del CSV. Las dos especiales (compresión<0.30 con precio>0.80 o <0.20) están vacías. Se muestran todas las celdas no vacías; las omitidas tienen N=0.

| Comp | Price | N | breaks | High% | Low% | Both% | No% | ΔHigh pp | ΔLow pp |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| [0.30,0.40) | [0.00,0.20) | 1 | 1 | 0.00 | 100.00 | 0.00 | 0.00 | -44.08 | 53.95 |
| [0.30,0.40) | [0.20,0.40) | 3 | 1 | 33.33 | 0.00 | 0.00 | 66.67 | -10.75 | -46.05 |
| [0.30,0.40) | [0.40,0.60) | 1 | 1 | 100.00 | 0.00 | 0.00 | 0.00 | 55.92 | -46.05 |
| [0.30,0.40) | [0.60,0.80) | 1 | 0 | 0.00 | 0.00 | 0.00 | 100.00 | -44.08 | -46.05 |
| [0.30,0.40) | [0.80,1.00] | 2 | 2 | 100.00 | 0.00 | 0.00 | 0.00 | 55.92 | -46.05 |
| [0.40,0.50) | [0.00,0.20) | 6 | 6 | 16.67 | 83.33 | 0.00 | 0.00 | -27.41 | 37.28 |
| [0.40,0.50) | [0.20,0.40) | 7 | 7 | 28.57 | 71.43 | 28.57 | 0.00 | -15.51 | 25.38 |
| [0.40,0.50) | [0.40,0.60) | 6 | 5 | 33.33 | 50.00 | 0.00 | 16.67 | -10.75 | 3.95 |
| [0.40,0.50) | [0.60,0.80) | 4 | 3 | 75.00 | 0.00 | 25.00 | 25.00 | 30.92 | -46.05 |
| [0.40,0.50) | [0.80,1.00] | 1 | 1 | 100.00 | 0.00 | 0.00 | 0.00 | 55.92 | -46.05 |
| [0.50,0.60) | [0.20,0.40) | 5 | 5 | 0.00 | 100.00 | 20.00 | 0.00 | -44.08 | 53.95 |
| [0.50,0.60) | [0.40,0.60) | 11 | 9 | 72.73 | 9.09 | 18.18 | 18.18 | 28.65 | -36.96 |
| [0.50,0.60) | [0.60,0.80) | 8 | 7 | 75.00 | 12.50 | 0.00 | 12.50 | 30.92 | -33.55 |
| [0.50,0.60) | [0.80,1.00] | 6 | 6 | 83.33 | 16.67 | 33.33 | 0.00 | 39.25 | -29.39 |
| [0.60,0.70) | [0.00,0.20) | 5 | 4 | 20.00 | 60.00 | 40.00 | 20.00 | -24.08 | 13.95 |
| [0.60,0.70) | [0.20,0.40) | 9 | 7 | 0.00 | 77.78 | 22.22 | 22.22 | -44.08 | 31.73 |
| [0.60,0.70) | [0.40,0.60) | 13 | 11 | 38.46 | 46.15 | 7.69 | 15.38 | -5.62 | 0.10 |
| [0.60,0.70) | [0.60,0.80) | 4 | 4 | 75.00 | 25.00 | 0.00 | 0.00 | 30.92 | -21.05 |
| [0.60,0.70) | [0.80,1.00] | 1 | 1 | 100.00 | 0.00 | 100.00 | 0.00 | 55.92 | -46.05 |
| [0.70,0.80) | [0.00,0.20) | 3 | 3 | 0.00 | 100.00 | 0.00 | 0.00 | -44.08 | 53.95 |
| [0.70,0.80) | [0.20,0.40) | 7 | 7 | 0.00 | 100.00 | 42.86 | 0.00 | -44.08 | 53.95 |
| [0.70,0.80) | [0.40,0.60) | 12 | 11 | 50.00 | 41.67 | 25.00 | 8.33 | 5.92 | -4.39 |
| [0.70,0.80) | [0.60,0.80) | 10 | 10 | 60.00 | 40.00 | 10.00 | 0.00 | 15.92 | -6.05 |
| [0.70,0.80) | [0.80,1.00] | 6 | 5 | 66.67 | 16.67 | 50.00 | 16.67 | 22.59 | -29.39 |
| [0.80,1.00] | [0.00,0.20) | 2 | 2 | 0.00 | 100.00 | 0.00 | 0.00 | -44.08 | 53.95 |
| [0.80,1.00] | [0.20,0.40) | 5 | 5 | 40.00 | 60.00 | 20.00 | 0.00 | -4.08 | 13.95 |
| [0.80,1.00] | [0.40,0.60) | 5 | 5 | 40.00 | 60.00 | 20.00 | 0.00 | -4.08 | 13.95 |
| [0.80,1.00] | [0.60,0.80) | 8 | 8 | 62.50 | 37.50 | 25.00 | 0.00 | 18.42 | -8.55 |


Magnitudes correspondientes, sin seleccionar únicamente celdas favorables:

| Comp | Price | N | MFE media | MFE mediana | MAE media | Norm media | Norm mediana |
| --- | --- | --- | --- | --- | --- | --- | --- |
| [0.30,0.40) | [0.00,0.20) | 1 | 10.00 | 10.00 | 12.10 | 0.09 | 0.09 |
| [0.30,0.40) | [0.20,0.40) | 3 | 59.00 | 59.00 | 45.00 | 0.53 | 0.53 |
| [0.30,0.40) | [0.40,0.60) | 1 | 32.90 | 32.90 | 5.40 | 0.78 | 0.78 |
| [0.30,0.40) | [0.60,0.80) | 1 | — | — | — | — | — |
| [0.30,0.40) | [0.80,1.00] | 2 | 65.20 | 65.20 | 3.30 | 0.90 | 0.90 |
| [0.40,0.50) | [0.00,0.20) | 6 | 16.57 | 10.50 | 19.48 | 0.31 | 0.28 |
| [0.40,0.50) | [0.20,0.40) | 7 | 42.50 | 23.50 | 17.21 | 1.25 | 0.73 |
| [0.40,0.50) | [0.40,0.60) | 6 | 48.28 | 18.60 | 10.70 | 1.41 | 0.21 |
| [0.40,0.50) | [0.60,0.80) | 4 | 14.17 | 18.00 | 15.80 | 0.41 | 0.55 |
| [0.40,0.50) | [0.80,1.00] | 1 | 5.70 | 5.70 | 33.40 | 0.09 | 0.09 |
| [0.50,0.60) | [0.20,0.40) | 5 | 21.22 | 14.50 | 19.20 | 0.54 | 0.34 |
| [0.50,0.60) | [0.40,0.60) | 11 | 15.40 | 5.90 | 31.60 | 0.37 | 0.16 |
| [0.50,0.60) | [0.60,0.80) | 8 | 12.99 | 11.40 | 17.56 | 0.26 | 0.20 |
| [0.50,0.60) | [0.80,1.00] | 6 | 11.85 | 10.15 | 33.50 | 0.26 | 0.16 |
| [0.60,0.70) | [0.00,0.20) | 5 | 16.55 | 13.60 | 30.88 | 0.45 | 0.43 |
| [0.60,0.70) | [0.20,0.40) | 9 | 42.21 | 38.30 | 21.81 | 1.11 | 0.86 |
| [0.60,0.70) | [0.40,0.60) | 13 | 19.52 | 11.30 | 22.23 | 0.52 | 0.26 |
| [0.60,0.70) | [0.60,0.80) | 4 | 14.48 | 13.15 | 15.32 | 0.34 | 0.41 |
| [0.60,0.70) | [0.80,1.00] | 1 | 8.90 | 8.90 | 22.30 | 0.42 | 0.42 |
| [0.70,0.80) | [0.00,0.20) | 3 | 28.87 | 27.40 | 10.20 | 0.94 | 0.97 |
| [0.70,0.80) | [0.20,0.40) | 7 | 13.11 | 10.50 | 24.74 | 0.65 | 0.63 |
| [0.70,0.80) | [0.40,0.60) | 12 | 32.15 | 29.50 | 19.49 | 1.02 | 0.79 |
| [0.70,0.80) | [0.60,0.80) | 10 | 24.36 | 16.20 | 18.70 | 0.71 | 0.54 |
| [0.70,0.80) | [0.80,1.00] | 6 | 11.96 | 11.30 | 48.54 | 0.34 | 0.39 |
| [0.80,1.00] | [0.00,0.20) | 2 | 9.75 | 9.75 | 19.30 | 0.39 | 0.39 |
| [0.80,1.00] | [0.20,0.40) | 5 | 32.06 | 22.00 | 18.30 | 0.95 | 0.51 |
| [0.80,1.00] | [0.40,0.60) | 5 | 26.08 | 21.20 | 15.74 | 1.07 | 0.72 |
| [0.80,1.00] | [0.60,0.80) | 8 | 25.84 | 20.20 | 23.04 | 0.93 | 0.79 |


**Ninguna celda alcanza N=20. La mayor tiene N=13.** En consecuencia, ninguna combinación merece la categoría de evidencia razonable ni se recomienda como regla de entrada. Un 100% con 2, 3, 5 o 7 observaciones no supera ese problema.

La conjunción amplia compresión<0.50 + precio extremo (<0.20 o ≥0.80) tiene **10 rupturas**, 9 con primer lado cercano correcto: 90%, IC95% **59.58%–98.21%**. Frente a usar solo los extremos, N baja de 31 a 10 y el acierto pasa de 87.10% a 90.00%: +2.90 pp con una incertidumbre enorme. Se descarta como mejora demostrada. La versión más simple conserva más evidencia y evita un filtro que no aporta valor probado.

## 14. Hora del breakout

Intervalos de apertura M1 en UTC−3, límite izquierdo inclusivo. Frecuencia sobre **137 días con primer breakout**; los 15 sin ruptura no pueden asignarse a un horario.

| Grupo | N | Frecuencia% | MFE media | MFE mediana | MAE media | Fake mínimo% | Both% | Norm media | Norm mediana |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 08:00–08:30 | 29 | 21.17 | 22.37 | 13.10 | 27.99 | 96.55 | 31.03 | 0.64 | 0.44 |
| 08:30–09:00 | 21 | 15.33 | 34.86 | 24.60 | 19.28 | 100.00 | 33.33 | 1.11 | 0.68 |
| 09:00–09:30 | 20 | 14.60 | 27.12 | 19.85 | 21.79 | 100.00 | 20.00 | 0.74 | 0.71 |
| 09:30–10:00 | 20 | 14.60 | 24.47 | 13.80 | 27.76 | 90.00 | 25.00 | 0.82 | 0.44 |
| 10:00–11:00 | 23 | 16.79 | 21.83 | 14.90 | 20.43 | 91.30 | 13.04 | 0.59 | 0.34 |
| 11:00–12:00 | 20 | 14.60 | 17.90 | 15.20 | 13.73 | 90.00 | 0.00 | 0.36 | 0.27 |
| 12:00–14:00 | 4 | 2.92 | 12.10 | 6.15 | 9.50 | 100.00 | 0.00 | 0.16 | 0.12 |


El bloque 08:30–09:00 parece mejor por MFE, pero contiene **21 casos** y no constituye un filtro validado. El bloque 12:00–14:00 tiene **4**, totalmente insuficiente. El 51.09% de los breakouts ocurre antes de las 09:30 (70/137); la mediana del primer breakout es **09:26**.

Spearman tiempo→MFE pips=**−0.128**, p=0.133; tiempo→MFE/Asia=−0.238, p=0.0066 y Holm=0.191. Las rupturas tardías tienen menos horizonte para expandirse **y** retroceder: la caída del MAE no las convierte automáticamente en mejores entradas. BothSides cae desde 31%–33% en las dos primeras franjas a 0% a partir de las 11:00, pero la ventana restante y N explican parte de esa diferencia. No se selecciona una hora óptima retrospectiva.

## 15. Tiempo hasta MFE

| Serie | N | P50 | P75 | P90 | P95 | Máximo |
| --- | --- | --- | --- | --- | --- | --- |
| MinutesToMFE | 137 | 75.00 | 162.00 | 248.40 | 278.80 | 309.00 |
| HighBreakMinutesToMFE | 81 | 63.00 | 142.00 | 225.00 | 244.00 | 295.00 |
| LowBreakMinutesToMFE | 84 | 74.50 | 164.25 | 257.10 | 277.25 | 309.00 |


Tiempos medidos **desde la ruptura de cada lado**, no desde las 08:00. Primer breakout: P50=75 min, P75=162, P90=248.4 y P95=278.8. El script retiene el primer instante si un extremo máximo se repite; una MFE en la vela inicial se registra en 0 minutos.

Estos tiempos están censurados por el final fijo de NY: un breakout a las 13:00 solo puede tener 60 minutos de observación. No basta tomar P90 y fijar un cierre a ese tiempo, ni sumar la mediana del breakout a la mediana de MinutesToMFE para obtener un percentil conjunto. Los datos sugieren comparar cierres prefijados en la siguiente fase, pero no permiten cuantificar el coste de oportunidad o el PnL de cada cierre sin precios de salida.

## 16. Volatilidad

Buckets del exportador, prefijados en pips; no se buscaron umbrales óptimos. N es el número de setups; `breaks` es el denominador de MFE/MAE. ATR/ADR disponen de 150 setups y 135 rupturas con dato.

| Variable | Grupo | N | breaks | MFE media | MFE mediana | MAE media | Norm media | Norm mediana | Both% | No% |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| AsiaRangePips | [0,20) | 8 | 8 | 17.29 | 13.35 | 11.02 | 1.03 | 0.84 | 25.00 | 0.00 |
| AsiaRangePips | [20,40) | 73 | 69 | 23.31 | 15.50 | 22.92 | 0.80 | 0.50 | 28.77 | 5.48 |
| AsiaRangePips | [40,60) | 46 | 40 | 28.20 | 21.15 | 20.34 | 0.62 | 0.47 | 8.70 | 13.04 |
| AsiaRangePips | [60,80) | 13 | 12 | 17.54 | 12.50 | 26.89 | 0.26 | 0.19 | 7.69 | 7.69 |
| AsiaRangePips | [80,100) | 6 | 5 | 32.34 | 19.50 | 10.18 | 0.38 | 0.23 | 0.00 | 16.67 |
| AsiaRangePips | [100,+inf) | 6 | 3 | 24.83 | 10.00 | 44.47 | 0.22 | 0.09 | 0.00 | 50.00 |
| ATR14Pips | [0,20) | 0 | 0 | — | — | — | — | — | — | — |
| ATR14Pips | [20,40) | 0 | 0 | — | — | — | — | — | — | — |
| ATR14Pips | [40,60) | 36 | 31 | 12.49 | 10.70 | 17.93 | 0.47 | 0.40 | 27.78 | 13.89 |
| ATR14Pips | [60,80) | 45 | 40 | 26.87 | 20.45 | 19.24 | 0.87 | 0.61 | 13.33 | 11.11 |
| ATR14Pips | [80,100) | 47 | 45 | 33.10 | 23.30 | 23.02 | 0.86 | 0.61 | 19.15 | 4.26 |
| ATR14Pips | [100,+inf) | 22 | 19 | 17.38 | 13.10 | 29.63 | 0.28 | 0.21 | 9.09 | 13.64 |
| ADR20Pips | [0,20) | 0 | 0 | — | — | — | — | — | — | — |
| ADR20Pips | [20,40) | 0 | 0 | — | — | — | — | — | — | — |
| ADR20Pips | [40,60) | 34 | 29 | 12.77 | 10.70 | 17.98 | 0.47 | 0.40 | 26.47 | 14.71 |
| ADR20Pips | [60,80) | 52 | 46 | 24.08 | 20.40 | 19.27 | 0.78 | 0.56 | 15.38 | 11.54 |
| ADR20Pips | [80,100) | 44 | 43 | 32.43 | 17.70 | 25.17 | 0.84 | 0.42 | 18.18 | 2.27 |
| ADR20Pips | [100,+inf) | 20 | 17 | 24.05 | 17.60 | 25.52 | 0.45 | 0.39 | 10.00 | 15.00 |


**AsiaRange:** el grupo 20–40 pips tiene N=73 y 40–60 tiene N=46. El primero registra más ambos lados (28.77% vs 8.70%) y MFE mediana menor (15.5 vs 21.15 pips), pero son asociaciones descriptivas y dependientes del tamaño de la barrera. Asia<20 tiene solo 8 casos; no se puede afirmar que sea ruido. Asia≥100 tiene 6 casos y 50% sin ruptura, indicio geométricamente plausible pero muy débil, insuficiente para fijar un máximo.

AsiaRange se relaciona con NYRange absoluto (rho=**0.409**, N=152, Holm=0.0038), pero apenas con MFE posterior en pips (rho=0.060, N=137, p=0.488). Su correlación negativa con MFE/Asia (−0.278, Holm=0.0186) comparte el propio denominador; no prueba que una Asia pequeña cause más alpha.

**ATR/ADR:** la volatilidad media de 60–100 pips parece acompañar más MFE que 40–60 o ≥100, sin monotonicidad. ATR≥100 presenta MFE media 17.38 y MAE media 29.63 pips (N=22 setups/19 rupturas), extremo negativo a investigar, no exclusión operativa validada.

ATR y ADR predicen principalmente **rango NY absoluto**: rho=0.496 y 0.481, N=150, Holm=0.0038 en ambos. Frente a MFE pips, rho=0.141 y 0.143, p≈0.10, sin evidencia suficiente. Estos indicadores están altamente relacionados conceptualmente y su cobertura es parcial; no se cuentan como dos confirmaciones independientes ni se propone combinarlos en múltiples filtros.

## 17. Día de semana

| Grupo | N | breaks | High% | Low% | MFE media | MFE mediana | MAE media | Fake mínimo% | Both% | Norm media | Norm mediana |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Lunes | 36 | 32 | 41.67 | 47.22 | 22.36 | 17.85 | 17.38 | 90.62 | 16.67 | 0.55 | 0.54 |
| Martes | 30 | 28 | 43.33 | 50.00 | 19.52 | 12.20 | 22.77 | 100.00 | 23.33 | 0.51 | 0.35 |
| Miércoles | 33 | 30 | 42.42 | 48.48 | 26.30 | 19.25 | 22.39 | 90.00 | 18.18 | 0.76 | 0.56 |
| Jueves | 31 | 29 | 38.71 | 54.84 | 30.63 | 19.00 | 22.59 | 96.55 | 16.13 | 0.94 | 0.68 |
| Viernes | 22 | 18 | 59.09 | 22.73 | 21.20 | 9.70 | 26.10 | 100.00 | 18.18 | 0.68 | 0.28 |


Todos los grupos son exploratorios (N=22–36). Jueves presenta la mayor MFE media, pero no hay evidencia estadística suficiente para convertirlo en filtro. Pruebas ómnibus por permutación (9,999), con rangos para magnitudes: p=**0.154** MFE, **0.151** MAE, **0.183** MFE/Asia, **0.312** dirección y **0.962** ambos lados. Ninguna pasa siquiera el nivel nominal 5%; corregir multiplicidad debilitaría más la evidencia. La frecuencia de retorno es alta toda la semana.

## 18. Análisis de R / expectativa

### Definiciones y límites de identificación

Se analizaron los **42 escenarios por día** disponibles (2 lados×3 modelos×7 objetivos) y, adicionalmente, la política conceptual de tomar **solo la primera ruptura**, 21 combinaciones. No se cuenta cada escenario como un trade independiente.

- **A:** SL=LondonRange; riesgo mediano del primer breakout 23.20 pips.
- **B:** SL=0.50×AsiaRange; riesgo mediano 18.15 pips.
- **C:** SL desde la barrera de entrada al extremo contrario de Londres; riesgo mediano 28.60 pips.
- TP: 0.5R, 1R, 1.5R, 2R, 2.5R, 3R, 4R. Winrates de equilibrio sin costes: 66.67%, 50%, 40%, 33.33%, 28.57%, 25%, 20% respectivamente.

`W`=HIT_BEFORE_SL, `L`=SL_FIRST, `U`=NOT_REACHED y `Amb`=AMBIGUOUS. **NOT_REACHED no significa pérdida de −1R**: ni TP ni SL se resolvieron dentro de NY. No se exporta el precio de cierre a las 14:00 ni el PnL al cierre. `AMBIGUOUS` no se reasigna a ganador/perdedor. Todos los primeros breakouts válidos tienen riesgo positivo y sin NA_GAP; High/Low también tienen cero gaps señalados.

Se calcula el winrate únicamente entre W+L y `E decididos=(W×RR−L)/(W+L)`. Es una expectativa **condicional a resolverse**, potencialmente sesgada por excluir U/Amb, y nunca se presenta como expectativa de la estrategia completa.

Para todos los N trades se proporcionan cotas de expectativa media **bajo fills ideales y salida pendiente a las 14:00**. En W y L se usan +RR y −1. En Amb se usa [−1,+RR]. En U se usa el intervalo conservador **[−min(1,MAE/R), +min(RR,MFE/R)]**. Así no se concede a una operación sin TP una ganancia que su MFE ni siquiera alcanzó. Son cotas de identificación con OHLC, no intervalos de confianza ni una simulación de ejecución real. No incorporan deslizamientos posteriores ni spread.

### Primera ruptura: 21 combinaciones

| Modelo | TP | N | W | L | U | Amb | WR decididos% | E decididos | E MFE/MAE mín | E MFE/MAE máx |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A | 0_5R | 137 | 74 | 32 | 27 | 4 | 69.81 | 0.047 | -0.107 | 0.105 |
| A | 1R | 137 | 46 | 45 | 44 | 2 | 50.55 | 0.011 | -0.186 | 0.168 |
| A | 1_5R | 137 | 27 | 47 | 61 | 2 | 36.49 | -0.088 | -0.276 | 0.272 |
| A | 2R | 137 | 16 | 48 | 71 | 2 | 25.00 | -0.250 | -0.372 | 0.332 |
| A | 2_5R | 137 | 10 | 48 | 77 | 2 | 17.24 | -0.397 | -0.436 | 0.384 |
| A | 3R | 137 | 5 | 48 | 82 | 2 | 9.43 | -0.623 | -0.521 | 0.425 |
| A | 4R | 137 | 2 | 48 | 85 | 2 | 4.00 | -0.800 | -0.579 | 0.467 |
| B | 0_5R | 137 | 74 | 40 | 17 | 6 | 64.91 | -0.026 | -0.132 | 0.032 |
| B | 1R | 137 | 49 | 58 | 26 | 4 | 45.79 | -0.084 | -0.197 | 0.042 |
| B | 1_5R | 137 | 31 | 60 | 42 | 4 | 34.07 | -0.148 | -0.272 | 0.175 |
| B | 2R | 137 | 22 | 62 | 50 | 3 | 26.19 | -0.214 | -0.314 | 0.243 |
| B | 2_5R | 137 | 12 | 63 | 59 | 3 | 16.00 | -0.440 | -0.453 | 0.293 |
| B | 3R | 137 | 9 | 64 | 61 | 3 | 12.33 | -0.507 | -0.484 | 0.316 |
| B | 4R | 137 | 4 | 64 | 66 | 3 | 5.88 | -0.706 | -0.575 | 0.382 |
| C | 0_5R | 137 | 73 | 26 | 36 | 2 | 73.74 | 0.106 | -0.072 | 0.146 |
| C | 1R | 137 | 41 | 37 | 58 | 1 | 52.56 | 0.051 | -0.191 | 0.219 |
| C | 1_5R | 137 | 21 | 38 | 77 | 1 | 35.59 | -0.110 | -0.303 | 0.316 |
| C | 2R | 137 | 13 | 39 | 84 | 1 | 25.00 | -0.250 | -0.360 | 0.362 |
| C | 2_5R | 137 | 9 | 39 | 88 | 1 | 18.75 | -0.344 | -0.394 | 0.405 |
| C | 3R | 137 | 6 | 39 | 91 | 1 | 13.33 | -0.467 | -0.434 | 0.437 |
| C | 4R | 137 | 2 | 39 | 95 | 1 | 4.88 | -0.756 | -0.515 | 0.471 |


### Lado High: todas sus rupturas, incluidas las segundas

| Modelo | TP | N | W | L | U | Amb | WR decididos% | E decididos | E MFE/MAE mín | E MFE/MAE máx |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A | 0_5R | 81 | 40 | 23 | 16 | 2 | 63.49 | -0.048 | -0.180 | 0.027 |
| A | 1R | 81 | 21 | 32 | 27 | 1 | 39.62 | -0.208 | -0.347 | 0.033 |
| A | 1_5R | 81 | 12 | 33 | 35 | 1 | 26.67 | -0.333 | -0.419 | 0.107 |
| A | 2R | 81 | 8 | 33 | 39 | 1 | 19.51 | -0.415 | -0.469 | 0.169 |
| A | 2_5R | 81 | 4 | 33 | 43 | 1 | 10.81 | -0.622 | -0.561 | 0.207 |
| A | 3R | 81 | 3 | 33 | 44 | 1 | 8.33 | -0.667 | -0.576 | 0.237 |
| A | 4R | 81 | 0 | 33 | 47 | 1 | 0.00 | -1.000 | -0.700 | 0.272 |
| B | 0_5R | 81 | 38 | 29 | 11 | 3 | 56.72 | -0.149 | -0.236 | -0.067 |
| B | 1R | 81 | 24 | 40 | 15 | 2 | 37.50 | -0.250 | -0.335 | -0.095 |
| B | 1_5R | 81 | 12 | 42 | 25 | 2 | 22.22 | -0.444 | -0.481 | -0.027 |
| B | 2R | 81 | 7 | 42 | 30 | 2 | 14.29 | -0.571 | -0.549 | 0.038 |
| B | 2_5R | 81 | 3 | 42 | 34 | 2 | 6.67 | -0.767 | -0.652 | 0.078 |
| B | 3R | 81 | 3 | 42 | 34 | 2 | 6.67 | -0.733 | -0.634 | 0.109 |
| B | 4R | 81 | 1 | 42 | 36 | 2 | 2.33 | -0.884 | -0.702 | 0.150 |
| C | 0_5R | 81 | 39 | 20 | 22 | 0 | 66.10 | -0.008 | -0.155 | 0.059 |
| C | 1R | 81 | 18 | 25 | 38 | 0 | 41.86 | -0.163 | -0.328 | 0.123 |
| C | 1_5R | 81 | 9 | 25 | 47 | 0 | 26.47 | -0.338 | -0.416 | 0.205 |
| C | 2R | 81 | 7 | 25 | 49 | 0 | 21.88 | -0.344 | -0.413 | 0.257 |
| C | 2_5R | 81 | 5 | 25 | 51 | 0 | 16.67 | -0.417 | -0.443 | 0.291 |
| C | 3R | 81 | 4 | 25 | 52 | 0 | 13.79 | -0.448 | -0.451 | 0.319 |
| C | 4R | 81 | 2 | 25 | 54 | 0 | 7.41 | -0.630 | -0.510 | 0.349 |


### Lado Low: todas sus rupturas, incluidas las segundas

| Modelo | TP | N | W | L | U | Amb | WR decididos% | E decididos | E MFE/MAE mín | E MFE/MAE máx |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A | 0_5R | 84 | 48 | 14 | 20 | 2 | 77.42 | 0.161 | -0.025 | 0.194 |
| A | 1R | 84 | 31 | 21 | 31 | 1 | 59.62 | 0.192 | -0.072 | 0.284 |
| A | 1_5R | 84 | 17 | 22 | 44 | 1 | 43.59 | 0.090 | -0.202 | 0.401 |
| A | 2R | 84 | 9 | 23 | 51 | 1 | 28.12 | -0.156 | -0.324 | 0.450 |
| A | 2_5R | 84 | 7 | 23 | 53 | 1 | 23.33 | -0.183 | -0.333 | 0.503 |
| A | 3R | 84 | 3 | 23 | 57 | 1 | 11.54 | -0.538 | -0.452 | 0.547 |
| A | 4R | 84 | 2 | 23 | 58 | 1 | 8.00 | -0.600 | -0.468 | 0.588 |
| B | 0_5R | 84 | 50 | 18 | 13 | 3 | 73.53 | 0.103 | -0.026 | 0.136 |
| B | 1R | 84 | 32 | 28 | 22 | 2 | 53.33 | 0.067 | -0.098 | 0.185 |
| B | 1_5R | 84 | 23 | 29 | 30 | 2 | 44.23 | 0.106 | -0.115 | 0.344 |
| B | 2R | 84 | 18 | 31 | 34 | 1 | 36.73 | 0.102 | -0.122 | 0.413 |
| B | 2_5R | 84 | 11 | 32 | 40 | 1 | 25.58 | -0.105 | -0.269 | 0.467 |
| B | 3R | 84 | 7 | 33 | 43 | 1 | 17.50 | -0.300 | -0.365 | 0.486 |
| B | 4R | 84 | 4 | 33 | 46 | 1 | 10.81 | -0.459 | -0.436 | 0.566 |
| C | 0_5R | 84 | 45 | 9 | 28 | 2 | 83.33 | 0.250 | -0.011 | 0.251 |
| C | 1R | 84 | 26 | 16 | 41 | 1 | 61.90 | 0.238 | -0.121 | 0.326 |
| C | 1_5R | 84 | 14 | 17 | 52 | 1 | 45.16 | 0.129 | -0.223 | 0.420 |
| C | 2R | 84 | 7 | 18 | 58 | 1 | 28.00 | -0.160 | -0.334 | 0.452 |
| C | 2_5R | 84 | 4 | 18 | 61 | 1 | 18.18 | -0.364 | -0.386 | 0.490 |
| C | 3R | 84 | 2 | 18 | 63 | 1 | 10.00 | -0.600 | -0.444 | 0.515 |
| C | 4R | 84 | 0 | 18 | 65 | 1 | 0.00 | -1.000 | -0.520 | 0.541 |


Las tablas por lado son políticas distintas de tomar el primer breakout. No deben combinarse como 165 operaciones independientes sin definir cancelación de órdenes, segunda entrada y riesgo simultáneo.

### Qué aparenta ser positivo y por qué no demuestra edge

En la primera ruptura, C con TP=0.5R muestra **73 W / 26 L**, winrate entre resueltos 73.74% y E decididos **+0.106R**, pero tiene **36 U + 2 Amb**: 38/137 resultados incompletamente identificados. A 0.5R muestra +0.047R entre resueltos y A 1R +0.011R; esas cifras pequeñas no establecen ventaja total.

Low C 0.5R presenta **45 W / 9 L / 28 U / 2 Amb**, 83.33% entre resueltos y +0.250R condicional. Es uno de muchos escenarios inspeccionados, con solo 54 resultados decididos, y su cota inferior completa sigue negativa. Debe considerarse exploratorio, no una estrategia corta validada.

No hay una configuración base con cota inferior positiva en el histórico completo. Que una cota superior sea positiva **solo significa que no se puede descartar** una expectativa positiva con la información faltante. No es evidencia a favor.

### Costes, drawdown y rachas

Un coste hipotético total de **1 pip por operación**, expresado como media de 1/SL, resta aproximadamente **0.0459R en A, 0.0584R en B y 0.0382R en C**; 2 pips restarían el doble. Es una sensibilidad aritmética, no una estimación del spread real. La aplicación correcta también cambia entradas/salidas y algunas clasificaciones. El ejemplo de +0.047R de A 0.5R es del mismo orden que un pip de fricción.

La secuencia del modelo B 0.5R, fijado desde el tramo inicial, tiene **4 pérdidas SL consecutivas comprobadas** y como máximo 4 pérdidas consecutivas aun si los casos no decididos resultaran negativos. Para la suma de R por operación, las trayectorias extremas compatibles con las cotas amplias generan drawdowns de **7–32R**; las cotas afinadas por MFE/MAE dan **9.01–24.10R**. **No son drawdowns realizados ni una predicción:** son un intervalo matemático bajo resultados ideales y gestión de riesgo constante por trade. El drawdown exacto, el drawdown monetario, el porcentaje de cuenta y la curva real no pueden reconstruirse con estos CSV.

La documentación de MetaTrader distingue los cuatro precios M1 de los ticks reales; los OHLC no certifican la trayectoria intrabar: [MetaTrader 5, ticks reales y generados](https://www.metatrader5.com/en/terminal/help/algotrading/tick_generation). Los estados inequívocos se pueden estudiar, pero completar los ambiguos exige mayor granularidad.

## 19. Estabilidad anual

### Comportamiento del mercado

| Grupo | N | breaks | High% | Low% | MFE media | MFE mediana | MAE media | Norm media | Norm mediana | Both% |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2020 | 22 | 17 | 59.09 | 18.18 | 25.41 | 20.30 | 22.75 | 0.52 | 0.43 | 13.64 |
| 2021 | 14 | 13 | 21.43 | 71.43 | 15.05 | 9.40 | 25.02 | 0.51 | 0.31 | 42.86 |
| 2022 | 18 | 16 | 38.89 | 50.00 | 29.25 | 16.75 | 22.95 | 0.70 | 0.35 | 16.67 |
| 2023 | 17 | 17 | 47.06 | 52.94 | 38.65 | 37.60 | 16.46 | 1.28 | 0.89 | 0.00 |
| 2024 | 15 | 15 | 60.00 | 40.00 | 14.90 | 11.30 | 13.37 | 0.65 | 0.44 | 20.00 |
| 2025 | 40 | 38 | 42.50 | 52.50 | 24.22 | 12.50 | 28.72 | 0.62 | 0.33 | 25.00 |
| 2026 | 26 | 21 | 38.46 | 42.31 | 20.22 | 14.20 | 16.17 | 0.60 | 0.46 | 11.54 |


2023 es particularmente favorable: MFE mediana 37.6 pips, MFE/Asia media 1.284 y ningún recorrido de ambos lados, pero solo **17 casos**. En 2025, con 38 rupturas, MFE mediana cae a 12.5 y MAE media sube a 28.72. Un relato construido principalmente sobre 2023 sería frágil.

### Configuración seleccionada exclusivamente en el tramo inicial: B, TP=0.5R

| Año | N | W | L | U | Amb | WR decididos% | E decididos | E MFE/MAE mín | E MFE/MAE máx |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2020 | 17 | 12 | 4 | 1 | 0 | 75.00 | 0.125 | 0.095 | 0.135 |
| 2021 | 13 | 7 | 5 | 1 | 0 | 58.33 | -0.125 | -0.176 | -0.094 |
| 2022 | 16 | 7 | 6 | 3 | 0 | 53.85 | -0.192 | -0.183 | -0.118 |
| 2023 | 17 | 12 | 1 | 1 | 3 | 92.31 | 0.385 | 0.072 | 0.389 |
| 2024 | 15 | 7 | 5 | 2 | 1 | 58.33 | -0.125 | -0.262 | -0.002 |
| 2025 | 38 | 14 | 16 | 7 | 1 | 46.67 | -0.300 | -0.362 | -0.184 |
| 2026 | 21 | 15 | 3 | 2 | 1 | 83.33 | 0.250 | 0.096 | 0.266 |


La E condicional es positiva en 2020, 2023 y 2026, negativa en 2021, 2022, 2024 y 2025. Los años tienen N=13–38 rupturas; todos quedan entre muy poco confiables y exploratorios. El año 2026 está incompleto. No hay estabilidad de rentabilidad acreditada.

### Otras configuraciones con apariencia favorable entre resultados decididos

Se muestran A 0.5R, C 0.5R y Low C 0.5R porque sus expectativas condicionales completas parecían positivas. **Esta elección es retrospectiva**, no selección sobre entrenamiento; sus divisiones temporales son sensibilidades, no pruebas fuera de muestra independientes. Low puede incluir la segunda ruptura del día.

| Configuración | Período | N | W | L | U | Amb | WR decididos% | E decididos | E mín | E máx |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Primero A 0.5R | 2020 | 17 | 10 | 5 | 2 | 0 | 66.67 | 0.000 | -0.065 | 0.044 |
| Primero A 0.5R | 2021 | 13 | 7 | 5 | 1 | 0 | 58.33 | -0.125 | -0.187 | -0.090 |
| Primero A 0.5R | 2022 | 16 | 7 | 3 | 6 | 0 | 70.00 | 0.050 | -0.174 | 0.130 |
| Primero A 0.5R | 2023 | 17 | 13 | 0 | 2 | 2 | 100.00 | 0.500 | 0.205 | 0.472 |
| Primero A 0.5R | 2024 | 15 | 9 | 3 | 3 | 0 | 75.00 | 0.125 | -0.013 | 0.178 |
| Primero A 0.5R | 2025 | 38 | 16 | 12 | 9 | 1 | 57.14 | -0.143 | -0.261 | -0.049 |
| Primero A 0.5R | 2026 | 21 | 12 | 4 | 4 | 1 | 75.00 | 0.125 | -0.082 | 0.186 |
| Primero A 0.5R | 70% | 75 | 44 | 15 | 14 | 2 | 74.58 | 0.119 | -0.040 | 0.164 |
| Primero A 0.5R | 30% | 62 | 30 | 17 | 13 | 2 | 63.83 | -0.043 | -0.188 | 0.033 |
| Primero C 0.5R | 2020 | 17 | 10 | 5 | 2 | 0 | 66.67 | 0.000 | -0.053 | 0.035 |
| Primero C 0.5R | 2021 | 13 | 7 | 5 | 1 | 0 | 58.33 | -0.125 | -0.182 | -0.092 |
| Primero C 0.5R | 2022 | 16 | 6 | 3 | 7 | 0 | 66.67 | 0.000 | -0.217 | 0.086 |
| Primero C 0.5R | 2023 | 17 | 13 | 0 | 3 | 1 | 100.00 | 0.500 | 0.235 | 0.463 |
| Primero C 0.5R | 2024 | 15 | 8 | 2 | 5 | 0 | 80.00 | 0.200 | 0.002 | 0.258 |
| Primero C 0.5R | 2025 | 38 | 17 | 9 | 11 | 1 | 65.38 | -0.019 | -0.193 | 0.041 |
| Primero C 0.5R | 2026 | 21 | 12 | 2 | 7 | 0 | 85.71 | 0.286 | 0.008 | 0.281 |
| Primero C 0.5R | 70% | 75 | 42 | 14 | 18 | 1 | 75.00 | 0.125 | -0.036 | 0.167 |
| Primero C 0.5R | 30% | 62 | 31 | 12 | 18 | 1 | 72.09 | 0.081 | -0.115 | 0.121 |
| Low C 0.5R | 2020 | 7 | 5 | 0 | 2 | 0 | 100.00 | 0.500 | 0.324 | 0.433 |
| Low C 0.5R | 2021 | 11 | 6 | 3 | 2 | 0 | 66.67 | 0.000 | -0.123 | 0.035 |
| Low C 0.5R | 2022 | 12 | 5 | 1 | 6 | 0 | 83.33 | 0.250 | -0.039 | 0.253 |
| Low C 0.5R | 2023 | 9 | 6 | 0 | 2 | 1 | 100.00 | 0.500 | 0.152 | 0.430 |
| Low C 0.5R | 2024 | 9 | 4 | 0 | 5 | 0 | 100.00 | 0.500 | -0.049 | 0.384 |
| Low C 0.5R | 2025 | 25 | 13 | 3 | 8 | 1 | 81.25 | 0.219 | -0.058 | 0.213 |
| Low C 0.5R | 2026 | 11 | 6 | 2 | 3 | 0 | 75.00 | 0.125 | -0.078 | 0.179 |
| Low C 0.5R | 70% | 46 | 25 | 4 | 16 | 1 | 86.21 | 0.293 | 0.028 | 0.282 |
| Low C 0.5R | 30% | 38 | 20 | 5 | 12 | 1 | 80.00 | 0.200 | -0.058 | 0.213 |


Las cotas vuelven a incluir los pendientes con sus excursiones disponibles. Una fila anual positiva con pocos trades no demuestra robustez de la estrategia y no debe usarse para excluir los años desfavorables.

### Dirección por año, sin ajustar umbrales

| Año | N | Precio acierto% | Londres acierto% |
| --- | --- | --- | --- |
| 2020 | 17 | 76.47 | 82.35 |
| 2021 | 13 | 84.62 | 69.23 |
| 2022 | 16 | 56.25 | 56.25 |
| 2023 | 17 | 64.71 | 52.94 |
| 2024 | 15 | 73.33 | 46.67 |
| 2025 | 38 | 84.21 | 71.05 |
| 2026 | 21 | 66.67 | 57.14 |


La regla de posición de precio supera 50% descriptivamente en los siete años (56.25%–84.62%), pero los intervalos por año son amplios. La dirección persiste mejor que la rentabilidad. El 50% es referencia simétrica; la comparación fuerte es la validación temporal y el baseline del lado mayoritario, no elegir a posteriori el mejor sesgo anual.

## 20. Robustez temporal 70/30

Se fijó el corte por **días calendario**, no por resultados ni por número de setups: **2020-01-01–2024-09-24** frente a **2024-09-25–2026-10-06**. Son 1729 y 742 días calendario, 83 y 69 setups con NY completo, y **75 y 62 rupturas**. El cambio de frecuencia hace que el 30% final del tiempo contenga 45.4% de las rupturas.

Se fijaron reglas sencillas (mitad del rango, extremos 0.20/0.80 y compresión 0.50), sin mover umbrales al ver el tramo final. Se eligió en entrenamiento, entre 21 escenarios R y con N≥50, el de mejor **cota conservadora amplia**: B con TP=0.5R. Ni siquiera esa mejor cota inicial es positiva (−0.10R).

Esto es una **validación cronológica retrospectiva conceptual**. Los archivos completos ya estaban disponibles y se vieron en la auditoría; no equivale a un conjunto ciego sellado ni a un forward verdaderamente nuevo. No se reoptimizó sobre el tramo final.

| Período | Regla | N rupturas | Aciertos | Acierto% | IC95 |
| --- | --- | --- | --- | --- | --- |
| 70% | Precio mitad | 75 | 54 | 72.00 | 60.96–80.90 |
| 70% | Londres mitad | 75 | 47 | 62.67 | 51.35–72.74 |
| 70% | Precio extremo | 19 | 16 | 84.21 | 62.43–94.48 |
| 70% | Comp<0.5 y extremo | 6 | 6 | 100.00 | 60.97–100.00 |
| 30% | Precio mitad | 62 | 47 | 75.81 | 63.85–84.75 |
| 30% | Londres mitad | 62 | 40 | 64.52 | 52.08–75.26 |
| 30% | Precio extremo | 12 | 11 | 91.67 | 64.61–98.51 |
| 30% | Comp<0.5 y extremo | 4 | 3 | 75.00 | 30.06–95.44 |
| Todo | Precio mitad | 137 | 101 | 73.72 | 65.78–80.37 |
| Todo | Londres mitad | 137 | 87 | 63.50 | 55.18–71.09 |
| Todo | Precio extremo | 31 | 27 | 87.10 | 71.15–94.87 |
| Todo | Comp<0.5 y extremo | 10 | 9 | 90.00 | 59.58–98.21 |


| Período | Grupo | N | breaks | MFE media | MFE mediana | MAE media | Norm media | Norm mediana | Both% |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 70% | Todos | 83 | 75 | 25.80 | 17.90 | 20.13 | 0.74 | 0.50 | 16.87 |
| 70% | Comp<0.5 | 15 | 13 | 31.12 | 11.60 | 18.54 | 0.76 | 0.31 | 6.67 |
| 70% | Comp>=0.5 | 68 | 62 | 24.68 | 18.90 | 20.46 | 0.74 | 0.54 | 19.12 |
| 70% | Precio bajo | 9 | 9 | 16.37 | 10.70 | 19.09 | 0.49 | 0.32 | 11.11 |
| 70% | Precio alto | 10 | 10 | 11.42 | 9.15 | 35.70 | 0.26 | 0.19 | 40.00 |
| 30% | Todos | 69 | 62 | 22.36 | 13.75 | 23.88 | 0.62 | 0.39 | 20.29 |
| 30% | Comp<0.5 | 17 | 14 | 36.73 | 23.90 | 14.27 | 0.88 | 0.70 | 11.76 |
| 30% | Comp>=0.5 | 52 | 48 | 18.17 | 11.90 | 26.68 | 0.55 | 0.35 | 23.08 |
| 30% | Precio bajo | 8 | 7 | 19.20 | 11.90 | 21.41 | 0.43 | 0.40 | 12.50 |
| 30% | Precio alto | 6 | 5 | 32.34 | 17.60 | 29.80 | 0.58 | 0.52 | 33.33 |


La dirección por precio mantiene 72.00%→75.81%. Londres mantiene 62.67%→64.52%. El cruce compresión+extremos baja de 100% a 75%, pero se basa en **6 y 4 rupturas**: no hay evidencia utilizable.

La correlación CompressionRatio→MFE/Asia cae de **0.312** (N=75, p=0.0074) a **0.023** (N=62, p=0.863). Frente a NYRange/Asia conserva signo positivo, 0.418→0.318, que sigue sin apoyar «menor ratio, más expansión». El grupo <0.50 mejora en el tramo final, pero tiene solo 13 y 14 rupturas por tramo y su mediana inicial era inferior al resto. No se selecciona después de verlo como ganador.

### Transferencia del modelo R elegido en entrenamiento

| Período | N | W | L | U | Amb | WR decididos% | E decididos | E mínima | E máxima | E MFE/MAE mín | E MFE/MAE máx |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 70% inicial | 75 | 45 | 19 | 8 | 3 | 70.31 | 0.055 | -0.100 | 0.120 | -0.044 | 0.097 |
| 30% final | 62 | 29 | 21 | 9 | 3 | 58.00 | -0.130 | -0.298 | -0.008 | -0.238 | -0.047 |
| Todo | 137 | 74 | 40 | 17 | 6 | 64.91 | -0.026 | -0.190 | 0.062 | -0.132 | 0.032 |


En el tramo final, incluso la cota más optimista **amplia** de B 0.5R es **−0.008R por trade** antes de costes, y entre resueltos E=−0.130R. No demuestra que la población futura sea negativa: el IC95% bootstrap por bloques mensuales de la cota optimista final es **[−0.216, +0.180]**. Sí significa que el tramo observado final no confirma el resultado inicial ni bajo una asignación favorable de sus pendientes.

Bootstrap por meses (10,000 repeticiones): cota pesimista inicial IC95% **[−0.280,+0.083]**, final **[−0.478,−0.111]**; cota optimista inicial **[−0.054,+0.286]**, final **[−0.216,+0.180]**. Los intervalos del tramo inicial además están expuestos al sesgo de selección entre 21 candidatos; no son pruebas confirmatorias.

### ¿Filtrar rupturas en el sentido del precio de las 08:00 arregla la expectativa?

Política prefijada conceptual: solo tomar la primera ruptura si coincide con la mitad del rango donde abrió el precio; cancelar el día si primero rompe el lado contrario. La condición se observa al entrar y no espera conocer el resultado. Produce **101 entradas**, 54 iniciales y 47 finales.

| Período | Modelo | TP | N | W | L | U | Amb | E decididos | E MFE/MAE mín | E MFE/MAE máx |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Todo | A | 0_5R | 101 | 55 | 25 | 19 | 2 | 0.031 | -0.109 | 0.085 |
| Todo | A | 1R | 101 | 31 | 36 | 33 | 1 | -0.075 | -0.252 | 0.116 |
| Todo | B | 0_5R | 101 | 55 | 31 | 13 | 2 | -0.041 | -0.132 | 0.010 |
| Todo | B | 1R | 101 | 34 | 46 | 20 | 1 | -0.150 | -0.246 | -0.022 |
| Todo | C | 0_5R | 101 | 53 | 21 | 25 | 2 | 0.074 | -0.101 | 0.122 |
| Todo | C | 1R | 101 | 28 | 31 | 41 | 1 | -0.051 | -0.261 | 0.156 |
| 70% | A | 0_5R | 54 | 32 | 12 | 9 | 1 | 0.091 | -0.032 | 0.140 |
| 70% | A | 1R | 54 | 15 | 19 | 19 | 1 | -0.118 | -0.277 | 0.140 |
| 70% | B | 0_5R | 54 | 33 | 14 | 6 | 1 | 0.053 | -0.026 | 0.095 |
| 70% | B | 1R | 54 | 20 | 22 | 11 | 1 | -0.048 | -0.156 | 0.092 |
| 70% | C | 0_5R | 54 | 30 | 11 | 12 | 1 | 0.098 | -0.047 | 0.150 |
| 70% | C | 1R | 54 | 14 | 17 | 22 | 1 | -0.097 | -0.276 | 0.161 |
| 30% | A | 0_5R | 47 | 23 | 13 | 10 | 1 | -0.042 | -0.197 | 0.022 |
| 30% | A | 1R | 47 | 16 | 17 | 14 | 0 | -0.030 | -0.223 | 0.088 |
| 30% | B | 0_5R | 47 | 22 | 17 | 7 | 1 | -0.154 | -0.253 | -0.088 |
| 30% | B | 1R | 47 | 14 | 24 | 9 | 0 | -0.263 | -0.349 | -0.153 |
| 30% | C | 0_5R | 47 | 23 | 10 | 13 | 1 | 0.045 | -0.162 | 0.091 |
| 30% | C | 1R | 47 | 14 | 14 | 19 | 0 | 0.000 | -0.244 | 0.149 |


No aparece una mejora robusta: B 0.5R entre resueltos pasa de +0.053 a −0.154R, y B 1R de −0.048 a −0.263R. La predicción del primer toque **no se convierte automáticamente en continuación rentable desde el nivel tocado**. C 0.5R conserva una cifra condicional ligeramente positiva, pero demasiadas posiciones sin cerrar identificablemente para sostener una expectativa completa.

## 21. Variables con mayor poder predictivo

| Orden | Variable | Utilidad observada | Muestra / estabilidad | Límite |
| --- | --- | --- | --- | --- |
| 1 | Price0800Position | Primer lado: 73.72% con regla de mitad, +22.63 pp frente a Low global | N=137; 72.00% inicial, 75.81% final | Gran parte compatible con cercanía a la barrera; no predice PnL probado |
| 2 | LondonMidPosition | Primer lado: 63.50%, +12.41 pp | N=137; 62.67% inicial, 64.52% final | Menor señal; aporte incremental al precio no demostrado |
| 3 | ATR14 / ADR20 | Rango NY absoluto, rho≈0.50/0.48 | N=150; contexto parcial en todos los disponibles | No hay relación robusta con MFE posterior en pips; no se acreditó estabilidad predictiva adicional |
| 4 | AsiaRange | Rango NY absoluto, rho=0.409; menor expansión relativa con Asia grande | N=152; efecto también geométrico | MFE pips rho=0.060; no demuestra filtro rentable |
| 5 | Hora del primer breakout | Horizonte restante, BothSides y expansión relativa | N=137; franjas N=4–29 | Variable conocida al romper, no antes de las 08:00; censura temporal |
| 6 | CompressionRatio | Poca información sobre MFE en pips; ratio NY/Asia positivo | N=137/152; MFE normalizada inestable en 70/30 | No valida menor ratio→mayor expansión |
| 7 | Día de semana | Ninguna mejora demostrada | N=22–36 por día; pruebas no significativas | Evitar filtros |
| 8 | Cruce compresión×precio | Porcentajes altos aislados | Máximo N=13 por celda | Insuficiente; añadir complejidad empeora evidencia |

Este orden combina fuerza de asociación, simplicidad y estabilidad observada; no es un ranking de importancia de un modelo multivariable ni prueba causal. No se suman correlaciones de variables dependientes como si fueran confirmaciones independientes.

## 22. Hallazgos robustos

Dentro de este histórico y sujeto a verificar la conversión horaria:

- La frecuencia es baja: 155 setups evaluables válidos y 137 primeras rupturas completas en casi siete años. Los 152 resultados diarios constituyen evidencia razonable descriptiva, pero ninguna política base alcanza N≥200.
- No hay sesgo direccional global: 67 High y 70 Low, p=0.864.
- La posición del precio contiene información sobre el **primer extremo** y la regla de la mitad persiste temporalmente. La asociación direccional merece evidencia moderada; la rentabilidad no.
- La expansión típica es muy inferior a los máximos: MFE mediana 16 pips, media 24.24, máximo 125.2.
- El retorno al interior es habitual, ≥94.89%; el recorrido de ambos lados es bastante menos frecuente, 18.42% de setups.
- No hay expansión NY absoluta claramente superior al control; la expansión relativa NY/Asia es menor en válidos en cada año.
- La simulación ideal de ruptura inmediata no acredita expectativa positiva robusta una vez incluidos los pendientes y la prueba temporal.

«Robusto» aquí significa respaldado por la muestra y comprobaciones realizadas, no universal entre brokers ni garantía de persistencia futura.

## 23. Hallazgos débiles o sospechosos

| Hallazgo aparente | Por qué es débil |
| --- | --- |
| Compresión 0.30–0.40: MFE media 46.46 pips | 8 setups, solo 5 rupturas; 3 días no rompen |
| Precio extremo: 81%–82% de primer lado entre todos los setups | N=16/17, amplio error de estimación y explicación por distancia |
| Londres 0.80–1.00: 100% High, MFE 65.2 | 2 observaciones; descartar como regla |
| Celdas con 100% direccional | N máximo 13 en toda la matriz, habitualmente mucho menos |
| 2023 especialmente favorable | 17 casos; no se repite como régimen estable |
| Ventana 08:30–09:00 con más MFE | N=21 y elección entre varias franjas; sin validación independiente |
| Jueves mejor que martes | Test ómnibus no significativo |
| Low C 0.5R con +0.25R | Solo 54 decididos de 84; 30 resultados abiertos o ambiguos; selección entre muchos escenarios |
| Media MFE/MAE=5.66 | Mediana 0.843; gran sensibilidad a denominadores pequeños |
| Asia pequeña mejor en múltiplos de Asia | El denominador por construcción aumenta el ratio; no acredita más beneficio en pips |

Se aplica la escala solicitada: **N<20 muy poco confiable; 20–49 exploratorio; 50–99 interesante pero débil; 100–199 evidencia razonable; ≥200 más sólida**. La etiqueta de tamaño no compensa sesgo, múltiples pruebas, mala cobertura ni ausencia del resultado económico completo.

## 24. Riesgo de overfitting

Se examinan 8 buckets de compresión, 5 de Londres, 7 de precio, 56 cruces básicos más 2 especiales, 18 de volatilidad, 5 días, 7 franjas y 42 estados R por día. El número de porcentajes potencialmente llamativos es grande respecto de 137 rupturas. Las tablas no son muestras independientes.

Las correlaciones usan Spearman y 9,999 permutaciones bilaterales, resolución mínima de p=0.0001. Se aplica Holm a las **38 correlaciones mostradas**. Esa corrección no cubre mágicamente todas las tablas, escenarios y narrativas exploradas: las restantes comparaciones son exploratorias. Las permutaciones por día suponen intercambiabilidad y pueden ser optimistas si hay dependencia temporal. Por eso se acompaña el resultado R con bootstrap por bloques mensuales y se da más peso a la persistencia temporal que a un p aislado.

Los IC Wilson de proporciones son marginales, no simultáneos para toda la matriz. Los IC bootstrap del control son por día y no ajustan por diferencias de régimen ni tamaño de Asia. No se presenta una inferencia causal. No se excluyen outliers de las tablas principales; se ofrecen medidas robustas y sensibilidades separadas.

La selección R inicial es una búsqueda pequeña y explícita entre 21 candidatos, aun así expuesta a sesgo del ganador. El corte 70/30 se hace por tiempo y las reglas no se reajustan sobre el final. Haber inspeccionado el histórico completo para auditoría impide llamarlo prueba ciega. La siguiente evaluación confirmatoria necesita fechas/datos nuevos o un conjunto sellado y reglas registradas antes.

No se selecciona retrospectivamente el mejor año, horario, día o combinación. Los indicadores normalizados comparten denominadores; las métricas High/Low comparten días; los años tienen tamaños pequeños. Estos factores pueden fabricar una impresión de múltiples confirmaciones cuando solo existe una misma relación geométrica.

Para la siguiente fase deben fijarse antes de evaluar: tolerancia de precio y qué significa ruptura, condición de activación/cancelación, entrada y fill, spread, SL/TP, cierre horario, tamaño de riesgo, tratamiento de gaps e intrabar, un control comparable y una métrica económica primaria neta. La prioridad es completar la medición, no buscar más filtros.

## 25. Hipótesis de estrategias para siguiente fase

Estas propuestas son **experimentos**, no estrategias rentables identificadas. Se presentan después del análisis y sin programar un EA. El orden prioriza sencillez y posibilidad de refutación. Los valores de SL/TP son modelos disponibles para una comparación acotada, no parámetros óptimos.

| Hipótesis | Condición y dirección | Entrada conceptual | SL / TP conceptual | Casos disponibles | Razón y criterio crítico |
| --- | --- | --- | --- | --- | --- |
| A. Ruptura inmediata como control | Londres estrictamente dentro; cualquiera de los lados | Primer toque ejecutable del extremo, cancela el otro | B=0.5×Asia; TP=0.5R; cierre de pendientes a las 14:00 | 137 entradas completas; 75/62 en 70/30 | Referencia simple elegida en tramo inicial. Resultado final desfavorable: debe servir para intentar descartar continuación automática, no como favorita |
| B. Primera ruptura alineada con posición 08:00 | Precio≥0.5: solo High; <0.5: solo Low. Cancelar el día si primero rompe el contrario | Entrada solo cuando el primer extremo coincide con la señal | Comparación prefijada B o C; TP=0.5R; cierre 14:00 | 101 entradas, 54/47; unos 15/año | Dirección tiene señal persistente, pero simulación no prueba mejora de E. Verificar si existe beneficio después de costes y cierre, sin cambiar umbral |
| C. Ruptura, retorno y nueva salida confirmada | Setup válido; preferencia direccional simple de la hipótesis B | Esperar retorno cierto y una nueva salida en la misma dirección; definir una única confirmación antes de medir | SL detrás del mínimo/máximo del retest; TP inicial 1R; cierre 14:00 | 130 días con retorno confirmado como universo máximo; número de confirmaciones/entradas desconocido | Retorno mediano 1 minuto y MFE potencial justifican contrastar timing. Los CSV no demuestran ventaja del retest ni permiten simularlo |
| D. Fade tras fracaso confirmado de la primera ruptura | Setup válido, retorno dentro y confirmación de rechazo; dirección opuesta a la primera | Entrada tras confirmación, no por mero toque interior | SL más allá del extremo del intento fallido; TP conceptual centro de Asia antes de estudiar extremo opuesto; cierre 14:00 | Hasta 130 candidatos de retorno; 28 días recorren ambos lados; trades efectivos desconocidos | Ambos lados existe, pero N=28 y la vuelta interior no implica continuación contraria. Útil como hipótesis rival, no como recomendación |

No se propone un filtro compresión×posición: no hay N suficiente que justifique su complejidad. Tampoco un filtro de jueves ni de una franja horaria «ganadora». Las cuatro alternativas deben compararse con las mismas convenciones, costes y períodos; no combinar reglas hasta que una hipótesis simple sobreviva por sí sola.

Antes de esa prueba hacen falta: histórico UTC/offset del servidor verificable; barras o ticks originales; Bid/Ask y costes; precio de salida a las 14:00; secuencia TP/SL o máscara de resultados posibles; MFE/MAE antes del primer retorno y antes de cada objetivo; y tiempos de confirmación/retest. Esa información sirve para validar el patrón sin construir todavía un EA operativo.

## 26. Conclusión

**NO HAY EVIDENCIA DE EDGE explotable demostrado.** La hipótesis fuerte —Londres contenido genera una expansión NY especialmente aprovechable— no sobrevive como conclusión general: el rango NY no es claramente mayor que el control, menor CompressionRatio no ofrece una relación monotónica favorable y las simulaciones no acreditan expectativa completa positiva estable.

Sí hay una regularidad útil: **el precio de las 08:00 anticipa el primer lado tocado**. Es sencilla, persiste en el tramo final y no requiere diez filtros. Pero gran parte puede explicarse por distancia al extremo y no se traduce por sí sola en continuación después del breakout. El retorno frecuente, los resultados pendientes, los costes y la inestabilidad anual son obstáculos materiales.

La decisión razonable es **no invertir todavía en desarrollar u optimizar un EA sobre esta premisa**. Si se continúa, conviene una validación limitada y falsable que resuelva las carencias de horario y ejecución, compare ruptura inmediata con entrada alineada y retest, y use datos nuevos. El siguiente avance debe reducir incertidumbre de medición, no aumentar el número de parámetros.

### Trazabilidad y reproducción

Los cálculos parten de los CSV originales sin modificación. Los resultados derivados, reconciliación campo por campo, conteos de vacíos por columna, protocolo temporal, semillas y hashes SHA-256 quedan en `analisis_compression/revision_20261007`. La rutina de investigación está en `analisis_compression/analisis_integral.py`; este informe se compone con `analisis_compression/generar_informe.py`. Son herramientas de análisis local, no código de un EA.

La referencia para los números es Daily. Los secundarios se auditaron completamente; la discrepancia de borde se conserva documentada. No se usaron cotizaciones externas para completar vacíos ni se fabricaron órdenes intrabar, resultados TP/SL, cierres, spreads o rentabilidades faltantes.
