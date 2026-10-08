from analizar import *
pd.set_option('display.width',300)
pd.set_option('display.max_columns',30)
COLS=PARAMS+['Pass_25','Profit_25','Profit_26','Equity DD %_25','Equity DD %_26','Profit Factor_25','Profit Factor_26','Recovery Factor_25','Recovery Factor_26','Sharpe Ratio_25','Sharpe Ratio_26','Trades_25','Trades_26']
PASSES=[125,137,141,445,457,461,473,296,285]
print('CANDIDATES')
print(M[M.Pass_25.isin(PASSES)][COLS].to_string(index=False))
print('\nCANDIDATES ALL VERSIONS')
C=M.merge(PAIR,on=PARAMS)
print(C[C.Pass_25.isin(PASSES)][['Pass_25']+PARAMS+['Pass_F','Pass_V','Profit_25','Profit_26','Profit_F','Profit_V','Equity DD %_F','Equity DD %_V','Profit Factor_F','Profit Factor_V','Recovery Factor_F','Recovery Factor_V','Trades_F','Trades_V']].to_string(index=False))
print('\nANNUAL WINNERS')
for k,d in [('F25',DATA['F25']),('F26',DATA['F26']),('new_fixed',VF),('variable',VT)]:
    print(k, d.sort_values('Profit',ascending=False).head(1)[PARAMS+METRICS+['Pass']].to_dict('records'))
    best=d.sort_values('Profit',ascending=False).head(1)
    print('old years:',M.merge(best[PARAMS],on=PARAMS)[COLS].to_string(index=False))
print('\nMARGINAL ON ORIGINAL FULL FACTORIAL RAW ROWS (BE duplicated equally)')
for p in PARAMS:
    print(p)
    a=RAW['F25'].groupby(p).agg(n=('Profit','size'),positive=('Profit',lambda s:(s>0).mean()*100),profit=('Profit','mean'),dd=('Equity DD %','mean'))
    b=RAW['F26'].groupby(p).agg(positive=('Profit',lambda s:(s>0).mean()*100),profit=('Profit','mean'),dd=('Equity DD %','mean'))
    print(a.join(b,rsuffix='_26').round(3).to_string())
print('\nBE ACTIVE THRESHOLD')
for k in ['F25','F26']:
    print(k,DATA[k].query("InpAutoBreakeven=='true'").groupby('InpBreakevenPips').agg(n=('Profit','size'),profit=('Profit','mean'),positive=('Profit',lambda s:(s>0).mean()*100)).round(3).to_string())
print('\nBINARY MATCHED EFFECTS')
for p in ['InpUseRangeA','InpCancelSecondEntry','InpAutoBreakeven']:
    for k in ['F25','F26']:
        d=RAW[k]; keys=[c for c in PARAMS if c!=p]
        pair=d[d[p]=='false'].merge(d[d[p]=='true'],on=keys,suffixes=('_off','_on'),validate='one_to_one')
        print(p,k,'n',len(pair),'true improves',int((pair.Profit_on>pair.Profit_off).sum()),'mean delta',round((pair.Profit_on-pair.Profit_off).mean(),2))
print('\nFAMILY A NO EARLY CANCEL BE ON')
fam=M.query("InpUseRangeA=='true' & InpCancelSecondEntry=='false' & InpAutoBreakeven=='true'")
print('family n/both',len(fam),int(fam.both_positive.sum()))
print(fam[['InpStopLossPips','InpRiskReward','InpBreakevenPips','Profit_25','Profit_26','max_period_DD']].to_string(index=False))
print('\nNEIGHBORS, ONE GRID STEP NUMERIC (no Boolean flips)')
for p in PASSES:
    r=M[M.Pass_25==p].iloc[0]
    same=M[(M.InpUseRangeA==r.InpUseRangeA)&(M.InpCancelSecondEntry==r.InpCancelSecondEntry)&(M.InpAutoBreakeven==r.InpAutoBreakeven)]
    near=same[((same.InpStopLossPips-r.InpStopLossPips).abs()/5+(same.InpRiskReward-r.InpRiskReward).abs()+(same.InpBreakevenPips-r.InpBreakevenPips).abs()/5)==1]
    print(p,'n',len(near),'both positive',int(near.both_positive.sum()),'worst25',near.Profit_25.min(),'median25',near.Profit_25.median(),'mean25',near.Profit_25.mean(),'worst26',near.Profit_26.min(),'neighbors',near.Pass_25.tolist())
print('\nVARIABLE DIAGNOSTICS')
print(PAIR[[c+'_delta' for c in ['Profit','Equity DD %','Profit Factor','Recovery Factor','Sharpe Ratio','Trades','Return_DD']]].describe().to_string())
print('dominate',int(((PAIR.Profit_delta>=0)&(PAIR['Equity DD %_delta']<=0)&((PAIR.Profit_delta>0)|(PAIR['Equity DD %_delta']<0))).sum()))
print('old-control same trade count',int((CONTROL.Trades_original==CONTROL.Trades_control).sum()))
for t in [5,10,15,20,30,40,50]:
    print('DD threshold',t,'fixed',int((VF['Equity DD %']>t).sum()),'variable',int((VT['Equity DD %']>t).sum()))
print('worst variable',VT.nsmallest(3,'Profit')[PARAMS+METRICS].to_dict('records'))
print('\nPARETO WORST PROFIT MAX DD')
valid=M[M.both_positive].copy()
valid['pareto']=[not (((valid.worst_period_profit>=r.worst_period_profit)&(valid.max_period_DD<=r.max_period_DD))&((valid.worst_period_profit>r.worst_period_profit)|(valid.max_period_DD<r.max_period_DD))).any() for _,r in valid.iterrows()]
print(valid[valid.pareto].sort_values('max_period_DD')[COLS].to_string(index=False))
print('\nGRID CORE SL 15-20 RR 3-4, BE all')
core=fam.query('InpStopLossPips>=15 & InpRiskReward>=3 & InpRiskReward<=4')
print(core[COLS].to_string(index=False))
print('\nRANK CHANGES & SELECTION')
for n in [10,20,32]:
    top25=M.nlargest(n,'Profit_25');top26=M.nlargest(n,'Profit_26')
    print(n,'overlap',len(set(top25.Pass_25)&set(top26.Pass_25)),'top26 losses25',int((top26.Profit_25<0).sum()),'top25 losses26',int((top25.Profit_26<0).sum()))
print('\nLOW DD RETURNS')
for cap in [5,8,10,15,20,100]:
    eligible=M[M.both_positive&(M.max_period_DD<=cap)]
    print(cap,'n',len(eligible),'best total',eligible.nlargest(1,'sum_independent_profit')[COLS].to_dict('records'))

# Save detailed machine-readable evidence without editing the source reports.
C.to_csv(OUT/'comparacion_todos_los_casos.csv',index=False,encoding='utf-8-sig')
valid.to_csv(OUT/'candidatos_dos_periodos.csv',index=False,encoding='utf-8-sig')
print('\nEXTRA AUDIT')
print('distinct metric vectors', {k:len(v.drop_duplicates(METRICS)) for k,v in DATA.items()})
print('sums',M[M.Pass_25.isin(PASSES)][['Pass_25','sum_independent_profit','illustrative_compound_pct']].to_string(index=False))
print('worst pair',PAIR.nsmallest(1,'Profit_V')[['Profit_F','Profit_V','Equity DD %_F','Equity DD %_V','Trades_F','Trades_V']].to_dict('records'))
print('same trade counts', len(PAIR[PAIR.Trades_delta==0]), int((PAIR[PAIR.Trades_delta==0].Profit_delta>0).sum()))
print('cancel flip',M.query("InpUseRangeA=='true' & InpStopLossPips==15 & InpRiskReward==4 & InpBreakevenPips==15 & InpAutoBreakeven=='true'")[['InpCancelSecondEntry','Profit_25','Profit_26','Equity DD %_25','Equity DD %_26']].to_string(index=False))
print('range flip',M.query("InpCancelSecondEntry=='false' & InpStopLossPips==15 & InpRiskReward==4 & InpBreakevenPips==15 & InpAutoBreakeven=='true'")[['InpUseRangeA','Profit_25','Profit_26']].to_string(index=False))
print('BE flip',M.query("InpUseRangeA=='true' & InpCancelSecondEntry=='false' & InpStopLossPips==15 & InpRiskReward==4 & (InpBreakevenPips==15 | InpBreakevenPips==0)")[['InpAutoBreakeven','Profit_25','Profit_26']].to_string(index=False))
for k in ['F25','F26']:
    print('marginal unique',k)
    for p in PARAMS[:5]:
        print(p,DATA[k].groupby(p).agg(n=('Profit','size'),positive=('Profit',lambda s:int((s>0).sum())),profit_mean=('Profit','mean')).to_dict('index'))
print('stress')
for n in [5,10,15,20,25,30]:
    fixed=1-(1-.01)**n
    variable=1-np.prod([1-.01*1.1**i for i in range(n)])
    print(n,'next risk',1.1**n,'loss fixed',fixed*100,'loss variable',variable*100)
