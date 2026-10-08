# Detector FVG opuestos de cinco velas — versión 1.00

Archivo principal: FVG_Opuestos_5Velas.mq5. Es autónomo, sin includes, indicadores ni llamadas de trading.

## Reglas exactas

V1..V5 están ordenadas de la más antigua a la más reciente.

| Patrón | Dirección V1,V2,V3,V4,V5 | FVG de V1–V3 | FVG de V3–V5 |
|---|---|---|---|
| Bajista | +,+,-,-,- | Alcista: Low(V3) > High(V1) | Bajista: High(V5) < Low(V3) |
| Alcista | -,-,+,+,+ | Bajista: High(V3) < Low(V1) | Alcista: Low(V5) > High(V3) |

+ significa Close > Open; - significa Close < Open. Se usan extremos completos.
Ambos huecos deben ser estrictamente positivos. Un contacto exacto no es FVG.
No se exige igualdad de tamaños, igualdad de límites exteriores ni confirmación posterior.

V3: Body = abs(Close - Open); UpperWick = High - max(Open, Close);
LowerWick = min(Open, Close) - Low; TotalRange = High - Low.
Porcentajes = 100 × magnitud / TotalRange.

| Parámetro | Inicial | Condición |
|---|---:|---|
| InpMaxBodyPct | 20 | Body% <= límite |
| InpMinDominantWickPct | 60 | Mecha dominante% >= límite |
| InpMaxOppositeWickPct | 10 | Mecha opuesta% <= límite |
| InpMinWickBodyRatio | 3 | Mecha dominante / Body >= límite; 0 lo desactiva |

Dominante = superior en bajista, inferior en alcista. Opuesta = la otra.
La relación 3:1 cuantifica la longitud respecto al cuerpo; es redundante con
60% mínimo de mecha y 20% máximo de cuerpo, pero queda independiente para optimizar.
Además, con cuerpo <=20% y mecha opuesta <=10%, la dominante resulta al menos 70%,
por lo que el mínimo de 60% también es redundante con los valores iniciales.
Se excluyen dojis exactos y rangos cero en las cinco velas.

## Uso en MetaTrader 5

1. Copiar el .mq5 a MQL5/Experts de la carpeta de datos del terminal.
2. Abrirlo en MetaEditor y compilar con F7; también se entrega el .ex5 compilado.
3. Seleccionarlo en el Probador, elegir símbolo, temporalidad y fechas.
4. Activar modo visual para revisar los dibujos. No necesita permiso de trading para detectar.
5. Consultar el Journal para la ruta CSV y los totales por dirección.

Usa únicamente _Symbol y _Period. No existe una temporalidad alternativa configurable.
En el primer tick analiza la última ventana de cinco velas ya cerradas disponible;
no recorre todo el historial precargado. Después avanza con cada cierre.
V1–V4 pueden estar antes del inicio de la prueba como contexto.
La primera ventana puede tener V5 justo antes de iniciar el EA.

Se lee CopyRates desde shift >=1. El OHLC de la vela en curso nunca participa.
El inicio de la siguiente barra permite reconocer el cierre de V5; no se espera su cierre.
No se registra de nuevo una V5 ya evaluada durante la misma ejecución. Si una lectura
de historia es incompleta, se reintenta; se recuperan ventanas pendientes en orden.
No se corrigen ni se recalculan hallazgos anteriores.
Si el backtest termina sin un tick posterior al cierre de su última vela, esa vela
no llega a evaluarse como V5.

## Gráfico

Marco de las cinco velas, etiquetas V1–V5 y marco dorado para V3.
FVG alcista verde y bajista rojo, con colores configurables.
El primer FVG se rellena y el segundo se dibuja como contorno para distinguir
su posible superposición. Los rectángulos abarcan sus tripletas y no se prolongan.
El título indica ALCISTA o BAJISTA y candidato iFVG.
Se conservan los dibujos al finalizar. En pruebas sin modo visual se omiten
los objetos para ahorrar recursos. InpDrawPatterns=false también los desactiva.

## CSV

InpSaveCSV=true lo activa. Cada ejecución genera un archivo nuevo, sin sobrescribir
resultados anteriores ni mezclar pasadas de optimización.

Por defecto: MQL5/Files/FVG_Opuestos_5Velas dentro de la carpeta del terminal,
o dentro de la carpeta del agente cuando se usa el Probador.
InpUseCommonFolder=true utiliza Terminal/Common/Files/FVG_Opuestos_5Velas.
La ruta se imprime al inicializar. Para recuperar archivos localmente, usar agentes locales.

UTF-8, separador punto y coma, punto decimal. Contiene 50 columnas:
hora V3; cierre V5; instante de detección; símbolo; temporalidad; dirección;
estado CANDIDATO_IFVG; hora y OHLC de cada vela; cuerpo, ambas mechas y rango
en unidades de precio; sus porcentajes; tamaños de FVG en puntos; extremos
de ambas zonas; tamaño de _Point; los cuatro parámetros de geometría.

Las fechas son del servidor, no de la zona horaria de Windows.
confirmation_v5_close es el final nominal del intervalo de V5; no significa
inversión confirmada del FVG. detected_at es el tick que detectó el patrón
y puede ser posterior por pausas de sesión o por lectura diferida del historial.
Cada tamaño en puntos se calcula como (límite superior - límite inferior) / _Point.

Los contadores corresponden a la ejecución actual. Se imprimen al detectar
y al finalizar, incluyendo ejecuciones con cero patrones. Reiniciar el EA crea
otra ejecución y otro CSV; no conserva contadores entre reinicios.
Un fallo de apertura impide iniciar; un fallo de escritura detiene el detector
con un mensaje para evitar perder registros silenciosamente.

## Validación realizada

MetaEditor: 0 errores y 0 advertencias; ver FVG_Opuestos_5Velas.compile.log.
Pruebas reproducibles: node FVG_Opuestos_5Velas.test.cjs.
66 comprobaciones, incluida una prueba de simetría con 1000 variaciones.
Cubren patrones en ambas direcciones, extremos/tamaños de FVG, contacto exacto,
falta de cada hueco, umbrales inclusivos, ratio, dojis, rangos cero,
direcciones incorrectas y datos OHLC inconsistentes.

Las pruebas extraen DetectPattern del .mq5 y traducen mecánicamente sus tipos
y funciones matemáticas a JavaScript. No sustituyen ejecutar el EA en MT5.
No se realizó un backtest histórico ni verificación visual dentro del Probador.

Referencias de API: [CopyRates](https://www.mql5.com/en/docs/series/copyrates),
[FileOpen](https://www.mql5.com/en/docs/files/fileopen),
[OBJ_RECTANGLE](https://www.mql5.com/en/docs/constants/objectconstants/enum_object/obj_rectangle).
