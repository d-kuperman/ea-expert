//+------------------------------------------------------------------+
//| FVG_Opuestos_5Velas - detector independiente SIN TRADING           |
//| V1..V5 cronologicas. Dos FVG opuestos: candidato, NO iFVG confirmado|
//+------------------------------------------------------------------+
#property strict
#property version "1.00"
#property description "Detector de cinco velas con FVG opuestos. Sin operaciones."

input group "Geometria V3: porcentajes 0..100"
input double InpMaxBodyPct=20.0;         // Cuerpo/rango: maximo %
input double InpMinDominantWickPct=60.0; // Mecha dominante/rango: minimo %
input double InpMaxOppositeWickPct=10.0; // Mecha opuesta/rango: maximo %
input double InpMinWickBodyRatio=3.0;    // Mecha dominante/cuerpo (0 desactiva)
input group "Salida"
input bool InpSaveCSV=true;
input bool InpUseCommonFolder=false;    // true: Terminal/Common/Files
input bool InpDrawPatterns=true;
input color InpBullFVGColor=clrMediumSeaGreen;
input color InpBearFVGColor=clrTomato;
input color InpV3Color=clrGold;

struct PatternInfo
{
   bool bullish;
   double body,upper_wick,lower_wick,total_range;
   double body_pct,upper_pct,lower_pct;
   double bull_low,bull_high,bear_low,bear_high;
};
datetime g_seen_bar=0,g_last_v5=0;
long g_bulls=0,g_bears=0,g_csv_rows=0;
int g_file=INVALID_HANDLE;
bool g_draw=false,g_ready=false;
string g_csv_name="",g_prefix="";

string TimeText(const datetime t) { return TimeToString(t,TIME_DATE|TIME_SECONDS); }
string TimeframeText()
{
   string s=EnumToString(_Period);
   StringReplace(s,"PERIOD_","");
   return s;
}
// Fin nominal de V5 en hora del servidor (MN1 usa meses calendario).
// Se reconoce el cierre al llegar el primer tick de la siguiente barra.
// detected_at se exporta aparte para distinguir las pausas de sesion.
datetime BarEnd(const datetime start)
{
   if(_Period!=PERIOD_MN1) return start+PeriodSeconds(_Period);
   MqlDateTime t;
   TimeToStruct(start,t);
   t.day=1; t.hour=0; t.min=0; t.sec=0; t.mon++;
   if(t.mon>12) { t.mon=1; t.year++; }
   return StructToTime(t);
}
// Funcion pura: solo las cinco velas cerradas suministradas.
// v[0]=V1, v[1]=V2, v[2]=V3, v[3]=V4, v[4]=V5.
bool DetectPattern(const MqlRates &v[],PatternInfo &p)
{
   if(ArraySize(v)!=5) return false;
   for(int i=0;i<5;i++)
   {
      if(v[i].high<=v[i].low || v[i].close==v[i].open) return false;
      // Integridad de OHLC; no es un filtro de estrategia.
      if(v[i].high<MathMax(v[i].open,v[i].close) ||
         v[i].low>MathMin(v[i].open,v[i].close)) return false;
   }
   bool bear=(v[0].close>v[0].open && v[1].close>v[1].open &&
              v[2].close<v[2].open && v[3].close<v[3].open && v[4].close<v[4].open);
   bool bull=(v[0].close<v[0].open && v[1].close<v[1].open &&
              v[2].close>v[2].open && v[3].close>v[3].open && v[4].close>v[4].open);
   if(!bear && !bull) return false;
   p.bullish=bull;
   p.body=MathAbs(v[2].close-v[2].open);
   p.upper_wick=v[2].high-MathMax(v[2].open,v[2].close);
   p.lower_wick=MathMin(v[2].open,v[2].close)-v[2].low;
   p.total_range=v[2].high-v[2].low;
   p.body_pct=100.0*p.body/p.total_range;
   p.upper_pct=100.0*p.upper_wick/p.total_range;
   p.lower_pct=100.0*p.lower_wick/p.total_range;
   double dominant=bull ? p.lower_wick : p.upper_wick;
   double dominant_pct=bull ? p.lower_pct : p.upper_pct;
   double opposite_pct=bull ? p.upper_pct : p.lower_pct;
   if(p.body_pct>InpMaxBodyPct || dominant_pct<InpMinDominantWickPct ||
      opposite_pct>InpMaxOppositeWickPct || dominant/p.body<InpMinWickBodyRatio) return false;
   if(bear)
   {
      // Tripleta V1-V2-V3: FVG alcista. Tripleta V3-V4-V5: FVG bajista.
      if(!(v[2].low>v[0].high && v[4].high<v[2].low)) return false;
      p.bull_low=v[0].high; p.bull_high=v[2].low;
      p.bear_low=v[4].high; p.bear_high=v[2].low;
   }
   else
   {
      // Tripleta V1-V2-V3: FVG bajista. Tripleta V3-V4-V5: FVG alcista.
      if(!(v[2].high<v[0].low && v[4].low>v[2].high)) return false;
      p.bear_low=v[2].high; p.bear_high=v[0].low;
      p.bull_low=v[2].high; p.bull_high=v[4].low;
   }
   return true;
}
// CSV UTF-8 con ';', punto decimal y escape de campos de texto.
string CSVQuote(string s)
{
   StringReplace(s,"\"","\"\"");
   return "\""+s+"\"";
}
bool WriteLine(const string s)
{
   ResetLastError();
   if(FileWriteString(g_file,s+"\r\n")==0)
   {
      PrintFormat("ERROR CSV (%d). Se detiene el detector para no perder registros silenciosamente.",GetLastError());
      return false;
   }
   return true;
}
bool OpenCSV()
{
   if(!InpSaveCSV) return true;
   string symbol=_Symbol;
   StringReplace(symbol,"\\","_"); StringReplace(symbol,"/","_");
   StringReplace(symbol,":","_"); StringReplace(symbol,"*","_");
   StringReplace(symbol,"?","_"); StringReplace(symbol,"\"","_");
   StringReplace(symbol,"<","_"); StringReplace(symbol,">","_"); StringReplace(symbol,"|","_");
   string stem="FVG_Opuestos_5Velas\\"+symbol+"_"+TimeframeText()+"_"+
               IntegerToString((long)TimeLocal())+"_"+IntegerToString((long)GetMicrosecondCount());
   int common=InpUseCommonFolder ? FILE_COMMON : 0;
   g_csv_name=stem+".csv";
   int suffix=0;
   while(FileIsExist(g_csv_name,common)) g_csv_name=stem+"_"+IntegerToString(++suffix)+".csv";
   g_file=FileOpen(g_csv_name,FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|common,0,CP_UTF8);
   if(g_file==INVALID_HANDLE)
   {
      PrintFormat("ERROR abriendo CSV %s (%d)",g_csv_name,GetLastError());
      return false;
   }
   string h="v3_time;confirmation_v5_close;detected_at;symbol;timeframe;direction;status";
   for(int i=1;i<=5;i++)
   {
      string tag=";v"+IntegerToString(i);
      h+=tag+"_time"+tag+"_open"+tag+"_high"+tag+"_low"+tag+"_close";
   }
   h+=";v3_body;v3_upper_wick;v3_lower_wick;v3_range;body_pct;upper_wick_pct;lower_wick_pct";
   h+=";bull_fvg_points;bear_fvg_points;bull_fvg_low;bull_fvg_high;bear_fvg_low;bear_fvg_high;point";
   h+=";max_body_pct;min_dominant_wick_pct;max_opposite_wick_pct;min_wick_body_ratio";
   if(!WriteLine(h)) return false;
   FileFlush(g_file);
   string root=InpUseCommonFolder ? TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\" :
                                   TerminalInfoString(TERMINAL_DATA_PATH)+"\\MQL5\\Files\\";
   Print("CSV de esta ejecucion: ",root,g_csv_name);
   return true;
}
bool SavePattern(const MqlRates &v[],const PatternInfo &p)
{
   if(!InpSaveCSV) return true;
   string s=TimeText(v[2].time)+";"+TimeText(BarEnd(v[4].time))+";"+TimeText(TimeCurrent())+";"+
            CSVQuote(_Symbol)+";"+TimeframeText()+";"+(p.bullish ? "ALCISTA" : "BAJISTA")+";CANDIDATO_IFVG";
   for(int i=0;i<5;i++)
      s+=";"+TimeText(v[i].time)+";"+DoubleToString(v[i].open,_Digits)+";"+
         DoubleToString(v[i].high,_Digits)+";"+DoubleToString(v[i].low,_Digits)+";"+DoubleToString(v[i].close,_Digits);
   s+=";"+DoubleToString(p.body,_Digits)+";"+DoubleToString(p.upper_wick,_Digits)+";"+
      DoubleToString(p.lower_wick,_Digits)+";"+DoubleToString(p.total_range,_Digits)+";"+
      DoubleToString(p.body_pct,8)+";"+DoubleToString(p.upper_pct,8)+";"+DoubleToString(p.lower_pct,8);
   s+=";"+DoubleToString((p.bull_high-p.bull_low)/_Point,8)+";"+
      DoubleToString((p.bear_high-p.bear_low)/_Point,8)+";"+
      DoubleToString(p.bull_low,_Digits)+";"+DoubleToString(p.bull_high,_Digits)+";"+
      DoubleToString(p.bear_low,_Digits)+";"+DoubleToString(p.bear_high,_Digits)+";"+DoubleToString(_Point,_Digits);
   s+=";"+DoubleToString(InpMaxBodyPct,8)+";"+DoubleToString(InpMinDominantWickPct,8)+";"+
      DoubleToString(InpMaxOppositeWickPct,8)+";"+DoubleToString(InpMinWickBodyRatio,8);
   if(!WriteLine(s)) return false;
   g_csv_rows++;
   FileFlush(g_file); // Solo al encontrar un patron, no por tick.
   return true;
}
void Rectangle(const string name,const datetime left,const datetime right,
               const double low,const double high,const color c,const bool fill,const int width)
{
   if(!ObjectCreate(0,name,OBJ_RECTANGLE,0,left,low,right,high))
   { PrintFormat("ERROR objeto %s (%d)",name,GetLastError()); return; }
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_FILL,fill);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,width);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}
void Label(const string name,const datetime at,const double price,const string text,const color c,const int size)
{
   if(!ObjectCreate(0,name,OBJ_TEXT,0,at,price))
   { PrintFormat("ERROR objeto %s (%d)",name,GetLastError()); return; }
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,c);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LOWER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}
void DrawPattern(const MqlRates &v[],const PatternInfo &p)
{
   if(!g_draw) return;
   string id=g_prefix+IntegerToString((long)v[2].time)+"_";
   color direction=p.bullish ? InpBullFVGColor : InpBearFVGColor;
   double top=v[0].high,bottom=v[0].low;
   for(int i=1;i<5;i++) { top=MathMax(top,v[i].high); bottom=MathMin(bottom,v[i].low); }
   double pad=MathMax((top-bottom)*0.08,3.0*_Point);
   datetime end=BarEnd(v[4].time);
   // Zonas limitadas a sus tripletas. Nunca se extienden al futuro.
   Rectangle(id+"FVG1",v[0].time,BarEnd(v[2].time),
             p.bullish ? p.bear_low : p.bull_low,p.bullish ? p.bear_high : p.bull_high,
             p.bullish ? InpBearFVGColor : InpBullFVGColor,true,1);
   Rectangle(id+"FVG2",v[2].time,end,
             p.bullish ? p.bull_low : p.bear_low,p.bullish ? p.bull_high : p.bear_high,
             p.bullish ? InpBullFVGColor : InpBearFVGColor,false,2);
   Rectangle(id+"FIVE",v[0].time,end,bottom-pad,top+pad,direction,false,1);
   Rectangle(id+"CENTRAL",v[2].time,BarEnd(v[2].time),v[2].low,v[2].high,InpV3Color,false,2);
   for(int i=0;i<5;i++)
      Label(id+"V"+IntegerToString(i+1),v[i].time,v[i].high+pad*0.2,
            "V"+IntegerToString(i+1),i==2 ? InpV3Color : direction,i==2 ? 11 : 8);
   Label(id+"TITLE",v[2].time,top+pad*2.0,
         (p.bullish ? "ALCISTA" : "BAJISTA")+" | candidato iFVG",direction,10);
   Label(id+"F1LABEL",v[1].time,p.bullish ? p.bear_high : p.bull_high,
         p.bullish ? "FVG1 bajista" : "FVG1 alcista",p.bullish ? InpBearFVGColor : InpBullFVGColor,8);
   Label(id+"F2LABEL",v[3].time,p.bullish ? p.bull_low : p.bear_low,
         p.bullish ? "FVG2 alcista" : "FVG2 bajista",p.bullish ? InpBullFVGColor : InpBearFVGColor,8);
   ChartRedraw(0);
}
void PrintTotals()
{
   PrintFormat("FVG opuestos | ALCISTAS=%I64d | BAJISTAS=%I64d | TOTAL=%I64d | filas CSV=%I64d",
               g_bulls,g_bears,g_bulls+g_bears,g_csv_rows);
}
int OnInit()
{
   if(!MathIsValidNumber(InpMaxBodyPct) || InpMaxBodyPct<0 || InpMaxBodyPct>100 ||
      !MathIsValidNumber(InpMinDominantWickPct) || InpMinDominantWickPct<0 || InpMinDominantWickPct>100 ||
      !MathIsValidNumber(InpMaxOppositeWickPct) || InpMaxOppositeWickPct<0 || InpMaxOppositeWickPct>100 ||
      !MathIsValidNumber(InpMinWickBodyRatio) || InpMinWickBodyRatio<0)
   { Print("Parametros invalidos: porcentajes 0..100, relacion mecha/cuerpo >=0."); return INIT_PARAMETERS_INCORRECT; }
   if(_Point<=0 || PeriodSeconds(_Period)<=0) return INIT_FAILED;
   g_draw=InpDrawPatterns && (!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE));
   g_prefix="FVG5_"+IntegerToString((long)GetMicrosecondCount())+"_";
   if(!OpenCSV()) return INIT_FAILED;
   g_ready=true;
   Print("Detector FVG opuestos: ",_Symbol," ",TimeframeText(),
         ". Solo candidatos iFVG; sin operaciones. Horas del servidor.");
   return INIT_SUCCEEDED;
}
void OnTick()
{
   if(!g_ready) return;
   datetime current=iTime(_Symbol,_Period,0);
   if(current<=0 || current<=g_seen_bar) return;
   int oldest_shift=1;
   if(g_last_v5>0)
   {
      int previous=iBarShift(_Symbol,_Period,g_last_v5,true);
      if(previous<0) return; // Esperar historia; no inventar resultados.
      oldest_shift=previous-1;
   }
   // Habitualmente una ventana por barra. Recupera pendientes si hubo
   // lectura incompleta, sin volver a escanear todo el pasado.
   for(int shift=oldest_shift;shift>=1;shift--)
   {
      MqlRates v[5]; // Array normal: CopyRates coloca la mas antigua primero.
      if(CopyRates(_Symbol,_Period,shift,5,v)!=5) return;
      if(v[4].time<=g_last_v5) continue;
      PatternInfo p;
      if(DetectPattern(v,p))
      {
         if(!SavePattern(v,p)) { g_ready=false; ExpertRemove(); return; }
         if(p.bullish) g_bulls++; else g_bears++;
         DrawPattern(v,p);
         PrintFormat("%s | V3=%s | cierre V5=%s | CANDIDATO_IFVG",
                     p.bullish ? "ALCISTA" : "BAJISTA",TimeText(v[2].time),TimeText(BarEnd(v[4].time)));
         PrintTotals();
      }
      g_last_v5=v[4].time; // Tambien sin patron: cada ventana una sola vez.
   }
   g_seen_bar=current;
}
void OnDeinit(const int reason)
{
   if(g_file!=INVALID_HANDLE) { FileFlush(g_file); FileClose(g_file); g_file=INVALID_HANDLE; }
   PrintTotals();
   // Conservar dibujos y resultados sin alterarlos retroactivamente.
}
