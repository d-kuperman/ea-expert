"""Read-only research audit. Never writes input CSVs. Python/pandas/numpy only."""
from pathlib import Path
import csv, hashlib, json, math, re
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'Estadísticas script Astra'
OUT = ROOT / 'analisis_compression'
OUT.mkdir(exist_ok=True)
PREFIX = 'EURUSD_AsiaLondonCompression_'
paths = sorted(SRC.glob(PREFIX+'*.csv'))
hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
raw = {p.stem.removeprefix(PREFIX): pd.read_csv(p, dtype=str, keep_default_na=False) for p in paths}
d = raw['Daily'].copy()
for c in d:
    nonempty = d[c].replace('',np.nan).dropna()
    if len(nonempty) and pd.to_numeric(nonempty,errors='coerce').notna().all():
        d[c] = pd.to_numeric(d[c].replace('',np.nan))
d = d.copy()
d['dt'] = pd.to_datetime(d.Date,format='%Y.%m.%d')
e = d[d.SetupStatus.isin(['VALID','INVALID'])].copy()
v = d[(d.SetupStatus=='VALID') & (d.OutcomeComplete=='true')].copy()
b = v[v.FirstBreakDirection.isin(['HIGH','LOW'])].copy()
iv = e[(e.SetupStatus=='INVALID') & (e.OutcomeComplete=='true')].copy()
issues=[]; checks={}
def check(name, passed):
    checks[name]=bool(passed)
    if not passed: issues.append(name)
for p in paths:
    rows=list(csv.reader(p.open(encoding='utf-8-sig',newline='')))
    check(p.name+': rectangular',all(len(r)==len(rows[0]) for r in rows))
    check(p.name+': unique headers',len(set(rows[0]))==len(rows[0]))
check('unique dates',not d.Date.duplicated().any())
check('no duplicate complete records',not raw['Daily'].duplicated().any())
check('continuous calendar',d.dt.tolist()==pd.date_range(d.dt.min(),d.dt.max()).tolist())
check('weekday labels',all(d.dt.dt.day_name()==d.DayOfWeek))
check('timezone -3',all(d.UTCOffset==-3))
check('symbol EURUSD',all(d.Symbol=='EURUSD'))
specials={name:int(t.apply(lambda col:col.str.fullmatch(r'(?i)(nan|[+-]?inf(inity)?|#DIV/0!|#NUM!|null|1\.#.*)',na=False)).sum().sum()) for name,t in raw.items()}
check('no literal error or nonfinite tokens',sum(specials.values())==0)
numeric=d.select_dtypes(include='number')
check('finite numeric values',np.isfinite(numeric.to_numpy()[numeric.notna().to_numpy()]).all())
def equalcol(name,x,y,tol=1e-7):
    mask=x.notna() & y.notna()
    check(name, np.allclose(x[mask],y[mask],atol=tol,rtol=0))
for s,expected in [('Asia',480),('London',240),('NY',360)]:
    sub=d[d.DataStatus!='WEEKEND']
    check(s+' expected bars',all(sub[s+'ExpectedBars']==expected))
    check(s+' missing arithmetic',all(sub[s+'Bars']+sub[s+'MissingBars']==expected))
    check(s+' no bad bars',all(sub[s+'BadBars']==0))
    check(s+' complete flag',all((sub[s+'Complete']=='true')==(sub[s+'MissingBars']==0)))
    equalcol(s+' range',d[s+'High']-d[s+'Low'],d[s+'Range'])
    equalcol(s+' pips',d[s+'Range']/0.0001,d[s+'RangePips'])
    equalcol(s+' points',d[s+'Range']/0.00001,d[s+'RangePoints'])
    check(s+' positive observed prices',all(d[s+'Low'].dropna()>0))
    check(s+' nonnegative range',all(d[s+'Range'].dropna()>=0))
check('no zero evaluable Asia range',all(e.AsiaRange>0))
check('strict setup containment',all((e.SetupStatus=='VALID')==((e.LondonHigh<e.AsiaHigh)&(e.LondonLow>e.AsiaLow))))
equalcol('compression formula',d.LondonRange/d.AsiaRange,d.CompressionRatio)
equalcol('London mid formula',(d.LondonHigh+d.LondonLow)/2,d.LondonMid)
equalcol('London position formula',(d.LondonMid-d.AsiaLow)/d.AsiaRange,d.LondonMidPosition)
equalcol('0800 position formula',(d.Price0800-d.AsiaLow)/d.AsiaRange,d.Price0800Position)
equalcol('NY normalized range',d.NYRange/d.AsiaRange,d.NYRangeToAsiaRange)
for side in ['High','Low']:
    for metric in ['MFE','MAE','MAELower']:
        p=side+'Break'+metric
        equalcol(p+' unit points',d[p+'_Points']/10,d[p+'_Pips'])
        equalcol(p+' percent Asia',100*d[p+'_Pips']/d.AsiaRangePips,d[p+'_PctAsia'])
        check(p+' nonnegative',all(d[p+'_Pips'].dropna()>=0))
    equalcol(side+' normalized',d[side+'BreakMFE_Pips']/d.AsiaRangePips,d[side+'NormalizedExpansion'])
    equalcol(side+' MAE ratio',d[side+'BreakMAE_Pips']/d.AsiaRangePips,d[side+'BreakMAERatio'])
    hit=d[d[side+'BreakOccurred']=='true']
    check(side+' MAE bounds',all(hit[side+'BreakMAELower_Pips']<=hit[side+'BreakMAE_Pips']))
    equalcol(side+' risk A',hit[side+'_A_SL_Pips'],hit.LondonRangePips)
    equalcol(side+' risk B',hit[side+'_B_SL_Pips'],hit.AsiaRangePips*.5)
    risk=(hit.AsiaHigh-hit.LondonLow)/.0001 if side=='High' else (hit.LondonHigh-hit.AsiaLow)/.0001
    equalcol(side+' risk C',hit[side+'_C_SL_Pips'],risk)
for side in ['HIGH','LOW']:
    rows=d[d.FirstBreakDirection==side]
    for met in ['MFE','MAE','MAELower']:
        equalcol('first '+side+' '+met,rows['FirstBreak'+met+'_Pips'],rows[side.title()+'Break'+met+'_Pips'])
for stem in ['FirstBreak','HighBreak','LowBreak']:
    rows=d[d[stem+'Time']!='']
    times=pd.to_datetime(rows[stem+'Time'])
    mins=(times-rows.dt).dt.total_seconds()/60
    check(stem+' in NY',all((mins>=480)&(mins<840)))
    if stem=='FirstBreak': equalcol('break minutes',(times-rows.dt).dt.total_seconds()/60-480,rows.FirstBreakMinutesFrom0800)
for stem,tc,mc in [('','MFETime','MinutesToMFE'),('HighBreak','HighBreakMFETime','HighBreakMinutesToMFE'),('LowBreak','LowBreakMFETime','LowBreakMinutesToMFE')]:
    start='FirstBreakTime' if not stem else stem+'Time'
    rows=d[(d[tc]!='') & (d[start]!='')]
    delta=(pd.to_datetime(rows[tc])-pd.to_datetime(rows[start])).dt.total_seconds()/60
    equalcol(mc+' arithmetic',delta,rows[mc])
    check(mc+' nonnegative',all(delta>=0))
states={'HIT_BEFORE_SL','SL_FIRST','NOT_REACHED','AMBIGUOUS','NO_BREAK','INVALID_RISK','NA_GAP','UNAVAILABLE'}
for col in [c for c in d if c.endswith('_Status')]:
    check(col+' legal state',set(d[col])<=states)
    expected=d[col].map(lambda s:'true' if s=='HIT_BEFORE_SL' else ('false' if s in ['SL_FIRST','NOT_REACHED'] else ''))
    check(col+' boolean',all(expected==d[col.replace('_Status','_HitBeforeSL')]))

CLASSES=['HIGH_ONLY','LOW_ONLY','HIGH_THEN_LOW','LOW_THEN_HIGH','NO_BREAK','BOTH_ORDER_AMBIGUOUS']
METRICS={'AsiaRangePips':'AsiaRangePips','LondonRangePips':'LondonRangePips','CompressionRatio':'CompressionRatio','MFE_Pips':'FirstBreakMFE_Pips','MAE_UpperPips':'FirstBreakMAE_Pips','FirstBreakMinutesFrom0800':'FirstBreakMinutesFrom0800','MinutesToMFE':'MinutesToMFE','NormalizedExpansion':'norm','HighBreakMFE_Pips':'HighBreakMFE_Pips','LowBreakMFE_Pips':'LowBreakMFE_Pips','MAE_LowerPips':'FirstBreakMAELower_Pips'}
d['norm']=d.FirstBreakMFE_Pips/d.AsiaRangePips
v['norm']=v.FirstBreakMFE_Pips/v.AsiaRangePips
def pct(k,n): return 100*k/n if n else np.nan
def agg(g):
    n=len(g); hi=sum(g.FirstBreakDirection=='HIGH'); lo=sum(g.FirstBreakDirection=='LOW')
    ret=sum(g.ReturnedInsideAsia=='true'); ambret=sum(g.ReturnedInsideAsia=='AMBIGUOUS')
    a={'Cases':n,'HighFirstCount':hi,'LowFirstCount':lo,'HighFirstPct':pct(hi,n),'LowFirstPct':pct(lo,n),'BothSidesPct':pct(sum(g.BreakBothSides=='true'),n),'NoBreakPct':pct(sum(g.BreakoutClass=='NO_BREAK'),n),'AmbiguousFirstPct':pct(sum(g.FirstBreakDirection=='AMBIGUOUS'),n),'KnownFirstBreakCases':hi+lo,'ReturnedInsideCount':ret,'ReturnAmbiguousCount':ambret,'FakeoutLowerPct':pct(ret,hi+lo),'FakeoutUpperPct':pct(ret+ambret,hi+lo)}
    for c in CLASSES: a[c+'_Count']=sum(g.BreakoutClass==c); a[c+'_Pct']=pct(a[c+'_Count'],n)
    for label,col in METRICS.items():
        x=g[col].dropna(); a[label+'_N']=len(x); a[label+'_Mean']=x.mean(); a[label+'_Median']=x.median() if len(x) else np.nan
        for q in [25,50,75,90,95]: a[label+'_P'+str(q)]=x.quantile(q/100) if len(x) else np.nan
    return a
def interval(s,label):
    if label=='BELOW_ASIA': return s<0
    if label=='ABOVE_ASIA': return s>1
    lo,hi=label[1:-1].split(','); lo=float(lo); hi=float(hi)
    return (s>=lo)&(s<=hi if label.endswith(']') else s<hi)
recon=[]; mismatches=[]
for name in ['Summary','ByCompression','ByLondonPosition','ByPrice0800Position','CompressionPriceCross','ByWeekday','ByVolatility']:
    compared=0; blankmatch=0
    for idx,r in raw[name].iterrows():
        group,sub=r.Group,r.Subgroup
        if name=='Summary': g=v
        elif name=='ByCompression': g=v[interval(v.CompressionRatio,group)]
        elif name=='ByLondonPosition': g=v[interval(v.LondonMidPosition,group)]
        elif name=='ByPrice0800Position': g=v[interval(v.Price0800Position,group)]
        elif name=='ByWeekday': g=v[v.DayOfWeek==group]
        elif name=='ByVolatility': g=v[interval(v[group],sub)]
        elif group=='Compression<0.30': g=v[(v.CompressionRatio<.3)&((v.Price0800Position>.8) if '>' in sub else (v.Price0800Position<.2))]
        else: g=v[interval(v.CompressionRatio,group)&interval(v.Price0800Position,sub)]
        a=agg(g)
        if name=='Summary':
            weekdays=d[d.DataStatus!='WEEKEND']
            a.update(CalendarRows=len(d),TotalDays=len(weekdays),WeekendDays=sum(d.DataStatus=='WEEKEND'),EvaluableSetupDays=len(e),UnknownSetupDays=sum(weekdays.SetupStatus=='UNKNOWN'),ValidSetups=sum(d.SetupStatus=='VALID'),InvalidSetups=sum(d.SetupStatus=='INVALID'),ValidSetupPercentage=pct(sum(d.SetupStatus=='VALID'),len(e)),ValidSetupsWithCompleteNY=len(v),ValidSetupsMissingNY=sum((d.SetupStatus=='VALID')&(d.OutcomeComplete!='true')))
        for c,expected in a.items():
            actual=r[c]
            if pd.isna(expected):
                blankmatch+=1
                if actual!='': mismatches.append([name,int(idx),c,actual,None])
            else:
                compared+=1
                if actual=='' or not math.isclose(float(actual),float(expected),abs_tol=2e-7,rel_tol=0): mismatches.append([name,int(idx),c,actual,float(expected)])
    recon.append([name,len(raw[name]),compared,blankmatch,sum(m[0]==name for m in mismatches)])
check('all secondary aggregates match Daily',len(mismatches)==0)
def wilson(k,n):
    if not n:return (np.nan,np.nan)
    z=1.959963984540054;p=k/n; den=1+z*z/n
    mid=(p+z*z/(2*n))/den; h=z*math.sqrt(p*(1-p)/n+z*z/(4*n*n))/den
    return 100*(mid-h),100*(mid+h)
def stats(x):
    x=x.dropna()
    return [len(x),x.mean(),x.median() if len(x) else np.nan,x.std(),*[x.quantile(q) if len(x) else np.nan for q in [.25,.5,.75,.9,.95]],x.max()]
def fisher(a,b,c,z):
    n=a+b+c+z; row=a+b; col=a+c
    def p(x):return math.comb(col,x)*math.comb(n-col,row-x)/math.comb(n,row)
    obs=p(a)
    return sum(p(x) for x in range(max(0,row-(n-col)),min(row,col)+1) if p(x)<=obs+1e-12)

audit={'files':{name:{'rows':len(t),'columns':len(t.columns),'empty_cells':int((t=='').sum().sum()),'literal_nonfinite':specials[name]} for name,t in raw.items()},'checks':checks,'issues':issues,'reconciliation':recon,'mismatches':mismatches,'hashes_before':hashes,'missing_per_daily_column':{c:int((raw['Daily'][c]=='').sum()) for c in raw['Daily']},'incomplete_dates':d[d.DataStatus=='INCOMPLETE_SETUP_M1'].Date.tolist()}
(OUT/'auditoria.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'checks':len(checks),'failures':issues,'reconciliation':recon,'invalid_comparison':{'n':len(iv),'NYmean':iv.NYRangePips.mean(),'NYmedian':iv.NYRangePips.median(),'NYnormmean':iv.NYRangeToAsiaRange.mean(),'NYnormmedian':iv.NYRangeToAsiaRange.median(),'breaks':int(sum(iv.BreakoutClass!='NO_BREAK'))},'valid_nyrange':stats(v.NYRangePips),'valid_norm':stats(v.NYRangeToAsiaRange),'fisher_break':fisher(2,2,int(sum(iv.BreakoutClass!='NO_BREAK')),int(sum(iv.BreakoutClass=='NO_BREAK')))},ensure_ascii=False,indent=2))

# Report is appended below; all source paths remain read-only.
