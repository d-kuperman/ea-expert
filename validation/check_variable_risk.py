"""Run the actual MQL decision functions in a C# MT5 simulator (no trading)."""
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'SETUP_B.mq5').read_text(encoding='utf-8-sig')

def function(name):
    match = re.search(r'^(?:bool|void|double|datetime) ' + name + r'\(', source, re.M)
    start = match.start()
    pos = source.index('{', start)
    depth = 1
    end = pos + 1
    while depth:
        depth += (source[end] == '{') - (source[end] == '}')
        end += 1
    result = source[start:end]
    result = re.sub(r'(int|double|datetime|ENUM_ORDER_TYPE) &(\w+)', r'ref \1 \2', result)
    result = result.replace('RiskPosition positions[];', 'RiskPosition[] positions = new RiskPosition[0];')
    result = result.replace('ArrayResize(positions,', 'ArrayResize(ref positions,')
    result = result.replace('ZeroMemory(positions[p]);', 'positions[p] = new RiskPosition();')
    result = result.replace('losing_stop, stops);', 'losing_stop, ref stops);')
    result = result.replace('price, sl, loss)', 'price, sl, ref loss)')
    result = result.replace('replacement.sl, replacement.volume)', 'replacement.sl, ref replacement.volume)')
    result = result.replace('GetSetupCancellation(HistoryDealGetTicket(i), setup_day, side)', 'GetSetupCancellation(HistoryDealGetTicket(i), ref setup_day, ref side)')
    result = result.replace('GetExecutedSetup(deal, setup_day, side)', 'GetExecutedSetup(deal, ref setup_day, ref side)')
    result = result.replace('GetExecutedSetup(opening_deal, setup_day, side)', 'GetExecutedSetup(opening_deal, ref setup_day, ref side)')
    result = result.replace('datetime setup_day;', 'datetime setup_day=0;').replace('ENUM_ORDER_TYPE side;', 'ENUM_ORDER_TYPE side=0;')
    result = re.sub(r'(Mql\w+) (\w+) = \{\};', r'\1 \2 = new \1();', result)
    return 'static ' + result

# Refresh the older cancellation suite from today's source rather than testing a stale copy.
old = (ROOT / 'validation/SETUP_B_cancellation_check.cs').read_text(encoding='utf-8-sig')
for name in ['SetupOrderAlreadyExists', 'GetExecutedSetup', 'CancelOppositeSetupOrder', 'GetSetupCancellation', 'SetupHasCancellation', 'PlaceSetupOrders']:
    start = old.index('static ', old.index('static ' + ('void' if name in ['CancelOppositeSetupOrder','PlaceSetupOrders'] else 'bool') + ' ' + name))
    pos = old.index('{', start)
    depth, end = 1, pos + 1
    while depth:
        depth += (old[end] == '{') - (old[end] == '}')
        end += 1
    old = old[:start] + function(name) + old[end:]
old = old.replace('const string _Symbol=', 'static bool g_risk_dirty; static bool RefreshRisk() { return g_risk_dirty; }\n const int ORDER_COMMENT=99;\n const string _Symbol=')
old = old.replace('class Order {', 'class Order { public string Comment="";')
old = old.replace('return selected.Symbol;', 'return p==ORDER_COMMENT ? selected.Comment : selected.Symbol;')
old = old.replace('return o==null ? "" : o.Symbol;', 'return o==null ? "" : p==ORDER_COMMENT ? o.Comment : o.Symbol;')
old = old.replace('  return passed;', '''
  Reset(false,ORDER_TYPE_BUY_STOP,DEAL_REASON_TP); active[0].Day+=86400; active[0].Comment="SETUP B 1970.01.11 SELL"; Apply(301); Assert(removals==1,"TP cancels replacement created on later day");
  Reset(false); history[0].Day+=86400; history[0].Comment="SETUP B 1970.01.11 BUY"; Assert(SetupOrderAlreadyExists(ORDER_TYPE_BUY_STOP,g_current_day),"replaced filled entry retains setup identity");
  return passed;''')
string_helpers = '''
 static int StringFind(string s,string x) { return s.IndexOf(x,StringComparison.Ordinal); } static int StringLen(string s) { return s.Length; } static string StringSubstr(string s,int a,int b) { return s.Substring(a,b); }
 static long StringToTime(string s) { DateTime d; return DateTime.TryParseExact(s,"yyyy.MM.dd",System.Globalization.CultureInfo.InvariantCulture,System.Globalization.DateTimeStyles.None,out d) ? (long)(d-new DateTime(1970,1,1)).TotalSeconds : 0; }
'''
old = old.replace(' public static int Run()', function('SetupOrderDay') + string_helpers + ' public static int Run()')

struct = re.search(r'struct RiskPosition\s*\{[^}]+\}', source).group(0)
struct = re.sub(r'^(\s+)(ulong|double|bool) ', r'\1public \2 ', struct, flags=re.M)
template = r'''
#pragma warning disable 0649, 0414
using System;
using System.Collections.Generic;
using datetime=System.Int64;
using ENUM_ORDER_TYPE=System.Int32;
using ENUM_DEAL_TYPE=System.Int32;
using ENUM_DEAL_ENTRY=System.Int32;
using ENUM_DEAL_REASON=System.Int32;
using ENUM_ORDER_STATE=System.Int32;
using ENUM_ORDER_TYPE_TIME=System.Int32;
public static class VariableRiskCheck {
 const string _Symbol="EURUSD"; const ulong InpMagicNumber=26100702; const double _Point=0.00001;
 const int DEAL_SYMBOL=1,DEAL_TYPE=2,DEAL_POSITION_ID=3,DEAL_ENTRY=4,DEAL_MAGIC=5,DEAL_VOLUME=6,DEAL_PRICE=7,DEAL_PROFIT=8,DEAL_COMMISSION=9,DEAL_SWAP=10,DEAL_FEE=11,DEAL_SL=12,DEAL_REASON=13;
 const int DEAL_TYPE_BUY=0,DEAL_TYPE_SELL=1,DEAL_ENTRY_IN=0,DEAL_ENTRY_OUT=1,DEAL_ENTRY_INOUT=2,DEAL_ENTRY_OUT_BY=3,DEAL_REASON_SL=4,DEAL_REASON_TP=5;
 const int SYMBOL_VOLUME_MIN=1,SYMBOL_VOLUME_MAX=2,SYMBOL_VOLUME_STEP=3,ORDER_TYPE_BUY=0,ORDER_TYPE_SELL=1,ORDER_TYPE_BUY_STOP=4,ORDER_TYPE_SELL_STOP=5,ACCOUNT_BALANCE=1;
 const int ORDER_SYMBOL=1,ORDER_MAGIC=2,ORDER_TYPE=3,ORDER_VOLUME_CURRENT=4,ORDER_VOLUME_INITIAL=5,ORDER_PRICE_OPEN=6,ORDER_SL=7,ORDER_TP=8,ORDER_TYPE_TIME=9,ORDER_TIME_EXPIRATION=10,ORDER_COMMENT=11,ORDER_TIME_SETUP=12,ORDER_STATE=13;
 const int TRADE_ACTION_PENDING=5,TRADE_ACTION_REMOVE=8,ORDER_FILLING_RETURN=2,TIME_DATE=1,TRADE_RETCODE_DONE=10009,TRADE_RETCODE_PLACED=10008,ORDER_STATE_CANCELED=2;
 const double BASE_RISK_PERCENT=1;
 static bool g_risk_dirty=true,historyOK=true,checkOK=true,removeOK=true,placeOK=true,cancelSetup=false,partialDuringCancel=false;
 static double InpRiskMultiplier=1.1,g_risk_percent=1,g_pending_risk_percent=-1,balance=10000;
 static long g_last_risk_check=0,now=1791331200;
 static int passed=0,removals=0,placements=0;
 class Deal { public ulong id,position,magic=InpMagicNumber; public string symbol=_Symbol; public int entry,type,reason; public double volume=1,price=1.1,profit,cost,sl; }
 class Order { public ulong id=100,magic=InpMagicNumber; public int type=ORDER_TYPE_SELL_STOP,state; public string symbol=_Symbol,comment="SETUP B 2026.10.05 SELL"; public long day=1791158400; public double volume=1,initial=1,price=1.09,sl=1.091,tp=1.088; }
 class MqlTradeRequest { public int action,type,type_time,type_filling; public ulong order,magic; public string symbol,comment; public double price,sl,tp,volume; public long expiration; }
 class MqlTradeResult { public int retcode; public ulong order; public string comment=""; }
 class MqlTradeCheckResult { public int retcode; public string comment=""; }
 static List<Deal> deals=new List<Deal>(); static List<Order> orders=new List<Order>(); static Order selected,removedOrder; static MqlTradeRequest lastPlaced;
 static int ArraySize<T>(T[] a) { return a.Length; }
 static int ArrayResize<T>(ref T[] a,int size) { Array.Resize(ref a,size); return size; }
 static bool MathIsValidNumber(double x) { return !double.IsNaN(x) && !double.IsInfinity(x); }
 static double MathPow(double a,double b) { return Math.Pow(a,b); } static double MathMax(double a,double b) { return Math.Max(a,b); }
 static double MathAbs(double a) { return Math.Abs(a); } static double MathFloor(double a) { return Math.Floor(a); }
 static double NormalizeDouble(double a,int n) { return Math.Round(a,n); }
 static void Print(string s) {} static void PrintFormat(string s,params object[] a) {}
 static long TimeCurrent() { return now; } static bool TradingAllowed() { return true; }
 static int StringFind(string s,string x) { return s.IndexOf(x,StringComparison.Ordinal); } static int StringLen(string s) { return s.Length; } static string StringSubstr(string s,int a,int b) { return s.Substring(a,b); }
 static long StringToTime(string s) { DateTime d; return DateTime.TryParseExact(s,"yyyy.MM.dd",System.Globalization.CultureInfo.InvariantCulture,System.Globalization.DateTimeStyles.None,out d) ? (long)(d-new DateTime(1970,1,1)).TotalSeconds : 0; }
 static long GetDayStart(long t) { return t-t%86400; } static string TimeToString(long t,int f) { return new DateTime(1970,1,1).AddSeconds(t).ToString("yyyy.MM.dd"); }
 static bool HistorySelect(long a,long b) { return historyOK; } static int HistoryDealsTotal() { return deals.Count; }
 static ulong HistoryDealGetTicket(int i) { return deals[i].id; }
 static string HistoryDealGetString(ulong t,int p) { return deals.Find(d=>d.id==t).symbol; }
 static long HistoryDealGetInteger(ulong t,int p) { var d=deals.Find(x=>x.id==t); if(p==DEAL_TYPE)return d.type; if(p==DEAL_POSITION_ID)return (long)d.position; if(p==DEAL_ENTRY)return d.entry; if(p==DEAL_MAGIC)return (long)d.magic; return d.reason; }
 static double HistoryDealGetDouble(ulong t,int p) { var d=deals.Find(x=>x.id==t); if(p==DEAL_VOLUME)return d.volume; if(p==DEAL_PRICE)return d.price; if(p==DEAL_PROFIT)return d.profit; if(p==DEAL_COMMISSION)return d.cost; if(p==DEAL_SL)return d.sl; return 0; }
 static double SymbolInfoDouble(string s,int p) { return p==SYMBOL_VOLUME_MAX ? 100 : 0.01; } static double AccountInfoDouble(int p) { return balance; }
 static bool OrderCalcProfit(int t,string s,double v,double p,double sl,ref double loss) { loss=(t==ORDER_TYPE_BUY ? sl-p : p-sl)*100000*v; return true; }
 static int OrdersTotal() { return orders.Count; } static ulong OrderGetTicket(int i) { selected=orders[i]; return selected.id; }
 static string OrderGetString(int p) { return p==ORDER_COMMENT ? selected.comment : selected.symbol; }
 static long OrderGetInteger(int p) { if(p==ORDER_MAGIC)return (long)selected.magic; if(p==ORDER_TYPE)return selected.type; if(p==ORDER_TIME_SETUP)return selected.day; return 0; }
 static double OrderGetDouble(int p) { if(p==ORDER_VOLUME_CURRENT)return selected.volume; if(p==ORDER_VOLUME_INITIAL)return selected.initial; if(p==ORDER_PRICE_OPEN)return selected.price; if(p==ORDER_SL)return selected.sl; return selected.tp; }
 static bool SetupHasCancellation(long d) { return cancelSetup; }
 static bool OrderCheck(MqlTradeRequest r,MqlTradeCheckResult c) { return checkOK; }
 static bool HistoryOrderSelect(ulong t) { return removedOrder!=null && removedOrder.id==t; }
 static long HistoryOrderGetInteger(ulong t,int p) { return removedOrder.state; }
 static double HistoryOrderGetDouble(ulong t,int p) { return removedOrder.volume; }
 static bool OrderSend(MqlTradeRequest r,MqlTradeResult result) {
  if(r.action==TRADE_ACTION_REMOVE) { if(!removeOK)return false; removedOrder=orders.Find(o=>o.id==r.order); orders.Remove(removedOrder); removedOrder.state=ORDER_STATE_CANCELED; if(partialDuringCancel) removedOrder.volume/=2; removals++; result.retcode=TRADE_RETCODE_DONE; return true; }
  placements++; lastPlaced=r; if(!placeOK)return false; result.retcode=TRADE_RETCODE_PLACED; result.order=999; orders.Add(new Order {id=999,volume=r.volume,initial=r.volume,comment=r.comment}); return true;
 }
 static void Reset() { deals.Clear(); orders.Clear(); InpRiskMultiplier=1.1; g_risk_percent=1; g_risk_dirty=true; g_pending_risk_percent=-1; g_last_risk_check=0; historyOK=checkOK=removeOK=placeOK=true; cancelSetup=partialDuringCancel=false; removals=placements=0; balance=10000; removedOrder=null; lastPlaced=null; }
 static void Open(ulong id,bool buy=true,double volume=1) { deals.Add(new Deal {id=(ulong)deals.Count+1,position=id,type=buy?0:1,entry=0,volume=volume}); }
 static void Close(ulong id,double profit=-100,int reason=DEAL_REASON_SL,double volume=1,double sl=1.099,bool buy=true,double cost=0) { deals.Add(new Deal {id=(ulong)deals.Count+1,position=id,type=buy?1:0,entry=1,profit=profit,reason=reason,volume=volume,sl=sl,cost=cost}); }
 static void Assert(bool ok,string name) { if(!ok)throw new Exception("FAIL "+name); passed++; Console.WriteLine("PASS "+name); }
 static bool Near(double a,double b) { return Math.Abs(a-b)<1e-8; }
 static double Risk() { g_risk_dirty=true; if(!RefreshRisk())throw new Exception("refresh failed"); return g_risk_percent; }
 public static int Run() {
  Reset(); Assert(Near(Risk(),1),"base 1 percent");
  for(ulong i=1;i<=19;i++) { Open(i); Close(i); Assert(Near(Risk(),Math.Pow(1.1,i)),"stop progression "+i); }
  Assert(Near(Math.Round(Risk(),2),6.12),"twentieth trade 6.12 percent");
  Assert(Near(Risk(),Risk()),"restart and repeated events do not double count");
  InpRiskMultiplier=0; Assert(Near(Risk(),1),"zero multiplier keeps fixed 1 percent despite stop history");
  InpRiskMultiplier=1.1; Open(30); Close(30,200,DEAL_REASON_TP); Assert(Near(Risk(),1),"net winner resets");
  Open(31); Close(31); Assert(Near(Risk(),1.1),"new cycle after winner");
  Open(32); Close(32,0,DEAL_REASON_SL,1,1.1,true,-5); Assert(Near(Risk(),1.1),"BE with fees does not multiply");
  Open(33); Close(33,-2,DEAL_REASON_SL,1,1.1); Assert(Near(Risk(),1.1),"BE with adverse slippage does not multiply");
  Open(34); Close(34,-100,0); Assert(Near(Risk(),1.1),"manual loss does not multiply");
  Open(35); Close(35,100,0); Assert(Near(Risk(),1),"manual winner resets own position");
  Reset(); Open(1); Close(1,-50,DEAL_REASON_SL,0.5); Assert(Near(Risk(),1),"partial close waits");
  Close(1,-50,DEAL_REASON_SL,0.5); Assert(Near(Risk(),1.1),"partial SL counted once");
  Reset(); Open(1,false); Close(1,-100,DEAL_REASON_SL,1,1.101,false); Assert(Near(Risk(),1.1),"sell stop increases risk");
  Reset(); Open(1); deals[0].magic=7; Close(1); Assert(Near(Risk(),1),"other magic ignored");
  Reset(); Open(1); Close(1); foreach(var d in deals)d.symbol="GBPUSD"; Assert(Near(Risk(),1),"other symbol ignored");
  Reset(); Open(1); Close(1); InpRiskMultiplier=2; Assert(Near(Risk(),2),"integer multiplier");
  InpRiskMultiplier=1; Assert(Near(Risk(),1),"unit multiplier");
  InpRiskMultiplier=0.5; Assert(Near(Risk(),0.5),"fractional multiplier");
  historyOK=false; g_risk_dirty=true; Assert(!RefreshRisk(),"unavailable history blocks new risk");
  Assert(Near(RiskVolume(121,100,0.01,100,0.01),1.21),"volume precision");
  Assert(Near(RiskVolume(133.1,100,0.01,100,0.01),1.33),"volume rounds down");
  Assert(RiskVolume(0.1,100,0.01,100,0.01)==0,"below minimum blocked");
  Assert(RiskVolume(10001,100,0.01,100,0.01)==0,"above maximum blocked");
  Assert(RiskVolume(double.PositiveInfinity,100,0.01,100,0.01)==0,"overflow blocked");
  Reset(); double lots=0; Assert(CalculateRiskVolume(ORDER_TYPE_BUY_STOP,1.1,1.099,ref lots)&&Near(lots,1),"balance based buy sizing");
  balance=9900; g_risk_percent=1.1; Assert(CalculateRiskVolume(ORDER_TYPE_SELL_STOP,1.09,1.091,ref lots)&&Near(lots,1.08),"new balance and increased percentage");
  Reset(); Open(1); Close(1); orders.Add(new Order()); ReconcilePendingRisk(); Assert(removals==1&&placements==1&&Near(lastPlaced.volume,1.1),"remaining pending resized after SL");
  Assert(lastPlaced.comment=="SETUP B 2026.10.05 SELL","replacement retains original setup day");
  now++; ReconcilePendingRisk(); Assert(removals==1&&placements==1,"repeated tick does not replace again");
  Reset(); Open(1); Close(1); orders.Add(new Order()); checkOK=false; ReconcilePendingRisk(); Assert(removals==0&&orders.Count==1,"preflight failure preserves original");
  Reset(); Open(1); Close(1); orders.Add(new Order()); removeOK=false; ReconcilePendingRisk(); Assert(placements==0&&orders.Count==1,"failed cancellation never duplicates");
  Reset(); Open(1); Close(1); orders.Add(new Order()); partialDuringCancel=true; ReconcilePendingRisk(); Assert(placements==0,"execution during cancellation never reopens full order");
  Reset(); Open(1); Close(1); orders.Add(new Order()); cancelSetup=true; ReconcilePendingRisk(); Assert(removals==0&&placements==0,"OCO prevents replacement");
  Reset(); Open(1); Close(1); orders.Add(new Order {volume=0.5}); ReconcilePendingRisk(); Assert(removals==0,"partially filled pending is not increased");
  Reset(); Open(1); Close(1); orders.Add(new Order()); placeOK=false; ReconcilePendingRisk(); now++; ReconcilePendingRisk(); Assert(placements==1&&orders.Count==0,"rejected replacement is not blindly duplicated");
  Assert(SetupOrderDay("SETUP B 2026.10.05 SELL",now)==StringToTime("2026.10.05"),"setup identity survives next day");
  return passed;
 }
'''
functions = '\n'.join(function(n) for n in ['SetupOrderDay','ApplyRiskClose','RefreshRisk','RiskVolume','CalculateRiskVolume','ReconcilePendingRisk'])
with tempfile.TemporaryDirectory(prefix='setup_b_risk_') as tmp:
    risk_path = Path(tmp) / 'risk.cs'
    cancel_path = Path(tmp) / 'cancellation.cs'
    risk_path.write_text(template + struct + '\n' + functions + '\n}', encoding='utf-8')
    cancel_path.write_text(old, encoding='utf-8')
    quote = lambda path: "'" + str(path).replace("'", "''") + "'"
    command = ("$ErrorActionPreference='Stop'; Add-Type -Path " + quote(risk_path) +
               "; [VariableRiskCheck]::Run(); Add-Type -Path " + quote(cancel_path) +
               "; [SetupCancellationCheck]::Run()")
    subprocess.run(['powershell', '-NoProfile', '-Command', command], cwd=ROOT, check=True)
