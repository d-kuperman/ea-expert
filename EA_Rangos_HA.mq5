//+------------------------------------------------------------------+
//|                                                 EA_Rangos_HA.mq5 |
//|                                  Copyright 2026, Dany            |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Dany"
#property link      "https://www.mql5.com"
#property version   "1.04"
#property description "Asesor Experto con Velas Heikin Ashi M15, Rangos A, B, C y división de días (UTC+3 The5ers) [Optimizado]"

//+------------------------------------------------------------------+
//| Parámetros de entrada                                            |
//+------------------------------------------------------------------+
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

//--- Velas Heikin Ashi ---
input group "--- Velas Heikin Ashi ---"
input color    InpHaBullColor    = C'34,139,34';     // Color velas Alcistas (#228B22)
input color    InpHaBearColor    = C'178,34,34';     // Color velas bajistas (#B22222)

//--- Lienzo ---
input group "--- Lienzo ---"
input color    InpBgColor        = C'219,219,219';   // Color de fondo del lienzo (#dbdbdb)

//--- Visualización Adicional ---
input group "--- Visualización Adicional ---"
input int      InpMaxBars        = 500;              // Velas históricas a procesar
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

// Estado diario para las futuras reglas de entrada. Se reinicia cada día.
bool g_setup_invalid_today = false;
bool g_setup_evaluated_today = false;

// Detección de entorno y control de gráficos
bool g_is_tester       = false;
bool g_is_visual       = false;
bool g_enable_graphics = true;

// Segundos desde medianoche (00:00 UTC+3) para cada rango
int g_sec_start_a = 0, g_sec_end_a = 0;
int g_sec_start_b = 0, g_sec_end_b = 0;
int g_sec_start_c = 0, g_sec_end_c = 0;

// Variables de estado de Heikin Ashi
datetime g_last_bar_time = 0;
double   g_curr_ha_open  = 0.0;
double   g_curr_ha_high  = 0.0;
double   g_curr_ha_low   = 0.0;
double   g_curr_ha_close = 0.0;

double   g_prev_ha_open  = 0.0;
double   g_prev_ha_close = 0.0;

// Registro de velas dibujadas para control FIFO
struct HACandle
{
   datetime time;
   double open, high, low, close;
};
HACandle g_drawn_bars[];
bool g_history_ready = false;
int      g_drawn_count = 0;

// Registro del día actual procesado
datetime g_current_day = 0;

// Configuración original del gráfico para restaurar en OnDeinit
long  g_orig_mode        = 0;
long  g_orig_bg          = 0;
long  g_orig_fg          = 0;
long  g_orig_grid        = 0;
long  g_orig_sep         = 0;
long  g_orig_line        = 0;
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
   g_orig_line        = ChartGetInteger(0, CHART_COLOR_CHART_LINE);
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
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, (color)g_orig_line);
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
   
   // Ocultar velas/barras normales (modo línea invisible)
   ChartSetInteger(0, CHART_MODE, CHART_LINE);
   ChartSetInteger(0, CHART_COLOR_CHART_LINE, clrNONE);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, clrNONE);
   ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, clrNONE);
   ChartSetInteger(0, CHART_COLOR_CHART_DOWN, clrNONE);
   ChartSetInteger(0, CHART_COLOR_CHART_UP, clrNONE);
   
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
//| Calcula el ancho de vela con caché de escala (evita CopyTime)    |
//+------------------------------------------------------------------+
int GetCurrentBarWidth(double ref_price = 0.0)
{
   static long last_scale = -1;
   static int  cached_width = 3;
   
   long scale = ChartGetInteger(0, CHART_SCALE);
   if(scale == last_scale && cached_width > 0)
      return cached_width;
      
   if(ref_price <= 0.0)
      ref_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ref_price <= 0.0)
      ref_price = 1.0;
      
   datetime times[2];
   int x0, x1, unused_y;
   if(CopyTime(_Symbol, PERIOD_M15, 0, 2, times) == 2 &&
      ChartTimePriceToXY(0, 0, times[0], ref_price, x0, unused_y) &&
      ChartTimePriceToXY(0, 0, times[1], ref_price, x1, unused_y))
   {
      int spacing = (int)MathAbs(x1 - x0);
      cached_width = (int)MathMax(1, MathMin(spacing - 1, (int)MathRound(spacing * 0.7)));
      last_scale = scale;
      return cached_width;
   }
   return (cached_width > 0 ? cached_width : 3);
}

//+------------------------------------------------------------------+
//| Dibuja o actualiza un rectángulo en coordenadas de píxeles       |
//+------------------------------------------------------------------+
void DrawPixelRectangle(string name, int x, int y, int width, int height, color clr, int chart_width, int chart_height)
{
   int right = (int)MathMin(chart_width, x + width);
   int bottom = (int)MathMin(chart_height, y + height);
   x = (int)MathMax(0, x);
   y = (int)MathMax(0, y);
   if(right <= x || bottom <= y)
   {
      ObjectDelete(0, name);
      return;
   }
   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return;
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, right - x);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, bottom - y);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Renderiza una vela Heikin Ashi específica                        |
//+------------------------------------------------------------------+
void RenderHACandle(const HACandle &bar, int width, int chart_width, int chart_height)
{
   int x, y_open, unused_x, y_close, y_high, y_low;
   if(!ChartTimePriceToXY(0, 0, bar.time, bar.open, x, y_open) ||
      !ChartTimePriceToXY(0, 0, bar.time, bar.close, unused_x, y_close) ||
      !ChartTimePriceToXY(0, 0, bar.time, bar.high, unused_x, y_high) ||
      !ChartTimePriceToXY(0, 0, bar.time, bar.low, unused_x, y_low))
   {
      DeleteHACandle(bar.time);
      return;
   }

   color clr = bar.close >= bar.open ? InpHaBullColor : InpHaBearColor;
   string suffix = IntegerToString((long)bar.time);

   // Mecha y cuerpo
   DrawPixelRectangle(OBJ_PREFIX + "W_" + suffix, x, y_high, 1,
                      (int)MathMax(1, y_low - y_high + 1), clr, chart_width, chart_height);
   DrawPixelRectangle(OBJ_PREFIX + "B_" + suffix, x - width / 2,
                      (int)MathMin(y_open, y_close), width,
                      (int)MathMax(1, MathAbs(y_close - y_open)), clr, chart_width, chart_height);
}

//+------------------------------------------------------------------+
//| Refresca todas las velas con parámetros precalculados            |
//+------------------------------------------------------------------+
void RefreshHACandles()
{
   if(!g_enable_graphics || g_drawn_count <= 0) return;
   
   int width = GetCurrentBarWidth();
   int chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);

   for(int i = 0; i < g_drawn_count; i++)
      RenderHACandle(g_drawn_bars[i], width, chart_width, chart_height);
}

//+------------------------------------------------------------------+
//| Registra y actualiza una vela Heikin Ashi                        |
//+------------------------------------------------------------------+
void DrawHACandle(datetime bar_time, double ha_open, double ha_high, double ha_low, double ha_close)
{
   int index = g_drawn_count - 1;
   while(index >= 0 && g_drawn_bars[index].time != bar_time)
      index--;
   if(index < 0)
   {
      if(g_drawn_count >= InpMaxBars)
      {
         if(g_enable_graphics)
            DeleteHACandle(g_drawn_bars[0].time);
         // Desplazamiento en bloque O(1) de memoria en lugar de bucle for O(N)
         ArrayCopy(g_drawn_bars, g_drawn_bars, 0, 1, g_drawn_count - 1);
         g_drawn_count--;
      }
      index = g_drawn_count++;
      if(g_drawn_count > ArraySize(g_drawn_bars))
         ArrayResize(g_drawn_bars, g_drawn_count + 50);
   }
   g_drawn_bars[index].time  = bar_time;
   g_drawn_bars[index].open  = ha_open;
   g_drawn_bars[index].high  = ha_high;
   g_drawn_bars[index].low   = ha_low;
   g_drawn_bars[index].close = ha_close;
   
   if(g_enable_graphics)
   {
      int width = GetCurrentBarWidth(ha_open);
      int chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      int chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
      RenderHACandle(g_drawn_bars[index], width, chart_width, chart_height);
   }
}

//+------------------------------------------------------------------+
//| Elimina objetos de una vela por su tiempo de apertura            |
//+------------------------------------------------------------------+
void DeleteHACandle(datetime t)
{
   if(!g_enable_graphics) return;
   ObjectDelete(0, OBJ_PREFIX + "W_" + IntegerToString((long)t));
   ObjectDelete(0, OBJ_PREFIX + "B_" + IntegerToString((long)t));
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
//| Evalúa precios reales y declara setup inválido si Rango B        |
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
      return; // Historia incompleta: no declarar una invalidación.

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

   bool invalid = (max_b <= max_a && min_b >= min_a);
   if(is_today)
   {
      g_setup_invalid_today   = invalid;
      g_setup_evaluated_today = true;
   }

   if(!g_enable_graphics)
      return;

   string name = OBJ_PREFIX + "SETUP_INVALID_" + TimeToString(day_start, TIME_DATE);
   if(!invalid)
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
   ObjectSetString(0, name, OBJPROP_TEXT, "SETUP NO VÁLIDO");
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 11);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpHaBearColor);
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
//| Inicializa el historial de velas Heikin Ashi y rangos            |
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
   
   ArrayResize(g_drawn_bars, InpMaxBars);
   g_drawn_count = 0;
   
   double ha_open = 0.0, ha_close = 0.0, ha_high = 0.0, ha_low = 0.0;
   double prev_open = 0.0, prev_close = 0.0;
   
   int width = 0, chart_width = 0, chart_height = 0;
   if(g_enable_graphics)
   {
      width = GetCurrentBarWidth();
      chart_width = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
      chart_height = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   }

   // 1. Cálculo y dibujo de velas Heikin Ashi históricas
   for(int i = 0; i < copied; i++)
   {
      ha_close = (rates[i].open + rates[i].high + rates[i].low + rates[i].close) / 4.0;
      if(i == 0)
      {
         ha_open = (rates[i].open + rates[i].close) / 2.0;
      }
      else
      {
         ha_open = (prev_open + prev_close) / 2.0;
      }
      ha_high = MathMax(rates[i].high, MathMax(ha_open, ha_close));
      ha_low  = MathMin(rates[i].low,  MathMin(ha_open, ha_close));
      
      if(i == copied - 2)
      {
         // Guardar los valores fijos de la penúltima barra (barra 1)
         g_prev_ha_open  = ha_open;
         g_prev_ha_close = ha_close;
      }
      
      prev_open  = ha_open;
      prev_close = ha_close;
      
      int idx = g_drawn_count++;
      g_drawn_bars[idx].time  = rates[i].time;
      g_drawn_bars[idx].open  = ha_open;
      g_drawn_bars[idx].high  = ha_high;
      g_drawn_bars[idx].low   = ha_low;
      g_drawn_bars[idx].close = ha_close;

      if(g_enable_graphics)
      {
         RenderHACandle(g_drawn_bars[idx], width, chart_width, chart_height);
      }
   }
   
   // Estado de la barra actual (barra 0)
   int last_idx = copied - 1;
   g_last_bar_time = rates[last_idx].time;
   g_curr_ha_open  = ha_open;
   g_curr_ha_high  = ha_high;
   g_curr_ha_low   = ha_low;
   g_curr_ha_close = ha_close;
   
   // 2. Procesamiento de días históricos y rangos
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
      g_setup_invalid_today = false;
      g_setup_evaluated_today = false;
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
//| Manejo de eventos del gráfico                                    |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(g_enable_graphics && id == CHARTEVENT_CHART_CHANGE && g_history_ready)
   {
      RefreshHACandles();
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // CopyRates puede no estar listo durante OnInit. Nunca calcular desde cero.
   if(!g_history_ready)
   {
      g_history_ready = InitHistory();
      if(!g_history_ready) return;
      if(g_enable_graphics) ChartRedraw(0);
   }
   MqlRates current_rates[1];
   if(CopyRates(_Symbol, PERIOD_M15, 0, 1, current_rates) <= 0) return;
   
   datetime bar_time = current_rates[0].time;
   bool is_new_bar = false;
   
   if(bar_time != g_last_bar_time)
   {
      // --- NUEVA VELA M15 ABIERTA ---
      is_new_bar = true;
      
      // La barra anterior queda definitivamente cerrada
      // Consultamos la barra recién cerrada (índice 1) para consolidar sus valores finales exactos
      MqlRates closed_rates[1];
      if(CopyRates(_Symbol, PERIOD_M15, 1, 1, closed_rates) > 0)
      {
         double closed_ha_close = (closed_rates[0].open + closed_rates[0].high + closed_rates[0].low + closed_rates[0].close) / 4.0;
         double closed_ha_high  = MathMax(closed_rates[0].high, MathMax(g_curr_ha_open, closed_ha_close));
         double closed_ha_low   = MathMin(closed_rates[0].low,  MathMin(g_curr_ha_open, closed_ha_close));
         DrawHACandle(g_last_bar_time, g_curr_ha_open, closed_ha_high, closed_ha_low, closed_ha_close);
         g_prev_ha_open  = g_curr_ha_open;
         g_prev_ha_close = closed_ha_close;
      }
      else
      {
         g_prev_ha_open  = g_curr_ha_open;
         g_prev_ha_close = g_curr_ha_close;
      }

      g_last_bar_time = bar_time;
      
      // Apertura de la nueva vela Heikin Ashi
      g_curr_ha_open  = (g_prev_ha_open + g_prev_ha_close) / 2.0;
      g_curr_ha_close = (current_rates[0].open + current_rates[0].high + current_rates[0].low + current_rates[0].close) / 4.0;
      g_curr_ha_high  = MathMax(current_rates[0].high, MathMax(g_curr_ha_open, g_curr_ha_close));
      g_curr_ha_low   = MathMin(current_rates[0].low,  MathMin(g_curr_ha_open, g_curr_ha_close));
      
      DrawHACandle(g_last_bar_time, g_curr_ha_open, g_curr_ha_high, g_curr_ha_low, g_curr_ha_close);
   }
   else
   {
      // --- MISMA VELA M15 (TICK EN CURSO) ---
      // HA_Open permanece fijo desde el comienzo de la vela
      g_curr_ha_close = (current_rates[0].open + current_rates[0].high + current_rates[0].low + current_rates[0].close) / 4.0;
      g_curr_ha_high  = MathMax(current_rates[0].high, MathMax(g_curr_ha_open, g_curr_ha_close));
      g_curr_ha_low   = MathMin(current_rates[0].low,  MathMin(g_curr_ha_open, g_curr_ha_close));
   }
   
   // Actualizar extremos de rangos si corresponde
   UpdateLiveRanges(current_rates[0], is_new_bar);
   EvaluateDaySetup(g_current_day, TimeCurrent(), true);
   
   // Refrescar el gráfico de forma optimizada y controlada
   if(g_enable_graphics)
   {
      ulong now_ms = GetTickCount64();
      if(is_new_bar || (now_ms - g_last_redraw_time >= 50))
      {
         if(!is_new_bar)
            DrawHACandle(g_last_bar_time, g_curr_ha_open, g_curr_ha_high, g_curr_ha_low, g_curr_ha_close);

         static long   last_first = -1, last_scale = -1, last_width = -1, last_height = -1;
         static double last_min = 0, last_max = 0;
         long   first     = ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
         long   scale     = ChartGetInteger(0, CHART_SCALE);
         long   width     = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
         long   height    = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
         double price_min = ChartGetDouble(0, CHART_PRICE_MIN, 0);
         double price_max = ChartGetDouble(0, CHART_PRICE_MAX, 0);
         
         if(is_new_bar || first != last_first || scale != last_scale ||
            width != last_width || height != last_height ||
            price_min != last_min || price_max != last_max)
         {
            RefreshHACandles();
            last_first  = first;
            last_scale  = scale;
            last_width  = width;
            last_height = height;
            last_min    = price_min;
            last_max    = price_max;
         }
         ChartRedraw(0);
         g_last_redraw_time = now_ms;
      }
   }
}
//+------------------------------------------------------------------+
