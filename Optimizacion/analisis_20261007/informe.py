from analizar import *
import html, re

def n(v,d=2):
    return f'{float(v):,.{d}f}'.replace(',','~').replace('.',',').replace('~','.')
def table(headers,rows):
    return '| '+' | '.join(headers)+' |\n| '+' | '.join(['---']*len(headers))+' |\n'+ '\n'.join('| '+' | '.join(map(str,r))+' |' for r in rows)+'\n'
def cfg(r):
    return f"{'A' if r.InpUseRangeA=='true' else 'B'} / {'al TP' if r.InpCancelSecondEntry=='false' else 'al entrar'} / {r.InpStopLossPips:g} / {r.InpRiskReward:g} / {r.InpBreakevenPips:g}" if r.InpAutoBreakeven=='true' else f"{'A' if r.InpUseRangeA=='true' else 'B'} / {'al TP' if r.InpCancelSecondEntry=='false' else 'al entrar'} / {r.InpStopLossPips:g} / {r.InpRiskReward:g} / apagado"

merged=M.merge(PAIR,on=PARAMS,validate='one_to_one')
selected=[457,141,445,461,125,137,473,296]
summary_rows=[]
for code,label in [('F25','2025 original'),('F26','2026 original'),('V26_control','2026 nuevo: porcentaje fijo'),('V26_variable','2026 nuevo: progresión 1,10')]:
    s=SUMMARY[code]
    summary_rows.append([label,s['n'],f"{s['positive']} ({n(s['positive']/s['n']*100,1)}%)",n(s['profit_median']),n(s['profit_max']),n(s['dd_median'])+'%',n(s['dd_max'])+'%'])

candidate_rows=[]
for p in selected:
    r=M.loc[M.Pass_25==p].iloc[0]
    candidate_rows.append([str(p),cfg(r),n(r.Profit_25),n(r.Profit_26),n(r.sum_independent_profit),n(r['Equity DD %_25'])+'%',n(r['Equity DD %_26'])+'%',n(r['Profit Factor_25'],3),n(r['Profit Factor_26'],3)])

new_rows=[]
for p in selected:
    r=merged.loc[merged.Pass_25==p].iloc[0]
    new_rows.append([p,f'{int(r.Pass_F)} / {int(r.Pass_V)}',n(r.Profit_F),n(r.Profit_V),n((r.Profit_V/r.Profit_F-1)*100,1)+'%',n(r['Equity DD %_F'])+'%',n(r['Equity DD %_V'])+'%',n(r['Recovery Factor_F'],3)+' / '+n(r['Recovery Factor_V'],3)])

neighbors=[]
for p in selected:
    r=M[M.Pass_25==p].iloc[0]
    fam=M[(M.InpUseRangeA==r.InpUseRangeA)&(M.InpCancelSecondEntry==r.InpCancelSecondEntry)&(M.InpAutoBreakeven==r.InpAutoBreakeven)]
    near=fam[((fam.InpStopLossPips-r.InpStopLossPips).abs()/5+(fam.InpRiskReward-r.InpRiskReward).abs()+(fam.InpBreakevenPips-r.InpBreakevenPips).abs()/5)==1]
    neighbors.append([p,len(near),int(near.both_positive.sum()),n(near.Profit_25.min()),n(near.Profit_25.median()),n(near.Profit_26.min())])

core=M.query("InpUseRangeA=='true' & InpCancelSecondEntry=='false' & InpAutoBreakeven=='true' & InpRiskReward==4 & InpStopLossPips>=15")
core_rows=[[int(r.Pass_25),n(r.InpStopLossPips,0),n(r.InpBreakevenPips,0),n(r.Profit_25),n(r.Profit_26),n(r.max_period_DD)+'%'] for _,r in core.sort_values(['InpStopLossPips','InpBreakevenPips']).iterrows()]

stress=[]
for count in [5,10,15,20,25,30]:
    stress.append([count,n(1.1**count,3)+'%',n((1-.99**count)*100)+'%',n((1-np.prod([1-.01*1.1**i for i in range(count)]))*100)+'%'])

report=f'''# Análisis de las optimizaciones de SETUP_B

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

{table(['Grupo','Casos','Con beneficio','Beneficio mediano USD','Máximo USD','DD mediano','DD máximo'],summary_rows)}

En los originales, **2025 fue el filtro exigente**: solo 52 de 320 combinaciones ganan, frente a 278 en 2026. Solamente **49 de 320 —15,31%— ganan en ambos**. De las 52 que ganaron en 2025, 49 también ganan en 2026; la situación inversa es mucho menos selectiva.

La correlación de rangos del beneficio entre períodos es **0,162**, calculada como correlación de Pearson entre los rangos medios de las 320 observaciones emparejadas. Es una asociación débil. Entre las diez configuraciones con mayor beneficio de 2026, cinco pierden en 2025. Entre las veinte mejores de 2026, once pierden en 2025. Las diez mejores de 2025 ganan en 2026, aunque esto sigue siendo una revisión retrospectiva.

Estas proporciones describen la malla elegida. **No son la tasa de acierto de las operaciones ni probabilidades de ganar en el futuro.** Las medianas de grupos con distinto espacio RR tampoco son una comparación causal de los modelos de riesgo.

## 4. Comparación de los candidatos principales

La configuración se expresa como **Rango / cancelación de la segunda entrada / SL / RR / BE**. Los precios se expresan en pips y el beneficio en USD. Todos parten de USD 100.000 en cada test.

{table(['Pase original','Configuración','Beneficio 2025','Beneficio 2026 parcial','Suma descriptiva','DD 2025','DD 2026','PF 2025','PF 2026'],candidate_rows)}

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

{table(['Pase original','Pases nuevos fijo / variable','Beneficio fijo USD','Beneficio variable USD','Mejora de beneficio','DD fijo','DD variable','Recovery fijo / variable'],new_rows)}

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

{table(['Pase','SL','BE','Beneficio 2025 USD','Beneficio 2026 USD','Mayor DD de los períodos'],core_rows)}

Eso respalda la familia de RR 4 y SL 15–20. Sin embargo, ampliar a RR 3 ya introduce pérdidas, y la familia A/cancelación al TP/BE activo completa tiene solo 20 de 60 combinaciones positivas en ambos. **No hay una meseta amplia de robustez demostrada.** Esta región se identificó mirando los resultados; es evidencia exploratoria, no una validación independiente.

## 7. Sensibilidad local: qué ocurre al mover un parámetro

Para cada candidato, tomé vecinos existentes a un único paso de la malla: SL ±5, RR ±1 o BE ±5, sin cambiar los otros parámetros ni los booleanos. No incluí la configuración central. En bordes hay menos vecinos y no se extrapolan valores fuera de la malla.

{table(['Pase','Vecinos','Positivos en ambos','Peor beneficio vecino 2025 USD','Mediana vecinos 2025 USD','Peor vecino 2026 USD'],neighbors)}

**141 tiene la mejor combinación de ganancia y estabilidad local entre estos candidatos:** sus cuatro vecinos ganan en ambos, y el peor vecino en 2025 aún gana USD 4.855. En 125 también ganan los cuatro, pero uno apenas gana USD 186, muy expuesto a pequeños cambios de costos. En 457 ganan cuatro de cinco; bajar RR de 4 a 3 con SL 15/BE 15 arroja −USD 1.588 en 2025. No considero 457 inmune al sobreajuste.

En 445 solo dos de cuatro vecinos ganan en ambos, aunque su punto central es el mejor de 2025. En 461 un vecino —RR 5— pierde USD 14.780 en 2025. Esta sensibilidad explica por qué no elijo automáticamente el máximo de beneficio acumulado descriptivo.

La falta de vecinos por encima de SL 20 y de BE 15 es una limitación de la malla. Un óptimo en un borde no confirma dónde termina la región favorable. Para robustez, la prueba posterior debe evaluar pequeñas perturbaciones predefinidas, sin sustituir continuamente la configuración por el nuevo máximo.

## 8. Cómo crece realmente el riesgo variable

El código actual usa **riesgo por orden = 1% × 1,10^n**, donde n cuenta los stops adversos desde la última posición cerrada con beneficio neto. Los stops en BE no aumentan el contador por sí mismos. Un cierre neto positivo reinicia la secuencia; no se reinicia automáticamente al cambiar de día. Se reconstruye desde el historial del símbolo/Magic.

La siguiente tabla es un **escenario mecánico hipotético**, no una racha observada ni su probabilidad. Supone una sola posición cada vez, cada SL pierde exactamente el porcentaje calculado del balance, sin gastos, deslizamiento, restricciones de lotes/margen ni ganancias intermedias.

{table(['SL consecutivos completados','Riesgo de la siguiente orden','Pérdida acumulada al 1% fijo','Pérdida acumulada progresiva'],stress)}

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

'''
all_rows=[]
for _,r in M[M.both_positive].sort_values('sum_independent_profit',ascending=False).iterrows():
    all_rows.append([int(r.Pass_25),cfg(r),n(r.Profit_25),n(r.Profit_26),n(r.sum_independent_profit),n(r.max_period_DD)+'%',n(r.min_period_PF,3)])
report+=table(['Pase','Rango / cancelación / SL / RR / BE','Beneficio 2025 USD','Beneficio 2026 USD','Suma USD','Mayor DD','PF mínimo'],all_rows)

(OUT/'INFORME_OPTIMIZACIONES.md').write_text(report,encoding='utf-8')

# Self-contained reading copy, without network resources or spreadsheet changes.
def inline(s):
    s=html.escape(s)
    s=re.sub(r'\[([^\]]+)\]\((https?://[^)]+)\)',r'<a href="\2">\1</a>',s)
    s=re.sub(r'\*\*([^*]+)\*\*',r'<strong>\1</strong>',s)
    s=re.sub(r'`([^`]+)`',r'<code>\1</code>',s)
    return s
parts=[]; lines=report.splitlines(); i=0
while i<len(lines):
    line=lines[i]
    if not line: i+=1; continue
    if line.startswith('| '):
        group=[]
        while i<len(lines) and lines[i].startswith('| '): group.append(lines[i]); i+=1
        headers=[inline(x.strip()) for x in group[0].strip('|').split('|')]
        rows=[[inline(x.strip()) for x in row.strip('|').split('|')] for row in group[2:]]
        assert all(len(row)==len(headers) for row in rows)
        parts.append('<div class="table-wrap"><table><thead><tr>'+''.join('<th>'+h+'</th>' for h in headers)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+c+'</td>' for c in row)+'</tr>' for row in rows)+'</tbody></table></div>')
        continue
    if line.startswith('#'):
        level=len(line)-len(line.lstrip('#'));parts.append(f'<h{level}>'+inline(line[level:].strip())+f'</h{level}>')
    elif line.startswith('- '):parts.append('<p class="item">• '+inline(line[2:])+'</p>')
    else:parts.append('<p>'+inline(line)+'</p>')
    i+=1
page='''<!doctype html><html lang="es"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Análisis de optimizaciones SETUP_B</title><style>
body{font:16px/1.65 system-ui,Segoe UI,Arial,sans-serif;color:#202a39;background:#f4f5f7;margin:0}main{max-width:1200px;margin:30px auto;padding:48px;background:white;box-shadow:0 2px 18px #17213010}h1{font-size:34px;line-height:1.2;letter-spacing:-.6px;color:#163f66}h2{font-size:24px;margin-top:44px;padding-top:22px;border-top:1px solid #dce2e9;color:#163f66}h3{font-size:19px;margin-top:28px}p{max-width:100ch}strong{color:#173b58}a{color:#176bb1}code{background:#eef2f6;padding:2px 5px;border-radius:4px;font-size:.9em}.table-wrap{overflow:auto;margin:22px 0}table{border-collapse:collapse;font-size:13px;width:100%;font-variant-numeric:tabular-nums}th{background:#163f66;color:white;text-align:left;font-weight:600;padding:11px 12px;line-height:1.4}td{padding:10px 12px;border-bottom:1px solid #e1e6eb;white-space:nowrap}tr:nth-child(even){background:#f4f7fa}.item{margin:5px 0}@media(max-width:800px){main{margin:0;padding:24px 18px}h1{font-size:29px}}@media print{body{background:white}main{margin:0;padding:0;box-shadow:none}table{font-size:9px}th,td{padding:5px}h2,h3{break-after:avoid}tr{break-inside:avoid}.table-wrap{overflow:visible}}
</style><main>'''+''.join(parts)+'</main></html>'
(OUT/'INFORME_OPTIMIZACIONES.html').write_text(page,encoding='utf-8')
assert len(all_rows)==49
assert len(merged)==192
print('Informe generado:',len(report.split()),'palabras;',len(all_rows),'candidatos en anexo.')
print('Checks: original file hashes unchanged:',all(hashlib.sha256((ROOT/FILES[k]).read_bytes()).hexdigest()==META[k]['sha256'] for k in FILES))
print('Candidato 457 nuevo:',merged.loc[merged.Pass_25==457,['Return_DD_F','Return_DD_V','Recovery Factor_F','Recovery Factor_V']].to_dict('records'))
