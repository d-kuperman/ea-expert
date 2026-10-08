from pathlib import Path
import xml.etree.ElementTree as ET
import json, hashlib
import pandas as pd
import numpy as np

OUT = Path(__file__).resolve().parent
ROOT = OUT.parent
NS = {'s':'urn:schemas-microsoft-com:office:spreadsheet','o':'urn:schemas-microsoft-com:office:office'}
PARAMS=['InpUseRangeA','InpCancelSecondEntry','InpStopLossPips','InpRiskReward','InpAutoBreakeven','InpBreakevenPips']
METRICS=['Result','Profit','Expected Payoff','Profit Factor','Recovery Factor','Sharpe Ratio','Custom','Equity DD %','Trades']
FILES={'F25':'ReportOptimizer-2025.xml','F26':'ReportOptimizer-2026.xml','V26':'ReportOptimizer-2026 Riesgo variable.xml'}

def parse(name):
    path=ROOT/name
    root=ET.parse(path).getroot()
    props={e.tag.split('}')[-1]:e.text for e in root.find('o:DocumentProperties',NS)}
    rows=[]
    for row in root.findall('.//s:Table/s:Row',NS):
        values=[]
        for cell in row.findall('s:Cell',NS):
            idx=int(cell.get('{'+NS['s']+'}Index',len(values)+1))-1
            values.extend([None]*(idx-len(values)))
            data=cell.find('s:Data',NS)
            val=None if data is None else data.text
            if data is not None and data.get('{'+NS['s']+'}Type')=='Number': val=float(val)
            values.append(val)
        rows.append(values)
    assert all(len(r)==len(rows[0]) for r in rows)
    df=pd.DataFrame(rows[1:],columns=rows[0])
    df['XML_row']=np.arange(2,len(df)+2)
    assert df.isna().sum().sum()==0
    assert not df['Pass'].duplicated().any()
    for col in METRICS: assert np.isfinite(df[col]).all()
    assert np.allclose(df['Profit']/df['Trades'],df['Expected Payoff'],atol=1e-6)
    props['sha256']=hashlib.sha256(path.read_bytes()).hexdigest()
    return df,props

RAW={}; META={}; DATA={}; AUDIT={}
for label,file in FILES.items():
    raw,meta=parse(file); RAW[label]=raw; META[label]=meta
    keys=PARAMS+(['InpVariableRisk'] if label=='V26' else [])
    assert not raw.duplicated(keys).any()
    df=raw.copy()
    # BE threshold does not change the strategy when automatic BE is disabled.
    df.loc[df.InpAutoBreakeven=='false','InpBreakevenPips']=0.
    variation=df.groupby(keys,dropna=False)[METRICS].nunique()
    assert (variation<=1).all().all(), 'inactive-BE duplicates disagree'
    df=df.sort_values('Pass').drop_duplicates(keys).reset_index(drop=True)
    df['Return_pct']=df.Profit/float(meta['Deposit'].split()[0])*100
    df['Return_DD']=df.Return_pct/df['Equity DD %']
    DATA[label]=df
    AUDIT[label]={'rows':len(raw),'unique_active':len(df),'parameters':{c:raw[c].unique().tolist() for c in keys},'meta':meta}
    raw.to_csv(OUT/(label+'_original.csv'),index=False,encoding='utf-8-sig')

M=DATA['F25'].merge(DATA['F26'],on=PARAMS,suffixes=('_25','_26'),validate='one_to_one')
M['both_positive']=(M.Profit_25>0)&(M.Profit_26>0)
M['sum_independent_profit']=M.Profit_25+M.Profit_26
M['worst_period_profit']=M[['Profit_25','Profit_26']].min(axis=1)
M['max_period_DD']=M[['Equity DD %_25','Equity DD %_26']].max(axis=1)
M['min_period_PF']=M[['Profit Factor_25','Profit Factor_26']].min(axis=1)
M['min_period_recovery']=M[['Recovery Factor_25','Recovery Factor_26']].min(axis=1)
M['min_period_return_DD']=M[['Return_DD_25','Return_DD_26']].min(axis=1)
M['total_trades']=M.Trades_25+M.Trades_26
M['illustrative_compound_pct']=((1+M.Return_pct_25/100)*(1+M.Return_pct_26/100)-1)*100

VF=DATA['V26'].query("InpVariableRisk=='false'")
VT=DATA['V26'].query("InpVariableRisk=='true'")
CONTROL=DATA['F26'].merge(VF,on=PARAMS,suffixes=('_original','_control'),validate='one_to_one')
PAIR=VF.merge(VT,on=PARAMS,suffixes=('_F','_V'),validate='one_to_one')
for c in METRICS+['Return_DD']:
    PAIR[c+'_delta']=PAIR[c+'_V']-PAIR[c+'_F']

def summary(df):
    return {'n':len(df),'positive':int((df.Profit>0).sum()),'profit_mean':df.Profit.mean(),'profit_median':df.Profit.median(),'profit_min':df.Profit.min(),'profit_max':df.Profit.max(),'dd_median':df['Equity DD %'].median(),'dd_max':df['Equity DD %'].max(),'PF_median':df['Profit Factor'].median(),'trades_min':df.Trades.min(),'trades_max':df.Trades.max()}

SUMMARY={k:summary(v) for k,v in {'F25':DATA['F25'],'F26':DATA['F26'],'V26_control':VF,'V26_variable':VT}.items()}
M.to_csv(OUT/'comparacion_2025_2026.csv',index=False,encoding='utf-8-sig')
PAIR.to_csv(OUT/'comparacion_fijo_variable.csv',index=False,encoding='utf-8-sig')
CONTROL.to_csv(OUT/'control_comparabilidad_2026.csv',index=False,encoding='utf-8-sig')
out={'audit':AUDIT,'summary':SUMMARY,'cross':{'n':len(M),'both_positive':int(M.both_positive.sum()),'rank_correlation':M.Profit_25.rank().corr(M.Profit_26.rank())},'control':{'n':len(CONTROL),'equal_rows':int((CONTROL[[c+'_original' for c in METRICS]].to_numpy()==CONTROL[[c+'_control' for c in METRICS]].to_numpy()).all(axis=1).sum()),'max_abs_delta':{c:float((CONTROL[c+'_control']-CONTROL[c+'_original']).abs().max()) for c in METRICS}},'variable_pair':{'n':len(PAIR),'higher_profit':int((PAIR.Profit_delta>0).sum()),'higher_dd':int((PAIR['Equity DD %_delta']>0).sum()),'higher_PF':int((PAIR['Profit Factor_delta']>0).sum()),'higher_Sharpe':int((PAIR['Sharpe Ratio_delta']>0).sum()),'higher_recovery':int((PAIR['Recovery Factor_delta']>0).sum()),'higher_return_DD':int((PAIR.Return_DD_delta>0).sum()),'different_trades':int((PAIR.Trades_delta!=0).sum())}}
(OUT/'resumen.json').write_text(json.dumps(out,indent=2,ensure_ascii=False),encoding='utf-8')

if __name__=='__main__':
    pd.set_option('display.width',240)
    pd.set_option('display.max_columns',30)
    print(json.dumps(out,indent=2,ensure_ascii=False))
    columns=PARAMS+['Pass_25','Pass_26','Profit_25','Profit_26','Equity DD %_25','Equity DD %_26','Profit Factor_25','Profit Factor_26','total_trades','min_period_return_DD']
    for criterion in ['sum_independent_profit','worst_period_profit','min_period_return_DD','min_period_recovery']:
        print('\nTOP',criterion)
        print(M[M.both_positive].sort_values(criterion,ascending=False)[columns].head(10).to_string(index=False))
    print('\nVARIABLE TOP')
    print(VT.sort_values('Profit',ascending=False)[PARAMS+METRICS].head(6).to_string(index=False))

