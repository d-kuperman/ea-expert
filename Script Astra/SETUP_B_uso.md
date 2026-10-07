# SETUP B — versión 1.05

El EA confirma SETUP B cuando cierran A y B y se cumple `MAX_B <= MAX_A` y
`MIN_B >= MIN_A`. Tocar los extremos está permitido, como en la versión anterior.
El cartel ahora dice **SETUP B**. Las velas Heikin Ashi son visuales: los niveles
de entrada se calculan con los precios reales de las barras M15.

## Parámetros

| Grupo | Entrada | Valor inicial |
|---|---|---|
| BUY / SELL STOP | SL en pips | 10 |
| BUY / SELL STOP | RR | 2 |
| BE Automático | Activar BE automático | false (No) |
| BE Automático | Activación en pips | 10 |
| Ejecución | Volumen de cada orden en lotes | 0,01 |
| Ejecución | Identificador exclusivo de este EA | 26100702 |

Para activar el BE, seleccionar `true` (Sí). El lote debe respetar el mínimo,
máximo y paso admitidos por el símbolo. Usar un identificador distinto para
otras instancias o estrategias sobre el mismo símbolo.

## Órdenes

- Buy stop en MAX_A: SL = MAX_A − SL_pips; TP = MAX_A + SL_pips × RR.
- Sell stop en MIN_A: SL = MIN_A + SL_pips; TP = MIN_A − SL_pips × RR.
- Los pips se convierten a precio antes de aplicar esas fórmulas. En símbolos
  de 5 o 3 decimales, un pip equivale a 10 puntos; en los demás, a un punto.
  Esta es la convención Forex; revisar su interpretación para otros activos.
- SL y TP se redondean al tick admitido por el símbolo. No se desplaza el
  extremo de entrada si no es representable como un precio válido.
- Hay un intento por lado y día, en el primer tick con el setup confirmado
  y los permisos de trading disponibles. No se envían órdenes por los días
  históricos que se dibujan. Si se inicia el EA después del cierre de B,
  puede operar el setup del día actual.
- Las órdenes son independientes, sin cancelación del lado contrario, y GTC
  (sin vencimiento automático solicitado por el EA). Pueden quedar pendientes
  de días anteriores. Se respetan las reglas de vigencia del bróker.
- Las órdenes ya aceptadas ese día, incluso ejecutadas, canceladas o expiradas,
  se consultan para evitar reponerlas después de reiniciar el EA.
- Si un extremo ya fue alcanzado, el spread o la distancia mínima impiden
  colocar la orden, o el bróker rechaza la solicitud, se informa en el Diario.
  No se transforma la entrada en una operación de mercado ni se repite el
  intento en cada tick. Las dos solicitudes son independientes: una puede
  ser aceptada y la otra rechazada.

Ejemplo EURUSD: MAX_A = 1,10000; MIN_A = 1,09000; SL = 10 pips; RR = 2.
Buy: entrada 1,10000, SL 1,09900, TP 1,10200.
Sell: entrada 1,09000, SL 1,09100, TP 1,08800.

## Breakeven

En cada tick, al alcanzar el avance configurado desde el precio real de
apertura, el SL pasa al precio de entrada y el TP se conserva. Se utiliza
Bid para compras y Ask para ventas. No se empeora un SL que ya esté en BE
o en beneficio. Si las distancias de stops o congelación del bróker impiden
el cambio, se vuelve a evaluar en ticks posteriores.

El BE se aplica sólo al símbolo y al identificador del EA. Es BE de precio:
no agrega compensación por comisiones o swap. En cuentas netting, las
ejecuciones sobre un mismo símbolo afectan la posición neta; para posiciones
long y short independientes se necesita una cuenta hedging.

Las solicitudes y restricciones de precios usan las APIs documentadas por
[MetaQuotes](https://www.mql5.com/en/docs/constants/structures/mqltraderequest)
y las [propiedades del símbolo](https://www.mql5.com/en/docs/constants/environment_state/marketinfoconstants).

## Validación y archivos

- `SETUP_B.mq5`: fuente editable.
- `SETUP_B.ex5`: ejecutable compilado, versión 1.05.
- `SETUP_B.compile.log`: compilación del 7 de octubre de 2026, **0 errores y
  0 advertencias**.
- `validation/build_setup_b_tests.py`: genera pruebas MQL5 con cotizaciones,
  órdenes y posiciones simuladas, extrayendo las funciones de trading del
  fuente. Todas las APIs de trading de esas funciones son sustituidas por
  simuladores; las pruebas no envían órdenes reales.

El script de pruebas compiló, pero no llegó a ejecutarse: la primera instancia
aislada no inicializó el script y el segundo intento de ejecución no fue
autorizado. **No se declara un backtest ni una prueba funcional aprobada.**
Los ejecutables anteriores ubicados en otras carpetas no se reemplazaron.
