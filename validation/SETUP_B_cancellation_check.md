# Validación de cancelación — SETUP_B 1.09

Se comprobaron 17 escenarios con órdenes y deals simulados. Las funciones
`SetupOrderAlreadyExists`, `GetExecutedSetup`, `CancelOppositeSetupOrder`,
`GetSetupCancellation`, `SetupHasCancellation` y `PlaceSetupOrders` se extrajeron
del fuente MQL5 y se ejecutaron en C# con adaptaciones de sintaxis (`ref`, aliases
de enums/fecha y construcción de estructuras). Las APIs de MT5 se sustituyeron
por simuladores. Esta prueba verifica las decisiones de la lógica; no es un
backtest ni una prueba de ejecución contra un servidor MT5.

Resultado: **17 escenarios aprobados**. Incluye ambos lados con cancelación
inmediata, conservar la pendiente tras entrada/SL/BE, cancelación por TP,
otros setups/identificadores, vínculo con la posición original, reinicio después
de SL/TP, ambos lados cerrados por SL sin reposición y reintento tras rechazo.

Repetir desde la carpeta del proyecto en una nueva sesión de PowerShell:

```powershell
Add-Type -Path 'validation\SETUP_B_cancellation_check.cs'
[SetupCancellationCheck]::Run()
```
