//+------------------------------------------------------------------+
//|                                                 EA_Rangos_HA.mq5 |
//|                                  Copyright 2026, Dany            |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Dany"
#property link      "https://www.mql5.com"
#property version   "1.01"
#property description "Asesor Experto con Velas Heikin Ashi M15, Rangos A, B, C y división de días (UTC+3 The5ers)"

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
datetime g_drawn_bars[];
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
//| Dibuja o actualiza una vela Heikin Ashi                          |
//+------------------------------------------------------------------+
void DrawHACandle(datetime bar_time, double ha_open, double ha_high, double ha_low, double ha_close)
{
   // Ancho temporal del cuerpo: aproximadamente 70% de una vela M15 (900 seg)
   int period_seconds = 15 * 60; // 900
   int half_body      = (int)(period_seconds * 0.35); // 315 segundos
   
   datetime center     = bar_time + period_seconds / 2;
   datetime body_left  = center - half_body;
   datetime body_right = center + half_body;
   
   // Clasificación de vela:
   // if(HA_Close > HA_Open) alcista;
   // else if(HA_Close < HA_Open) bajista;
   // else doji;
   color clr = clrGray;
   bool is_doji = (ha_close == ha_open);
   
   if(ha_close > ha_open)
      clr = InpHaBullColor;
   else if(ha_close < ha_open)
      clr = InpHaBearColor;
   else
      clr = InpHaBullColor; // Color base para el Doji
   
   string wick_name = OBJ_PREFIX + "W_" + IntegerToString((long)bar_time);
   string body_name = OBJ_PREFIX + "B_" + IntegerToString((long)bar_time);
   
   // 1. MECHA: Línea vertical fina (1 píxel) desde HA_Low hasta HA_High
   if(ObjectFind(0, wick_name) < 0)
   {
      ObjectCreate(0, wick_name, OBJ_TREND, 0, center, ha_low, center, ha_high);
      ObjectSetInteger(0, wick_name, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, wick_name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, wick_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, wick_name, OBJPROP_HIDDEN, true);
   }
   else
   {
      ObjectMove(0, wick_name, 0, center, ha_low);
      ObjectMove(0, wick_name, 1, center, ha_high);
   }
   ObjectSetInteger(0, wick_name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, wick_name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, wick_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, wick_name, OBJPROP_ZORDER, 10);
   
   // 2. CUERPO:
   if(is_doji)
   {
      // Doji: Si HA_Open == HA_Close, dibujar pequeña línea horizontal en ese precio
      // No modificar matemáticamente HA_Close ni HA_Open
      if(ObjectFind(0, body_name) >= 0)
      {
         if(ObjectGetInteger(0, body_name, OBJPROP_TYPE) != OBJ_TREND)
            ObjectDelete(0, body_name);
      }
      
      if(ObjectFind(0, body_name) < 0)
      {
         ObjectCreate(0, body_name, OBJ_TREND, 0, body_left, ha_open, body_right, ha_open);
         ObjectSetInteger(0, body_name, OBJPROP_RAY_LEFT, false);
         ObjectSetInteger(0, body_name, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, body_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, body_name, OBJPROP_HIDDEN, true);
      }
      else
      {
         ObjectMove(0, body_name, 0, body_left, ha_open);
         ObjectMove(0, body_name, 1, body_right, ha_open);
      }
      ObjectSetInteger(0, body_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, body_name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, body_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, body_name, OBJPROP_ZORDER, 20);
   }
   else
   {
      // Cuerpo normal: Rectángulo completamente relleno entre HA_Open y HA_Close
      if(ObjectFind(0, body_name) >= 0)
      {
         if(ObjectGetInteger(0, body_name, OBJPROP_TYPE) != OBJ_RECTANGLE)
            ObjectDelete(0, body_name);
      }
      
      if(ObjectFind(0, body_name) < 0)
      {
         ObjectCreate(0, body_name, OBJ_RECTANGLE, 0, body_left, ha_open, body_right, ha_close);
         ObjectSetInteger(0, body_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, body_name, OBJPROP_HIDDEN, true);
      }
      else
      {
         ObjectMove(0, body_name, 0, body_left, ha_open);
         ObjectMove(0, body_name, 1, body_right, ha_close);
      }
      ObjectSetInteger(0, body_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, body_name, OBJPROP_FILL, true);
      ObjectSetInteger(0, body_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, body_name, OBJPROP_ZORDER, 20);
   }
}

//+------------------------------------------------------------------+
//| Elimina objetos de una vela por su tiempo de apertura            |
//+------------------------------------------------------------------+
void DeleteHACandle(datetime t)
{
   ObjectDelete(0, OBJ_PREFIX + "W_" + IntegerToString((long)t));
   ObjectDelete(0, OBJ_PREFIX + "B_" + IntegerToString((long)t));
}

//+------------------------------------------------------------------+
//| Dibuja la línea divisoria punteada para el inicio del día (00:00)|
//+------------------------------------------------------------------+
void DrawDaySeparator(datetime day_start)
{
   if(!InpShowSeparators) return;
   
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
   if(!InpShowLabels) return;
   
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
//| Procesa y dibuja los 3 rangos para un día específico             |
//+------------------------------------------------------------------+
void ProcessDayRanges(datetime day_start, const MqlRates &rates[], int total_rates, bool is_today)
{
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
   
   string date_str = TimeToString(day_start, TIME_DATE);
   
   if(has_a)
   {
      DrawRangeRectangle("RNG_A_" + date_str, t_start_a, t_end_a, max_a, min_a, InpColorA, "RANGO_A");
      DrawRangeLabel("LBL_A_" + date_str, t_start_a, max_a, " RANGO_A [MAX: " + DoubleToString(max_a, _Digits) + " | MIN: " + DoubleToString(min_a, _Digits) + "]");
      if(is_today)
      {
         MAX_A = max_a;
         MIN_A = min_a;
         HAS_RANGO_A = true;
      }
   }
   
   if(has_b)
   {
      DrawRangeRectangle("RNG_B_" + date_str, t_start_b, t_end_b, max_b, min_b, InpColorB, "RANGO_B");
      DrawRangeLabel("LBL_B_" + date_str, t_start_b, max_b, " RANGO_B [MAX: " + DoubleToString(max_b, _Digits) + " | MIN: " + DoubleToString(min_b, _Digits) + "]");
      if(is_today)
      {
         MAX_B = max_b;
         MIN_B = min_b;
         HAS_RANGO_B = true;
      }
   }
   
   if(has_c)
   {
      DrawRangeRectangle("RNG_C_" + date_str, t_start_c, t_end_c, max_c, min_c, InpColorC, "RANGO_C");
      DrawRangeLabel("LBL_C_" + date_str, t_start_c, max_c, " RANGO_C [MAX: " + DoubleToString(max_c, _Digits) + " | MIN: " + DoubleToString(min_c, _Digits) + "]");
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
      PrintFormat("[EA_Rangos_HA] Esperando datos históricos de M15 (disponibles: %d)...", copied);
      return false;
   }
   
   ArrayResize(g_drawn_bars, copied);
   g_drawn_count = 0;
   
   double ha_open = 0.0, ha_close = 0.0, ha_high = 0.0, ha_low = 0.0;
   double prev_open = 0.0, prev_close = 0.0;
   
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
      
      DrawHACandle(rates[i].time, ha_open, ha_high, ha_low, ha_close);
      g_drawn_bars[g_drawn_count++] = rates[i].time;
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
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Actualiza en vivo los rangos de la sesión actual                 |
//+------------------------------------------------------------------+
void UpdateLiveRanges(const MqlRates &cur_bar)
{
   datetime now = cur_bar.time;
   datetime today = GetDayStart(now);
   
   // Cambio de día a las 00:00 UTC+3
   if(today != g_current_day)
   {
      g_current_day = today;
      HAS_RANGO_A = false;
      HAS_RANGO_B = false;
      HAS_RANGO_C = false;
      MAX_A = 0.0; MIN_A = 0.0;
      MAX_B = 0.0; MIN_B = 0.0;
      MAX_C = 0.0; MIN_C = 0.0;
      
      DrawDaySeparator(today);
      PrintFormat("[EA_Rangos_HA] === Nuevo día detectado: %s 00:00 (UTC+3) ===", TimeToString(today, TIME_DATE));
   }
   
   datetime t_start_a = today + g_sec_start_a;
   datetime t_end_a   = today + g_sec_end_a;
   datetime t_start_b = today + g_sec_start_b;
   datetime t_end_b   = today + g_sec_end_b;
   datetime t_start_c = today + g_sec_start_c;
   datetime t_end_c   = today + g_sec_end_c;
   string date_str    = TimeToString(today, TIME_DATE);
   
   // --- RANGO_A ---
   if(now >= t_start_a && now < t_end_a)
   {
      if(!HAS_RANGO_A)
      {
         HAS_RANGO_A = true;
         MAX_A = cur_bar.high;
         MIN_A = cur_bar.low;
         PrintFormat("[EA_Rangos_HA] Iniciando RANGO_A para %s", date_str);
      }
      else
      {
         if(cur_bar.high > MAX_A) MAX_A = cur_bar.high;
         if(cur_bar.low  < MIN_A) MIN_A = cur_bar.low;
      }
      DrawRangeRectangle("RNG_A_" + date_str, t_start_a, t_end_a, MAX_A, MIN_A, InpColorA, "RANGO_A");
      DrawRangeLabel("LBL_A_" + date_str, t_start_a, MAX_A, " RANGO_A [MAX: " + DoubleToString(MAX_A, _Digits) + " | MIN: " + DoubleToString(MIN_A, _Digits) + "]");
   }
   
   // --- RANGO_B ---
   if(now >= t_start_b && now < t_end_b)
   {
      if(!HAS_RANGO_B)
      {
         HAS_RANGO_B = true;
         MAX_B = cur_bar.high;
         MIN_B = cur_bar.low;
         PrintFormat("[EA_Rangos_HA] Iniciando RANGO_B para %s", date_str);
      }
      else
      {
         if(cur_bar.high > MAX_B) MAX_B = cur_bar.high;
         if(cur_bar.low  < MIN_B) MIN_B = cur_bar.low;
      }
      DrawRangeRectangle("RNG_B_" + date_str, t_start_b, t_end_b, MAX_B, MIN_B, InpColorB, "RANGO_B");
      DrawRangeLabel("LBL_B_" + date_str, t_start_b, MAX_B, " RANGO_B [MAX: " + DoubleToString(MAX_B, _Digits) + " | MIN: " + DoubleToString(MIN_B, _Digits) + "]");
   }
   
   // --- RANGO_C ---
   if(now >= t_start_c && now < t_end_c)
   {
      if(!HAS_RANGO_C)
      {
         HAS_RANGO_C = true;
         MAX_C = cur_bar.high;
         MIN_C = cur_bar.low;
         PrintFormat("[EA_Rangos_HA] Iniciando RANGO_C para %s", date_str);
      }
      else
      {
         if(cur_bar.high > MAX_C) MAX_C = cur_bar.high;
         if(cur_bar.low  < MIN_C) MIN_C = cur_bar.low;
      }
      DrawRangeRectangle("RNG_C_" + date_str, t_start_c, t_end_c, MAX_C, MIN_C, InpColorC, "RANGO_C");
      DrawRangeLabel("LBL_C_" + date_str, t_start_c, MAX_C, " RANGO_C [MAX: " + DoubleToString(MAX_C, _Digits) + " | MIN: " + DoubleToString(MIN_C, _Digits) + "]");
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== [EA_Rangos_HA] Inicializando Asesor Experto... ===");
   
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
   
   // Guardar y configurar lienzo
   SaveOriginalChart();
   SetupChart();
   
   // Limpiar cualquier objeto previo del EA
   ObjectsDeleteAll(0, OBJ_PREFIX);
   
   // Inicializar datos históricos
   InitHistory();
   
   ChartRedraw(0);
   PrintFormat("[EA_Rangos_HA] Configuración horaria (UTC+3 The5ers): A[%s-%s] B[%s-%s] C[%s-%s]",
               InpStartTimeA, InpEndTimeA, InpStartTimeB, InpEndTimeB, InpStartTimeC, InpEndTimeC);
   Print("=== [EA_Rangos_HA] Inicialización completada con éxito ===");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("[EA_Rangos_HA] Desinicializando y limpiando objetos...");
   ObjectsDeleteAll(0, OBJ_PREFIX);
   RestoreOriginalChart();
   Print("[EA_Rangos_HA] Gráfico restaurado correctamente.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   MqlRates current_rates[1];
   if(CopyRates(_Symbol, PERIOD_M15, 0, 1, current_rates) <= 0) return;
   
   datetime bar_time = current_rates[0].time;
   bool is_new_bar = false;
   
   if(bar_time != g_last_bar_time)
   {
      // --- NUEVA VELA M15 ABIERTA ---
      is_new_bar = true;
      
      // La barra anterior queda definitivamente cerrada
      g_prev_ha_open  = g_curr_ha_open;
      g_prev_ha_close = g_curr_ha_close;
      g_last_bar_time = bar_time;
      
      // Apertura de la nueva vela Heikin Ashi
      g_curr_ha_open  = (g_prev_ha_open + g_prev_ha_close) / 2.0;
      g_curr_ha_close = (current_rates[0].open + current_rates[0].high + current_rates[0].low + current_rates[0].close) / 4.0;
      g_curr_ha_high  = MathMax(current_rates[0].high, MathMax(g_curr_ha_open, g_curr_ha_close));
      g_curr_ha_low   = MathMin(current_rates[0].low,  MathMin(g_curr_ha_open, g_curr_ha_close));
      
      DrawHACandle(g_last_bar_time, g_curr_ha_open, g_curr_ha_high, g_curr_ha_low, g_curr_ha_close);
      
      // Control FIFO de memoria de objetos
      if(g_drawn_count >= InpMaxBars && g_drawn_count > 0)
      {
         DeleteHACandle(g_drawn_bars[0]);
         ArrayCopy(g_drawn_bars, g_drawn_bars, 0, 1, g_drawn_count - 1);
         g_drawn_bars[g_drawn_count - 1] = bar_time;
      }
      else
      {
         ArrayResize(g_drawn_bars, g_drawn_count + 1);
         g_drawn_bars[g_drawn_count++] = bar_time;
      }
   }
   else
   {
      // --- MISMA VELA M15 (TICK EN CURSO) ---
      // HA_Open permanece fijo desde el comienzo de la vela
      g_curr_ha_close = (current_rates[0].open + current_rates[0].high + current_rates[0].low + current_rates[0].close) / 4.0;
      g_curr_ha_high  = MathMax(current_rates[0].high, MathMax(g_curr_ha_open, g_curr_ha_close));
      g_curr_ha_low   = MathMin(current_rates[0].low,  MathMin(g_curr_ha_open, g_curr_ha_close));
      
      // Actualizar cuerpo y mecha sin crear duplicados
      DrawHACandle(g_last_bar_time, g_curr_ha_open, g_curr_ha_high, g_curr_ha_low, g_curr_ha_close);
   }
   
   // Actualizar extremos de rangos si corresponde
   UpdateLiveRanges(current_rates[0]);
   
   // Refrescar el gráfico suavemente
   ulong now_ms = GetTickCount64();
   if(is_new_bar || (now_ms - g_last_redraw_time > 40))
   {
      ChartRedraw(0);
      g_last_redraw_time = now_ms;
   }
}
//+------------------------------------------------------------------+
