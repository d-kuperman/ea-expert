# EURUSD — compresión de Londres dentro de Asia

Script estadístico MQL5 para MetaTrader 5. No contiene funciones para enviar órdenes, no administra posiciones, no optimiza parámetros y no utiliza indicadores de tendencia. ATR14 y ADR20 se calculan aritméticamente, únicamente como contexto solicitado.

## Archivos entregados

- `EURUSD_AsiaLondonCompression.mq5`: fuente completo, independiente y sin includes.
- `EURUSD_AsiaLondonCompression.ex5`: ejecutable compilado.
- `EURUSD_AsiaLondonCompression.compile.log`: resultado de MetaEditor.
- Esta guía: decisiones metodológicas e instrucciones.
- `EURUSD_AsiaLondonCompression_Columnas.md`: listado literal de todas las columnas, extraído de CSV generados por el script.
- `validation/`: evidencia de pruebas con datos artificiales. No es un estudio histórico de EURUSD.

## Ambigüedades resueltas antes de implementar

### Precisión y fuente de precios

`CopyRates(StudySymbol, PERIOD_M1, ...)` obtiene las velas del bróker. No se utiliza el timeframe del gráfico. En Forex, normalmente estas velas representan Bid; el script conserva la fuente OHLC del bróker sin reconstruir Ask.

M1 **no permite obtener el segundo exacto ni el tick exacto de un máximo, mínimo o breakout**, ni permite conocer siempre el orden intravela. Todos los timestamps de eventos son el inicio de la vela M1 correspondiente. Si hay varios máximos/mínimos iguales, se conserva el primero. Un tiempo de cero minutos significa “en la misma vela”, no latencia cero en ticks.

`FirstBreakPrice`, `HighBreakPrice` y `LowBreakPrice` son el **nivel asiático tocado**, no un precio de ejecución real. El open de la vela de ruptura también se exporta. Si comienza más allá del nivel, `*BreakGap=true` y las simulaciones R de ese lado quedan `NA_GAP`; no se presupone una entrada al nivel que el precio saltó.

### Reloj, fecha y sesiones

Todas las fechas de estudio y CSV están en el reloj fijo `UTCOffset=-3`; no se ajusta ese reloj a horario de verano. Los nombres Londres/NY identifican las ventanas configuradas, no horarios de mercados ajustados automáticamente por país.

`Date` corresponde al día de inicio de NY. Asia se busca hacia atrás desde Londres, y Londres hacia atrás desde NY. Las sesiones tienen inicio incluido y fin excluido:

| Sesión | Inputs por defecto | Velas incluidas |
|---|---|---|
| Asia | 20 → 4 | Día anterior 20:00 hasta día de estudio 03:59 |
| Londres | 4 → 8 | 04:00 hasta 07:59 |
| NY | 8 → 14 | 08:00 hasta 13:59 |

La vela de las 14:00 se excluye porque contiene movimientos posteriores al cierre de la ventana. Para incluir también esa vela completa se necesitaría extender la ventana; esta versión configura horas enteras. Se aceptan sesiones que cruzan medianoche siempre que respeten Asia → Londres → NY y todo el tramo abarque como máximo 24 horas. Un fin igual al inicio significa una sesión de 24 horas y será rechazado si el conjunto supera ese límite.

`Price0800` es el open de la vela al comienzo de NY. Si se modifica `NYStartHour`, ese campo sigue el nuevo horario por compatibilidad con el esquema pedido; `Price0800Time` deja constancia. Si esa vela falta, el precio queda vacío. No se reemplaza por el close anterior ni por la primera vela posterior.

Las distancias al extremo alto/bajo son algebraicas: `AsiaHigh - Price0800` y `Price0800 - AsiaLow`. Pueden ser negativas si NY abre fuera del rango. Las posiciones no se recortan artificialmente a [0,1].

### Conversión desde la hora del servidor

**Es obligatorio configurar el desfase histórico del bróker.** La hora actual del servidor no permite deducir con seguridad varios años de cambios de horario. `ServerUTCOffsetMinutes=999` es un centinela que impide una ejecución mal alineada; no representa un offset válido.

- Servidor fijo UTC+2: `ServerUTCOffsetMinutes=120`.
- Servidor fijo UTC+3: `ServerUTCOffsetMinutes=180`.
- Cambios históricos: completar `ServerOffsetSchedule` con instantes **UTC**, ordenados y únicos, usando `YYYY.MM.DD HH:MM=minutos`, separados por `;`.
- La primera entrada debe preceder todo el warmup. Si se proporciona una tabla, reemplaza al offset fijo.

Ejemplo exclusivamente de sintaxis, **no calendario de ningún bróker**:

```text
2019.01.01 00:00=120;2020.03.29 01:00=180;2020.10.25 01:00=120
```

La tabla necesita todos los cambios relevantes de los años analizados y debe proceder de información del bróker. El código divide las solicitudes de históricos en cada transición. Si un retraso del reloj repite minutos del servidor, esos minutos se consideran no utilizables; M1 no distingue de forma inequívoca ambas ocurrencias. No se inventa una regla europea o estadounidense.

### Setup y calidad de datos

El setup se define exclusivamente con Asia y Londres:

```text
LondonHigh < AsiaHigh AND LondonLow > AsiaLow
```

La igualdad invalida. No hay tolerancia de pips ni filtro adicional. La validez del setup no consulta NY ni el contexto diario.

Cada minuto esperado debe tener una vela M1 válida. La ausencia de una vela puede ser un hueco del histórico o un minuto sin ticks: el script no puede distinguirlo y no rellena precios. La política es deliberadamente estricta para poder afirmar que se observó **toda** la ventana.

- Asia/Londres incompletos: `SetupStatus=UNKNOWN`, `SetupValid` vacío.
- Asia de rango cero: no evaluable, se impiden divisiones por cero.
- Asia/Londres completos: `VALID` o `INVALID`, aunque NY esté incompleto.
- NY incompleto: se conservan extremos observados y cobertura; no se calculan resultados de breakout, MFE/MAE ni R.
- Sábado/domingo: una fila `WEEKEND`, sin estudio de sesiones.
- Día sin datos/feriado: fila no evaluable; no se transforma en setup inválido ni en `NO_BREAK`.
- Ventana aún no cerrada: solo se cargan velas cerradas al comenzar la ejecución; queda incompleta.

Los extremos de una sesión incompleta son **observados parciales**, no su rango verdadero. Revisar `*Complete`, `*MissingBars`, `*MaxGapMinutes`, `*BadBars` y `DataStatus` antes de usarlos.

### Clasificación y primer breakout

Se considera ruptura tanto el toque como el cruce: high ≥ AsiaHigh o low ≤ AsiaLow. Se exportan las cinco clases solicitadas más `BOTH_ORDER_AMBIGUOUS`.

Si ambas rupturas aparecen por primera vez en la misma vela:

- Open ≥ AsiaHigh: primero HIGH.
- Open ≤ AsiaLow: primero LOW.
- Open dentro de Asia: no hay orden demostrable; `FirstBreakDirection=AMBIGUOUS` y clase `BOTH_ORDER_AMBIGUOUS`.

En ese último caso se conoce el minuto inicial y que rompió ambos lados, pero los campos genéricos que dependen de elegir un lado quedan vacíos. Las métricas individuales High/Low sí se calculan. Esta sexta categoría evita convertir artificialmente la incertidumbre en un sesgo direccional.

### MFE, MAE y retorno

Para cada lado se analiza la **primera** ruptura de ese lado hasta el fin de NY. No se reinicia la medición por cada recrossing. Se incluye la vela de ruptura.

- High MFE = máximo high desde la ruptura − AsiaHigh.
- Low MFE = AsiaLow − mínimo low desde la ruptura.
- High MAE = máximo(0, AsiaHigh − mínimo posterior).
- Low MAE = máximo(0, máximo posterior − AsiaLow).

El MAE se mide desde el nivel roto, no desde el máximo beneficio flotante. No es un trailing drawdown. Un MAE cero es posible si nunca vuelve contra el nivel.

El extremo adverso de la vela inicial puede preceder al breakout. Por eso `*BreakMAE_*` es un **límite superior** y `*BreakMAELower_*` un límite inferior. El límite inferior considera el close de la vela inicial y los extremos de las velas posteriores; si la ruptura ya está activa en el open inicial, incluye la vela inicial completa. Si ambos coinciden, el MAE queda resuelto a precisión M1. `*BreakMAEAmbiguous` identifica los casos no resueltos. El resumen ofrece estadísticas de ambos límites.

El retorno exige entrar **estrictamente** entre AsiaLow y AsiaHigh; tocar de nuevo la frontera no basta. Se confirma con una observación OHLC interior demostrablemente posterior a la ruptura. Un extremo interior de la vela inicial puede ser anterior: se marca como posibilidad, no como certeza. Un salto de fuera de un extremo a fuera del otro tampoco demuestra un tick dentro del rango. Se exportan:

- `true`: al menos un retorno confirmado.
- `false`: ningún retorno posible en los OHLC observados.
- `AMBIGUOUS`: solo hay evidencia de retorno posible.
- `*TimeReturnedInsideAsia`: minuto de la primera confirmación.
- `*EarliestPossibleReturnTime`: primer minuto compatible con retorno, incluso si luego se confirma más tarde.

`ReturnedInsideAsia` y los campos genéricos MFE/MAE/tiempos corresponden al **primer lado conocido**. `BreakBothSides` incluye ambos órdenes y el orden incierto. “Fakeout” en los resúmenes significa este retorno al rango; no presupone una operación perdedora ni un cierre final interior.

Para cada lado, `*BreakOppositeAfter` registra si **después de su propia primera ruptura** alcanza la frontera contraria. Incluye recrossings posteriores aunque esa frontera ya hubiese roto antes. Puede ser true, false o AMBIGUOUS por orden intravela. `*OppositeAfterTime` es la primera confirmación y `*EarliestPossibleOppositeTime` el primer minuto compatible. Así, romper ambos lados durante NY no se confunde con haber roto el lado contrario después de cada entrada individual.

### Simulación R

Referencia de entrada teórica: frontera de Asia. Se estudia cada lado y cada target por separado; no se simulan parciales, reentradas ni manejo de posiciones.

| Modelo | Distancia de SL |
|---|---|
| A | LondonRange |
| B | 0.50 × AsiaRange |
| C High | AsiaHigh − LondonLow |
| C Low | LondonHigh − AsiaLow |

En días inválidos, C puede no ser positivo; se marca `INVALID_RISK`. A también puede ser cero. Nunca se toma el valor absoluto para forzar una simulación válida.

Se comprueban 0.5R, 1R, 1.5R, 2R, 2.5R, 3R y 4R antes del SL. Estado de cada combinación:

| Estado | Interpretación | `HitBeforeSL` |
|---|---|---|
| `HIT_BEFORE_SL` | Target inequívocamente antes del SL | true |
| `SL_FIRST` | SL inequívocamente antes del target | false |
| `NOT_REACHED` | No alcanzó ni target ni SL antes de terminar NY | false |
| `AMBIGUOUS` | M1 admite varios resultados | vacío |
| `NO_BREAK` | No hubo ruptura de ese lado | vacío |
| `INVALID_RISK` | SL no positivo | vacío |
| `NA_GAP` | Open inicial saltó el nivel de entrada teórico | vacío |
| `UNAVAILABLE` | Datos insuficientes | vacío |

Se comprueba primero el open de las velas posteriores. Si una vela alcanza objetivo y stop sin orden demostrable, el resultado es ambiguo. Si la vela inicial podría haber tocado el stop después de entrar, esa posibilidad se conserva aunque después alcance el objetivo. No se asume una trayectoria Open→High→Low→Close ni se fuerza “stop primero” o “target primero”. El modelo supone cruce de los niveles entre los extremos OHLC para medir toques; no reconstruye cada tick ni garantiza ejecuciones.

No incluye spread, comisión, slippage, swap ni restricciones de ejecución del bróker. Es una medición geométrica en R, no un backtest de rentabilidad ejecutable.

### Contexto diario

Se reconstruye el día `[00:00,24:00)` de UTC-3 desde M1, para no mezclarlo con las velas D1 del servidor. Se consideran días laborables lunes–viernes. “Día anterior” significa el día laborable anterior; un lunes refiere al viernes. No se incorporan velas parciales del domingo.

- Dirección: UP si close > open; DOWN si close < open; FLAT si iguales.
- True range: máximo de high−low, abs(high−close anterior), abs(low−close anterior).
- ATR14: Wilder, semilla media de 14 TR y después `(13×ATRprev + TR)/14`.
- ADR20: promedio de rangos de los 20 días laborables anteriores consecutivos con observaciones.
- El contexto del día actual se asigna **antes** de incorporar sus OHLC: no contiene futuro respecto al inicio de NY.
- Warmup por defecto: 120 días calendario. El ATR puede cambiar ligeramente con otra longitud de warmup por el efecto de su semilla.

El cierre semanal, pausas del bróker o huecos pueden dejar días con menos de 1.440 velas. El rango contextual usa las observaciones disponibles y lo informa mediante `PreviousDayCoveragePct`, `Context20MinCoveragePct` y `ContextQuality=OBSERVED_M1_PARTIAL`. **No se afirma que ese contexto esté libre de huecos.** Un día laborable totalmente ausente interrumpe la cadena ATR/ADR y obliga a reconstruir el warmup. No se sustituye por un día más antiguo para completar N. Estas columnas no filtran setups.

## Arquitectura y rendimiento

1. Validar horarios, fechas y mapa horario del servidor.
2. Leer M1 con `CopyRates`, reintentos acotados para sincronización y conversión por segmentos de offset.
3. Mantener hasta tres días M1 en memoria y acumular contexto diario ligero.
4. Separar sesiones, comprobar cobertura y evaluar inclusión estricta de Londres.
5. Medir NY, ambos breakouts, incertidumbre intravela y 42 combinaciones R.
6. Escribir una fila Daily por fecha solicitada.
7. Agregar exclusivamente setups válidos con NY completo; exportar las tablas y metadatos.

La descarga puede tardar, y está limitada por el histórico del bróker y `TERMINAL_MAXBARS`. La versión 1.01 comprueba **antes de sobrescribir Daily** que el límite de barras cubra todo el período M1 solicitado más el warmup; también prueba si existen velas cerca del inicio y del final. Si falla, escribe `Diagnostic.csv` con `MAX_BARS_TOO_LOW`, `HISTORY_START_UNAVAILABLE` o `HISTORY_END_UNAVAILABLE`. Un límite suficiente no garantiza que el bróker conserve los datos: hay que observar la cobertura real de Daily. `HistoryRetries` no puede recuperar datos que el servidor no ofrece.

El Journal muestra warmup, progreso `días procesados/días solicitados`, errores de archivos y ruta final. Una interrupción puede dejar archivos parciales; comprobar siempre `RunMetadata.RunStatus=COMPLETE` antes de analizar una ejecución. `CANCELLED_PARTIAL` significa que MT5 retiró o detuvo el script antes de finalizar; `LastWrittenDate` indica hasta dónde llegó. Dejar abierto el gráfico y la instancia hasta ver `Research COMPLETE`. `COMPLETE` confirma que terminó la ejecución, **no** que todos los días tengan cobertura completa.

## CSV generados y denominadores

Para `StudySymbol=EURUSD`, prefijo `EURUSD_AsiaLondonCompression_`:

| Archivo | Filas y finalidad |
|---|---|
| `Daily.csv` | Una por fecha calendario inclusiva, incluso inválidos, no evaluables y fines de semana |
| `Summary.csv` | Una fila con conteos de calidad y estadística global de válidos |
| `ByCompression.csv` | Los 8 intervalos de compresión pedidos |
| `ByLondonPosition.csv` | Los 5 intervalos de LondonMidPosition pedidos |
| `ByPrice0800Position.csv` | Los 5 intervalos pedidos + BELOW_ASIA y ABOVE_ASIA |
| `CompressionPriceCross.csv` | 8×7 = 56 combinaciones + 2 cruces explícitos `<0.30 / >0.80` y `<0.30 / <0.20` |
| `ByWeekday.csv` | Monday, Tuesday, Wednesday, Thursday y Friday |
| `ByVolatility.csv` | 18 filas: AsiaRange, ATR14 y ADR20, cada uno en 6 intervalos de pips |
| `RunMetadata.csv` | Pares Key/Value con inputs, convenciones, versión y estado |

Los intervalos incluyen el borde inferior y excluyen el superior, excepto el último [0.8,1], que incluye 1. Las dos filas especiales del cruce se solapan con las 56 filas base: **no se deben sumar todas las filas juntas**. Sus desigualdades son estrictas según el ejemplo pedido.

Volatilidad: `[0,20)`, `[20,40)`, `[40,60)`, `[60,80)`, `[80,100)`, `[100,+inf)` pips. Son intervalos descriptivos fijos, no ajustados buscando resultados. Los datos diarios permiten otros cortes posteriormente. No se elige ni recomienda una combinación “mejor”.

`TotalDays` excluye fines de semana pero incluye laborables sin datos. Se cumple:

```text
TotalDays = ValidSetups + InvalidSetups + UnknownSetupDays
ValidSetupPercentage = 100 × ValidSetups / EvaluableSetupDays
EvaluableSetupDays = ValidSetups + InvalidSetups
```

`ValidSetupsWithCompleteNY` es el denominador de todas las estadísticas de resultados agrupadas. `ValidSetupsMissingNY` documenta la exclusión por falta de observación posterior. Los descriptivos agrupados de Asia/Londres también usan ese mismo conjunto para facilitar comparación homogénea.

HighFirstPct y LowFirstPct tienen como denominador todos los casos del grupo, incluyendo NO_BREAK y orden ambiguo. Las cinco clases solicitadas más BOTH_ORDER_AMBIGUOUS suman 100% cuando hay muestras. BothSidesPct es una propiedad adicional y no se suma a esas clases.

Cada variable exporta su propio `_N`. MFE/MAE/expansión genéricos excluyen días sin ruptura o sin primer lado conocido; no se rellenan con cero. El tiempo al primer breakout sí se conoce cuando ambos lados rompen en el mismo minuto. MFE alcista/bajista se condiciona a que ese lado haya roto.

`FakeoutLowerPct` = retornos confirmados / primeras rupturas de lado conocido. `FakeoutUpperPct` incluye también los retornos ambiguos. Los casos con primer lado ambiguo no entran en estos denominadores.

Mediana y percentiles: interpolación lineal tipo 7 sobre índice `(N−1)×p`. Un grupo vacío conserva su fila y conteos cero; porcentajes y métricas quedan vacíos. Datos vacíos nunca equivalen a cero.

## Columnas

El listado literal y ordenado de cada CSV está en **`EURUSD_AsiaLondonCompression_Columnas.md`**. Convenciones generales:

- Precios y rangos sin sufijo de unidad: unidades de cotización, por ejemplo 0.00100.
- `Points`: dividido por `SYMBOL_POINT`.
- `Pips`: para 5/3 dígitos, 1 pip = 10 points; para 4/2 dígitos, 1 pip = 1 point. En EURUSD de 5 dígitos, 0.00100 = 100 points = 10 pips.
- `PctAsia`: 100 × excursión / AsiaRange.
- `Ratio` / `NormalizedExpansion`: cociente, no porcentaje; 0.5 significa medio rango.
- Fechas/horas: `YYYY.MM.DD HH:MM:SS` en UTCOffset; eventos con precisión de minuto.
- CSV UTF-8, coma como delimitador, punto decimal, cadenas entre comillas.

Familias de Daily: identificación y calidad; cobertura/extremos de Asia/Londres/NY; compresión/posición; precio inicial/distancias; clasificación; métricas High/Low; 3 modelos × 7 targets × 2 lados (estado + booleano); métricas de primer breakout; contexto diario y calidad.

Familias de las tablas agrupadas: grupo/subgrupo; cantidad; direcciones; ambos lados; sin ruptura; incertidumbre; retorno; clases; y N/media/mediana/P25/P50/P75/P90/P95 para 11 variables. Summary agrega conteos globales al mismo esquema. RunMetadata tiene solo `Key` y `Value`.

## Instalación y ejecución exacta

1. Abrir la instancia de MT5 del bróker cuyo histórico se desea estudiar.
2. Menú **Archivo → Abrir carpeta de datos**.
3. Copiar `EURUSD_AsiaLondonCompression.mq5` a `MQL5\Scripts\` de esa carpeta. Se puede copiar también el `.ex5` entregado.
4. Abrir el `.mq5` en MetaEditor y pulsar **F7**. Verificar 0 errores y 0 warnings.
5. En MT5, **Herramientas → Opciones → Gráficos → Máx. barras en gráfico**: configurar un límite suficiente para todos los años M1 y reiniciar MT5 si lo solicita. El script informa el mínimo concreto en `MAX_BARS_TOO_LOW`. Para 2020-01-01 a 2026-10-06 con 120 días de warmup exige **al menos 3.735.360**; usar un valor mayor, por ejemplo 5.000.000. El límite anterior de 100.000 impidió observar 2020.
6. En **Observación del mercado**, mostrar el símbolo exacto del bróker (`EURUSD`, `EURUSD.a`, etc.). Con conexión al servidor, se puede solicitar M1 desde **Símbolos → Barras** para precargar el histórico y comprobar sus fechas disponibles.
7. Abrir cualquier gráfico y timeframe. En **Navegador → Scripts**, actualizar si es necesario y arrastrar el script al gráfico. El gráfico puede ser de otro timeframe; `StudySymbol` selecciona el instrumento analizado.
8. Configurar `StartDate` y `EndDate` en fechas del reloj UTC-3, ambas inclusivas. Se ignora la parte horaria de esos dos inputs.
9. Configurar `StudySymbol` y **obligatoriamente** `ServerUTCOffsetMinutes` o `ServerOffsetSchedule`. Con el valor inicial 999 y sin tabla, el script termina explicando el motivo en el Journal.
10. Mantener los horarios predeterminados o ajustar las horas sabiendo que los fines son exclusivos. Mantener `UTCOffset=-3` para este estudio.
11. Dejar `RunSelfTestsOnly=false`. Opcionalmente establecer `RunTag`, por ejemplo `EURUSD_2020_2025_brokerA`, para separar ejecuciones. El mismo directorio y prefijo se sobrescriben al repetir una ejecución.
12. Aceptar. No necesita DLL, WebRequest ni autorización para enviar órdenes. Puede mantenerse desactivado **Algo Trading**: el script no opera.
13. Revisar **Caja de herramientas → Expertos/Diario** hasta el mensaje `Research COMPLETE`. Abrir `RunMetadata.csv` y revisar `RunStatus`, luego los conteos de cobertura de Summary y Daily.

No se ejecuta como EA en el Probador de Estrategias: es un script de ejecución única sobre histórico. Se retira del gráfico al terminar.

### Ubicación de salida

Por defecto:

```text
<carpeta de datos de ESA instancia de MT5>\MQL5\Files\AsiaLondonCompression\
```

Si se indicó RunTag:

```text
<carpeta de datos>\MQL5\Files\AsiaLondonCompression\<RunTag>\
```

Con `UseCommonFiles=true`:

```text
%APPDATA%\MetaQuotes\Terminal\Common\Files\AsiaLondonCompression\[RunTag\]
```

El Journal imprime la ruta absoluta real. No se guardan por defecto al lado del fuente ni en la carpeta de instalación de Program Files. La separación entre carpeta del terminal y carpeta común sigue [FileOpen de MQL5](https://www.mql5.com/en/docs/files/fileopen).

Si falla la configuración horaria, el símbolo, el límite de barras o la disponibilidad de M1 **antes** de iniciar el estudio, aparece una alerta y se escribe `<prefijo>Diagnostic.csv` en esa carpeta, con `TimeUTC,Code,Detail,Symbol,StartDate,EndDate`. En ese caso no se crean nuevos Daily ni Summary; los CSV de ejecuciones anteriores permanecen y pueden estar incompletos. La pestaña **Expertos** también muestra `RESEARCH STOPPED` y la ruta exacta. Un fallo posterior de escritura se informa en Expertos como `CSV write failure`.

### Pruebas sintéticas reproducibles

Ejecutar el mismo script con `RunSelfTestsOnly=true`. No necesita offset de servidor ni descarga históricos. Comprueba detección, límites de sesiones, igualdad invalidante, clasificación, MAE/R ambiguos, conversiones, gaps, contexto y esquema CSV. Escribe CSV artificiales en `MQL5\Files\AsiaLondonCompression_SelfTests\` (o Common si se activó).

El resultado esperado del Journal es `SELF TESTS: ALL PASSED, failures=0`. Volver a `RunSelfTestsOnly=false` para estudiar mercado. Los CSV de pruebas llevan `RunStatus=SYNTHETIC_TEST_DATA` y no deben mezclarse con resultados históricos.

## Limitaciones que afectan la interpretación

1. M1 no satisface literalmente “hora/precio exactos” a nivel tick. Los casos intravela no resueltos se conservan como tales. Una futura versión con ticks podría resolver parte de esa incertidumbre si el bróker los conserva.
2. Necesita un mapa horario histórico correcto del servidor. No se ha supuesto el offset de tu cuenta.
3. La cobertura estricta puede excluir bastantes días, incluso minutos sin ticks. Comparar valid/invalid exige revisar primero la calidad y la distribución de exclusiones.
4. El contexto usa OHLC diario observado y permite días parciales explícitamente etiquetados; un viernes corto por cierre semanal no equivale a 24 horas negociadas.
5. MAE principal es un límite superior cuando la vela inicial introduce incertidumbre. Compararlo junto al límite inferior; no leerlo como valor exacto si `MAEAmbiguous=true`.
6. Las simulaciones R son referencias geométricas sin costes ni garantía de fill. Los valores ambiguos/vacíos no son pérdidas ni victorias.
7. No se han ejecutado varios años reales del bróker ni se ha validado empíricamente la hipótesis con esta entrega. Compilación y pruebas sintéticas verifican software; el estudio real requiere sus datos y configuración horaria.
8. No se hacen recomendaciones, búsqueda de mejores bins ni optimización. Las tablas cruzadas son descriptivas y pueden contener pocas muestras.

La carga, orden cronológico y límites de disponibilidad se basan en la documentación oficial de [CopyRates](https://www.mql5.com/en/docs/series/copyrates); la precisión proviene de la estructura [MqlRates](https://www.mql5.com/en/docs/constants/structures/mqlrates).
