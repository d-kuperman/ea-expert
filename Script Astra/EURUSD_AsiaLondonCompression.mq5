// Statistical research script. No order, position or indicator APIs.
#property copyright "Statistical research"
#property version   "1.01"
#property strict
#property script_show_inputs

input datetime StartDate=D'2020.01.01'; // Dates in study timezone; inclusive
input datetime EndDate=D'2025.12.31';
input int AsiaStartHour=20;
input int AsiaEndHour=4;                // EXCLUSIVE: 4 means through 03:59:59
input int LondonStartHour=4;
input int LondonEndHour=8;              // EXCLUSIVE
input int NYStartHour=8;
input int NYEndHour=14;                 // EXCLUSIVE
input int UTCOffset=-3;                // Fixed study timezone, no DST
input string StudySymbol="EURUSD";     // Symbol (broker suffix allowed)
input int ServerUTCOffsetMinutes=999;   // REQUIRED: 120=UTC+2; 999=not configured
input string ServerOffsetSchedule=""; // UTC effective time=minutes;... (overrides fixed)
input int ContextWarmupCalendarDays=120;
input int HistoryRetries=3;
input int RetryDelayMilliseconds=200;
input int ProgressEveryDays=20;
input bool UseCommonFiles=false;
input string OutputFolder="AsiaLondonCompression";
input string RunTag="";                // Optional separate run subdirectory
input bool RunSelfTestsOnly=false;      // Synthetic tests, no historical download

const double NA=EMPTY_VALUE;
double g_point=0.00001,g_pip=0.0001;
int g_digits=5;
datetime g_offset_time[],g_now_utc;
int g_offset_minutes[];
string g_dir,g_prefix,g_header="";
bool g_io_ok=true;
int g_tests_failed=0;
double g_targets[7]={0.5,1.0,1.5,2.0,2.5,3.0,4.0};
string g_target_names[7]={"0_5R","1R","1_5R","2R","2_5R","3R","4R"};

struct Session
  {
   bool complete;
   int expected,bars,missing,max_gap,bad;
   double high,low,range,open,close;
   datetime high_time,low_time;
  };
struct BreakResult
  {
   bool hit,gap,mae_ambiguous,return_possible;
   int index;
   double level,observed_open,mfe,mae,mae_lower,normalized,minutes_mfe;
   datetime time,mfe_time,return_time,return_possible_time,opposite_time,opposite_possible_time;
   string returned,opposite_after;
   double risk[3];
   string outcome[21];
  };
struct DayResult
  {
   datetime date,ny_start;
   int dow;
   string status,setup_status,classification,first_direction;
   bool weekend,setup_known,valid,outcome_complete,both;
   Session asia,london,ny;
   double compression,london_mid,london_pos,price,price_pos;
   BreakResult high_break,low_break;
   datetime first_time,mfe_time,returned_time;
   double first_level,minutes_break,mfe,mae,mae_lower,expansion,minutes_mfe;
   string returned;
   datetime previous_date;
   double previous_range,previous_open,previous_close,atr,adr,previous_coverage,context_min_coverage;
   string previous_direction,context_quality;
   int context_days;
  };
struct ContextDay
  {
   datetime date;
   bool present;
   double range,open,close,coverage,tr,atr;
  };
DayResult g_days[];
ContextDay g_context[];

bool Has(const double x) { return x!=NA && MathIsValidNumber(x); }
datetime Midnight(const datetime t) { return (datetime)((long)t/86400*86400); }
int Weekday(const datetime t) { MqlDateTime z; TimeToStruct(t,z); return z.day_of_week; }
string DayName(const int d)
  {
   string names[7]={"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"};
   return names[d];
  }
string N(const double x,const int decimals=8) { return Has(x)?DoubleToString(x,decimals):""; }
string I(const int x) { return IntegerToString(x); }
string B(const bool x) { return x?"true":"false"; }
string T(const datetime t) { return t>0?TimeToString(t,TIME_DATE|TIME_SECONDS):""; }
string Quote(string s)
  {
   StringReplace(s,"\"","\"\"");
   return "\""+s+"\"";
  }
void Cell(string &row,const string s) { if(row!="") row+=","; row+=Quote(s); }
void Field(string &row,string &head,const string name,const string value)
  { Cell(row,value); Cell(head,name); }
void Number(string &row,string &head,const string name,const double value)
  { Field(row,head,name,N(value)); }
void Units(string &row,string &head,const string name,const double value,const double reference=EMPTY_VALUE)
  {
   Number(row,head,name+"Points",Has(value)?value/g_point:NA);
   Number(row,head,name+"Pips",Has(value)?value/g_pip:NA);
   if(Has(reference)) Number(row,head,name+"PctAsia",Has(value)&&reference>0?100*value/reference:NA);
  }
bool WriteLine(const int handle,const string line)
  {
   if(!g_io_ok) return false;
   ResetLastError();
   if(FileWriteString(handle,line+"\r\n")==0)
     { Print("CSV write failure: ",GetLastError()); g_io_ok=false; return false; }
   return true;
  }
int OpenCSV(const string suffix)
  {
   int flags=FILE_WRITE|FILE_TXT|FILE_ANSI;
   if(UseCommonFiles) flags|=FILE_COMMON;
   int h=FileOpen(g_dir+g_prefix+suffix+".csv",flags,0,CP_UTF8);
   if(h==INVALID_HANDLE) { Print("Cannot open ",suffix," error ",GetLastError()); g_io_ok=false; }
   return h;
  }
void InitSession(Session &s)
  {
   ZeroMemory(s); s.high=NA; s.low=NA; s.range=NA; s.open=NA; s.close=NA;
  }
void InitBreak(BreakResult &b)
  {
   ZeroMemory(b); b.index=-1; b.level=NA; b.observed_open=NA;
   b.mfe=NA; b.mae=NA; b.mae_lower=NA; b.normalized=NA; b.minutes_mfe=NA;
   b.returned="";
   for(int j=0;j<3;j++) b.risk[j]=NA;
   for(int j=0;j<21;j++) b.outcome[j]="NO_BREAK";
  }
void InitDay(DayResult &d,const datetime date)
  {
   ZeroMemory(d); d.date=date; d.dow=Weekday(date); d.weekend=(d.dow==0||d.dow==6);
   InitSession(d.asia); InitSession(d.london); InitSession(d.ny);
   InitBreak(d.high_break); InitBreak(d.low_break);
   d.compression=NA; d.london_mid=NA; d.london_pos=NA; d.price=NA; d.price_pos=NA;
   d.first_level=NA; d.minutes_break=NA; d.mfe=NA; d.mae=NA; d.mae_lower=NA;
   d.expansion=NA; d.minutes_mfe=NA; d.previous_range=NA; d.previous_open=NA;
   d.previous_close=NA; d.atr=NA; d.adr=NA; d.previous_coverage=NA;
   d.context_min_coverage=NA; d.setup_status="UNKNOWN"; d.classification="UNAVAILABLE";
  }

// Each schedule entry is an effective UTC timestamp. Never infer past DST from today's offset.
bool InitOffsets()
  {
   ArrayResize(g_offset_time,0); ArrayResize(g_offset_minutes,0);
   if(ServerOffsetSchedule=="")
     {
      if(ServerUTCOffsetMinutes < -840 || ServerUTCOffsetMinutes > 840)
        { Print("Configure ServerUTCOffsetMinutes or ServerOffsetSchedule before running."); return false; }
      ArrayResize(g_offset_time,1); ArrayResize(g_offset_minutes,1);
      g_offset_time[0]=0; g_offset_minutes[0]=ServerUTCOffsetMinutes; return true;
     }
   string entries[]; int count=StringSplit(ServerOffsetSchedule,';',entries);
   if(count<1) return false;
   ArrayResize(g_offset_time,count); ArrayResize(g_offset_minutes,count);
   for(int j=0;j<count;j++)
     {
      string pair[];
      if(StringSplit(entries[j],'=',pair)!=2) { Print("Bad offset entry: ",entries[j]); return false; }
      StringTrimLeft(pair[0]); StringTrimRight(pair[0]);
      StringTrimLeft(pair[1]); StringTrimRight(pair[1]);
      datetime t=StringToTime(pair[0]);
      if(StringLen(pair[0])!=16 || TimeToString(t,TIME_DATE|TIME_MINUTES)!=pair[0])
        { Print("Offset date must be YYYY.MM.DD HH:MM: ",pair[0]); return false; }
      int minutes=(int)StringToInteger(pair[1]);
      if(IntegerToString(minutes)!=pair[1] || minutes < -840 || minutes > 840)
        { Print("Offset must be integer minutes without + prefix: ",pair[1]); return false; }
      if(j>0 && t<=g_offset_time[j-1]) { Print("Offsets must be sorted and unique."); return false; }
      g_offset_time[j]=t; g_offset_minutes[j]=minutes;
     }
   datetime need=Midnight(StartDate)-(ContextWarmupCalendarDays+2)*86400-UTCOffset*3600;
   if(g_offset_time[0]>need) { Print("Offset schedule must cover warmup too: ",T(need)); return false; }
   return true;
  }
bool AmbiguousServerMinute(const datetime server_time)
  {
   for(int k=1;k<ArraySize(g_offset_time);k++)
     {
      if(g_offset_minutes[k]>=g_offset_minutes[k-1]) continue;
      datetime lo=g_offset_time[k]+g_offset_minutes[k]*60;
      datetime hi=g_offset_time[k]+g_offset_minutes[k-1]*60;
      if(server_time>=lo && server_time<hi) return true;
     }
   return false;
  }

// Chronological M1 bars, converted to the study clock. Segment requests at historical offset changes.
int LoadLocal(const datetime lo,const datetime hi,MqlRates &out[])
  {
   ArrayResize(out,0); ArraySetAsSeries(out,false);
   datetime utc_lo=lo-UTCOffset*3600,utc_hi=hi-UTCOffset*3600;
   datetime closed_until=(datetime)((long)g_now_utc/60*60);
   if(utc_hi>closed_until) utc_hi=closed_until;
   if(utc_hi<=utc_lo) return 0;
   for(int s=0;s<ArraySize(g_offset_time)&&!IsStopped();s++)
     {
      datetime a=utc_lo>g_offset_time[s]?utc_lo:g_offset_time[s];
      datetime b=utc_hi;
      if(s+1<ArraySize(g_offset_time) && b>g_offset_time[s+1]) b=g_offset_time[s+1];
      if(b<=a) continue;
      MqlRates bars[]; ArraySetAsSeries(bars,false);
      int n=-1,last=-2;
      for(int attempt=0;attempt<HistoryRetries&&!IsStopped();attempt++)
        {
         ResetLastError();
         n=CopyRates(StudySymbol,PERIOD_M1,a+g_offset_minutes[s]*60,b+g_offset_minutes[s]*60-1,bars);
         if(n>=(int)((b-a)/60)) break;
         bool synced=(bool)SeriesInfoInteger(StudySymbol,PERIOD_M1,SERIES_SYNCHRONIZED);
         if(n>=0 && n==last && synced) break;
         last=n;
         // A synchronized series with a stable partial result needs no retry delay.
         if(n>=0 && synced) continue;
         if(attempt+1<HistoryRetries) Sleep(RetryDelayMilliseconds);
        }
      int old=ArraySize(out);
      if(n<=0) continue;
      ArrayResize(out,old+n);
      for(int j=0;j<n;j++)
        {
         out[old+j]=bars[j];
         out[old+j].time=bars[j].time-g_offset_minutes[s]*60+UTCOffset*3600;
         // Repeated server-clock minutes cannot be uniquely mapped after a backward DST switch.
         if(AmbiguousServerMinute(bars[j].time)) out[old+j].open=0;
        }
     }
   return ArraySize(out);
  }
bool GoodBar(const MqlRates &b)
  {
   return b.time%60==0 && MathIsValidNumber(b.open) && MathIsValidNumber(b.high)
      && MathIsValidNumber(b.low) && MathIsValidNumber(b.close) && b.low>0
      && b.high>=b.low && b.open>=b.low && b.open<=b.high && b.close>=b.low && b.close<=b.high;
  }
void Slice(const MqlRates &all[],const datetime lo,const datetime hi,MqlRates &part[],Session &s)
  {
   InitSession(s); s.expected=(int)((hi-lo)/60); ArrayResize(part,0);
   datetime next=lo;
   for(int j=0;j<ArraySize(all);j++)
     {
      if(all[j].time<lo || all[j].time>=hi) continue;
      if(!GoodBar(all[j]) || all[j].time<next) { s.bad++; continue; }
      int gap=(int)((all[j].time-next)/60);
      if(gap>s.max_gap) s.max_gap=gap;
      next=all[j].time+60;
      int k=ArraySize(part); ArrayResize(part,k+1,2048); part[k]=all[j];
      if(s.bars==0) { s.high=all[j].high; s.low=all[j].low; s.open=all[j].open; s.high_time=all[j].time; s.low_time=all[j].time; }
      if(all[j].high>s.high) { s.high=all[j].high; s.high_time=all[j].time; }
      if(all[j].low<s.low) { s.low=all[j].low; s.low_time=all[j].time; }
      s.close=all[j].close; s.bars++;
     }
   int end_gap=(int)((hi-next)/60); if(end_gap>s.max_gap) s.max_gap=end_gap;
   s.missing=s.expected-s.bars;
   s.complete=(s.bars==s.expected && s.bad==0 && s.expected>0);
   if(s.bars>0) s.range=s.high-s.low;
  }
void SessionBounds(const datetime date,datetime &as,datetime &ae,datetime &ls,datetime &le,datetime &ns,datetime &ne)
  {
   ns=date+NYStartHour*3600;
   ne=date+NYEndHour*3600; if(ne<=ns) ne+=86400;
   le=date+LondonEndHour*3600; if(le>ns) le-=86400;
   ls=Midnight(le)+LondonStartHour*3600; if(ls>=le) ls-=86400;
   ae=Midnight(ls)+AsiaEndHour*3600; if(ae>ls) ae-=86400;
   as=Midnight(ae)+AsiaStartHour*3600; if(as>=ae) as-=86400;
  }

// Outcome masks: win=1, loss=2, alive at NY end=4. Multiple possibilities => AMBIGUOUS.
string Simulate(const MqlRates &bars[],const BreakResult &br,const bool up,const double risk,const double target_r)
  {
   if(!br.hit) return "NO_BREAK";
   if(!Has(risk) || risk<=0) return "INVALID_RISK";
   if(br.gap) return "NA_GAP"; // A synthetic threshold fill cannot be assumed across a gap.
   double sl=br.level+(up?-risk:risk),tp=br.level+(up?risk*target_r:-risk*target_r);
   int mask=0; bool alive=true;
   for(int j=br.index;j<ArraySize(bars)&&alive;j++)
     {
      bool entry=(j==br.index);
      bool active_open=(!entry || (up?bars[j].open>=br.level:bars[j].open<=br.level));
      if(active_open && (up?bars[j].open<=sl:bars[j].open>=sl)) { mask|=2; alive=false; break; }
      if(active_open && (up?bars[j].open>=tp:bars[j].open<=tp)) { mask|=1; alive=false; break; }
      bool target=up?bars[j].high>=tp:bars[j].low<=tp;
      bool stop=up?bars[j].low<=sl:bars[j].high>=sl;
      bool stop_certain=stop && (active_open || (up?bars[j].close<=sl:bars[j].close>=sl));
      if(target)
        {
         mask|=1;
         if(stop) mask|=2; // Extremum order or a recrossing is unknowable from M1 OHLC.
         alive=false;
        }
      else if(stop) { mask|=2; if(stop_certain) alive=false; }
     }
   if(alive) mask|=4;
   if(mask==1) return "HIT_BEFORE_SL";
   if(mask==2) return "SL_FIRST";
   if(mask==4) return "NOT_REACHED";
   return "AMBIGUOUS";
  }
void MeasureBreak(const MqlRates &bars[],const Session &asia,const Session &london,const bool up,BreakResult &br)
  {
   InitBreak(br);
   for(int j=0;j<ArraySize(bars);j++)
     if(up?bars[j].high>=asia.high:bars[j].low<=asia.low) { br.index=j; break; }
   if(br.index<0) return;
   br.hit=true; br.level=up?asia.high:asia.low; br.time=bars[br.index].time;
   br.observed_open=bars[br.index].open;
   br.gap=up?br.observed_open>br.level:br.observed_open<br.level;
   br.mfe=0; br.mae=0; br.mae_lower=0; br.mfe_time=br.time; br.returned="false"; br.opposite_after="false";
   for(int j=br.index;j<ArraySize(bars);j++)
     {
      double favorable=MathMax(0,up?bars[j].high-br.level:br.level-bars[j].low);
      double adverse=MathMax(0,up?br.level-bars[j].low:bars[j].high-br.level);
      if(favorable>br.mfe) { br.mfe=favorable; br.mfe_time=bars[j].time; }
      br.mae=MathMax(br.mae,adverse);
      bool active_open=j>br.index || (up?bars[j].open>=br.level:bars[j].open<=br.level);
      bool opposite=up?bars[j].low<=asia.low:bars[j].high>=asia.high;
      bool opposite_certain=opposite && (active_open || (up?bars[j].close<=asia.low:bars[j].close>=asia.high));
      if(opposite && br.opposite_possible_time==0) br.opposite_possible_time=bars[j].time;
      if(opposite_certain && br.opposite_time==0) { br.opposite_time=bars[j].time; br.opposite_after="true"; }
      double certain=active_open?adverse:MathMax(0,up?br.level-bars[j].close:bars[j].close-br.level);
      br.mae_lower=MathMax(br.mae_lower,certain);
      bool inside_open=(bars[j].open>asia.low && bars[j].open<asia.high);
      bool inside_close=(bars[j].close>asia.low && bars[j].close<asia.high);
      // Actual in-range OHLC observation; do not invent an in-range tick across gaps.
      bool inside_extreme=up?(bars[j].low>asia.low && bars[j].low<asia.high)
                            :(bars[j].high>asia.low && bars[j].high<asia.high);
      bool certain_return=inside_close || (active_open&&inside_extreme) || (j>br.index&&inside_open);
      bool possible_return=up?bars[j].low<asia.high:bars[j].high>asia.low;
      if(possible_return && !br.return_possible)
        { br.return_possible=true; br.return_possible_time=bars[j].time; }
      if(certain_return && br.return_time==0) { br.return_time=bars[j].time; br.returned="true"; }
     }
   if(br.return_time==0 && br.return_possible) br.returned="AMBIGUOUS";
   if(br.opposite_time==0 && br.opposite_possible_time>0) br.opposite_after="AMBIGUOUS";
   br.mae_ambiguous=(br.mae>br.mae_lower+g_point*0.001);
   br.normalized=br.mfe/asia.range;
   br.minutes_mfe=(double)(br.mfe_time-br.time)/60.0;
   br.risk[0]=london.range; br.risk[1]=asia.range*0.5;
   br.risk[2]=up?br.level-london.low:london.high-br.level;
   for(int m=0;m<3;m++) for(int k=0;k<7;k++)
      br.outcome[m*7+k]=Simulate(bars,br,up,br.risk[m],g_targets[k]);
  }
void Classify(DayResult &d,const MqlRates &ny[])
  {
   d.first_direction=""; d.first_time=0; d.first_level=NA; d.minutes_break=NA;
   d.mfe=NA; d.mae=NA; d.mae_lower=NA; d.expansion=NA; d.mfe_time=0;
   d.minutes_mfe=NA; d.returned=""; d.returned_time=0;
   MeasureBreak(ny,d.asia,d.london,true,d.high_break);
   MeasureBreak(ny,d.asia,d.london,false,d.low_break);
   d.both=d.high_break.hit&&d.low_break.hit;
   int first=0;
   if(!d.high_break.hit && !d.low_break.hit) { d.classification="NO_BREAK"; d.first_direction="NONE"; return; }
   if(d.high_break.hit && !d.low_break.hit) { d.classification="HIGH_ONLY"; first=1; }
   else if(!d.high_break.hit && d.low_break.hit) { d.classification="LOW_ONLY"; first=-1; }
   else if(d.high_break.index<d.low_break.index) { d.classification="HIGH_THEN_LOW"; first=1; }
   else if(d.low_break.index<d.high_break.index) { d.classification="LOW_THEN_HIGH"; first=-1; }
   else
     {
      double op=ny[d.high_break.index].open;
      if(op>=d.asia.high) { d.classification="HIGH_THEN_LOW"; first=1; }
      else if(op<=d.asia.low) { d.classification="LOW_THEN_HIGH"; first=-1; }
      else { d.classification="BOTH_ORDER_AMBIGUOUS"; d.first_direction="AMBIGUOUS"; }
     }
   if(first==0)
     { d.first_time=d.high_break.time; d.minutes_break=(double)(d.first_time-d.ny_start)/60; return; }
   BreakResult br; if(first==1) br=d.high_break; else br=d.low_break;
   d.first_direction=first==1?"HIGH":"LOW";
   d.first_time=br.time; d.first_level=br.level;
   d.minutes_break=(double)(br.time-d.ny_start)/60;
   d.mfe=br.mfe; d.mae=br.mae; d.mae_lower=br.mae_lower; d.expansion=br.normalized;
   d.mfe_time=br.mfe_time; d.minutes_mfe=br.minutes_mfe; d.returned=br.returned; d.returned_time=br.return_time;
  }

void AssignContext(DayResult &d)
  {
   int n=ArraySize(g_context); d.context_quality="INSUFFICIENT";
   if(n==0) return;
   ContextDay prev=g_context[n-1];
   d.previous_date=prev.date;
   if(!prev.present) { d.context_quality="PREVIOUS_WEEKDAY_MISSING"; return; }
   d.previous_range=prev.range; d.previous_open=prev.open; d.previous_close=prev.close;
   d.previous_coverage=prev.coverage; d.atr=prev.atr;
   d.previous_direction=prev.close>prev.open?"UP":(prev.close<prev.open?"DOWN":"FLAT");
   double sum=0,mincov=100;
   for(int j=n-1;j>=0 && d.context_days<20;j--)
     {
      if(!g_context[j].present) break;
      sum+=g_context[j].range; mincov=MathMin(mincov,g_context[j].coverage); d.context_days++;
     }
   if(d.context_days>0) d.context_min_coverage=mincov;
   if(d.context_days==20) d.adr=sum/20;
   if(Has(d.atr)&&Has(d.adr)) d.context_quality=mincov==100?"FULL_M1":"OBSERVED_M1_PARTIAL";
  }
void AppendContext(const datetime date,const MqlRates &all[])
  {
   int dow=Weekday(date); if(dow==0 || dow==6) return;
   Session s; MqlRates part[]; Slice(all,date,date+86400,part,s);
   ContextDay c; ZeroMemory(c); c.date=date; c.present=s.bars>0 && s.bad==0;
   c.range=NA; c.open=NA; c.close=NA; c.tr=NA; c.atr=NA; c.coverage=100.0*s.bars/1440;
   int n=ArraySize(g_context);
   if(c.present)
     {
      c.range=s.range; c.open=s.open; c.close=s.close;
      if(n>0 && g_context[n-1].present)
         c.tr=MathMax(c.range,MathMax(MathAbs(s.high-g_context[n-1].close),MathAbs(s.low-g_context[n-1].close)));
      if(Has(c.tr))
        {
         if(n>0 && Has(g_context[n-1].atr)) c.atr=(13*g_context[n-1].atr+c.tr)/14;
         else
           {
            double sum=c.tr; int k=1;
            for(int j=n-1;j>=0 && k<14;j--) { if(!Has(g_context[j].tr)) break; sum+=g_context[j].tr; k++; }
            if(k==14) c.atr=sum/14;
           }
        }
     }
   ArrayResize(g_context,n+1,512); g_context[n]=c;
  }
void Analyze(const datetime date,const MqlRates &all[],DayResult &d)
  {
   InitDay(d,date); AssignContext(d);
   if(d.weekend) { d.status="WEEKEND"; return; }
   datetime a,b,c,e,f,g; SessionBounds(date,a,b,c,e,f,g); d.ny_start=f;
   MqlRates asia[],london[],ny[];
   Slice(all,a,b,asia,d.asia); Slice(all,c,e,london,d.london); Slice(all,f,g,ny,d.ny);
   if(d.asia.complete && d.london.complete && d.asia.range>0)
     {
      d.setup_known=true;
      d.valid=d.london.high<d.asia.high && d.london.low>d.asia.low;
      d.setup_status=d.valid?"VALID":"INVALID";
      d.compression=d.london.range/d.asia.range;
      d.london_mid=(d.london.high+d.london.low)/2;
      d.london_pos=(d.london_mid-d.asia.low)/d.asia.range;
     }
   if(ArraySize(ny)>0 && ny[0].time==f) d.price=ny[0].open;
   if(d.asia.complete && d.asia.range>0 && Has(d.price)) d.price_pos=(d.price-d.asia.low)/d.asia.range;
   d.outcome_complete=d.setup_known && d.ny.complete;
   if(!d.asia.complete || !d.london.complete) d.status="INCOMPLETE_SETUP_M1";
   else if(d.asia.range<=0) d.status="ZERO_ASIA_RANGE";
   else if(!d.ny.complete) d.status="INCOMPLETE_NY_M1";
   else d.status="OK";
   if(d.outcome_complete) Classify(d,ny);
  }

void SessionFields(string &row,string &head,const string name,const Session &s)
  {
   Field(row,head,name+"Complete",B(s.complete));
   Field(row,head,name+"ExpectedBars",I(s.expected)); Field(row,head,name+"Bars",I(s.bars));
   Field(row,head,name+"MissingBars",I(s.missing)); Field(row,head,name+"MaxGapMinutes",I(s.max_gap));
   Field(row,head,name+"BadBars",I(s.bad));
   Number(row,head,name+"High",s.high); Number(row,head,name+"Low",s.low);
   Number(row,head,name+"Range",s.range); Units(row,head,name+"Range",s.range);
   Field(row,head,name+"HighTime",T(s.high_time)); Field(row,head,name+"LowTime",T(s.low_time));
  }
void BreakFields(string &row,string &head,const string side,const BreakResult &b,const double ar,const bool available)
  {
   string p=side+"Break";
   Field(row,head,p+"Occurred",available?B(b.hit):"");
   Field(row,head,p+"Time",T(b.time)); Number(row,head,p+"Price",b.level);
   Number(row,head,p+"BarOpen",b.observed_open); Field(row,head,p+"Gap",b.hit?B(b.gap):"");
   Units(row,head,p+"MFE_",b.mfe,ar); Units(row,head,p+"MAE_",b.mae,ar);
   Units(row,head,p+"MAELower_",b.mae_lower,ar);
   Number(row,head,p+"MAERatio",b.hit?b.mae/ar:NA);
   Number(row,head,side+"NormalizedExpansion",b.normalized);
   Field(row,head,p+"MAEAmbiguous",b.hit?B(b.mae_ambiguous):"");
   Field(row,head,p+"MFETime",T(b.mfe_time)); Number(row,head,p+"MinutesToMFE",b.minutes_mfe);
   Field(row,head,p+"ReturnedInsideAsia",b.returned);
   Field(row,head,p+"TimeReturnedInsideAsia",T(b.return_time));
   Field(row,head,p+"EarliestPossibleReturnTime",T(b.return_possible_time));
   Field(row,head,p+"OppositeAfter",b.opposite_after);
   Field(row,head,p+"OppositeAfterTime",T(b.opposite_time));
   Field(row,head,p+"EarliestPossibleOppositeTime",T(b.opposite_possible_time));
   string model[3]={"A","B","C"};
   for(int m=0;m<3;m++)
     {
      Units(row,head,side+"_"+model[m]+"_SL_",b.risk[m]);
      for(int k=0;k<7;k++)
        {
         string stem=side+"_"+model[m]+"_"+g_target_names[k];
         string state=available?b.outcome[m*7+k]:"UNAVAILABLE";
         Field(row,head,stem+"_Status",state);
         Field(row,head,stem+"_HitBeforeSL",state=="HIT_BEFORE_SL"?"true":
               ((state=="SL_FIRST"||state=="NOT_REACHED")?"false":""));
        }
     }
  }
string DailyRow(const DayResult &d,string &head)
  {
   string row=""; head="";
   Field(row,head,"Date",TimeToString(d.date,TIME_DATE)); Field(row,head,"DayOfWeek",DayName(d.dow));
   Field(row,head,"Symbol",StudySymbol); Field(row,head,"UTCOffset",I(UTCOffset));
   Field(row,head,"DataStatus",d.status); Field(row,head,"SetupStatus",d.setup_status);
   Field(row,head,"SetupValid",d.setup_known?B(d.valid):"");
   Field(row,head,"OutcomeComplete",B(d.outcome_complete));
   SessionFields(row,head,"Asia",d.asia); SessionFields(row,head,"London",d.london);
   Number(row,head,"CompressionRatio",d.compression); Number(row,head,"LondonMid",d.london_mid);
   Number(row,head,"LondonMidPosition",d.london_pos);
   Field(row,head,"Price0800Time",T(d.ny_start)); Number(row,head,"Price0800",d.price);
   Number(row,head,"Price0800Position",d.price_pos);
   double ar=Has(d.asia.range)?d.asia.range:0;
   bool price_ok=d.asia.complete&&ar>0&&Has(d.price);
   Units(row,head,"Distance0800ToAsiaHigh",price_ok?d.asia.high-d.price:NA,ar);
   Units(row,head,"Distance0800ToAsiaLow",price_ok?d.price-d.asia.low:NA,ar);
   Field(row,head,"BreakoutClass",d.classification); Field(row,head,"FirstBreakDirection",d.first_direction);
   Field(row,head,"FirstBreakTime",T(d.first_time)); Number(row,head,"FirstBreakMinutesFrom0800",d.minutes_break);
   Number(row,head,"FirstBreakPrice",d.first_level);
   SessionFields(row,head,"NY",d.ny);
   Number(row,head,"NYRangeToAsiaRange",d.outcome_complete?d.ny.range/ar:NA);
   BreakFields(row,head,"High",d.high_break,ar,d.outcome_complete);
   BreakFields(row,head,"Low",d.low_break,ar,d.outcome_complete);
   Field(row,head,"ReturnedInsideAsia",d.returned); Field(row,head,"TimeReturnedInsideAsia",T(d.returned_time));
   Field(row,head,"BreakBothSides",d.outcome_complete?B(d.both):"");
   Units(row,head,"FirstBreakMFE_",d.mfe,ar); Units(row,head,"FirstBreakMAE_",d.mae,ar);
   Units(row,head,"FirstBreakMAELower_",d.mae_lower,ar);
   Field(row,head,"MFETime",T(d.mfe_time)); Number(row,head,"MinutesToMFE",d.minutes_mfe);
   Field(row,head,"PreviousDayDate",T(d.previous_date));
   Number(row,head,"PreviousDayRange",d.previous_range); Units(row,head,"PreviousDayRange",d.previous_range);
   Number(row,head,"PreviousDayOpen",d.previous_open); Number(row,head,"PreviousDayClose",d.previous_close);
   Field(row,head,"PreviousDayDirection",d.previous_direction);
   Number(row,head,"ATR14",d.atr); Units(row,head,"ATR14",d.atr);
   Number(row,head,"ADR20",d.adr); Units(row,head,"ADR20",d.adr);
   Number(row,head,"PreviousDayCoveragePct",d.previous_coverage);
   Number(row,head,"Context20MinCoveragePct",d.context_min_coverage);
   Field(row,head,"ContextConsecutiveDays",I(d.context_days)); Field(row,head,"ContextQuality",d.context_quality);
   return row;
  }

double Percentile(double &values[],const double p)
  {
   int n=ArraySize(values); if(n==0) return NA;
   ArraySort(values); double x=(n-1)*p; int a=(int)MathFloor(x),b=(int)MathCeil(x);
   return values[a]+(values[b]-values[a])*(x-a); // Linear interpolation, type 7
  }
double Mean(const double &values[])
  {
   int n=ArraySize(values); if(n==0) return NA;
   double total=0; for(int j=0;j<n;j++) total+=values[j]; return total/n;
  }
void Push(double &values[],const double x)
  { if(!Has(x)) return; int n=ArraySize(values); ArrayResize(values,n+1,256); values[n]=x; }
double Pct(const int a,const int n) { return n>0?100.0*a/n:NA; }
int CompressionBin(const double x)
  {
   if(!Has(x)||x<0||x>1) return -1;
   double edges[9]={0,0.2,0.3,0.4,0.5,0.6,0.7,0.8,1.0};
   for(int j=0;j<8;j++) if(x<edges[j+1] || (j==7&&x<=1)) return j;
   return -1;
  }
int PositionBin(const double x)
  {
   if(!Has(x)) return -1;
   if(x<0) return 5; if(x>1) return 6;
   if(x==1) return 4;
   return (int)MathFloor(x*5);
  }
int VolatilityBin(const double x)
  {
   if(!Has(x)) return -1;
   if(x<20) return 0; if(x<40) return 1; if(x<60) return 2; if(x<80) return 3;
   if(x<100) return 4; return 5;
  }
string CompressionLabel(const int j)
  { string a[8]={"[0.00,0.20)","[0.20,0.30)","[0.30,0.40)","[0.40,0.50)","[0.50,0.60)","[0.60,0.70)","[0.70,0.80)","[0.80,1.00]"}; return a[j]; }
string PositionLabel(const int j)
  { string a[7]={"[0.00,0.20)","[0.20,0.40)","[0.40,0.60)","[0.60,0.80)","[0.80,1.00]","BELOW_ASIA","ABOVE_ASIA"}; return a[j]; }
string VolatilityLabel(const int j)
  { string a[6]={"[0,20)","[20,40)","[40,60)","[60,80)","[80,100)","[100,+inf)"}; return a[j]; }
double Metric(const DayResult &d,const int id)
  {
   switch(id)
     {
      case 0: return d.asia.range/g_pip;
      case 1: return d.london.range/g_pip;
      case 2: return d.compression;
      case 3: return Has(d.mfe)?d.mfe/g_pip:NA;
      case 4: return Has(d.mae)?d.mae/g_pip:NA;
      case 5: return d.minutes_break;
      case 6: return d.minutes_mfe;
      case 7: return d.expansion;
      case 8: return Has(d.high_break.mfe)?d.high_break.mfe/g_pip:NA;
      case 9: return Has(d.low_break.mfe)?d.low_break.mfe/g_pip:NA;
      case 10: return Has(d.mae_lower)?d.mae_lower/g_pip:NA;
     }
   return NA;
  }
string MetricName(const int id)
  {
   string a[11]={"AsiaRangePips","LondonRangePips","CompressionRatio","MFE_Pips","MAE_UpperPips",
      "FirstBreakMinutesFrom0800","MinutesToMFE","NormalizedExpansion","HighBreakMFE_Pips","LowBreakMFE_Pips","MAE_LowerPips"}; return a[id];
  }
bool InGroup(const DayResult &d,const int kind,const int a,const int b)
  {
   if(!d.valid || !d.outcome_complete || d.weekend) return false;
   if(kind==0) return true;
   if(kind==1) return CompressionBin(d.compression)==a;
   if(kind==2) return PositionBin(d.london_pos)==a;
   if(kind==3) return PositionBin(d.price_pos)==a;
   if(kind==4) return CompressionBin(d.compression)==a && PositionBin(d.price_pos)==b;
   if(kind==5) return d.dow==a;
   if(kind==6)
     { double v=a==0?d.asia.range:(a==1?d.atr:d.adr); return Has(v)&&VolatilityBin(v/g_pip)==b; }
   if(kind==7) return d.compression<0.30 && (a==0?d.price_pos>0.80:d.price_pos<0.20);
   return false;
  }
string GroupRow(const int kind,const int a,const int b,const string label,const string label2,string &head)
  {
   int n=0,high=0,low=0,both=0,no=0,amb=0,fake=0,fake_unknown=0,first=0;
   int classes[6]; ArrayInitialize(classes,0);
   string row=""; head="";
   for(int j=0;j<ArraySize(g_days);j++)
     {
      if(!InGroup(g_days[j],kind,a,b)) continue;
      n++;
      if(g_days[j].first_direction=="HIGH") high++;
      if(g_days[j].first_direction=="LOW") low++;
      if(g_days[j].both) both++;
      if(g_days[j].classification=="NO_BREAK") no++;
      if(g_days[j].first_direction=="AMBIGUOUS") amb++;
      if(g_days[j].first_direction=="HIGH"||g_days[j].first_direction=="LOW")
        { first++; if(g_days[j].returned=="true") fake++; else if(g_days[j].returned=="AMBIGUOUS") fake_unknown++; }
      string c=g_days[j].classification;
      if(c=="HIGH_ONLY") classes[0]++; else if(c=="LOW_ONLY") classes[1]++;
      else if(c=="HIGH_THEN_LOW") classes[2]++; else if(c=="LOW_THEN_HIGH") classes[3]++;
      else if(c=="NO_BREAK") classes[4]++; else if(c=="BOTH_ORDER_AMBIGUOUS") classes[5]++;
     }
   Field(row,head,"Group",label); Field(row,head,"Subgroup",label2); Field(row,head,"Cases",I(n));
   Field(row,head,"HighFirstCount",I(high)); Field(row,head,"LowFirstCount",I(low));
   Number(row,head,"HighFirstPct",Pct(high,n)); Number(row,head,"LowFirstPct",Pct(low,n));
   Number(row,head,"BothSidesPct",Pct(both,n)); Number(row,head,"NoBreakPct",Pct(no,n));
   Number(row,head,"AmbiguousFirstPct",Pct(amb,n));
   Field(row,head,"KnownFirstBreakCases",I(first)); Field(row,head,"ReturnedInsideCount",I(fake));
   Field(row,head,"ReturnAmbiguousCount",I(fake_unknown));
   Number(row,head,"FakeoutLowerPct",Pct(fake,first)); Number(row,head,"FakeoutUpperPct",Pct(fake+fake_unknown,first));
   string cn[6]={"HIGH_ONLY","LOW_ONLY","HIGH_THEN_LOW","LOW_THEN_HIGH","NO_BREAK","BOTH_ORDER_AMBIGUOUS"};
   for(int k=0;k<6;k++) { Field(row,head,cn[k]+"_Count",I(classes[k])); Number(row,head,cn[k]+"_Pct",Pct(classes[k],n)); }
   for(int m=0;m<11;m++)
     {
      double v[];
      for(int j=0;j<ArraySize(g_days);j++) if(InGroup(g_days[j],kind,a,b)) Push(v,Metric(g_days[j],m));
      string p=MetricName(m);
      Field(row,head,p+"_N",I(ArraySize(v))); Number(row,head,p+"_Mean",Mean(v));
      Number(row,head,p+"_Median",Percentile(v,0.5));
      Number(row,head,p+"_P25",Percentile(v,0.25)); Number(row,head,p+"_P50",Percentile(v,0.5));
      Number(row,head,p+"_P75",Percentile(v,0.75)); Number(row,head,p+"_P90",Percentile(v,0.90));
      Number(row,head,p+"_P95",Percentile(v,0.95));
     }
   return row;
  }
void WriteGroups(const string suffix,const int kind)
  {
   int h=OpenCSV(suffix); if(h==INVALID_HANDLE) return;
   string head,row; bool wrote=false;
   int na=1,nb=1;
   if(kind==1||kind==4) na=8;
   if(kind==2) na=5;
   if(kind==3) na=7;
   if(kind==4) nb=7;
   if(kind==5) na=5;
   if(kind==6) { na=3; nb=6; }
   for(int a=0;a<na;a++) for(int b=0;b<nb;b++)
     {
      string label="ALL_VALID_COMPLETE",sub="";
      if(kind==1||kind==4) label=CompressionLabel(a);
      if(kind==2||kind==3) label=PositionLabel(a);
      if(kind==4) sub=PositionLabel(b);
      if(kind==5) label=DayName(a+1);
      if(kind==6) { label=a==0?"AsiaRangePips":(a==1?"ATR14Pips":"ADR20Pips"); sub=VolatilityLabel(b); }
      row=GroupRow(kind,kind==5?a+1:a,b,label,sub,head);
      if(!wrote) { WriteLine(h,head); wrote=true; }
      WriteLine(h,row);
     }
   if(kind==4)
     {
      WriteLine(h,GroupRow(7,0,0,"Compression<0.30","Price0800Position>0.80",head));
      WriteLine(h,GroupRow(7,1,0,"Compression<0.30","Price0800Position<0.20",head));
     }
   FileFlush(h); FileClose(h);
  }
void WriteSummary()
  {
   int total=0,valid=0,invalid=0,unknown=0,weekends=0,usable=0;
   for(int j=0;j<ArraySize(g_days);j++)
     {
      if(g_days[j].weekend) { weekends++; continue; }
      total++;
      if(!g_days[j].setup_known) unknown++;
      else if(g_days[j].valid) { valid++; if(g_days[j].outcome_complete) usable++; }
      else invalid++;
     }
   string row="",head="",gh,gr;
   Field(row,head,"CalendarRows",I(ArraySize(g_days))); Field(row,head,"TotalDays",I(total));
   Field(row,head,"WeekendDays",I(weekends)); Field(row,head,"EvaluableSetupDays",I(valid+invalid));
   Field(row,head,"UnknownSetupDays",I(unknown)); Field(row,head,"ValidSetups",I(valid));
   Field(row,head,"InvalidSetups",I(invalid)); Number(row,head,"ValidSetupPercentage",Pct(valid,valid+invalid));
   Field(row,head,"ValidSetupsWithCompleteNY",I(usable)); Field(row,head,"ValidSetupsMissingNY",I(valid-usable));
   gr=GroupRow(0,0,0,"ALL_VALID_COMPLETE","",gh);
   int h=OpenCSV("Summary"); if(h==INVALID_HANDLE) return;
   WriteLine(h,head+","+gh); WriteLine(h,row+","+gr); FileFlush(h); FileClose(h);
  }
void Meta(const int h,const string key,const string value)
  { WriteLine(h,Quote(key)+","+Quote(value)); }
void WriteMetadata(const string run_status,const datetime begun)
  {
   int h=OpenCSV("RunMetadata"); if(h==INVALID_HANDLE) return;
   WriteLine(h,"Key,Value"); Meta(h,"Version","1.01"); Meta(h,"RunStatus",run_status);
   Meta(h,"StartedUTC",T(begun)); Meta(h,"CompletedUTC",T(TimeGMT()));
   Meta(h,"DataSnapshotUTC",T(g_now_utc)); Meta(h,"Symbol",StudySymbol);
   Meta(h,"StartDate",T(Midnight(StartDate))); Meta(h,"EndDate",T(Midnight(EndDate)));
   Meta(h,"UTCOffset",I(UTCOffset)); Meta(h,"ServerUTCOffsetMinutes",I(ServerUTCOffsetMinutes));
   Meta(h,"ServerOffsetSchedule",ServerOffsetSchedule);
   Meta(h,"ServerClockFold","Repeated server minutes at backward offset changes are unusable and counted as BadBars");
   Meta(h,"AsiaStartHour",I(AsiaStartHour)); Meta(h,"AsiaEndHourExclusive",I(AsiaEndHour));
   Meta(h,"LondonStartHour",I(LondonStartHour)); Meta(h,"LondonEndHourExclusive",I(LondonEndHour));
   Meta(h,"NYStartHour",I(NYStartHour)); Meta(h,"NYEndHourExclusive",I(NYEndHour));
   Meta(h,"Digits",I(g_digits)); Meta(h,"Point",N(g_point)); Meta(h,"Pip",N(g_pip));
   Meta(h,"ContextWarmupCalendarDays",I(ContextWarmupCalendarDays));
   Meta(h,"HistoryRetries",I(HistoryRetries)); Meta(h,"RetryDelayMilliseconds",I(RetryDelayMilliseconds));
   Meta(h,"MaxBars",IntegerToString(TerminalInfoInteger(TERMINAL_MAXBARS)));
   Meta(h,"TerminalBuild",IntegerToString(TerminalInfoInteger(TERMINAL_BUILD)));
   Meta(h,"RowsWritten",I(ArraySize(g_days))); Meta(h,"UseCommonFiles",B(UseCommonFiles));
   Meta(h,"LastWrittenDate",ArraySize(g_days)>0?T(g_days[ArraySize(g_days)-1].date):"");
   Meta(h,"RequestedCalendarDays",IntegerToString((long)(Midnight(EndDate)-Midnight(StartDate))/86400+1));
   Meta(h,"RequiredM1Bars",IntegerToString(RequiredM1Bars()));
   Meta(h,"OutputFolder",g_dir); Meta(h,"OutputPrefix",g_prefix);
   Meta(h,"PriceSource","Broker M1 OHLC; no spread, commissions, swaps or slippage");
   Meta(h,"TimePrecision","M1 bar opening time, not exact tick time; first tied extremum retained");
   Meta(h,"Sessions","Start inclusive, end exclusive; anchored backwards from NY date; no overlaps");
   Meta(h,"MissingBars","Any missing setup minute -> UNKNOWN; any missing NY minute -> no outcome statistics");
   Meta(h,"MFE_MAE","First known side for generic metrics; both sides separately; MAE main fields are upper bounds; lower bounds exported");
   Meta(h,"Intrabar","No invented OHLC order; BOTH_ORDER_AMBIGUOUS, AMBIGUOUS R and return flags");
   Meta(h,"BreakPrice","Asian boundary, not a tick fill; gap at first bar open is flagged and R is NA_GAP");
   Meta(h,"RModels","A=LondonRange; B=0.5*AsiaRange; C=boundary to opposite London extreme; independent targets and sides");
   Meta(h,"RStatuses","HIT_BEFORE_SL,SL_FIRST,NOT_REACHED,AMBIGUOUS,NO_BREAK,INVALID_RISK,NA_GAP,UNAVAILABLE");
   Meta(h,"Context","Observed weekday M1 UTC study-day OHLC; partial coverage flagged; missing weekdays interrupt ATR/ADR");
   Meta(h,"ATR14","Wilder smoothing, seed mean of first 14 true ranges in warmup; only prior weekdays");
   Meta(h,"ADR20","Mean range of previous 20 consecutive observed weekdays; excludes weekends; no current day");
   Meta(h,"Percentiles","Type 7 linear interpolation at (N-1)*p; blanks are missing, never zero substitutes");
   Meta(h,"GroupDenominators","Valid setups with complete NY; first-direction percentages include ambiguous/no-break in denominator; metric N exported");
   Meta(h,"Fakeout","Return strictly inside Asia after first known breakout; lower/upper rates over known first-break cases");
   Meta(h,"VolatilityBinsPips","[0,20),[20,40),[40,60),[60,80),[80,100),[100,+inf); descriptive, not optimized");
   FileFlush(h); FileClose(h);
  }
void WriteDiagnostic(const string code,const string detail)
  {
   int h=OpenCSV("Diagnostic");
   if(h==INVALID_HANDLE) return;
   WriteLine(h,"TimeUTC,Code,Detail,Symbol,StartDate,EndDate");
   string row="",head="";
   Field(row,head,"TimeUTC",T(TimeGMT()));
   Field(row,head,"Code",code);
   Field(row,head,"Detail",detail);
   Field(row,head,"Symbol",StudySymbol);
   Field(row,head,"StartDate",T(Midnight(StartDate)));
   Field(row,head,"EndDate",T(Midnight(EndDate)));
   WriteLine(h,row); FileFlush(h); FileClose(h);
  }
void ShowStartupError(const string code,const string detail)
  {
   string base=UseCommonFiles?TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\":TerminalInfoString(TERMINAL_DATA_PATH)+"\\MQL5\\Files\\";
   Print("RESEARCH STOPPED [",code,"]: ",detail);
   Print("Diagnostic CSV: ",base,g_dir,g_prefix,"Diagnostic.csv");
   WriteDiagnostic(code,detail);
   Alert("AsiaLondonCompression detenido: "+detail+"\nRevisar Expertos y Diagnostic.csv.");
  }

void Check(const bool condition,const string name)
  { if(condition) Print("PASS ",name); else { Print("FAIL ",name); g_tests_failed++; } }
void SetBar(MqlRates &b,const datetime t,const double o,const double h,const double l,const double c)
  { ZeroMemory(b); b.time=t; b.open=o; b.high=h; b.low=l; b.close=c; b.tick_volume=1; }
void Fixture(const datetime date,const int mode,DayResult &d)
  {
   datetime a,b,c,e,f,g; SessionBounds(date,a,b,c,e,f,g);
   MqlRates rates[]; int n=(int)((g-a)/60); ArrayResize(rates,n+1);
   for(int j=0;j<n;j++)
     {
      datetime t=a+j*60;
      double hi=1.1005,lo=1.0995;
      if(t>=a&&t<b) { hi=1.102; lo=1.098; }
      if(t>=c&&t<e) { hi=1.101; lo=1.099; }
      if(mode==6&&t==c) hi=1.102; // exact high touch invalidates
      if(mode==7&&t==c) lo=1.098; // exact low touch invalidates
      if(t>=f)
        {
         int m=(int)((t-f)/60);
         if(mode==0 || (mode==2&&m==0) || (mode==3&&m>0)) hi=1.104;
         if(mode==1 || (mode==3&&m==0) || (mode==2&&m>0)) lo=1.096;
         if(mode==4) { hi=1.104; lo=1.096; }
        }
      SetBar(rates[j],t,1.1,hi,lo,1.1);
     }
   SetBar(rates[n],g,1.1,2.0,0.5,1.1); // Must never enter the NY outcome.
   if(mode==8) rates[n-1].open=0; // corrupted last NY minute
   if(mode==9) rates[1].open=0;   // corrupted Asia minute
   Analyze(date,rates,d);
  }
void SelfTests()
  {
   // No terminal history, no trades. Uses the same production analysis functions.
   g_point=0.00001; g_pip=0.0001; g_digits=5; g_tests_failed=0;
   Session asia,london; InitSession(asia); InitSession(london);
   asia.high=1.1010; asia.low=1.0990; asia.range=0.0020;
   london.high=1.1005; london.low=1.0995; london.range=0.0010;
   MqlRates bars[]; ArrayResize(bars,3); datetime t=D'2024.01.02 08:00';
   SetBar(bars[0],t,1.1000,1.1012,1.0998,1.1011);
   SetBar(bars[1],t+60,1.1011,1.1030,1.1008,1.1020);
   SetBar(bars[2],t+120,1.1020,1.1025,1.1005,1.1015);
   BreakResult br; MeasureBreak(bars,asia,london,true,br);
   Check(br.hit && br.time==t,"high touch/break detected");
   Check(MathAbs(br.mfe-0.0020)<1e-10,"high MFE includes breakout bar and later highs");
   Check(br.mae_ambiguous && br.mae>br.mae_lower,"pre-entry low is only an MAE upper bound");
   Check(br.returned=="true" && br.return_time==t+60,"first confirmed return minute");
   Check(Simulate(bars,br,true,0.0010,1.0)=="AMBIGUOUS","possible entry-bar stop retained across future target");
   Check(Simulate(bars,br,true,0.0015,1.0)=="HIT_BEFORE_SL","unambiguous TP before SL");
   DayResult d; InitDay(d,D'2024.01.02'); d.asia=asia; d.london=london; d.ny_start=t;
   Classify(d,bars); Check(d.classification=="HIGH_ONLY","HIGH_ONLY classification");
   SetBar(bars[0],t,1.1000,1.1015,1.0985,1.1000);
   Classify(d,bars); Check(d.classification=="BOTH_ORDER_AMBIGUOUS","same-minute both sides unresolved");
   SetBar(bars[0],t,1.1011,1.1015,1.0985,1.1000);
   Classify(d,bars); Check(d.classification=="HIGH_THEN_LOW","outside open resolves first side");
   Check(d.high_break.outcome[0]=="NA_GAP","gap cannot assume boundary fill");
   ArrayResize(bars,1); SetBar(bars[0],t,1.1000,1.1005,1.0995,1.1001);
   InitDay(d,D'2024.01.02'); d.asia=asia; d.london=london; d.ny_start=t; Classify(d,bars);
   Check(d.classification=="NO_BREAK" && !Has(d.mfe),"NO_BREAK metrics missing, not zero");
   SetBar(bars[0],t,1.1000,1.1005,1.0980,1.0985);
   MeasureBreak(bars,asia,london,false,br);
   Check(br.hit && MathAbs(br.mfe-0.001)<1e-10,"low MFE symmetric");
   Check(Simulate(bars,br,false,0,1)=="INVALID_RISK","zero risk protected");
   MqlRates part[]; Session coverage;
   Slice(bars,t,t+120,part,coverage); Check(!coverage.complete && coverage.missing==1,"missing M1 detected");
   double v[4]={1,2,3,4}; Check(Percentile(v,0.25)==1.75,"percentile type 7");
   Check(CompressionBin(0.2)==1 && CompressionBin(0.3)==2,"non-overlapping compression boundaries");
   Check(PositionBin(1)==4 && PositionBin(1.1)==6 && PositionBin(-0.1)==5,"position edges and outside bins");
   Check(MathAbs(0.001/g_pip-10)<1e-10,"5 digit conversion 100 points equals 10 pips");
   ArrayResize(g_offset_time,2); ArrayResize(g_offset_minutes,2);
   g_offset_time[0]=D'2023.01.01'; g_offset_minutes[0]=180;
   g_offset_time[1]=D'2023.10.29 01:00'; g_offset_minutes[1]=120;
   Check(AmbiguousServerMinute(D'2023.10.29 03:00') && AmbiguousServerMinute(D'2023.10.29 03:59'),"backward server clock repeated minutes");
   Check(!AmbiguousServerMinute(D'2023.10.29 02:59')&&!AmbiguousServerMinute(D'2023.10.29 04:00'),"clock fold interval is half open");
   ArrayResize(g_offset_time,0); ArrayResize(g_offset_minutes,0);
   ArrayResize(g_context,0); ArrayResize(g_days,0);
   string expected[6]={"HIGH_ONLY","LOW_ONLY","HIGH_THEN_LOW","LOW_THEN_HIGH","BOTH_ORDER_AMBIGUOUS","NO_BREAK"};
   datetime date=D'2024.01.02';
   for(int k=0;k<10;k++)
     {
      while(Weekday(date)==0||Weekday(date)==6) date+=86400;
      Fixture(date,k,d);
      if(k<6) Check(d.valid&&d.classification==expected[k],"fixture "+expected[k]);
      if(k==2) Check(d.high_break.opposite_after=="true" && d.low_break.opposite_after=="false","opposite side measured after each breakout independently");
      if(k==4) Check(d.high_break.opposite_after=="true" && d.high_break.opposite_possible_time<d.high_break.opposite_time,"possible intrabar opposite followed by confirmed later opposite");
      if(k==6||k==7) Check(d.setup_known&&!d.valid,"London exact boundary invalidates "+I(k));
      if(k==8) Check(d.valid&&!d.outcome_complete&&d.status=="INCOMPLETE_NY_M1","NY gap keeps setup known without outcomes");
      if(k==9) Check(!d.setup_known&&d.status=="INCOMPLETE_SETUP_M1","Asia gap is UNKNOWN, not invalid");
      Check(d.ny.high<2.0,"exclusive NY end "+I(k));
      ArrayResize(g_days,k+1); g_days[k]=d; date+=86400;
     }
   DayResult saturday; InitDay(saturday,D'2024.01.06'); saturday.status="WEEKEND";
   int count=ArraySize(g_days); ArrayResize(g_days,count+1); g_days[count]=saturday;
   // Context seed, Wilder update, and no look-ahead in the first analyzed day.
   ArrayResize(g_context,0);
   MqlRates ctx[]; ArrayResize(ctx,1440); date=D'2023.10.02';
   for(int day=0;day<22;day++)
     {
      while(Weekday(date)==0||Weekday(date)==6) date+=86400;
      for(int j=0;j<1440;j++) SetBar(ctx[j],date+j*60,1.1,1.102,1.098,1.1);
      AppendContext(date,ctx); date+=86400;
     }
   InitDay(d,date); AssignContext(d);
   Check(MathAbs(d.atr-0.004)<1e-10 && MathAbs(d.adr-0.004)<1e-10,"prior-day ATR14 Wilder and ADR20 context");
   Check(d.previous_date<date && d.context_days==20,"context excludes current day");
   ArrayResize(ctx,0); AppendContext(date,ctx); InitDay(d,date+86400); AssignContext(d);
   Check(!Has(d.atr)&&!Has(d.adr),"missing weekday breaks context chain");
   ArrayResize(g_context,0);
   // Emit actual CSVs for structural and numeric checks by external validation.
   g_dir="AsiaLondonCompression_SelfTests\\"; g_prefix="EURUSD_AsiaLondonCompression_";
   g_now_utc=TimeGMT(); g_io_ok=true;
   int file=OpenCSV("Daily"); string schema="",current_schema="";
   if(file!=INVALID_HANDLE)
     {
      for(int j=0;j<ArraySize(g_days);j++)
        {
         string line=DailyRow(g_days[j],current_schema);
         if(j==0) { schema=current_schema; WriteLine(file,schema); }
         Check(schema==current_schema,"stable daily schema "+I(j)); WriteLine(file,line);
        }
      FileClose(file);
     }
   WriteSummary(); WriteGroups("ByCompression",1); WriteGroups("ByLondonPosition",2);
   WriteGroups("ByPrice0800Position",3); WriteGroups("CompressionPriceCross",4);
   WriteGroups("ByWeekday",5); WriteGroups("ByVolatility",6); WriteMetadata("SYNTHETIC_TEST_DATA",g_now_utc);
   Check(g_io_ok,"nine synthetic CSV files written");
   Print("SELF TESTS: ",g_tests_failed==0?"ALL PASSED":"FAILED",", failures=",g_tests_failed);
  }

bool ValidateInputs()
  {
   if(Midnight(StartDate)>Midnight(EndDate) || StartDate<D'1971.01.01') return false;
   if(UTCOffset < -12 || UTCOffset > 14 || ContextWarmupCalendarDays<35 || HistoryRetries<1
      || HistoryRetries>20 || RetryDelayMilliseconds<0 || RetryDelayMilliseconds>5000 || ProgressEveryDays<1) return false;
   if(AsiaStartHour<0||AsiaStartHour>23||AsiaEndHour<0||AsiaEndHour>24
      ||LondonStartHour<0||LondonStartHour>23||LondonEndHour<0||LondonEndHour>24
      ||NYStartHour<0||NYStartHour>23||NYEndHour<0||NYEndHour>24) return false;
   datetime a,b,c,e,f,g; SessionBounds(Midnight(StartDate),a,b,c,e,f,g);
   if(!(a<b&&b<=c&&c<e&&e<=f&&f<g) || g-a>86400 || g-a<=0)
     { Print("Sessions must be ordered Asia -> London -> NY and span at most 24 hours."); return false; }
   // Keep daily aggregation independent of arbitrary paths supplied through inputs.
   if(StringFind(OutputFolder,"..")>=0||StringFind(OutputFolder,":")>=0||StringFind(OutputFolder,"/")>=0
      ||StringFind(OutputFolder,"\\")>=0||StringFind(RunTag,"..")>=0||StringFind(RunTag,":")>=0
      ||StringFind(RunTag,"/")>=0||StringFind(RunTag,"\\")>=0) return false;
   return true;
  }
long RequiredM1Bars()
  {
   datetime first=Midnight(StartDate)-(ContextWarmupCalendarDays+2)*86400;
   datetime last=Midnight(EndDate)+2*86400;
   return (long)(last-first)/60;
  }
bool ProbeHistory(const datetime lo,const datetime hi)
  {
   MqlRates sample[];
   for(int attempt=0;attempt<8&&!IsStopped();attempt++)
     {
      int bars=LoadLocal(lo,hi,sample);
      if(bars>0) return true;
      if(attempt<7) Sleep(1000);
     }
   return false;
  }
void OnStart()
  {
   if(RunSelfTestsOnly) { SelfTests(); return; }
   if(!ValidateInputs()) { Print("Invalid inputs. Read the analysis guide."); return; }
   g_prefix=StudySymbol+"_AsiaLondonCompression_";
   StringReplace(g_prefix,"/","_"); StringReplace(g_prefix,"\\","_"); StringReplace(g_prefix,":","_");
   g_dir=OutputFolder==""?"":OutputFolder+"\\";
   if(RunTag!="") g_dir+=RunTag+"\\";
   if(!InitOffsets())
     {
      int estimated=(int)MathRound((double)(TimeTradeServer()-TimeGMT())/60.0);
      if(estimated>=-840 && estimated<=840 && TimeTradeServer()>0)
         Print("Current server UTC offset estimate: ",estimated,
               " minutes. This is only a present-time clue; verify the broker's historical DST schedule before multi-year research.");
      ShowStartupError("SERVER_UTC_OFFSET_MISSING_OR_INVALID",
         "Configurar ServerUTCOffsetMinutes (minutos frente a UTC; 999 es marcador sin configurar) o ServerOffsetSchedule con los cambios historicos del broker. No se genero el estudio.");
      return;
     }
   if(!SymbolSelect(StudySymbol,true))
     {
      ShowStartupError("SYMBOL_UNAVAILABLE","El broker no ofrece el simbolo exacto configurado en StudySymbol.");
      return;
     }
   g_point=SymbolInfoDouble(StudySymbol,SYMBOL_POINT);
   g_digits=(int)SymbolInfoInteger(StudySymbol,SYMBOL_DIGITS);
   g_pip=(g_digits==3||g_digits==5)?10*g_point:g_point;
   if(g_point<=0) { ShowStartupError("INVALID_SYMBOL_POINT","El simbolo no tiene SYMBOL_POINT valido."); return; }
   g_now_utc=TimeGMT(); datetime begun=g_now_utc;
   long max_bars=TerminalInfoInteger(TERMINAL_MAXBARS);
   long required=RequiredM1Bars();
   if(max_bars<required)
     {
      ShowStartupError("MAX_BARS_TOO_LOW",
         "MT5 Max. barras en grafico="+IntegerToString(max_bars)+
         "; el periodo M1 solicitado requiere al menos "+IntegerToString(required)+
         ". Aumentar el limite, reiniciar MT5 y precargar M1. Se conservaron los CSV anteriores; no son resultados nuevos.");
      return;
     }
   datetime start=Midnight(StartDate),end=Midnight(EndDate);
   Print("Preflight M1: MaxBars=",max_bars," required>=",required,
         "; checking first and last requested weeks before creating CSVs.");
   if(!ProbeHistory(start,start+7*86400))
     {
      if(!IsStopped()) ShowStartupError("HISTORY_START_UNAVAILABLE",
         "No hay ninguna vela M1 de "+StudySymbol+" en la primera semana solicitada desde "+T(start)+
         ". Precargar el historico del broker o mover StartDate. Se conservaron los CSV anteriores.");
      return;
     }
   datetime last_probe=end;
   datetime current_study_date=Midnight(g_now_utc+UTCOffset*3600);
   if(last_probe>current_study_date) last_probe=current_study_date;
   if(!ProbeHistory(last_probe-7*86400,last_probe+86400))
     {
      if(!IsStopped()) ShowStartupError("HISTORY_END_UNAVAILABLE",
         "No hay velas M1 de "+StudySymbol+" cerca del final solicitado "+T(last_probe)+
         ". Precargar el historico del broker y revisar EndDate. Se conservaron los CSV anteriores.");
      return;
     }
   WriteMetadata("RUNNING",begun); if(!g_io_ok) return;
   int daily=OpenCSV("Daily"); if(daily==INVALID_HANDLE) return;
   DayResult empty; InitDay(empty,Midnight(StartDate)); string header; DailyRow(empty,header);
   WriteLine(daily,header); g_header=header;
   ArrayResize(g_days,0); ArrayResize(g_context,0);
   datetime warm=start-ContextWarmupCalendarDays*86400;
   MqlRates previous[],current[],next[];
   LoadLocal(warm-86400,warm,previous); LoadLocal(warm,warm+86400,current);
   int processed=0;
   Print("Starting M1 research: ",StudySymbol," UTC",UTCOffset,"; no orders. Warmup from ",T(warm));
   for(datetime date=warm;date<=end&&!IsStopped()&&g_io_ok;date+=86400)
     {
      // At most three local days held in memory, including configurable cross-midnight NY.
      LoadLocal(date+86400,date+172800,next);
      if(date>=start)
        {
         MqlRates combined[];
         int p=ArraySize(previous),c=ArraySize(current),n=ArraySize(next);
         ArrayResize(combined,p+c+n);
         if(p>0) ArrayCopy(combined,previous,0,0,p);
         if(c>0) ArrayCopy(combined,current,p,0,c);
         if(n>0) ArrayCopy(combined,next,p+c,0,n);
         DayResult day; Analyze(date,combined,day);
         string row=DailyRow(day,header);
         if(header!=g_header) { Print("Internal CSV schema mismatch."); g_io_ok=false; break; }
         if(!WriteLine(daily,row)) break;
         int size=ArraySize(g_days); ArrayResize(g_days,size+1,512); g_days[size]=day;
         processed++;
         if(processed%ProgressEveryDays==0)
           {
            long requested=(long)(end-start)/86400+1;
            Print("Progress ",T(date)," | days=",processed,"/",requested,
                  " (",DoubleToString(100.0*processed/requested,1),"%) | ",day.status);
            FileFlush(daily);
           }
        }
      else if((int)((date-warm)/86400)%ProgressEveryDays==0) Print("Context warmup: ",T(date));
      // Current day's OHLC is appended ONLY AFTER measuring today's setup/context.
      AppendContext(date,current);
      ArraySwap(previous,current); ArraySwap(current,next);
     }
   FileFlush(daily); FileClose(daily);
   if(g_io_ok)
     {
      WriteSummary(); WriteGroups("ByCompression",1); WriteGroups("ByLondonPosition",2);
      WriteGroups("ByPrice0800Position",3); WriteGroups("CompressionPriceCross",4);
      WriteGroups("ByWeekday",5); WriteGroups("ByVolatility",6);
     }
   string status=IsStopped()?"CANCELLED_PARTIAL":(g_io_ok?"COMPLETE":"IO_ERROR");
   if(g_io_ok) WriteMetadata(status,begun);
   string base=UseCommonFiles?TerminalInfoString(TERMINAL_COMMONDATA_PATH)+"\\Files\\":TerminalInfoString(TERMINAL_DATA_PATH)+"\\MQL5\\Files\\";
   Print("Research ",status,"; rows=",ArraySize(g_days),"; CSV folder: ",base,g_dir);
  }
