
using System;
using System.Collections.Generic;
using datetime=System.Int64;
using ENUM_ORDER_TYPE=System.Int32;
using ENUM_ORDER_STATE=System.Int32;
using ENUM_DEAL_TYPE=System.Int32;
using ENUM_DEAL_ENTRY=System.Int32;
using ENUM_DEAL_REASON=System.Int32;
public static class SetupCancellationCheck {
 const string _Symbol="EURUSD";
 const ulong InpMagicNumber=26100702;
 const int ORDER_SYMBOL=1,ORDER_MAGIC=2,ORDER_TYPE=3,ORDER_TIME_SETUP=4,ORDER_STATE=5;
 const int DEAL_SYMBOL=6,DEAL_MAGIC=7,DEAL_TYPE=8,DEAL_ORDER=9,DEAL_REASON=10,DEAL_ENTRY=11,DEAL_POSITION_ID=12,DEAL_TIME_MSC=13;
 const int ORDER_TYPE_BUY_STOP=4,ORDER_TYPE_SELL_STOP=5,ORDER_STATE_REJECTED=6,ORDER_STATE_FILLED=4,ORDER_STATE_CANCELED=2;
 const int DEAL_TYPE_BUY=0,DEAL_TYPE_SELL=1,DEAL_ENTRY_IN=0,DEAL_ENTRY_OUT=1,DEAL_ENTRY_INOUT=2,DEAL_ENTRY_OUT_BY=3;
 const int DEAL_REASON_EXPERT=3,DEAL_REASON_SL=4,DEAL_REASON_TP=5;
 const int TRADE_ACTION_REMOVE=8,TRADE_RETCODE_DONE=10009,TIME_DATE=1;
 static bool InpCancelSecondEntry=true,InpUseRangeA=true,g_setup_evaluated_today=true,g_setup_b_today=true,g_setup_orders_processed=false;
 static datetime g_current_day=864000,g_last_oco_error=0;
 static double MAX_A=1.10,MIN_A=1.09,MAX_B=1.098,MIN_B=1.092;
 class Order { public ulong Ticket; public int Type,State; public long Day; public ulong Magic=InpMagicNumber; public string Symbol=_Symbol; }
 class Deal { public ulong Ticket,Order,Position,Magic=InpMagicNumber; public int Type,Entry,Reason; public long Time; public string Symbol=_Symbol; }
 class MqlTradeRequest { public int action; public ulong order,magic; public string symbol; }
 class MqlTradeResult { public int retcode; public string comment=""; }
 static List<Order> active=new List<Order>(),history=new List<Order>();
 static List<Deal> deals=new List<Deal>();
 static Order selected;
 static int removals=0,placements=0,passed=0;
 static bool reject=false;
 static long GetDayStart(long t) { return t-t%86400; }
 static long TimeCurrent() { return g_current_day+14*3600; }
 static bool TradingAllowed() { return true; }
 static bool HistorySelect(long a,long b) { return true; }
 static int OrdersTotal() { return active.Count; }
 static int HistoryOrdersTotal() { return history.Count; }
 static int HistoryDealsTotal() { return deals.Count; }
 static ulong OrderGetTicket(int i) { selected=active[i]; return selected.Ticket; }
 static bool OrderSelect(ulong t) { selected=active.Find(o=>o.Ticket==t); return selected!=null; }
 static ulong HistoryOrderGetTicket(int i) { return history[i].Ticket; }
 static ulong HistoryDealGetTicket(int i) { return deals[i].Ticket; }
 static bool HistoryOrderSelect(ulong t) { return history.Exists(o=>o.Ticket==t); }
 static long OrderInt(Order o,int p) {
  if(o==null) return 0;
  if(p==ORDER_MAGIC) return (long)o.Magic;
  if(p==ORDER_TYPE) return o.Type;
  if(p==ORDER_STATE) return o.State;
  return o.Day;
 }
 static long OrderGetInteger(int p) { return OrderInt(selected,p); }
 static string OrderGetString(int p) { return selected.Symbol; }
 static long HistoryOrderGetInteger(ulong t,int p) { return OrderInt(history.Find(o=>o.Ticket==t),p); }
 static string HistoryOrderGetString(ulong t,int p) { var o=history.Find(x=>x.Ticket==t); return o==null ? "" : o.Symbol; }
 static string HistoryDealGetString(ulong t,int p) { var d=deals.Find(x=>x.Ticket==t); return d==null ? "" : d.Symbol; }
 static long HistoryDealGetInteger(ulong t,int p) {
  var d=deals.Find(x=>x.Ticket==t); if(d==null) return 0;
  if(p==DEAL_MAGIC) return (long)d.Magic;
  if(p==DEAL_TYPE) return d.Type;
  if(p==DEAL_ORDER) return (long)d.Order;
  if(p==DEAL_REASON) return d.Reason;
  if(p==DEAL_ENTRY) return d.Entry;
  if(p==DEAL_POSITION_ID) return (long)d.Position;
  return d.Time;
 }
 static bool OrderSend(MqlTradeRequest request,MqlTradeResult result) {
  if(reject) { result.retcode=10006; return false; }
  var o=active.Find(x=>x.Ticket==request.order);
  if(o==null || request.action!=TRADE_ACTION_REMOVE) throw new Exception("Unexpected removal");
  active.Remove(o); o.State=ORDER_STATE_CANCELED; history.Add(o); removals++; result.retcode=TRADE_RETCODE_DONE; return true;
 }
 static void PrintFormat(string fmt,params object[] values) {}
 static string TimeToString(long t,int p) { return t.ToString(); }
 static bool PlaceSetupStop(int side,double price) { placements++; return true; }
 static void Reset(bool cancel,int side=ORDER_TYPE_BUY_STOP,int reason=-1) {
  InpCancelSecondEntry=cancel; g_setup_orders_processed=false; g_last_oco_error=0; reject=false;
  removals=0; placements=0; active.Clear(); history.Clear(); deals.Clear();
  ulong ticket=side==ORDER_TYPE_BUY_STOP ? 101UL : 102UL;
  var opening=new Order {Ticket=ticket,Type=side,State=ORDER_STATE_FILLED,Day=g_current_day+36000}; history.Add(opening);
  active.Add(new Order {Ticket=side==ORDER_TYPE_BUY_STOP ? 102UL : 101UL,Type=side==ORDER_TYPE_BUY_STOP ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_BUY_STOP,Day=g_current_day+36000});
  deals.Add(new Deal {Ticket=201,Order=ticket,Position=501,Type=side==ORDER_TYPE_BUY_STOP ? DEAL_TYPE_BUY : DEAL_TYPE_SELL,Entry=DEAL_ENTRY_IN,Reason=DEAL_REASON_EXPERT,Time=1000});
  if(reason>=0) deals.Add(new Deal {Ticket=301,Order=999,Position=501,Type=side==ORDER_TYPE_BUY_STOP ? DEAL_TYPE_SELL : DEAL_TYPE_BUY,Entry=DEAL_ENTRY_OUT,Reason=reason,Time=2000});
 }
 static void Assert(bool ok,string label) { if(!ok) throw new Exception("FAIL "+label); passed++; System.Console.WriteLine("PASS "+label); }
 static void Apply(ulong deal) { long day=0; int side=0; if(GetSetupCancellation(deal,ref day,ref side)) CancelOppositeSetupOrder(day,side); }
static bool SetupOrderAlreadyExists(ENUM_ORDER_TYPE type, datetime day_start)
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
static bool GetExecutedSetup(ulong deal, ref datetime setup_day, ref ENUM_ORDER_TYPE side)
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
static void CancelOppositeSetupOrder(datetime setup_day, ENUM_ORDER_TYPE executed_side)
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
      MqlTradeRequest request = new MqlTradeRequest();
      MqlTradeResult result = new MqlTradeResult();
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
static bool GetSetupCancellation(ulong deal, ref datetime setup_day, ref ENUM_ORDER_TYPE side)
{
   if(InpCancelSecondEntry) return GetExecutedSetup(deal, ref setup_day, ref side);
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
   return GetExecutedSetup(opening_deal, ref setup_day, ref side);
}
static bool SetupHasCancellation(datetime day_start)
{
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      datetime setup_day=0;
      ENUM_ORDER_TYPE side=0;
      if(GetSetupCancellation(HistoryDealGetTicket(i), ref setup_day, ref side) && setup_day == day_start)
         return true;
   }
   return false;
}
static void PlaceSetupOrders()
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
 public static int Run() {
  Reset(true); Apply(201); Assert(removals==1 && active.Count==0,"true buy execution cancels sell");
  Reset(true,ORDER_TYPE_SELL_STOP); Apply(201); Assert(removals==1,"true sell execution cancels buy");
  Reset(false); Apply(201); Assert(removals==0 && active.Count==1,"false keeps pending after entry");
  Reset(false,ORDER_TYPE_BUY_STOP,DEAL_REASON_SL); Apply(301); Assert(removals==0 && active.Count==1,"false keeps pending after buy SL or BE");
  Reset(false,ORDER_TYPE_SELL_STOP,DEAL_REASON_SL); Apply(301); Assert(removals==0,"false keeps pending after sell SL");
  Reset(false,ORDER_TYPE_BUY_STOP,DEAL_REASON_TP); Apply(301); Assert(removals==1,"false buy TP cancels sell");
  Reset(false,ORDER_TYPE_SELL_STOP,DEAL_REASON_TP); Apply(301); Assert(removals==1,"false sell TP cancels buy");
  Reset(false,ORDER_TYPE_BUY_STOP,DEAL_REASON_EXPERT); Apply(301); Assert(removals==0,"manual close does not cancel");
  Reset(false,ORDER_TYPE_BUY_STOP,DEAL_REASON_TP); deals[1].Magic=7; Apply(301); Assert(removals==0,"ignores other EA TP");
  Reset(false,ORDER_TYPE_BUY_STOP,DEAL_REASON_TP); active[0].Day-=86400; Apply(301); Assert(removals==0,"ignores pending from other setup day");
  Reset(false,ORDER_TYPE_BUY_STOP,DEAL_REASON_TP); deals[1].Position=888; Apply(301); Assert(removals==0,"TP requires linked opening position");
  Reset(false,ORDER_TYPE_BUY_STOP,DEAL_REASON_SL); PlaceSetupOrders(); Assert(placements==0 && active.Count==1,"restart after SL preserves pending and never rearms filled side");
  Reset(false,ORDER_TYPE_BUY_STOP,DEAL_REASON_SL); var other=active[0]; active.Clear(); other.State=ORDER_STATE_FILLED; history.Add(other);
  deals.Add(new Deal {Ticket=202,Order=other.Ticket,Position=502,Type=DEAL_TYPE_SELL,Entry=DEAL_ENTRY_IN,Reason=DEAL_REASON_EXPERT,Time=3000});
  deals.Add(new Deal {Ticket=302,Order=998,Position=502,Type=DEAL_TYPE_BUY,Entry=DEAL_ENTRY_OUT,Reason=DEAL_REASON_SL,Time=4000});
  PlaceSetupOrders(); Assert(placements==0 && !SetupHasCancellation(g_current_day),"both SL never rearms either entry");
  Reset(false,ORDER_TYPE_BUY_STOP,DEAL_REASON_TP); Assert(SetupHasCancellation(g_current_day),"restart detects TP in history");
  Reset(true); Assert(SetupHasCancellation(g_current_day),"restart true detects execution");
  Reset(false,ORDER_TYPE_BUY_STOP,DEAL_REASON_TP); reject=true; Apply(301); Assert(removals==0 && active.Count==1,"rejected cancellation retains pending");
  reject=false; Apply(301); Assert(removals==1,"cancellation retries successfully");
  return passed;
 }
}
