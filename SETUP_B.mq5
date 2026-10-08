//+------------------------------------------------------------------+
//|                                                 SETUP_B.mq5 |
//|                                  Copyright 2026, Dany            |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Dany"
#property link      "https://www.mql5.com"
#property version   "1.14"
#property description "Asesor Experto con velas normales M15, Rangos A, B, C y división de días (UTC+3 The5ers) [Optimizado]"

//+------------------------------------------------------------------+
//| Parámetros de entrada                                            |
//+------------------------------------------------------------------+
input group "-- ENTRADAS RANGO_A / RANGO_B ---"
input bool     InpUseRangeA      = true;            // RANGO_A (true) / RANGO_B (false)
input bool     InpCancelSecondEntry = true;         // TRUE CANCELA LA ORDEN PENDIENTE - FALSE CANCELA AL CERRAR
input bool     InpKeepPendingOrders = false;        // Mantener pendientes tras el cierre del día (false=cancelar)

input group "--- BUY / SELL STOP ---"
input double   InpStopLossPips   = 10.0;            // SL en pips
input double   InpRiskReward     = 2.0;             // RR

input group "--- BE Automático ---"
input double   InpBreakevenPips  = 0.0;             // Activación BE en pips (0=apagado; >0=encendido)

input group "--- Ejecución ---"
input double   InpRiskMultiplier = 0.0;            // Riesgo: 0=fijo al 1%; >0=multiplicador por SL (base 1%)
input ulong    InpMagicNumber   = 26100702;         // Identificador exclusivo de este EA

//--- RANGO_A ---
input group "--- RANGO_A ---"
input string   InpStartTimeA     = "02:00";          // Horario inicio RANGO_A
input string   InpEndTimeA       = "10:00";          // Horario fin RANGO_A
input color    InpColorA         = C'222,219,186';   // Color de fondo RANGO_A (222,219,186)

//--- RANGO_B ---
input group "--- RANGO_B ---"
input string   InpStartTimeB     = "10:00";          // Horario inicio RANGO_B
input string   InpEndTimeB       = "14:00";          // Horario fin RANGO_B
input color    InpColorB         = C'189,200,230';   // Color de fondo RANGO_B (189,200,230)

//--- RANGO_C ---
input group "--- RANGO_C ---"
input string   InpStartTimeC     = "14:00";          // Horario inicio RANGO_C
input string   InpEndTimeC       = "20:00";          // Horario fin RANGO_C
input color    InpColorC         = C'229,196,193';   // Color de fondo RANGO_C (229,196,193)

//--- Lienzo ---
input group "--- Lienzo ---"
input color    InpBgColor        = C'219,219,219';   // Color de fondo del lienzo (#dbdbdb)

//--- Visualización Adicional ---
input group "--- Visualización Adicional ---"
input int      InpMaxBars        = 500;              // Barras M15 históricas para los rangos
input bool     InpShowSeparators = true;             // Mostrar línea punteada divisoria de días
input color    InpSeparatorColor = C'120,120,120';   // Color línea divisoria de días
input bool     InpShowLabels     = true;             // Mostrar etiquetas con MAX y MIN

//+------------------------------------------------------------------+
//| Constantes y prefijos de objetos                                 |
//+------------------------------------------------------------------+
#define OBJ_PREFIX "EA_HA_"
const double BASE_RISK_PERCENT = 1.0; // Riesgo inicial y tras una ganancia (% del balance por orden)

//+------------------------------------------------------------------+
//| Variables globales para los extremos de los rangos               |
//+------------------------------------------------------------------+
double MAX_A = 0.0, MIN_A = 0.0;
double MAX_B = 0.0, MIN_B = 0.0;
double MAX_C = 0.0, MIN_C = 0.0;

bool   HAS_RANGO_A = false;
bool   HAS_RANGO_B = false;
bool   HAS_RANGO_C = false;

// Estado diario. Las órdenes se envían sólo desde OnTick, nunca al dibujar historia.
bool g_setup_b_today = false;
bool g_setup_evaluated_today = false;
bool g_setup_orders_processed = false;
datetime g_last_be_error = 0;
datetime g_last_oco_check = 0;
datetime g_last_oco_error = 0;
datetime g_last_expiry_error = 0;
datetime g_last_expiry_check = 0;
bool g_risk_dirty = true;
double g_risk_percent = 0.0;
double g_pending_risk_percent = -1.0;
datetime g_last_risk_check = 0;

// Se agrupan ejecuciones parciales: una posición cerrada cuenta una sola vez.
struct RiskPosition
{
   ulong id;
   double volume;
   double entry_price;
   double net_profit;
   bool is_buy;
   bool losing_stop;
};

// Detección de entorno y control de gráficos
bool g_is_tester       = false;
bool g_is_visual       = false;
bool g_enable_graphics = true;

// Segundos desde medianoche (00:00 UTC+3) para cada rango
int g_sec_start_a = 0, g_sec_end_a = 0;
int g_sec_start_b = 0, g_sec_end_b = 0;
int g_sec_start_c = 0, g_sec_end_c = 0;

// Estado del historial y detección de nuevas barras M15 para los rangos
datetime g_last_bar_time = 0;
bool g_history_ready = false;

// Registro del día actual procesado
datetime g_current_day = 0;

// Configuración original del gráfico para restaurar en OnDeinit
long  g_orig_mode        = 0;
long  g_orig_bg          = 0;
long  g_orig_fg          = 0;
long  g_orig_grid        = 0;
long  g_orig_sep         = 0;
long  g_orig_candle_bull = 0;
long  g_orig_candle_bear = 0;
long  g_orig_chart_down  = 0;
long  g_orig_chart_up    = 0;

// Control de refresco visual
ulong g_last_redraw_time = 0;

//+------------------------------------------------------------------+
//| Parser de horario en formato "HH:MM"                             |
//+------------------------------------------------------------------+
bool ParseTimeString(string time_str, int &hour, int &minute)
{
   string parts[];
   int count = StringSplit(time_str, ':', parts);
   if(count < 2)
   {
      PrintFormat("[EA_Rangos_HA] Formato de hora inválido '%s'. Debe ser 'HH:MM'", time_str);
      return false;
   }
   hour   = (int)StringToInteger(parts[0]);
   minute = (int)StringToInteger(parts[1]);
   if(hour < 0 || hour > 23 || minute < 0 || minute > 59)
   {
      PrintFormat("[EA_Rangos_HA] Horario '%s' fuera de rango (00:00 - 23:59)", time_str);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Retorna 00:00:00 (UTC+3) correspondiente a una fecha/hora dada   |
//+------------------------------------------------------------------+
datetime GetDayStart(datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Guarda configuración original del gráfico                        |
//+------------------------------------------------------------------+
void SaveOriginalChart()
{
   g_orig_mode        = ChartGetInteger(0, CHART_MODE);
   g_orig_bg          = ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   g_orig_fg          = ChartGetInteger(0, CHART_COLOR_FOREGROUND);
   g_orig_grid        = ChartGetInteger(0, CHART_SHOW_GRID);
   g_orig_sep         = ChartGetInteger(0, CHART_SHOW_PERIOD_SEP);
   g_orig_candle_bull = ChartGetInteger(0, CHART_COLOR_CANDLE_BULL);
   g_orig_candle_bear = ChartGetInteger(0, CHART_COLOR_CANDLE_BEAR);
   g_orig_chart_down  = ChartGetInteger(0, CHART_COLOR_CHART_DOWN);
   g_orig_chart_up    = ChartGetInteger(0, CHART_COLOR_CHART_UP);
}

//+------------------------------------------------------------------+
//| Restaura configuración original del gráfico                      |
//+------------------------------------------------------------------+
void RestoreOriginalChart()
{
   ChartSetInteger(0, CHART_MODE, g_orig_mode);
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, (color)g_orig_bg);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, (color)g_orig_fg);
   ChartSetInteger(0, CHART_SHOW_GRID, (bool)g_orig_grid);
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, (bool)g_orig_sep);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, (color)g_orig_candle_bull);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, (color)g_orig_candle_bear);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, (color)g_orig_chart_down);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, (color)g_orig_chart_up);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Aplica el estilo visual requerido al gráfico                     |
//+------------------------------------------------------------------+
void SetupChart()
{
   // Fondo gris clarito #dbdbdb y texto en negro para contraste
   ChartSetInteger(0, CHART_COLOR_BACKGROUND, InpBgColor);
   ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrBlack);
   
   // Sin cuadrícula ni separadores nativos
   ChartSetInteger(0, CHART_SHOW_GRID, false);
   ChartSetInteger(0, CHART_SHOW_PERIOD_SEP, false);
   
   // Velas japonesas nativas de MT5, basadas en los precios reales.
   ChartSetInteger(0, CHART_MODE, CHART_CANDLES);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, C'34,139,34');
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, C'178,34,34');
   ChartSetInteger(0, CHART_COLOR_CHART_UP, C'34,139,34');
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, C'178,34,34');

   // Espacio a la derecha para ver velas en formación
   ChartSetInteger(0, CHART_SHIFT, true);
   ChartSetDouble(0, CHART_SHIFT_SIZE, 10.0);
   
   // Asegurar timeframe M15 si está en gráfico en vivo
   if(Period() != PERIOD_M15)
   {
      Print("[EA_Rangos_HA] Ajustando gráfico a periodicidad M15...");
      ChartSetSymbolPeriod(0, _Symbol, PERIOD_M15);
   }
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Dibuja la línea divisoria punteada para el inicio del día (00:00)|
//+------------------------------------------------------------------+
void DrawDaySeparator(datetime day_start)
{
   if(!g_enable_graphics || !InpShowSeparators) return;
   
   string name = OBJ_PREFIX + "SEP_" + TimeToString(day_start, TIME_DATE);
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_VLINE, 0, day_start, 0);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_COLOR, InpSeparatorColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, "Día nuevo: " + TimeToString(day_start, TIME_DATE) + " 00:00 (UTC+3)");
   }
}

//+------------------------------------------------------------------+
//| Dibuja o actualiza un rectángulo de rango                        |
//+------------------------------------------------------------------+
void DrawRangeRectangle(string range_id, datetime t_start, datetime t_end, double max_price, double min_price, color bg_color, string tag)
{
   if(!g_enable_graphics) return;
   if(max_price <= 0 || min_price <= 0 || min_price > max_price) return;
   
   string name = OBJ_PREFIX + range_id;
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t_start, max_price, t_end, min_price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, bg_color);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true); // Detrás de las velas
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);   // Prioridad visual inferior
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   else
   {
      ObjectMove(0, name, 0, t_start, max_price);
      ObjectMove(0, name, 1, t_end, min_price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, bg_color);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   }
   
   string tooltip = tag + "\n" +
                    "Horario: " + TimeToString(t_start, TIME_MINUTES) + " - " + TimeToString(t_end, TIME_MINUTES) + " (UTC+3)\n" +
                    "MAX: " + DoubleToString(max_price, _Digits) + "\n" +
                    "MIN: " + DoubleToString(min_price, _Digits) + "\n" +
                    "Amplitud: " + DoubleToString((max_price - min_price)/_Point, 1) + " pts";
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}

//+------------------------------------------------------------------+
//| Dibuja o actualiza la etiqueta de texto en el rango              |
//+------------------------------------------------------------------+
void DrawRangeLabel(string label_id, datetime t_start, double max_price, string text)
{
   if(!g_enable_graphics || !InpShowLabels) return;
   
   string name = OBJ_PREFIX + label_id;
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_TEXT, 0, t_start, max_price);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 2);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   else
   {
      ObjectMove(0, name, 0, t_start, max_price);
   }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| Evalúa precios reales y declara SETUP B si Rango B               |
//| cotiza íntegramente dentro de Rango A                            |
//+------------------------------------------------------------------+
void EvaluateDaySetup(datetime day_start, datetime evaluation_time, bool is_today)
{
   datetime start_a = day_start + g_sec_start_a;
   datetime end_a   = day_start + g_sec_end_a;
   datetime start_b = day_start + g_sec_start_b;
   datetime end_b   = day_start + g_sec_end_b;
   if(evaluation_time < end_a || evaluation_time < end_b)
      return;
   if(is_today && g_setup_evaluated_today)
      return;
   if(end_a <= start_a || end_b <= start_b)
      return;

   // Leer de nuevo los rangos cerrados evita decidir con el último tick parcial
   // y permite evaluar días cuyo comienzo quedó fuera de InpMaxBars.
   MqlRates range_rates[];
   ArraySetAsSeries(range_rates, false);
   datetime first = (datetime)MathMin(start_a, start_b);
   datetime last  = (datetime)MathMax(end_a, end_b);
   int count = CopyRates(_Symbol, PERIOD_M15, day_start, last - 1, range_rates);
   if(count <= 0 || range_rates[0].time > first)
      return; // Historia incompleta: no declarar un setup.

   double max_a = -DBL_MAX, min_a = DBL_MAX;
   double max_b = -DBL_MAX, min_b = DBL_MAX;
   bool has_a = false, has_b = false;
   for(int i = 0; i < count; i++)
   {
      datetime t = range_rates[i].time;
      if(t >= start_a && t < end_a)
      {
         has_a = true;
         max_a = MathMax(max_a, range_rates[i].high);
         min_a = MathMin(min_a, range_rates[i].low);
      }
      if(t >= start_b && t < end_b)
      {
         has_b = true;
         max_b = MathMax(max_b, range_rates[i].high);
         min_b = MathMin(min_b, range_rates[i].low);
      }
   }
   if(!has_a || !has_b)
      return;

   bool setup_b = (max_b <= max_a && min_b >= min_a);
   if(is_today)
   {
      // Usar también para las entradas los extremos definitivos recién leídos.
      MAX_A = max_a; MIN_A = min_a; HAS_RANGO_A = true;
      MAX_B = max_b; MIN_B = min_b; HAS_RANGO_B = true;
      g_setup_b_today         = setup_b;
      g_setup_evaluated_today = true;
   }

   if(!g_enable_graphics)
      return;

   string name = OBJ_PREFIX + "SETUP_B_" + TimeToString(day_start, TIME_DATE);
   if(!setup_b)
   {
      ObjectDelete(0, name);
      return;
   }

   // Cartel independiente de InpShowLabels, centrado por encima de RANGO_B.
   datetime center = start_b + (end_b - start_b) / 2;
   double label_price = max_b + MathMax((max_b - min_b) * 0.08, 10 * _Point);
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, center, label_price);
   else
      ObjectMove(0, name, 0, center, label_price);
   ObjectSetString(0, name, OBJPROP_TEXT, "SETUP B");
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 11);
   ObjectSetInteger(0, name, OBJPROP_COLOR, C'178,34,34');
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LOWER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Procesa y dibuja los 3 rangos para un día específico             |
//+------------------------------------------------------------------+
void ProcessDayRanges(datetime day_start, const MqlRates &rates[], int total_rates, bool is_today)
{
   if(g_enable_graphics)
      DrawDaySeparator(day_start);
   
   datetime t_start_a = day_start + g_sec_start_a;
   datetime t_end_a   = day_start + g_sec_end_a;
   
   datetime t_start_b = day_start + g_sec_start_b;
   datetime t_end_b   = day_start + g_sec_end_b;
   
   datetime t_start_c = day_start + g_sec_start_c;
   datetime t_end_c   = day_start + g_sec_end_c;
   
   double max_a = 0.0, min_a = DBL_MAX;
   double max_b = 0.0, min_b = DBL_MAX;
   double max_c = 0.0, min_c = DBL_MAX;
   
   bool has_a = false, has_b = false, has_c = false;
   
   for(int i = 0; i < total_rates; i++)
   {
      datetime bt = rates[i].time;
      
      // RANGO_A
      if(bt >= t_start_a && bt < t_end_a)
      {
         has_a = true;
         if(rates[i].high > max_a) max_a = rates[i].high;
         if(rates[i].low  < min_a) min_a = rates[i].low;
      }
      
      // RANGO_B
      if(bt >= t_start_b && bt < t_end_b)
      {
         has_b = true;
         if(rates[i].high > max_b) max_b = rates[i].high;
         if(rates[i].low  < min_b) min_b = rates[i].low;
      }
      
      // RANGO_C
      if(bt >= t_start_c && bt < t_end_c)
      {
         has_c = true;
         if(rates[i].high > max_c) max_c = rates[i].high;
         if(rates[i].low  < min_c) min_c = rates[i].low;
      }
   }
   
   string date_str = "";
   if(g_enable_graphics)
      date_str = TimeToString(day_start, TIME_DATE);
   
   if(has_a)
   {
      if(g_enable_graphics)
      {
         DrawRangeRectangle("RNG_A_" + date_str, t_start_a, t_end_a, max_a, min_a, InpColorA, "RANGO_A");
         DrawRangeLabel("LBL_A_" + date_str, t_start_a, max_a, " RANGO_A [MAX: " + DoubleToString(max_a, _Digits) + " | MIN: " + DoubleToString(min_a, _Digits) + "]");
      }
      if(is_today)
      {
         MAX_A = max_a;
         MIN_A = min_a;
         HAS_RANGO_A = true;
      }
   }
   
   if(has_b)
   {
      if(g_enable_graphics)
      {
         DrawRangeRectangle("RNG_B_" + date_str, t_start_b, t_end_b, max_b, min_b, InpColorB, "RANGO_B");
         DrawRangeLabel("LBL_B_" + date_str, t_start_b, max_b, " RANGO_B [MAX: " + DoubleToString(max_b, _Digits) + " | MIN: " + DoubleToString(min_b, _Digits) + "]");
      }
      if(is_today)
      {
         MAX_B = max_b;
         MIN_B = min_b;
         HAS_RANGO_B = true;
      }
   }
   
   if(has_c)
   {
      if(g_enable_graphics)
      {
         DrawRangeRectangle("RNG_C_" + date_str, t_start_c, t_end_c, max_c, min_c, InpColorC, "RANGO_C");
         DrawRangeLabel("LBL_C_" + date_str, t_start_c, max_c, " RANGO_C [MAX: " + DoubleToString(max_c, _Digits) + " | MIN: " + DoubleToString(min_c, _Digits) + "]");
      }
      if(is_today)
      {
         MAX_C = max_c;
         MIN_C = min_c;
         HAS_RANGO_C = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Inicializa el historial M15 y los rangos diarios                 |
//+------------------------------------------------------------------+
bool InitHistory()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, false); // Index 0 = más antiguo, copied-1 = actual
   int copied = CopyRates(_Symbol, PERIOD_M15, 0, InpMaxBars, rates);
   if(copied <= 1)
   {
      if(g_enable_graphics)
         PrintFormat("[EA_Rangos_HA] Esperando datos históricos de M15 (disponibles: %d)...", copied);
      return false;
   }
   
   g_last_bar_time = rates[copied - 1].time;

   // Procesamiento de días históricos y rangos
   datetime unique_days[];
   int day_count = 0;
   datetime last_d = 0;
   
   for(int i = 0; i < copied; i++)
   {
      datetime d = GetDayStart(rates[i].time);
      if(d != last_d)
      {
         last_d = d;
         day_count++;
         ArrayResize(unique_days, day_count);
         unique_days[day_count - 1] = d;
      }
   }
   
   datetime today = GetDayStart(rates[copied - 1].time);
   g_current_day = today;
   
   for(int i = 0; i < day_count; i++)
   {
      bool is_today = (unique_days[i] == today);
      ProcessDayRanges(unique_days[i], rates, copied, is_today);
      EvaluateDaySetup(unique_days[i], rates[copied - 1].time, is_today);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Actualiza en vivo los rangos de la sesión actual                 |
//+------------------------------------------------------------------+
void UpdateLiveRanges(const MqlRates &cur_bar, bool is_new_bar)
{
   datetime now = cur_bar.time;
   datetime today = GetDayStart(now);
   
   // Cambio de día a las 00:00 UTC+3
   if(today != g_current_day)
   {
      g_current_day = today;
      g_setup_b_today = false;
      g_setup_evaluated_today = false;
      g_setup_orders_processed = false;
      HAS_RANGO_A = false;
      HAS_RANGO_B = false;
      HAS_RANGO_C = false;
      MAX_A = 0.0; MIN_A = 0.0;
      MAX_B = 0.0; MIN_B = 0.0;
      MAX_C = 0.0; MIN_C = 0.0;
      
      DrawDaySeparator(today);
      if(g_enable_graphics)
         PrintFormat("[EA_Rangos_HA] === Nuevo día detectado: %s 00:00 (UTC+3) ===", TimeToString(today, TIME_DATE));
   }
   
   datetime t_start_a = today + g_sec_start_a;
   datetime t_end_a   = today + g_sec_end_a;
   datetime t_start_b = today + g_sec_start_b;
   datetime t_end_b   = today + g_sec_end_b;
   datetime t_start_c = today + g_sec_start_c;
   datetime t_end_c   = today + g_sec_end_c;
   string date_str    = "";
   if(g_enable_graphics)
      date_str = TimeToString(today, TIME_DATE);
   
   // --- RANGO_A ---
   if(now >= t_start_a && now < t_end_a)
   {
      bool changed = false;
      if(!HAS_RANGO_A)
      {
         HAS_RANGO_A = true;
         MAX_A = cur_bar.high;
         MIN_A = cur_bar.low;
         changed = true;
         if(g_enable_graphics)
            PrintFormat("[EA_Rangos_HA] Iniciando RANGO_A para %s", date_str);
      }
      else
      {
         if(cur_bar.high > MAX_A) { MAX_A = cur_bar.high; changed = true; }
         if(cur_bar.low  < MIN_A) { MIN_A = cur_bar.low;  changed = true; }
      }
      // Actualizar objetos sólo si hubo un nuevo extremo o abrió una nueva vela
      if(g_enable_graphics && (changed || is_new_bar))
      {
         DrawRangeRectangle("RNG_A_" + date_str, t_start_a, t_end_a, MAX_A, MIN_A, InpColorA, "RANGO_A");
         DrawRangeLabel("LBL_A_" + date_str, t_start_a, MAX_A, " RANGO_A [MAX: " + DoubleToString(MAX_A, _Digits) + " | MIN: " + DoubleToString(MIN_A, _Digits) + "]");
      }
   }
   
   // --- RANGO_B ---
   if(now >= t_start_b && now < t_end_b)
   {
      bool changed = false;
      if(!HAS_RANGO_B)
      {
         HAS_RANGO_B = true;
         MAX_B = cur_bar.high;
         MIN_B = cur_bar.low;
         changed = true;
         if(g_enable_graphics)
            PrintFormat("[EA_Rangos_HA] Iniciando RANGO_B para %s", date_str);
      }
      else
      {
         if(cur_bar.high > MAX_B) { MAX_B = cur_bar.high; changed = true; }
         if(cur_bar.low  < MIN_B) { MIN_B = cur_bar.low;  changed = true; }
      }
      // Actualizar objetos sólo si hubo un nuevo extremo o abrió una nueva vela
      if(g_enable_graphics && (changed || is_new_bar))
      {
         DrawRangeRectangle("RNG_B_" + date_str, t_start_b, t_end_b, MAX_B, MIN_B, InpColorB, "RANGO_B");
         DrawRangeLabel("LBL_B_" + date_str, t_start_b, MAX_B, " RANGO_B [MAX: " + DoubleToString(MAX_B, _Digits) + " | MIN: " + DoubleToString(MIN_B, _Digits) + "]");
      }
   }
   
   // --- RANGO_C ---
   if(now >= t_start_c && now < t_end_c)
   {
      bool changed = false;
      if(!HAS_RANGO_C)
      {
         HAS_RANGO_C = true;
         MAX_C = cur_bar.high;
         MIN_C = cur_bar.low;
         changed = true;
         if(g_enable_graphics)
            PrintFormat("[EA_Rangos_HA] Iniciando RANGO_C para %s", date_str);
      }
      else
      {
         if(cur_bar.high > MAX_C) { MAX_C = cur_bar.high; changed = true; }
         if(cur_bar.low  < MIN_C) { MIN_C = cur_bar.low;  changed = true; }
      }
      // Actualizar objetos sólo si hubo un nuevo extremo o abrió una nueva vela
      if(g_enable_graphics && (changed || is_new_bar))
      {
         DrawRangeRectangle("RNG_C_" + date_str, t_start_c, t_end_c, MAX_C, MIN_C, InpColorC, "RANGO_C");
         DrawRangeLabel("LBL_C_" + date_str, t_start_c, MAX_C, " RANGO_C [MAX: " + DoubleToString(MAX_C, _Digits) + " | MIN: " + DoubleToString(MIN_C, _Digits) + "]");
      }
   }
}

//+------------------------------------------------------------------+
//| Trading de SETUP B                                               |
//+------------------------------------------------------------------+
double PipSize()
{
   // Convención Forex: 5/3 decimales = 10 puntos por pip; otros = 1 punto.
   return ((_Digits == 3 || _Digits == 5) ? 10.0 : 1.0) * _Point;
}

double RoundTradePrice(double price)
{
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_size <= 0.0) tick_size = _Point;
   return NormalizeDouble(MathRound(price / tick_size) * tick_size, _Digits);
}

bool TradingAllowed()
{
   return TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
          MQLInfoInteger(MQL_TRADE_ALLOWED) &&
          AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) &&
          AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
}

// Conserva el día del setup cuando una pendiente se reemplaza en otro día.
datetime SetupOrderDay(string comment, datetime created)
{
   if(StringFind(comment, "SETUP B ") == 0 && StringLen(comment) >= 18)
   {
      datetime day = StringToTime(StringSubstr(comment, 8, 10));
      if(day > 0) return GetDayStart(day);
   }
   return GetDayStart(created);
}

void ApplyRiskClose(double net_profit, bool losing_stop, int &stops)
{
   if(net_profit > 0.0000001) stops = 0;
   else if(net_profit < -0.0000001 && losing_stop) stops++;
}

// Reconstrucción determinista: reinicios y notificaciones repetidas no duplican SL.
// Sólo se consulta al cambiar el historial o antes de enviar un nuevo setup.
bool RefreshRisk()
{
   if(InpRiskMultiplier <= 0.0)
   {
      g_risk_percent = BASE_RISK_PERCENT;
      g_risk_dirty = false;
      return true;
   }
   if(!g_risk_dirty) return true;
   if(!HistorySelect(0, TimeCurrent())) return false;
   RiskPosition positions[];
   int stops = 0;
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      ENUM_DEAL_TYPE type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
      if(type != DEAL_TYPE_BUY && type != DEAL_TYPE_SELL) continue;
      ulong id = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      if(id == 0) continue;
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      int p = -1;
      for(int j = 0; j < ArraySize(positions); j++)
         if(positions[j].id == id) { p = j; break; }
      if(p < 0)
      {
         if(entry != DEAL_ENTRY_IN ||
            (ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagicNumber) continue;
         p = ArraySize(positions);
         if(ArrayResize(positions, p + 1) != p + 1) return false;
         ZeroMemory(positions[p]);
         positions[p].id = id;
      }
      double volume = HistoryDealGetDouble(deal, DEAL_VOLUME);
      double price = HistoryDealGetDouble(deal, DEAL_PRICE);
      double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
      double costs = HistoryDealGetDouble(deal, DEAL_COMMISSION) +
                     HistoryDealGetDouble(deal, DEAL_SWAP) + HistoryDealGetDouble(deal, DEAL_FEE);
      if(entry == DEAL_ENTRY_IN)
      {
         double total = positions[p].volume + volume;
         if(total <= 0.0) continue;
         positions[p].entry_price = (positions[p].entry_price * positions[p].volume + price * volume) / total;
         positions[p].volume = total;
         positions[p].is_buy = (type == DEAL_TYPE_BUY);
         positions[p].net_profit += profit + costs;
         continue;
      }
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT) continue;
      if(positions[p].volume <= 0.00000001) continue;
      double sl = HistoryDealGetDouble(deal, DEAL_SL);
      bool adverse_sl = sl <= 0.0 || (positions[p].is_buy ?
                        sl < positions[p].entry_price - _Point * 0.1 :
                        sl > positions[p].entry_price + _Point * 0.1);
      if((ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON) == DEAL_REASON_SL &&
         profit < 0.0 && adverse_sl) positions[p].losing_stop = true;
      // En una reversión, repartir la comisión proporcionalmente entre cierre y apertura.
      double remaining = positions[p].volume - volume;
      double close_costs = (entry == DEAL_ENTRY_INOUT && volume > positions[p].volume) ?
                           costs * positions[p].volume / volume : costs;
      positions[p].net_profit += profit + close_costs;
      positions[p].volume = MathMax(0.0, remaining);
      if(positions[p].volume <= 0.00000001)
      {
         ApplyRiskClose(positions[p].net_profit, positions[p].losing_stop, stops);
         positions[p].volume = 0.0;
         positions[p].net_profit = 0.0;
         positions[p].losing_stop = false;
         if(entry == DEAL_ENTRY_INOUT && remaining < -0.00000001)
         {
            positions[p].volume = -remaining;
            positions[p].entry_price = price;
            positions[p].is_buy = (type == DEAL_TYPE_BUY);
            positions[p].net_profit = costs - close_costs;
         }
      }
   }
   double risk = BASE_RISK_PERCENT * MathPow(InpRiskMultiplier, stops);
   if(!MathIsValidNumber(risk) || risk <= 0.0)
   {
      Print("[SETUP B] Riesgo fuera del rango numérico. No se enviarán nuevas órdenes.");
      return false;
   }
   if(risk != g_risk_percent)
      PrintFormat("[SETUP B] Riesgo por orden: %.8f%% del balance (%d SL desde la última ganancia).", risk, stops);
   g_risk_percent = risk;
   g_risk_dirty = false;
   return true;
}

double RiskVolume(double risk_money, double loss_per_lot, double minimum, double maximum, double step)
{
   if(!MathIsValidNumber(risk_money) || risk_money <= 0.0 ||
      !MathIsValidNumber(loss_per_lot) || loss_per_lot <= 0.0 ||
      minimum <= 0.0 || maximum < minimum || step <= 0.0) return 0.0;
   double raw = risk_money / loss_per_lot;
   if(!MathIsValidNumber(raw) || raw < minimum - step * 0.0000001 ||
      raw > maximum + step * 0.0000001) return 0.0;
   // Redondear sólo los lotes, hacia abajo; nunca el porcentaje acumulado.
   double lots = NormalizeDouble(MathFloor(raw / step + 0.0000001) * step, 8);
   if(lots < minimum || lots > maximum) return 0.0;
   return lots;
}

bool CalculateRiskVolume(ENUM_ORDER_TYPE type, double price, double sl, double &volume)
{
   double minimum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maximum = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double loss = 0.0;
   ENUM_ORDER_TYPE market_type = type == ORDER_TYPE_BUY_STOP ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(minimum <= 0.0 || !OrderCalcProfit(market_type, _Symbol, minimum, price, sl, loss) || loss >= 0.0)
   {
      Print("[SETUP B] No se pudo calcular la pérdida al SL en moneda de la cuenta.");
      return false;
   }
   double money = AccountInfoDouble(ACCOUNT_BALANCE) * g_risk_percent / 100.0;
   volume = RiskVolume(money, -loss / minimum, minimum, maximum, step);
   if(volume <= 0.0)
   {
      PrintFormat("[SETUP B] Orden omitida: riesgo %.8f%% incompatible con los límites de volumen del símbolo.", g_risk_percent);
      return false;
   }
   return true;
}

// Busca también órdenes ejecutadas, canceladas o expiradas: nunca reponerlas
// al reiniciar el EA o cambiar sus parámetros durante el mismo día.
bool SetupOrderAlreadyExists(ENUM_ORDER_TYPE type, datetime day_start)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderGetTicket(i) == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) == _Symbol &&
         (ulong)OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) == type &&
         SetupOrderDay(OrderGetString(ORDER_COMMENT), (datetime)OrderGetInteger(ORDER_TIME_SETUP)) == day_start)
         return true;
   }
   for(int i = HistoryOrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryOrderGetString(ticket, ORDER_SYMBOL) == _Symbol &&
         (ulong)HistoryOrderGetInteger(ticket, ORDER_MAGIC) == InpMagicNumber &&
         (ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE) == type &&
         SetupOrderDay(HistoryOrderGetString(ticket, ORDER_COMMENT), (datetime)HistoryOrderGetInteger(ticket, ORDER_TIME_SETUP)) == day_start &&
         (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE) != ORDER_STATE_REJECTED)
         return true;
   }
   return false;
}

// Vencimiento de la pendiente, sin afectar el SL/TP de una posición ejecutada.
void SetPendingExpiry(MqlTradeRequest &request, datetime setup_day)
{
   request.type_time = ORDER_TIME_GTC;
   request.expiration = 0;
   if(InpKeepPendingOrders) return;
   long modes = SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_MODE);
   if((modes & SYMBOL_EXPIRATION_SPECIFIED) != 0)
   {
      request.type_time = ORDER_TIME_SPECIFIED;
      request.expiration = setup_day + 86400;
   }
   else if((modes & SYMBOL_EXPIRATION_SPECIFIED_DAY) != 0)
   {
      request.type_time = ORDER_TIME_SPECIFIED_DAY;
      request.expiration = setup_day + 86399;
   }
   // Sin vencimiento compatible, ReconcilePendingExpiry limpia en el próximo tick.
}

// También recupera pendientes de días anteriores después de un reinicio.
// Sincroniza el vencimiento al cambiar el bool; nunca cierra posiciones abiertas.
void ReconcilePendingExpiry()
{
   if(!TradingAllowed() || g_last_expiry_check == TimeCurrent()) return;
   g_last_expiry_check = TimeCurrent();
   datetime today = GetDayStart(TimeCurrent());
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (ulong)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_STOP && type != ORDER_TYPE_SELL_STOP) continue;
      datetime day = SetupOrderDay(OrderGetString(ORDER_COMMENT), (datetime)OrderGetInteger(ORDER_TIME_SETUP));
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      request.order = ticket;
      request.symbol = _Symbol;
      request.magic = InpMagicNumber;
      bool expired = (!InpKeepPendingOrders && day < today);
      if(expired)
         request.action = TRADE_ACTION_REMOVE;
      else
      {
         SetPendingExpiry(request, day);
         if(request.type_time == (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME) &&
            request.expiration == (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION)) continue;
         request.action = TRADE_ACTION_MODIFY;
         request.price = OrderGetDouble(ORDER_PRICE_OPEN);
         request.sl = OrderGetDouble(ORDER_SL);
         request.tp = OrderGetDouble(ORDER_TP);
         request.stoplimit = OrderGetDouble(ORDER_PRICE_STOPLIMIT);
      }
      if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
      {
         if(expired)
            PrintFormat("[SETUP B] Fin de día: pendiente #%I64u cancelada (setup %s).", ticket, TimeToString(day, TIME_DATE));
         else
            PrintFormat("[SETUP B] Vencimiento de pendiente #%I64u actualizado: %s.", ticket,
                        InpKeepPendingOrders ? "sin vencimiento diario" : "al cierre del día");
      }
      else if(g_last_expiry_error == 0 || TimeCurrent() - g_last_expiry_error >= 60)
      {
         g_last_expiry_error = TimeCurrent();
         PrintFormat("[SETUP B] No se pudo %s pendiente #%I64u: %u, %s. Se reintentará.",
                     expired ? "cancelar" : "actualizar vencimiento de", ticket, result.retcode, result.comment);
      }
   }
}

bool PlaceSetupStop(ENUM_ORDER_TYPE type, double entry)
{
   bool is_buy = (type == ORDER_TYPE_BUY_STOP);
   string side = is_buy ? "BUY STOP" : "SELL STOP";
   double direction = is_buy ? 1.0 : -1.0;
   double distance = InpStopLossPips * PipSize();
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   MqlTradeCheckResult check = {};
   request.action = TRADE_ACTION_PENDING;
   request.symbol = _Symbol;
   request.magic = InpMagicNumber;
   request.type = type;
   request.price = RoundTradePrice(entry);
   request.sl = RoundTradePrice(entry - direction * distance);
   request.tp = RoundTradePrice(entry + direction * distance * InpRiskReward);
   if(!CalculateRiskVolume(type, request.price, request.sl, request.volume)) return false;
   request.type_filling = ORDER_FILLING_RETURN;
   SetPendingExpiry(request, g_current_day);
   request.comment = "SETUP B " + TimeToString(g_current_day, TIME_DATE) + (is_buy ? " BUY" : " SELL");

   // No desplazar el extremo elegido ni enviar a mercado si ya hubo una ruptura.
   if(MathAbs(request.price - entry) > _Point * 0.01 ||
      request.sl <= 0.0 || request.tp <= 0.0 ||
      direction * (request.price - request.sl) <= 0.0 ||
      direction * (request.tp - request.price) <= 0.0)
   {
      PrintFormat("[SETUP B] %s omitida: niveles incompatibles con el tick del símbolo.", side);
      return false;
   }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return false;
   double min_distance = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double gap = is_buy ? request.price - tick.ask : tick.bid - request.price;
   if(gap <= 0.0 || gap + _Point * 0.01 < min_distance)
   {
      PrintFormat("[SETUP B] %s omitida: extremo alcanzado o demasiado cerca del precio actual (spread/stops).", side);
      return false;
   }
   // Verificar margen, volumen, SL/TP y restricciones del bróker.
   if(!OrderCheck(request, check))
   {
      PrintFormat("[SETUP B] %s rechazada en validación: %u, %s", side, check.retcode, check.comment);
      return false;
   }
   bool sent = OrderSend(request, result);
   if(!sent || (result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED))
   {
      PrintFormat("[SETUP B] Error enviando %s: %u, %s (error %d)", side, result.retcode, result.comment, GetLastError());
      return false;
   }
   PrintFormat("[SETUP B] %s #%I64u: entrada=%s SL=%s TP=%s, lotes=%.8f, riesgo=%.8f%%", side, result.order,
               DoubleToString(request.price, _Digits), DoubleToString(request.sl, _Digits),
               DoubleToString(request.tp, _Digits), request.volume, g_risk_percent);
   return true;
}

// Identificar el par por símbolo, Magic y día de creación de la orden.
// Usar la orden de origen evita confundir un cierre por SL/TP con una entrada.
bool GetExecutedSetup(ulong deal, datetime &setup_day, ENUM_ORDER_TYPE &side)
{
   if(deal == 0 || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol ||
      (ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagicNumber)
      return false;
   ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(deal, DEAL_TYPE);
   if(deal_type != DEAL_TYPE_BUY && deal_type != DEAL_TYPE_SELL) return false;
   ulong order = (ulong)HistoryDealGetInteger(deal, DEAL_ORDER);
   if(HistoryOrderSelect(order))
   {
      side = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(order, ORDER_TYPE);
      setup_day = SetupOrderDay(HistoryOrderGetString(order, ORDER_COMMENT), (datetime)HistoryOrderGetInteger(order, ORDER_TIME_SETUP));
   }
   else if(OrderSelect(order)) // También cancelar ante una ejecución parcial.
   {
      side = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      setup_day = SetupOrderDay(OrderGetString(ORDER_COMMENT), (datetime)OrderGetInteger(ORDER_TIME_SETUP));
   }
   else return false; // El historial puede llegar después del evento; reintentar.
   return side == ORDER_TYPE_BUY_STOP || side == ORDER_TYPE_SELL_STOP;
}

void CancelOppositeSetupOrder(datetime setup_day, ENUM_ORDER_TYPE executed_side)
{
   if(!TradingAllowed()) return;
   ENUM_ORDER_TYPE opposite = executed_side == ORDER_TYPE_BUY_STOP ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_BUY_STOP;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (ulong)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber ||
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != opposite ||
         SetupOrderDay(OrderGetString(ORDER_COMMENT), (datetime)OrderGetInteger(ORDER_TIME_SETUP)) != setup_day)
         continue;
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      request.action = TRADE_ACTION_REMOVE;
      request.order = ticket;
      request.symbol = _Symbol;
      request.magic = InpMagicNumber;
      bool sent = OrderSend(request, result);
      if(sent && result.retcode == TRADE_RETCODE_DONE)
         PrintFormat("[SETUP B] OCO: pendiente contraria #%I64u cancelada (setup %s).",
                     ticket, TimeToString(setup_day, TIME_DATE));
      else if(g_last_oco_error == 0 || TimeCurrent() - g_last_oco_error >= 60)
      {
         g_last_oco_error = TimeCurrent();
         PrintFormat("[SETUP B] OCO: cancelación pendiente #%I64u: %u, %s. Se reintentará.",
                     ticket, result.retcode, result.comment);
      }
   }
}

// true: cancelar al ejecutarse una entrada. false: sólo al cerrar por TP.
// El historial seleccionado debe incluir el deal de apertura de la posición.
bool GetSetupCancellation(ulong deal, datetime &setup_day, ENUM_ORDER_TYPE &side)
{
   if(InpCancelSecondEntry) return GetExecutedSetup(deal, setup_day, side);
   if(deal == 0 || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol ||
      (ulong)HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagicNumber ||
      (ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON) != DEAL_REASON_TP)
      return false;
   ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return false;
   ulong position_id = (ulong)HistoryDealGetInteger(deal, DEAL_POSITION_ID);
   if(position_id == 0) return false;
   long close_time = HistoryDealGetInteger(deal, DEAL_TIME_MSC);
   // Vincular el TP a la última apertura/reversión de esa posición; no usar
   // el tipo de la orden de cierre, que es el contrario al de la entrada.
   ulong opening_deal = 0;
   long opening_time = -1;
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong candidate = HistoryDealGetTicket(i);
      if(candidate == deal || (ulong)HistoryDealGetInteger(candidate, DEAL_POSITION_ID) != position_id)
         continue;
      ENUM_DEAL_ENTRY candidate_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(candidate, DEAL_ENTRY);
      if(candidate_entry != DEAL_ENTRY_IN && candidate_entry != DEAL_ENTRY_INOUT) continue;
      long candidate_time = HistoryDealGetInteger(candidate, DEAL_TIME_MSC);
      if(candidate_time <= close_time && candidate_time >= opening_time)
      {
         opening_deal = candidate;
         opening_time = candidate_time;
      }
   }
   return GetExecutedSetup(opening_deal, setup_day, side);
}

// El llamador selecciona el historial de deals antes de esta consulta.
bool SetupHasCancellation(datetime day_start)
{
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      datetime setup_day;
      ENUM_ORDER_TYPE side;
      if(GetSetupCancellation(HistoryDealGetTicket(i), setup_day, side) && setup_day == day_start)
         return true;
   }
   return false;
}

// Recuperación tras reinicios, eventos fuera de orden o rechazo de cancelación.
// Incluye pendientes antiguas: el par pertenece al día de creación, no al de ejecución.
void ReconcileSetupOCO()
{
   datetime now = TimeCurrent();
   if(g_last_oco_check == now || !TradingAllowed()) return;
   g_last_oco_check = now;
   datetime first_day = now;
   bool has_pending = false;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderGetTicket(i) == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (ulong)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      ENUM_ORDER_TYPE side = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(side != ORDER_TYPE_BUY_STOP && side != ORDER_TYPE_SELL_STOP) continue;
      datetime day = SetupOrderDay(OrderGetString(ORDER_COMMENT), (datetime)OrderGetInteger(ORDER_TIME_SETUP));
      if(day < first_day) first_day = day;
      has_pending = true;
   }
   if(!has_pending || !HistorySelect(first_day, now)) return;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      datetime setup_day;
      ENUM_ORDER_TYPE side;
      if(GetSetupCancellation(HistoryDealGetTicket(i), setup_day, side))
         CancelOppositeSetupOrder(setup_day, side);
   }
}

// MT5 no permite modificar el volumen de una pendiente. Validar el reemplazo,
// cancelar y enviarlo sólo tras confirmar que la original no llegó a ejecutarse.
void ReconcilePendingRisk()
{
   if(!TradingAllowed() || g_last_risk_check == TimeCurrent()) return;
   g_last_risk_check = TimeCurrent();
   if(!RefreshRisk() || g_pending_risk_percent == g_risk_percent) return;
   bool complete = true;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (ulong)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_STOP && type != ORDER_TYPE_SELL_STOP) continue;
      // No aumentar el remanente de una entrada que ya se ejecutó parcialmente.
      if(OrderGetDouble(ORDER_VOLUME_CURRENT) != OrderGetDouble(ORDER_VOLUME_INITIAL)) continue;
      MqlTradeRequest replacement = {};
      replacement.action = TRADE_ACTION_PENDING;
      replacement.symbol = _Symbol;
      replacement.magic = InpMagicNumber;
      replacement.type = type;
      replacement.price = OrderGetDouble(ORDER_PRICE_OPEN);
      replacement.sl = OrderGetDouble(ORDER_SL);
      replacement.tp = OrderGetDouble(ORDER_TP);
      replacement.type_time = (ENUM_ORDER_TYPE_TIME)OrderGetInteger(ORDER_TYPE_TIME);
      replacement.expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
      replacement.type_filling = ORDER_FILLING_RETURN;
      datetime day = SetupOrderDay(OrderGetString(ORDER_COMMENT), (datetime)OrderGetInteger(ORDER_TIME_SETUP));
      if(!InpKeepPendingOrders && day < GetDayStart(TimeCurrent())) { complete = false; continue; }
      SetPendingExpiry(replacement, day);
      replacement.comment = "SETUP B " + TimeToString(day, TIME_DATE) + (type == ORDER_TYPE_BUY_STOP ? " BUY" : " SELL");
      double previous_volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
      // Consultar OCO también aquí evita recrear una pendiente cuyo TP acaba de llegar.
      if(!HistorySelect(day, TimeCurrent())) { complete = false; continue; }
      if(SetupHasCancellation(day)) { complete = false; continue; }
      if(replacement.sl <= 0.0 || !CalculateRiskVolume(type, replacement.price, replacement.sl, replacement.volume))
      { complete = false; continue; }
      if(MathAbs(replacement.volume - previous_volume) < 0.00000001) continue;
      MqlTradeCheckResult check = {};
      if(!OrderCheck(replacement, check))
      {
         PrintFormat("[SETUP B] Pendiente #%I64u conserva su volumen: reemplazo rechazado (%u, %s).", ticket, check.retcode, check.comment);
         complete = false;
         continue;
      }
      MqlTradeRequest removal = {};
      MqlTradeResult removed = {};
      removal.action = TRADE_ACTION_REMOVE;
      removal.order = ticket;
      removal.symbol = _Symbol;
      removal.magic = InpMagicNumber;
      if(!OrderSend(removal, removed) || removed.retcode != TRADE_RETCODE_DONE)
      { complete = false; continue; }
      if(!HistoryOrderSelect(ticket) ||
         (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE) != ORDER_STATE_CANCELED ||
         MathAbs(HistoryOrderGetDouble(ticket, ORDER_VOLUME_CURRENT) - previous_volume) > 0.00000001)
      {
         PrintFormat("[SETUP B] No se repone #%I64u: no se confirmó cancelación íntegra sin ejecuciones.", ticket);
         continue;
      }
      if((!InpKeepPendingOrders && day < GetDayStart(TimeCurrent())) ||
         !HistorySelect(day, TimeCurrent()) || SetupHasCancellation(day)) continue;
      MqlTradeResult placed = {};
      if(!OrderSend(replacement, placed) ||
         (placed.retcode != TRADE_RETCODE_DONE && placed.retcode != TRADE_RETCODE_PLACED))
         PrintFormat("[SETUP B] ATENCIÓN: #%I64u cancelada pero reemplazo rechazado (%u, %s). No se reenvía para evitar duplicados.", ticket, placed.retcode, placed.comment);
      else
         PrintFormat("[SETUP B] Riesgo actualizado: #%I64u reemplazada por #%I64u; %.8f lotes, %.8f%%.", ticket, placed.order, replacement.volume, g_risk_percent);
   }
   if(complete) g_pending_risk_percent = g_risk_percent;
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD || trans.type == TRADE_TRANSACTION_DEAL_UPDATE ||
      trans.type == TRADE_TRANSACTION_DEAL_DELETE)
   {
      g_risk_dirty = true;
      g_last_risk_check = 0;
   }
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.symbol != _Symbol) return;
   if(!HistoryDealSelect(trans.deal)) return;
   // DEAL_ADD puede anunciar el cierre de una posición cuyo setup sea antiguo.
   // Cargar su historia sin perder el vínculo con la entrada al buscar el TP.
   if(!InpCancelSecondEntry)
   {
      if((ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal, DEAL_REASON) != DEAL_REASON_TP) return;
      ulong position_id = (ulong)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
      if(!HistorySelectByPosition(position_id)) return;
   }
   datetime setup_day;
   ENUM_ORDER_TYPE side;
   if(GetSetupCancellation(trans.deal, setup_day, side))
      CancelOppositeSetupOrder(setup_day, side);
   // Permitir la recuperación en el siguiente tick, incluso del mismo segundo.
   g_last_oco_check = 0;
}

void PlaceSetupOrders()
{
   if(!g_setup_evaluated_today || !g_setup_b_today || g_setup_orders_processed ||
      g_current_day != GetDayStart(TimeCurrent()) || !TradingAllowed())
      return;
   g_risk_dirty = true;
   if(!RefreshRisk()) return;
   // Si la historia aún no está disponible, esperar antes de arriesgar duplicados.
   if(!HistorySelect(g_current_day, TimeCurrent())) return;
   bool has_buy = SetupOrderAlreadyExists(ORDER_TYPE_BUY_STOP, g_current_day);
   bool has_sell = SetupOrderAlreadyExists(ORDER_TYPE_SELL_STOP, g_current_day);
   g_setup_orders_processed = true;
   // Respetar el modo de cancelación tras un reinicio. Las órdenes ya ejecutadas
   // o canceladas siguen en el historial y nunca se reponen, aunque cierren por SL.
   if(SetupHasCancellation(g_current_day)) return;
   // Un intento por lado y día. No reintentar una ruptura ya perdida al retroceder
   // el precio. Cada fallo queda explicado en el Diario del probador.
   double buy_entry = InpUseRangeA ? MAX_A : MAX_B;
   double sell_entry = InpUseRangeA ? MIN_A : MIN_B;
   if(!has_buy) PlaceSetupStop(ORDER_TYPE_BUY_STOP, buy_entry);
   // Revisar si ocurrió el evento de cancelación mientras se colocaba la compra.
   if(!HistorySelect(g_current_day, TimeCurrent()) || SetupHasCancellation(g_current_day)) return;
   if(!has_sell) PlaceSetupStop(ORDER_TYPE_SELL_STOP, sell_entry);
}

void ManageBreakeven()
{
   if(InpBreakevenPips <= 0.0 || !TradingAllowed()) return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return;
   double trigger = InpBreakevenPips * PipSize();
   double stops = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double freeze = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      bool is_buy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double old_sl = PositionGetDouble(POSITION_SL);
      double exit_price = is_buy ? tick.bid : tick.ask;
      double advance = is_buy ? exit_price - entry : entry - exit_price;
      if(advance + _Point * 0.01 < trigger) continue;
      double new_sl = RoundTradePrice(entry);
      // No retroceder un stop que ya esté en BE o en beneficio.
      if(old_sl != 0.0 && (is_buy ? old_sl >= new_sl - _Point * 0.01 : old_sl <= new_sl + _Point * 0.01))
         continue;
      double gap = is_buy ? exit_price - new_sl : new_sl - exit_price;
      if(gap <= 0.0 || gap + _Point * 0.01 < stops || gap <= freeze) continue;
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.symbol = _Symbol;
      request.magic = InpMagicNumber;
      request.sl = new_sl;
      request.tp = PositionGetDouble(POSITION_TP);
      bool sent = OrderSend(request, result);
      if(sent && result.retcode == TRADE_RETCODE_DONE)
         PrintFormat("[SETUP B] BE aplicado a #%I64u: SL=%s", ticket, DoubleToString(new_sl, _Digits));
      else if(result.retcode != TRADE_RETCODE_NO_CHANGES && TimeCurrent() - g_last_be_error >= 60)
      {
         g_last_be_error = TimeCurrent();
         PrintFormat("[SETUP B] BE pendiente en #%I64u: %u, %s", ticket, result.retcode, result.comment);
      }
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_is_tester = (bool)MQLInfoInteger(MQL_TESTER);
   g_is_visual = (bool)MQLInfoInteger(MQL_VISUAL_MODE);
   // Si está en tester no visual, se apagan todos los gráficos para maximizar rendimiento
   g_enable_graphics = (!g_is_tester || g_is_visual);

   if(g_enable_graphics)
      Print("=== [EA_Rangos_HA] Inicializando Asesor Experto... ===");
   
   if(InpMaxBars < 2)
      return INIT_PARAMETERS_INCORRECT;

   if(!MathIsValidNumber(InpStopLossPips) || InpStopLossPips <= 0.0 ||
      !MathIsValidNumber(InpRiskReward) || InpRiskReward <= 0.0 ||
      !MathIsValidNumber(InpBreakevenPips) || InpBreakevenPips < 0.0 ||
      !MathIsValidNumber(InpRiskMultiplier) || InpRiskMultiplier < 0.0 ||
      InpMagicNumber == 0)
   {
      Print("[SETUP B] SL, RR y Magic deben ser positivos. Multiplicador de riesgo debe ser >= 0 (0=fijo al 1%). Activación BE debe ser >= 0 (0=apagado).");
      return INIT_PARAMETERS_INCORRECT;
   }
   g_risk_dirty = true;
   g_risk_percent = BASE_RISK_PERCENT;
   g_pending_risk_percent = -1.0;
   g_last_risk_check = 0;
   g_last_expiry_check = 0;

   // Parsear horarios configurados
   int h_sa, m_sa, h_ea, m_ea;
   int h_sb, m_sb, h_eb, m_eb;
   int h_sc, m_sc, h_ec, m_ec;
   
   if(!ParseTimeString(InpStartTimeA, h_sa, m_sa) || !ParseTimeString(InpEndTimeA, h_ea, m_ea) ||
      !ParseTimeString(InpStartTimeB, h_sb, m_sb) || !ParseTimeString(InpEndTimeB, h_eb, m_eb) ||
      !ParseTimeString(InpStartTimeC, h_sc, m_sc) || !ParseTimeString(InpEndTimeC, h_ec, m_ec))
   {
      Alert("[EA_Rangos_HA] Error en los parámetros de horario.");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   g_sec_start_a = h_sa * 3600 + m_sa * 60;
   g_sec_end_a   = h_ea * 3600 + m_ea * 60;
   g_sec_start_b = h_sb * 3600 + m_sb * 60;
   g_sec_end_b   = h_eb * 3600 + m_eb * 60;
   g_sec_start_c = h_sc * 3600 + m_sc * 60;
   g_sec_end_c   = h_ec * 3600 + m_ec * 60;
   
   if(g_enable_graphics)
   {
      // Guardar y configurar lienzo
      SaveOriginalChart();
      SetupChart();
      
      // Limpiar cualquier objeto previo del EA
      ObjectsDeleteAll(0, OBJ_PREFIX);
   }
   
   // Inicializar datos históricos
   g_history_ready = InitHistory();
   
   if(g_enable_graphics)
   {
      ChartRedraw(0);
      PrintFormat("[EA_Rangos_HA] Configuración horaria (UTC+3 The5ers): A[%s-%s] B[%s-%s] C[%s-%s]",
                  InpStartTimeA, InpEndTimeA, InpStartTimeB, InpEndTimeB, InpStartTimeC, InpEndTimeC);
      Print("=== [EA_Rangos_HA] Inicialización completada con éxito ===");
   }
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_enable_graphics)
   {
      Print("[EA_Rangos_HA] Desinicializando y limpiando objetos...");
      ObjectsDeleteAll(0, OBJ_PREFIX);
      RestoreOriginalChart();
      Print("[EA_Rangos_HA] Gráfico restaurado correctamente.");
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   ReconcilePendingExpiry();
   ReconcileSetupOCO();
   ReconcilePendingRisk();
   // Gestionar posiciones aun si la historia de rangos todavía no está lista.
   ManageBreakeven();
   // CopyRates puede no estar listo durante OnInit; esperar el historial de rangos.
   if(!g_history_ready)
   {
      g_history_ready = InitHistory();
      if(!g_history_ready) return;
      if(g_enable_graphics) ChartRedraw(0);
   }
   MqlRates current_rates[1];
   if(CopyRates(_Symbol, PERIOD_M15, 0, 1, current_rates) <= 0) return;
   
   datetime bar_time = current_rates[0].time;
   bool is_new_bar = (bar_time != g_last_bar_time);
   g_last_bar_time = bar_time;

   // Actualizar extremos de rangos si corresponde
   UpdateLiveRanges(current_rates[0], is_new_bar);
   EvaluateDaySetup(g_current_day, TimeCurrent(), true);
   PlaceSetupOrders();
   
   // Refrescar el gráfico de forma optimizada y controlada
   if(g_enable_graphics)
   {
      ulong now_ms = GetTickCount64();
      if(is_new_bar || (now_ms - g_last_redraw_time >= 50))
      {
         ChartRedraw(0);
         g_last_redraw_time = now_ms;
      }
   }
}
//+------------------------------------------------------------------+
