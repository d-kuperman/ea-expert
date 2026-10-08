# SETUP B 1.12 — riesgo por porcentaje del balance

El fuente actual es `SETUP_B.mq5` en la raíz del proyecto. La versión 1.12 no
se compiló; el `SETUP_B.ex5` existente corresponde a una compilación anterior.
Esta versión sustituye `InpLots` por el cálculo automático de lotes según el
porcentaje del balance y la distancia entre entrada y SL. Los archivos antiguos
de `Script Astra` conservan sus versiones anteriores.

## Parámetros del grupo Ejecución

| Parámetro | Inicial | Uso |
|---|---:|---|
| Riesgo: 0=fijo al 1%; >0=multiplicador por SL (base 1%) | 0.0 | 0 mantiene el 1% por orden; un valor positivo aplica la progresión. |
| Identificador exclusivo de este EA | 26100702 | Separa el historial de esta estrategia. |

El riesgo base queda fijado al 1%; se eliminaron su entrada y el booleano de
riesgo variable. El multiplicador se valida siempre: debe ser finito y >= 0.
Con 0 no se aplica la progresión ni se consulta el historial de stops.
Un valor 1 mantiene el porcentaje; uno mayor que 1 lo aumenta; uno entre 0 y 1
lo reduce. Al cargar ajustes anteriores, revisar `InpRiskMultiplier`: ahora su
valor determina directamente si se usa riesgo fijo o variable.

## Progresión

`riesgo actual = 1% × multiplicador ^ cantidad de stops` (multiplicador > 0)

Con base 1 y multiplicador 1.10: 1%, 1.10%, 1.21%, 1.331%, 1.4641%…
La operación número 20, después de 19 stops, usa 6.115909…%, que se muestra
como 6.12% al redondear a dos decimales. El cálculo no redondea el porcentaje
después de cada stop.

- Un cierre completo por SL con pérdida incrementa el contador una vez, aunque
  tenga varias ejecuciones parciales.
- Un cierre completo con ganancia neta reinicia el contador, incluido un cierre
  manual de una posición del EA. El resultado neto incluye comisión, swap y fee
  registrados en sus deals.
- Un SL colocado en breakeven o en beneficio no incrementa el contador, aunque
  haya gastos o un pequeño deslizamiento negativo. Un cierre manual con pérdida
  tampoco lo incrementa.
- No se reinicia por cambio de día. Al reiniciar el EA se reconstruye la secuencia
  usando el historial disponible de sus posiciones, por símbolo y Magic.
  Se incluyen operaciones anteriores con ese identificador. Para una secuencia
  independiente, usar un Magic distinto.
- Evitar compartir símbolo y posición netting con otras estrategias: las
  operaciones sobre una misma posición forman un resultado conjunto.

El importe se calcula sobre el balance al enviar o reemplazar cada orden.
Por ejemplo, con balance de 10.000 y riesgo de 1%, el objetivo es 100. Si luego
del stop el balance es 9.900, el 1.10% corresponde a 108,90.
El porcentaje es **por orden**, no el total combinado de ambas entradas.

## Volumen y pendientes

La pérdida estimada entre entrada y SL se convierte a moneda de la cuenta con
[OrderCalcProfit](https://www.mql5.com/en/docs/trading/ordercalcprofit).
Los lotes se redondean hacia abajo al paso permitido. Si el volumen requerido
queda fuera del mínimo/máximo del símbolo, se omite la orden y se informa en el
Diario. También se comprueban margen y restricciones del bróker. No se impone un
tope adicional a la progresión. El riesgo calculado excluye futuros gastos y
deslizamientos de ejecución.

Cuando cambia el porcentaje, el EA intenta ajustar las pendientes propias que
todavía no se ejecutaron, incluida la segunda entrada tras un stop. Conserva
entrada, SL, TP, vencimiento y día original del setup para mantener la lógica de
cancelación. No cambia el volumen de posiciones abiertas ni de pendientes que
ya tuvieron una ejecución parcial.

El ajuste ocurre en el siguiente tick y requiere cancelar y volver a colocar la
orden: no es una operación atómica del servidor. Si falla la validación previa
o la cancelación, la pendiente original se conserva y se vuelve a evaluar. Si
la cancelación se confirma pero la reposición falla o no se puede verificar que
la original no tuvo ejecuciones, puede quedar sin pendiente; se registra en el
Diario y no se reenvía automáticamente. Si se detecta el evento de cancelación
del setup, no se repone. Una orden que el servidor ejecute antes de poder
cancelarla conserva su volumen anterior.

## Verificación del 7 de octubre de 2026

- Versión 1.12 sin compilar, por pedido del usuario. El registro
  `SETUP_B.compile.log` corresponde a una compilación anterior.
- **55 comprobaciones de riesgo** y **19 de cancelación** aprobadas.
- El verificador extrae las funciones del fuente actual y las ejecuta en C#,
  adaptando sintaxis y sustituyendo APIs de MT5 por simuladores. Comprueba
  progresión, ganancias, BE, parciales, reinicios, filtro de estrategia,
  lotes, límites, rechazo de solicitudes y conservación del día del setup.
- No es un backtest de MT5 ni una prueba contra un servidor. No se enviaron
  órdenes reales durante la validación.

Repetir desde la raíz del proyecto con Python y Windows PowerShell:

```powershell
python validation/check_variable_risk.py
```

Las propiedades de cierre utilizadas se describen en la
[referencia de deals de MetaQuotes](https://www.mql5.com/en/docs/constants/tradingconstants/dealproperties).
