//+------------------------------------------------------------------+
//|                                                 SETUP_B.mq5 |
//|                                  Copyright 2026, Dany            |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Dany"
#property link      "https://www.mql5.com"
#property version   "1.09"
#property description "Asesor Experto con velas normales M15, Rangos A, B, C y división de días (UTC+3 The5ers) [Optimizado]"

//+------------------------------------------------------------------+
//| Parámetros de entrada                                            |
//+------------------------------------------------------------------+
input group "-- ENTRADAS RANGO_A / RANGO_B ---"
input bool     InpUseRangeA      = true;            // RANGO_A (true) / RANGO_B (false)
input bool     InpCancelSecondEntry = true;         // Cancelar segunda entrada

input group "--- BUY / SELL STOP ---"
input double   InpStopLossPips   = 10.0;            // SL en pips
input double   InpRiskReward     = 2.0;             // RR

input group "--- BE Automático ---"
input bool     InpAutoBreakeven  = false;           // Activar BE automático (true=Sí / false=No)
input double   InpBreakevenPips  = 10.0;            // Activación en pips

input group "--- Ejecución ---"
input double   InpLots          = 0.01;            // Volumen de cada orden en lotes
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
         (datetime)OrderGetInteger(ORDER_TIME_SETUP) >= day_start)
         return true;
   }
   for(int i = HistoryOrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryOrderGetString(ticket, ORDER_SYMBOL) == _Symbol &&
         (ulong)HistoryOrderGetInteger(ticket, ORDER_MAGIC) == InpMagicNumber &&
         (ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE) == type &&
         (datetime)HistoryOrderGetInteger(ticket, ORDER_TIME_SETUP) >= day_start &&
         (ENUM_ORDER_STATE)HistoryOrderGetInteger(ticket, ORDER_STATE) != ORDER_STATE_REJECTED)
         return true;
   }
   return false;
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
   request.volume = InpLots;
   request.type = type;
   request.price = RoundTradePrice(entry);
   request.sl = RoundTradePrice(entry - direction * distance);
   request.tp = RoundTradePrice(entry + direction * distance * InpRiskReward);
   request.type_filling = ORDER_FILLING_RETURN;
   request.type_time = ORDER_TIME_GTC;
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
   PrintFormat("[SETUP B] %s #%I64u: entrada=%s SL=%s TP=%s", side, result.order,
               DoubleToString(request.price, _Digits), DoubleToString(request.sl, _Digits),
               DoubleToString(request.tp, _Digits));
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
      setup_day = GetDayStart((datetime)HistoryOrderGetInteger(order, ORDER_TIME_SETUP));
   }
   else if(OrderSelect(order)) // También cancelar ante una ejecución parcial.
   {
      side = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      setup_day = GetDayStart((datetime)OrderGetInteger(ORDER_TIME_SETUP));
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
         GetDayStart((datetime)OrderGetInteger(ORDER_TIME_SETUP)) != setup_day)
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
      datetime day = GetDayStart((datetime)OrderGetInteger(ORDER_TIME_SETUP));
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

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
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
   if(!InpAutoBreakeven || !TradingAllowed()) return;
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
      (InpAutoBreakeven && (!MathIsValidNumber(InpBreakevenPips) || InpBreakevenPips <= 0.0)) ||
      !MathIsValidNumber(InpLots) || InpLots <= 0.0 || InpMagicNumber == 0)
   {
      Print("[SETUP B] SL, RR, lotes y Magic deben ser positivos; activación BE también si está habilitado.");
      return INIT_PARAMETERS_INCORRECT;
   }
   double volume_min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double volume_max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(volume_step <= 0.0 || InpLots < volume_min || InpLots > volume_max ||
      MathAbs(InpLots / volume_step - MathRound(InpLots / volume_step)) > 0.0000001)
   {
      PrintFormat("[SETUP B] Lotes inválidos: mínimo=%g, máximo=%g, paso=%g", volume_min, volume_max, volume_step);
      return INIT_PARAMETERS_INCORRECT;
   }

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
   ReconcileSetupOCO();
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
