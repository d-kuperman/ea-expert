// Pruebas de la funcion real extraida del EA, sin dependencias.
// Uso: node FVG_Opuestos_5Velas.test.cjs
// No ejecuta MetaTrader ni comprueba el render grafico.
const fs=require("node:fs");
const path=require("node:path");
const source=fs.readFileSync(path.join(__dirname,"FVG_Opuestos_5Velas.mq5"),"utf8");
const result=(function(source) {

const detectorSource=source.match(/bool DetectPattern\([^]*?\n}\n/)[0];
const translated=detectorSource
 .replace(/bool DetectPattern\(const MqlRates &v\[\],PatternInfo &p\)/,"function detect(v,p,params)")
 .replace(/\b(?:int|bool|double)\s+(\w+)/g,"let $1")
 .replace(/ArraySize\(v\)/g,"v.length")
 .replace(/MathMax/g,"Math.max").replace(/MathMin/g,"Math.min").replace(/MathAbs/g,"Math.abs")
 .replace(/\b(Inp\w+)\b/g,"params.$1");
const detect=new Function(translated+"; return detect;")();
const defaults={InpMaxBodyPct:20,InpMinDominantWickPct:60,InpMaxOppositeWickPct:10,InpMinWickBodyRatio:3};
const candle=(open,high,low,close)=>({open,high,low,close});
const base=[candle(80,95,75,90),candle(90,130,85,120),candle(115,200,100,105),candle(106,110,88,90),candle(92,98,80,85)];
const mirror=v=>v.map(c=>candle(300-c.open,300-c.low,300-c.high,300-c.close));
const clone=v=>JSON.parse(JSON.stringify(v));
const rows=[];
function check(name,fn) { fn(); rows.push(name); }
function assert(ok,msg) { if(!ok) throw new Error(msg); }
for(const inverse of [false,true]) {
 const tag=inverse?"alcista":"bajista";
 const run=(name,modify,expected,overrides={})=>check(tag+": "+name,()=>{
   let v=clone(base); if(modify) modify(v);
   if(inverse) v=mirror(v);
   const p={};
   const found=detect(v,p,{...defaults,...overrides});
   assert(found===expected,name+" -> "+found);
   if(found) assert(p.bullish===inverse,"direccion");
 });
 run("patron valido",null,true);
 check(tag+": extremos y metricas exactas",()=>{
   const p={}; assert(detect(inverse?mirror(base):base,p,defaults),"detect");
   assert(p.body===10 && p.total_range===100 && p.body_pct===10,"cuerpo");
   assert((inverse?p.lower_wick:p.upper_wick)===85,"mecha dominante");
   assert((inverse?p.upper_wick:p.lower_wick)===5,"mecha opuesta");
   assert(p.bull_high-p.bull_low===(inverse?2:5),"FVG alcista");
   assert(p.bear_high-p.bear_low===(inverse?5:2),"FVG bajista");
 });
 run("FVG1 contacto exacto",v=>v[0].high=100,false);
 run("FVG2 contacto exacto",v=>v[4].high=100,false);
 run("FVG1 ausente",v=>v[0].high=101,false);
 run("FVG2 ausente",v=>v[4].high=101,false);
 run("mechas invalidan gap aunque cuerpos no se toquen",v=>v[0].high=105,false);
 run("cuerpo exactamente 20 por ciento",v=>v[2].open=125,true);
 run("cuerpo supera 20 por ciento",v=>v[2].open=126,false);
 run("mecha corta exactamente 10 por ciento",v=>{v[2].close=110;v[2].open=120;},true);
 run("mecha corta supera 10 por ciento",v=>{v[2].close=111;v[2].open=121;},false);
 run("mecha dominante exactamente limite configurable",null,true,{InpMinDominantWickPct:85});
 run("mecha dominante debajo de limite configurable",null,false,{InpMinDominantWickPct:86});
 run("ratio exactamente limite configurable",null,true,{InpMinWickBodyRatio:8.5});
 run("ratio debajo de limite configurable",null,false,{InpMinWickBodyRatio:8.6});
 run("ratio desactivado",null,true,{InpMinWickBodyRatio:0});
 for(let i=0;i<5;i++) {
   run("direccion equivocada V"+(i+1),v=>{[v[i].open,v[i].close]=[v[i].close,v[i].open];},false);
   run("doji V"+(i+1),v=>v[i].close=v[i].open,false);
   run("rango cero V"+(i+1),v=>v[i]=candle(100,100,100,100),false);
 }
 run("OHLC corrupto",v=>v[2].high=110,false);
}
check("ventana incompleta rechazada",()=>assert(!detect(base.slice(1),{},defaults),"4 velas"));
check("simetria de 1000 geometrías y extremos",()=>{
 let seed=197;
 const random=()=>{ seed=(seed*1664525+1013904223)>>>0; return seed/4294967296; };
 for(let n=0;n<1000;n++) {
   const v=clone(base);
   v[2]=candle(100+random()*50,200,100,100+random()*20);
   v[0].high=90+random()*20; v[4].high=92+random()*20;
   const p={},q={};
   assert(detect(v,p,defaults)===detect(mirror(v),q,defaults),"simetria "+n);
 }
});
return {passed:rows.length,checks:rows,scope:"Funcion DetectPattern extraida del mq5 y traducida mecanicamente a JavaScript; no sustituye backtest MT5."};

})(source);
console.log(JSON.stringify(result,null,2));
