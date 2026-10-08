# Análisis de las optimizaciones de SETUP_B

Fecha de análisis: 7 de octubre de 2026. EURUSD. Capital inicial de cada prueba: USD 100.000.

## 1. Recomendación para tu objetivo

**Mi primera elección como configuración de entradas y salidas es Rango A, SL de 15 pips, RR 4, breakeven activado a 15 pips y cancelación de la segunda entrada únicamente al TP.** Corresponde al pase **457** en los reportes originales y a los pases **265** —porcentaje fijo— y **553** —progresión— del reporte nuevo.

Tu prioridad es la rentabilidad y no fijaste un techo de drawdown. Por eso esta elección busca un beneficio alto que también tenga respaldo en 2025, el período difícil, y que conserve buen comportamiento en la versión nueva. Es una elección razonada entre compromisos; no es la ganadora de todas las métricas.

**Para la gestión del dinero, usaría el 1% fijo como configuración de referencia. La progresión 1,10 queda como variante agresiva prometedora, pendiente de probar en 2025 con la misma versión.** El motivo principal es la falta de esa comparación, no una preferencia tuya por bajo drawdown. En 2026, la progresión mejora el resultado de esta configuración y justifica investigarla; los datos disponibles no prueban su superioridad entre regímenes.

Hay dos alternativas especialmente relevantes. El pase **141** —SL 20, RR 4, BE 5— ofrece mayor estabilidad local y mejor desempeño en el año difícil con un sacrificio de beneficio en 2026. El pase **445** —SL 20, RR 3, BE 15— maximiza el beneficio del peor período entre las configuraciones rentables en ambos, pero sus vecinos son menos consistentes y rinde menos que 457 con la gestión nueva.

## 2. Qué contienen realmente los archivos

| Archivo | Período del título | Timeframe del título | Filas | Combinaciones tras normalizar BE apagado |
| --- | --- | --- | --- | --- |
| ReportOptimizer-2025.xml | 01/01/2025–31/12/2025 | M15 | 480 | 320 |
| ReportOptimizer-2026.xml | 01/01/2026–07/10/2026 | M15 | 480 | 320 |
| ReportOptimizer-2026 Riesgo variable.xml | 01/01/2026–07/10/2026 | M1 | 576 | 384: 192 fijo y 192 variable |

Los tres indican depósito de USD 100.000, servidor FivePercentOnline-Real y apalancamiento 100. **El nombre del servidor no convierte las optimizaciones en resultados de una cuenta real.** Son reportes del probador. 2026 es un período parcial; no anualicé ni extrapolé sus beneficios.

Los originales recorren Rango A/B, dos modos de cancelación, SL de 5/10/15/20, RR de 1/2/3/4/5, BE activado/desactivado y umbral de BE de 5/10/15. El nuevo recorre el mismo espacio salvo RR, limitado a 3/4/5, y añade riesgo variable activado/desactivado. Las filas cubren las mallas cartesianas de esos valores, sin claves de parámetros duplicadas.

Cuando BE está apagado, cambiar su umbral no tiene efecto. Verifiqué que todas las métricas se repiten y conté una sola vez esas combinaciones. Quedan **1.024 observaciones normalizadas entre archivos**, frente a **1.376 filas originales**. No son 1.024 pruebas estadísticas independientes. Quedan otros resultados coincidentes: hay 284 vectores de métricas distintos en cada original y 376 en el nuevo. No fusioné parámetros activos solo por coincidir históricamente: podrían diferir en otras secuencias de mercado.

El porcentaje base del **1%** y el multiplicador **1,10** fueron confirmados por vos; no están exportados en las tablas. El archivo tampoco explora varios multiplicadores. Por lo tanto, **no permite elegir entre 1,05, 1,10, 1,15, etc.**

### Diferencia de gestión entre las versiones

El historial local aporta una observación material. En el commit `27b9d13`, que incorpora los reportes originales, el EA usa `InpLots` y asigna ese volumen fijo a cada orden. El commit posterior `c7c4147` lo sustituye por porcentaje del balance e incorpora la progresión. La versión actual calcula el importe como balance × porcentaje y ajusta los lotes a la distancia al SL.

Esto indica que la comparación puede abarcar **lotaje fijo, porcentaje fijo del balance y porcentaje progresivo**. Los XML no identifican el binario exacto ni los valores constantes completos; el historial es evidencia fuerte de la diferencia de versiones, pero no prueba qué ejecutable produjo cada reporte. Tu confirmación del 1% se usa para la gestión nueva y no se fuerza sobre los originales ante esta discrepancia.

La distinción importa: con lotaje fijo, aumentar SL también aumenta el dinero arriesgado por orden. Con porcentaje fijo del balance, aumentar SL reduce el volumen. Una mayor ganancia del SL 20 en el original no demuestra por sí sola una ventaja sobre SL 15 a igual riesgo.

También cambia el timeframe declarado: M15 frente a M1. El código actual toma los rangos mediante `PERIOD_M15`, así que el título M1 no demuestra que las señales hayan pasado a calcularse sobre velas M1. Sí obliga a unificar el entorno antes de atribuir cualquier diferencia únicamente al sizing. El modo de ticks no se puede deducir del timeframe ni de `Condition=0`.

**Control empírico:** comparé las 192 configuraciones comunes del 2026 original con las 192 de porcentaje fijo del archivo nuevo. Ninguna coincide en todas sus métricas. En 181 coincide el número de trades y en 11 difiere. La diferencia absoluta máxima de beneficio llega a USD 29.054,84 y la de drawdown a 12,0718 puntos porcentuales. Por eso la comparación limpia disponible de progresión es la de los dos modos dentro del archivo nuevo.

## 3. Qué período discrimina mejor las configuraciones

| Grupo | Casos | Con beneficio | Beneficio mediano USD | Máximo USD | DD mediano | DD máximo |
| --- | --- | --- | --- | --- | --- | --- |
| 2025 original | 320 | 52 (16,2%) | -6.056,50 | 20.503,00 | 13,60% | 34,43% |
| 2026 original | 320 | 278 (86,9%) | 7.167,50 | 66.638,00 | 7,04% | 29,08% |
| 2026 nuevo: porcentaje fijo | 192 | 163 (84,9%) | 8.226,15 | 47.651,72 | 8,98% | 24,08% |
| 2026 nuevo: progresión 1,10 | 192 | 166 (86,5%) | 11.253,69 | 77.369,99 | 10,45% | 60,48% |


En los originales, **2025 fue el filtro exigente**: solo 52 de 320 combinaciones ganan, frente a 278 en 2026. Solamente **49 de 320 —15,31%— ganan en ambos**. De las 52 que ganaron en 2025, 49 también ganan en 2026; la situación inversa es mucho menos selectiva.

La correlación de rangos del beneficio entre períodos es **0,162**, calculada como correlación de Pearson entre los rangos medios de las 320 observaciones emparejadas. Es una asociación débil. Entre las diez configuraciones con mayor beneficio de 2026, cinco pierden en 2025. Entre las veinte mejores de 2026, once pierden en 2025. Las diez mejores de 2025 ganan en 2026, aunque esto sigue siendo una revisión retrospectiva.

Estas proporciones describen la malla elegida. **No son la tasa de acierto de las operaciones ni probabilidades de ganar en el futuro.** Las medianas de grupos con distinto espacio RR tampoco son una comparación causal de los modelos de riesgo.

## 4. Comparación de los candidatos principales

La configuración se expresa como **Rango / cancelación de la segunda entrada / SL / RR / BE**. Los precios se expresan en pips y el beneficio en USD. Todos parten de USD 100.000 en cada test.

| Pase original | Configuración | Beneficio 2025 | Beneficio 2026 parcial | Suma descriptiva | DD 2025 | DD 2026 | PF 2025 | PF 2026 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 457 | A / al TP / 15 / 4 / 15 | 18.676,00 | 48.393,00 | 67.069,00 | 16,08% | 8,12% | 1,288 | 2,409 |
| 141 | A / al TP / 20 / 4 / 5 | 19.358,00 | 35.378,00 | 54.736,00 | 13,54% | 8,58% | 1,443 | 2,852 |
| 445 | A / al TP / 20 / 3 / 15 | 20.503,00 | 48.513,00 | 69.016,00 | 18,08% | 10,05% | 1,297 | 2,209 |
| 461 | A / al TP / 20 / 4 / 15 | 14.563,00 | 58.617,00 | 73.180,00 | 19,53% | 10,79% | 1,201 | 2,363 |
| 125 | A / al TP / 20 / 3 / 5 | 16.942,00 | 22.349,00 | 39.291,00 | 9,98% | 8,89% | 1,398 | 2,170 |
| 137 | A / al TP / 15 / 4 / 5 | 12.900,00 | 16.739,00 | 29.639,00 | 8,27% | 8,41% | 1,318 | 1,890 |
| 473 | A / al TP / 15 / 5 / 15 | 6.500,00 | 58.519,00 | 65.019,00 | 19,23% | 9,14% | 1,096 | 2,609 |
| 296 | B / al TP / 15 / 4 / 10 | 16.954,00 | 21.057,00 | 38.011,00 | 11,21% | 12,64% | 1,396 | 1,805 |


**La suma descriptiva agrega dos pruebas reiniciadas a USD 100.000; no es el resultado de un backtest continuo ni una rentabilidad compuesta.** Tampoco el máximo de los DD de cada período es el drawdown de una curva concatenada. Para obtener esas métricas hace falta una prueba continua. Por la posible diferencia de lotaje, no uso una capitalización teórica de estos originales para justificar la elección.

### Por qué elijo 457 para tu prioridad de beneficio

Frente a 461, sacrifica USD 6.111 en la suma descriptiva —8,35%—, pero gana USD 4.113 más en 2025, reduce el drawdown de ese período de 19,53% a 16,08% y mejora PF de 1,201 a 1,288. Además, en el archivo nuevo supera a 461 tanto con porcentaje fijo como progresivo. El máximo de la suma original favorece SL 20, pero la comparación con la gestión actual favorece SL 15.

Frente a 445, su suma descriptiva es USD 1.947 menor —2,82%—, con menor drawdown en ambos originales. Su PF de 2025 es ligeramente inferior —1,288 frente a 1,297— y no hay que ocultarlo. En la prueba nueva, 457 gana USD 35.771,49 fijo y USD 47.586,74 progresivo, frente a USD 26.036,24 y USD 32.920,17 de 445. Esa diferencia pesa para utilizar la versión actual al 1%.

Frente a 141, 457 gana USD 12.333 más en la suma original, pero tiene peor PF y mayor DD en 2025 y menor estabilidad local. **141 sería mi preferencia si el objetivo pasara de mayor beneficio a mayor tolerancia a errores de parametrización.**

### Qué configuración gana con cada criterio

| Criterio explícito | Candidato | Qué significa |
| --- | --- | --- |
| Mayor suma de beneficios originales entre positivos en ambos | 461: A / SL 20 / RR 4 / BE 15 | USD 73.180; depende más del buen 2026 |
| Mayor beneficio del peor período | 445: A / SL 20 / RR 3 / BE 15 | Mínimo de USD 20.503; menor consistencia local |
| Mayor mínimo de retorno del período / DD porcentual | 125: A / SL 20 / RR 3 / BE 5 | Mínimo 1,698; también lidera el mínimo Recovery Factor |
| Compromiso de rentabilidad y estabilidad local | 141: A / SL 20 / RR 4 / BE 5 | Cuatro de cuatro vecinos numéricos ganan en ambos |
| Elección considerando tu prioridad y la versión nueva | 457: A / SL 15 / RR 4 / BE 15 | Buen respaldo de 2025 y mejor beneficio con el sizing actual entre estos candidatos |

No construí una puntuación con pesos arbitrarios ni presenté una de estas métricas como verdad universal. El retorno/DD indicado es un cociente descriptivo del período, **no un Calmar anualizado**. Recovery Factor usa drawdown monetario y no coincide necesariamente con ese cociente. PF es beneficio bruto dividido por pérdida bruta absoluta; no es porcentaje de operaciones ganadoras. Definiciones: [MetaTrader 5, Testing Report](https://www.metatrader5.com/en/terminal/help/algotrading/testing_report).

## 5. Riesgo fijo frente a progresión 1,10: comparación emparejada

Esta sección usa exclusivamente el reporte nuevo: mismo archivo, mismo período y mismos parámetros de entradas/salidas. Hay 192 parejas después de normalizar BE apagado.

| Cambio al activar la progresión | Casos | Proporción |
| --- | --- | --- |
| Mayor beneficio neto | 162 / 192 | 84,38% |
| Mayor drawdown porcentual | 187 / 192 | 97,40% |
| Mejor Profit Factor | 147 / 192 | 76,56% |
| Mejor Recovery Factor | 122 / 192 | 63,54% |
| Mejor Sharpe reportado | 132 / 192 | 68,75% |
| Mejor retorno del período / DD | 130 / 192 | 67,71% |
| Más beneficio sin aumentar DD | 5 / 192 | 2,60% |

El incremento medio de beneficio es USD 2.742,81 y el mediano USD 2.562,71. El aumento medio del DD es **2,84 puntos porcentuales** y el mediano 1,54 puntos. El número de configuraciones rentables pasa de 163 a 166: gran parte de la mejora aumenta ganancias de estrategias ya rentables; no convierte de forma generalizada una estrategia perdedora en ganadora.

En 16 parejas cambia el número de operaciones —siempre disminuye con progresión, entre una y tres—. Esto indica que no es una simple multiplicación de los mismos resultados: tamaño, margen o reemplazo de pendientes pueden alterar la ejecución. Sin logs no se puede atribuir la causa concreta. Excluyendo esas 16 parejas, la progresión mejora el beneficio en **148 de 176**, 84,09%. La conclusión descriptiva de mayor beneficio no depende de esos casos.

### Cuánto cambia cada candidato con tu riesgo del 1%

| Pase original | Pases nuevos fijo / variable | Beneficio fijo USD | Beneficio variable USD | Mejora de beneficio | DD fijo | DD variable | Recovery fijo / variable |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 457 | 265 / 553 | 35.771,49 | 47.586,74 | 33,0% | 7,62% | 9,48% | 3,513 / 3,607 |
| 141 | 77 / 365 | 18.862,93 | 20.669,11 | 9,6% | 4,80% | 5,15% | 3,598 / 3,656 |
| 445 | 253 / 541 | 26.036,24 | 32.920,17 | 26,4% | 6,87% | 8,73% | 3,119 / 3,010 |
| 461 | 269 / 557 | 32.105,85 | 41.208,79 | 28,4% | 6,87% | 8,73% | 3,833 / 3,747 |
| 125 | 61 / 349 | 11.508,44 | 13.211,45 | 14,8% | 4,83% | 4,97% | 2,224 / 2,474 |
| 137 | 73 / 361 | 11.328,96 | 14.228,85 | 25,6% | 6,03% | 6,25% | 1,711 / 2,063 |
| 473 | 281 / 569 | 44.201,84 | 60.068,89 | 35,9% | 8,55% | 10,05% | 3,823 / 4,265 |
| 296 | 168 / 456 | 14.327,44 | 17.883,30 | 24,8% | 10,20% | 12,69% | 1,176 / 1,152 |


Para **457**, activar la progresión añade **USD 11.815,25 —33,03%—**, mientras el DD sube de **7,6210% a 9,4820%**, un aumento de 1,8610 puntos —24,42% relativo—. El retorno/DD mejora aproximadamente 6,92% y el Recovery Factor solo 2,66%. PF sube de 2,247 a 2,427. Ambos registran 50 trades. Es una mejora histórica interesante y mayor que un aumento proporcional simple de riesgo, pero la mejora de recuperación es bastante más modesta que el incremento de beneficio.

Para **445** y **461**, la progresión también gana más dinero, pero empeora Recovery Factor: 3,119 a 3,010 y 3,833 a 3,747, respectivamente. Para **141**, Recovery apenas mejora —3,598 a 3,656— y la ganancia adicional es 9,57%. No hay una ventaja uniforme de la progresión para todas las configuraciones.

### El máximo absoluto de 2026 y por qué no lo recomiendo como base

El mayor beneficio del nuevo archivo es **USD 77.369,99**, con A, segunda entrada hasta TP, **SL 15, RR 5, BE apagado y progresión activa**. Su DD es **16,2780%**, PF 2,192 y 49 operaciones. Un pase equivalente normalizado es 329; también existen repeticiones con otro umbral BE inactivo.

Con porcentaje fijo, esa misma configuración obtiene USD 47.651,72 y DD 11,0013%. La progresión añade 62,37% de beneficio, pero Recovery Factor baja de 3,105 a 3,063. Y en el original de 2025, esas entradas/salidas pierden **USD 2.156**, con PF **0,978** y DD **20,4838%**. Eso no prueba que el porcentaje variable también habría perdido en 2025; **esa prueba no existe**. Sí impide defenderla como la configuración más consistente con la evidencia actual.

Tampoco elegiría sin más el pase 473 —RR 5 con BE 15—, aunque gana USD 60.068,89 progresivo en 2026: su 2025 original se queda en USD 6.500, PF 1,096 y Recovery 0,321. Tiene mucho menos margen de beneficio en el período difícil que 457.

### El extremo adverso de la progresión

En B, segunda entrada hasta TP, SL 10, RR 5 y BE apagado, el modo fijo pierde **USD 7.122** con DD **24,0824%**. La progresión pierde **USD 48.453,75**, con DD **60,4795%**, manteniendo 48 operaciones. Es un caso observado, no una simulación de ruina ni una estimación de probabilidad. Una caída de 60,48% exige aproximadamente 153,03% de recuperación desde el mínimo para volver al máximo anterior.

El número de configuraciones con DD superior al 20% pasa de 2 a 19; con DD superior al 30%, de 0 a 3. Tu tolerancia a DD permite considerar la variante agresiva, pero no elimina el hecho de que la progresión amplifica algunas secuencias desfavorables de manera mucho mayor que las favorables.

## 6. Qué parámetros tienen respaldo y cuáles son frágiles

### Segunda entrada: mantener hasta que haya TP

`InpCancelSecondEntry=false` **no significa dejar siempre la segunda orden sin cancelación**. Según el código actual, significa cancelarla cuando una operación del setup cierra por TP. `true` cancela al ejecutarse la primera entrada. Los cierres por SL o BE no son equivalentes a TP.

Entre las combinaciones normalizadas de 2025, con cancelación al TP ganan 46 de 160 —28,75%—, mientras que cancelando al entrar ganan 6 de 160 —3,75%—. En la configuración 457, cambiar únicamente esta opción a `true` convierte USD 18.676 en **−USD 11.612** en 2025 y reduce USD 48.393 a USD 11.560 en 2026. Es uno de los cambios con respaldo más claro para esta selección.

### Breakeven: protección que importa en el período difícil

Sin BE, ganan 7 de 80 configuraciones normalizadas en 2025 —8,75%—. Con BE, 45 de 240 —18,75%—. No son muestras de igual tamaño: BE activado tiene tres umbrales. En la malla completa emparejada por los otros parámetros, activar BE mejora el beneficio de 2025 en 147 de 240 comparaciones y el de 2026 en 80 de 240; estas comparaciones reutilizan controles cuando BE está apagado y no son observaciones independientes.

Para A, SL 15, RR 4 y segunda entrada hasta TP, apagar BE cambia el resultado de 2025 de **+USD 18.676 a −USD 12.134**. En 2026 apenas aumenta el beneficio de USD 48.393 a USD 49.132. La renuncia a ese pequeño extra de 2026 evita una pérdida mucho mayor en el original de 2025. Ese es el argumento concreto para mantener BE.

El BE del código mueve SL al precio de entrada. **No garantiza resultado neto cero**, porque no compensa necesariamente comisión, swap ni deslizamiento. Un trigger de 15 con SL 15 mueve a entrada después de un avance de aproximadamente 1R; RR 4 fija un objetivo nominal de 60 pips. El RR nominal no es el ratio realizado medio cuando intervienen BE y otros cierres.

### Rango A: adecuado en esta combinación, no ganador universal

En toda la malla normalizada de 2025, B tiene más configuraciones rentables —32 frente a 20 de A—. En la configuración elegida, A gana USD 18.676/48.393 en los originales, frente a USD 9.855/11.366 al cambiar solo a B. Por eso prefiero A **para este conjunto concreto**. No concluyo que A sea siempre superior.

Los horarios por defecto del código actual son A 02:00–10:00 y B 10:00–14:00. Los XML no exportan esos inputs constantes ni su relación con la zona horaria del bróker. Deben conservarse los horarios realmente utilizados; no los convierto automáticamente a hora argentina.

### SL y RR: una región útil, con límites

En 2025, solo 2 de 80 combinaciones con SL 5 ganan y 8 de 80 con SL 10; con SL 15 y 20 ganan 21 de 80 en cada grupo. A lotaje fijo, esta comparación mezcla distancia de stop y exposición monetaria. La prueba nueva permite una comparación más pertinente con base porcentual.

El grupo específico **A + cancelación al TP + BE activo + RR 4 + SL 15 o 20** tiene seis combinaciones de BE, y las seis ganan en ambos originales:

| Pase | SL | BE | Beneficio 2025 USD | Beneficio 2026 USD | Mayor DD de los períodos |
| --- | --- | --- | --- | --- | --- |
| 137 | 15 | 5 | 12.900,00 | 16.739,00 | 8,41% |
| 297 | 15 | 10 | 11.293,00 | 37.503,00 | 16,84% |
| 457 | 15 | 15 | 18.676,00 | 48.393,00 | 16,08% |
| 141 | 20 | 5 | 19.358,00 | 35.378,00 | 13,54% |
| 301 | 20 | 10 | 5.075,00 | 54.278,00 | 20,09% |
| 461 | 20 | 15 | 14.563,00 | 58.617,00 | 19,53% |


Eso respalda la familia de RR 4 y SL 15–20. Sin embargo, ampliar a RR 3 ya introduce pérdidas, y la familia A/cancelación al TP/BE activo completa tiene solo 20 de 60 combinaciones positivas en ambos. **No hay una meseta amplia de robustez demostrada.** Esta región se identificó mirando los resultados; es evidencia exploratoria, no una validación independiente.

## 7. Sensibilidad local: qué ocurre al mover un parámetro

Para cada candidato, tomé vecinos existentes a un único paso de la malla: SL ±5, RR ±1 o BE ±5, sin cambiar los otros parámetros ni los booleanos. No incluí la configuración central. En bordes hay menos vecinos y no se extrapolan valores fuera de la malla.

| Pase | Vecinos | Positivos en ambos | Peor beneficio vecino 2025 USD | Mediana vecinos 2025 USD | Peor vecino 2026 USD |
| --- | --- | --- | --- | --- | --- |
| 457 | 5 | 4 | -1.588,00 | 6.500,00 | 12.636,00 |
| 141 | 4 | 4 | 4.855,00 | 8.987,50 | 16.739,00 |
| 445 | 4 | 2 | -1.588,00 | 6.032,00 | 23.519,00 |
| 461 | 4 | 3 | -14.780,00 | 11.875,50 | 48.393,00 |
| 125 | 4 | 4 | 186,00 | 7.221,50 | 13.867,00 |
| 137 | 5 | 4 | -2.628,00 | 10.050,00 | 1.986,00 |
| 473 | 4 | 2 | -14.780,00 | 3.986,00 | 18.072,00 |
| 296 | 6 | 5 | -6.075,00 | 7.295,00 | 1.574,00 |


**141 tiene la mejor combinación de ganancia y estabilidad local entre estos candidatos:** sus cuatro vecinos ganan en ambos, y el peor vecino en 2025 aún gana USD 4.855. En 125 también ganan los cuatro, pero uno apenas gana USD 186, muy expuesto a pequeños cambios de costos. En 457 ganan cuatro de cinco; bajar RR de 4 a 3 con SL 15/BE 15 arroja −USD 1.588 en 2025. No considero 457 inmune al sobreajuste.

En 445 solo dos de cuatro vecinos ganan en ambos, aunque su punto central es el mejor de 2025. En 461 un vecino —RR 5— pierde USD 14.780 en 2025. Esta sensibilidad explica por qué no elijo automáticamente el máximo de beneficio acumulado descriptivo.

La falta de vecinos por encima de SL 20 y de BE 15 es una limitación de la malla. Un óptimo en un borde no confirma dónde termina la región favorable. Para robustez, la prueba posterior debe evaluar pequeñas perturbaciones predefinidas, sin sustituir continuamente la configuración por el nuevo máximo.

## 8. Cómo crece realmente el riesgo variable

El código actual usa **riesgo por orden = 1% × 1,10^n**, donde n cuenta los stops adversos desde la última posición cerrada con beneficio neto. Los stops en BE no aumentan el contador por sí mismos. Un cierre neto positivo reinicia la secuencia; no se reinicia automáticamente al cambiar de día. Se reconstruye desde el historial del símbolo/Magic.

La siguiente tabla es un **escenario mecánico hipotético**, no una racha observada ni su probabilidad. Supone una sola posición cada vez, cada SL pierde exactamente el porcentaje calculado del balance, sin gastos, deslizamiento, restricciones de lotes/margen ni ganancias intermedias.

| SL consecutivos completados | Riesgo de la siguiente orden | Pérdida acumulada al 1% fijo | Pérdida acumulada progresiva |
| --- | --- | --- | --- |
| 5 | 1,611% | 4,90% | 5,96% |
| 10 | 2,594% | 9,56% | 14,85% |
| 15 | 4,177% | 13,99% | 27,51% |
| 20 | 6,727% | 18,21% | 44,21% |
| 25 | 10,835% | 22,22% | 63,67% |
| 30 | 17,449% | 26,03% | 82,15% |


Fórmulas: pérdida fija = 1 − 0,99^n; pérdida progresiva = 1 − producto de (1 − 0,01 × 1,10^i), para i de 0 a n−1. Con 20 stops, la siguiente orden arriesga 6,7275% y la caída teórica acumulada alcanza 44,21%, frente a 18,21% fijo.

No hay un tope explícito de porcentaje en el código actual. Los límites del bróker pueden impedir órdenes, pero no equivalen a un límite de pérdidas diseñado. **El 1% es por orden**, no por setup: con la segunda pendiente conservada, la exposición conjunta puede superar el porcentaje base. No se deduce la exposición máxima simultánea de estos resúmenes. Tampoco se deduce del drawdown cuántos stops consecutivos hubo.

## 9. Configuración concreta propuesta

| Parámetro | Configuración de referencia | Variante agresiva a validar |
| --- | --- | --- |
| InpUseRangeA | true | true |
| InpCancelSecondEntry | false | false |
| InpStopLossPips | 15 | 15 |
| InpRiskReward | 4 | 4 |
| InpAutoBreakeven | true | true |
| InpBreakevenPips | 15 | 15 |
| InpRiskPercent | 1,0 | 1,0 |
| InpVariableRisk | false | true |
| InpRiskMultiplier | 1,10; inactivo | 1,10 |

Mantener símbolo, horarios, versión, Magic y condiciones documentadas para la prueba. Para evitar que la progresión herede otra secuencia, su historial/Magic debe corresponder al escenario que se está evaluando. Los números de pase identifican filas **dentro de cada archivo** y no deben cruzarse entre archivos sin emparejar parámetros.

Resultados de referencia de esta selección:

| Métrica | Original 2025, pase 457 | Original 2026, pase 457 | Nuevo 2026 fijo, pase 265 | Nuevo 2026 variable, pase 553 |
| --- | --- | --- | --- | --- |
| Beneficio USD | 18.676,00 | 48.393,00 | 35.771,49 | 47.586,74 |
| Retorno sobre depósito | 18,676% | 48,393% | 35,77149% | 47,58674% |
| Equity DD | 16,0802% | 8,1209% | 7,6210% | 9,4820% |
| PF | 1,288299 | 2,409477 | 2,247109 | 2,427459 |
| Recovery Factor | 1,134629 | 4,101797 | 3,513219 | 3,606709 |
| Trades | 74 | 50 | 50 | 50 |

Los cuatro resultados se muestran por separado para no atribuir al 1% actual los beneficios de los reportes antiguos. La única comparación directa de gestión de dinero en esta tabla es **nuevo fijo frente a nuevo variable**. Las columnas originales apoyan la selección de reglas de trading, con las limitaciones de versión descritas.

## 10. Qué falta para resolver la elección de riesgo con evidencia suficiente

1. **Repetir 2025 con el EA actual**, el mismo entorno de ticks y el 1% base, comparando fijo frente a 1,10. Hacerlo al menos para 457 y 141, con 445 y 461 como referencias. Es la ausencia que más puede cambiar esta recomendación.
2. **Ejecutar un backtest continuo de 01/01/2025 a 07/10/2026**, por candidato y modo de riesgo. Eso permite observar capital, secuencia progresiva y DD que atraviesa el cambio de año. No sustituirlo por suma de beneficios o máximo de DD anuales.
3. Exportar el informe detallado y operaciones: entradas/salidas, lotes, comisiones, swap, resultados, SL/TP, balance, equity y logs de órdenes rechazadas/reemplazadas. Verificar ejecución intrabar con ticks reales, porque BE y pendientes dependen de ella.
4. Revisar resultados mensuales, peor mes, rachas, concentración en pocas ganancias, tiempo bajo máximos, exposición simultánea y riesgo máximo efectivo. Añadir sensibilidad de spread, comisión y deslizamiento. El PF 1,288 de 2025 no deja un margen ilimitado para mayores fricciones.
5. Congelar candidatos antes de una muestra nueva. Como 2025 y 2026 ya se usaron para elegir, no son validación fuera de muestra de esta decisión. Usar un período histórico reservado solo si no participó en el desarrollo o un forward posterior al 07/10/2026. Los procedimientos forward están descritos por [MetaTrader 5](https://www.metatrader5.com/en/terminal/help/algotrading/strategy_optimization).
6. Con operaciones completas, analizar remuestreo de secuencias y costos. Para riesgo progresivo hay que recalcular lotes y reinicios en cada secuencia; mezclar P&L ya dimensionado daría una comparación engañosa. No se puede ejecutar un Monte Carlo fiable de este tipo con las tablas agregadas.

No ejecuté nuevos backtests ni modifiqué el EA o las cuentas. La tarea completada es la comparación exhaustiva de los resultados disponibles y la selección de candidatos. **El ganador futuro y el mejor modo de riesgo entre regímenes no se pueden establecer a partir de estos tres XML.**

## 11. Límites y controles de calidad del análisis

Cada fila se leyó respetando los namespaces y el índice de celdas XML. Se verificaron columnas completas, ausencia de valores faltantes/no finitos en las métricas, unicidad de pase y de clave de inputs, y coincidencia entre Expected Payoff y Profit/Trades. Los duplicados por BE apagado coinciden en todas las métricas. Los cruces se validaron como uno a uno: 320 entre originales y 192 entre modos nuevos.

Las muestras son pequeñas: los candidatos centrales tienen aproximadamente 49–54 operaciones en 2026 y 73–76 en 2025. **74+50=124 trades del candidato 457 no equivalen a 124 observaciones independientes de una misma versión porcentual**. La comparación incluye cambios de entorno/gestión potenciales, correlación temporal y selección posterior entre muchas configuraciones.

Los XML no dan tasa de acierto, secuencias de operaciones, DD diario, tiempo de recuperación, calidad/modelo de ticks, gastos completos, lotaje máximo o exposición simultánea. No calculé probabilidades de ruina, intervalos de confianza, significación estadística, Sharpe combinado ni compatibilidad con reglas de una cuenta de fondeo. Los Sharpe reportados se conservan como referencia, pero no se interpretan como una probabilidad de éxito. El campo `Result` depende del criterio elegido en MT5 y `Custom` es cero; no los uso para reemplazar el análisis de métricas. [Definición de las columnas de optimización](https://www.metatrader5.com/en/terminal/help/algotrading/strategy_optimization).

Los controles se basan en los reportes completos entregados. La muestra contiene pérdidas y DD altos, pero no hay un registro externo que permita certificar todas las ejecuciones intentadas, descartadas o anteriores al exportado.

## 12. Fuentes y trazabilidad

- Los tres XML originales de la carpeta Optimizacion, identificados en la sección 2. Se conservaron sin cambios.
- Confirmación del usuario: base 1%, multiplicador 1,10; sin límite inicial de DD, pero incorporándolo a la decisión.
- Código actual SETUP_B.mq5: inputs de riesgo, ApplyRiskClose/RefreshRisk, CalculateRiskVolume, GetSetupCancellation y ManageBreakeven. Historial local: commits 27b9d13 y c7c4147.
- Documentación local SETUP_B_riesgo.md y documentación oficial de MetaQuotes enlazada junto a cada definición.

Los CSV del mismo directorio conservan los cruces completos, parámetros, métricas, pase y fila XML. El resumen JSON conserva metadatos y SHA-256. El campo XML_row cuenta filas de la tabla —cabecera incluida—, no líneas físicas del archivo. El umbral BE normalizado a cero significa «inactivo», no un input recomendado de cero. Los datos originales se conservan aparte.

## Anexo. Las 49 configuraciones rentables en ambos originales

Ordenadas por suma descriptiva de beneficios. Esta tabla es exhaustiva dentro del filtro; la preferencia final usa también la prueba nueva y la sensibilidad. «Mayor DD» es el mayor de los DD separados, no el DD continuo. «PF mínimo» es el menor PF de los dos períodos, no un PF agregado.

| Pase | Rango / cancelación / SL / RR / BE | Beneficio 2025 USD | Beneficio 2026 USD | Suma USD | Mayor DD | PF mínimo |
| --- | --- | --- | --- | --- | --- | --- |
| 461 | A / al TP / 20 / 4 / 15 | 14.563,00 | 58.617,00 | 73.180,00 | 19,53% | 1,201 |
| 445 | A / al TP / 20 / 3 / 15 | 20.503,00 | 48.513,00 | 69.016,00 | 18,08% | 1,297 |
| 457 | A / al TP / 15 / 4 / 15 | 18.676,00 | 48.393,00 | 67.069,00 | 16,08% | 1,288 |
| 473 | A / al TP / 15 / 5 / 15 | 6.500,00 | 58.519,00 | 65.019,00 | 19,23% | 1,096 |
| 301 | A / al TP / 20 / 4 / 10 | 5.075,00 | 54.278,00 | 59.353,00 | 20,09% | 1,077 |
| 285 | A / al TP / 20 / 3 / 10 | 12.827,00 | 43.613,00 | 56.440,00 | 19,76% | 1,198 |
| 141 | A / al TP / 20 / 4 / 5 | 19.358,00 | 35.378,00 | 54.736,00 | 13,54% | 1,443 |
| 297 | A / al TP / 15 / 4 / 10 | 11.293,00 | 37.503,00 | 48.796,00 | 16,84% | 1,188 |
| 157 | A / al TP / 20 / 5 / 5 | 4.855,00 | 38.699,00 | 43.554,00 | 23,42% | 1,110 |
| 125 | A / al TP / 20 / 3 / 5 | 16.942,00 | 22.349,00 | 39.291,00 | 9,98% | 1,398 |
| 296 | B / al TP / 15 / 4 / 10 | 16.954,00 | 21.057,00 | 38.011,00 | 12,64% | 1,396 |
| 153 | A / al TP / 15 / 5 / 5 | 10.050,00 | 24.828,00 | 34.878,00 | 13,47% | 1,241 |
| 72 | B / al TP / 15 / 5 / apagado | 9.962,00 | 21.814,00 | 31.776,00 | 21,90% | 1,107 |
| 284 | B / al TP / 20 / 3 / 10 | 12.974,00 | 17.430,00 | 30.404,00 | 13,74% | 1,277 |
| 76 | B / al TP / 20 / 5 / apagado | 10.617,00 | 19.670,00 | 30.287,00 | 29,08% | 1,089 |
| 137 | A / al TP / 15 / 4 / 5 | 12.900,00 | 16.739,00 | 29.639,00 | 8,41% | 1,318 |
| 469 | A / al TP / 10 / 5 / 15 | 10.217,00 | 18.072,00 | 28.289,00 | 12,49% | 1,186 |
| 446 | B / al entrar / 20 / 3 / 15 | 992,00 | 26.310,00 | 27.302,00 | 12,76% | 1,028 |
| 316 | B / al TP / 20 / 5 / 10 | 10.289,00 | 16.170,00 | 26.459,00 | 19,33% | 1,212 |
| 136 | B / al TP / 15 / 4 / 5 | 11.461,00 | 12.836,00 | 24.297,00 | 10,07% | 1,378 |
| 60 | B / al TP / 20 / 4 / apagado | 11.633,00 | 12.618,00 | 24.251,00 | 24,45% | 1,102 |
| 444 | B / al TP / 20 / 3 / 15 | 14.559,00 | 8.389,00 | 22.948,00 | 16,48% | 1,197 |
| 248 | B / al TP / 15 / 1 / 10 | 8.739,00 | 14.110,00 | 22.849,00 | 9,99% | 1,245 |
| 312 | B / al TP / 15 / 5 / 10 | 7.505,00 | 15.327,00 | 22.832,00 | 18,72% | 1,171 |
| 309 | A / al TP / 10 / 5 / 10 | 3.305,00 | 18.651,00 | 21.956,00 | 14,41% | 1,064 |
| 456 | B / al TP / 15 / 4 / 15 | 9.855,00 | 11.366,00 | 21.221,00 | 16,54% | 1,176 |
| 124 | B / al TP / 20 / 3 / 5 | 9.261,00 | 10.207,00 | 19.468,00 | 10,71% | 1,285 |
| 8 | B / al TP / 15 / 1 / apagado | 5.237,00 | 12.464,00 | 17.701,00 | 10,70% | 1,116 |
| 408 | B / al TP / 15 / 1 / 15 | 5.237,00 | 12.464,00 | 17.701,00 | 10,70% | 1,116 |
| 280 | B / al TP / 15 / 3 / 10 | 2.172,00 | 13.677,00 | 15.849,00 | 13,09% | 1,051 |
| 109 | A / al TP / 20 / 2 / 5 | 1.616,00 | 13.997,00 | 15.613,00 | 14,59% | 1,038 |
| 56 | B / al TP / 15 / 4 / apagado | 904,00 | 14.575,00 | 15.479,00 | 17,98% | 1,010 |
| 476 | B / al TP / 20 / 5 / 15 | 7.080,00 | 7.129,00 | 14.209,00 | 23,89% | 1,115 |
| 121 | A / al TP / 15 / 3 / 5 | 186,00 | 13.867,00 | 14.053,00 | 11,20% | 1,005 |
| 453 | A / al TP / 10 / 4 / 15 | 1.245,00 | 12.636,00 | 13.881,00 | 14,46% | 1,023 |
| 300 | B / al TP / 20 / 4 / 10 | 7.085,00 | 6.468,00 | 13.553,00 | 20,29% | 1,148 |
| 44 | B / al TP / 20 / 3 / apagado | 2.734,00 | 10.771,00 | 13.505,00 | 25,15% | 1,026 |
| 250 | B / al entrar / 15 / 1 / 10 | 1.324,00 | 11.898,00 | 13.222,00 | 9,50% | 1,053 |
| 88 | B / al TP / 15 / 1 / 5 | 3.647,00 | 6.633,00 | 10.280,00 | 8,78% | 1,146 |
| 152 | B / al TP / 15 / 5 / 5 | 5.170,00 | 4.136,00 | 9.306,00 | 13,75% | 1,164 |
| 149 | A / al TP / 10 / 5 / 5 | 1.444,00 | 7.006,00 | 8.450,00 | 9,56% | 1,037 |
| 406 | B / al entrar / 10 / 1 / 15 | 1.650,00 | 6.308,00 | 7.958,00 | 5,30% | 1,075 |
| 246 | B / al entrar / 10 / 1 / 10 | 1.650,00 | 6.308,00 | 7.958,00 | 5,30% | 1,075 |
| 6 | B / al entrar / 10 / 1 / apagado | 1.650,00 | 6.308,00 | 7.958,00 | 5,30% | 1,075 |
| 90 | B / al entrar / 15 / 1 / 5 | 1.062,00 | 6.171,00 | 7.233,00 | 7,04% | 1,068 |
| 120 | B / al TP / 15 / 3 / 5 | 1.169,00 | 5.426,00 | 6.595,00 | 10,21% | 1,039 |
| 308 | B / al TP / 10 / 5 / 10 | 2.935,00 | 3.407,00 | 6.342,00 | 15,75% | 1,070 |
| 289 | A / al TP / 5 / 4 / 10 | 1.061,00 | 1.496,00 | 2.557,00 | 9,06% | 1,035 |
| 449 | A / al TP / 5 / 4 / 15 | 61,00 | 26,00 | 87,00 | 10,05% | 1,001 |
