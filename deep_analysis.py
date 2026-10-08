import xml.etree.ElementTree as ET
import pandas as pd
import numpy as np

ns = {'ss': 'urn:schemas-microsoft-com:office:spreadsheet'}

def parse_xml(filepath):
    tree = ET.parse(filepath)
    root = tree.getroot()
    table = root.find('.//ss:Table', ns)
    rows = table.findall('ss:Row', ns)
    headers = [c.find('ss:Data', ns).text if c.find('ss:Data', ns) is not None else '' for c in rows[0].findall('ss:Cell', ns)]
    records = []
    for row in rows[1:]:
        cells = row.findall('ss:Cell', ns)
        records.append([c.find('ss:Data', ns).text if c.find('ss:Data', ns) is not None else None for c in cells])
    df = pd.DataFrame(records, columns=headers)
    for col in df.columns:
        try:
            df[col] = pd.to_numeric(df[col])
        except (ValueError, TypeError):
            pass
    return df

df_2025 = parse_xml('Optimizacion/ReportOptimizer-2025.xml')
df_2026 = parse_xml('Optimizacion/ReportOptimizer-2026.xml')
df_var = parse_xml('Optimizacion/ReportOptimizer-2026 Riesgo variable.xml')

param_cols = ['InpUseRangeA', 'InpCancelSecondEntry', 'InpStopLossPips', 'InpRiskReward', 'InpAutoBreakeven', 'InpBreakevenPips']

print("="*80)
print("TABLA DETALLADA DE IMPACTO MARGINAL (2025 vs 2026 FIJO)")
print("="*80)
pd.set_option('display.max_columns', 15)
pd.set_option('display.width', 1000)

for p in param_cols:
    g25 = df_2025.groupby(p).agg(
        WinRate=('Profit', lambda x: round((x > 0).mean() * 100, 1)),
        Profit_25=('Profit', lambda x: round(x.mean(), 1)),
        DD_25=('Equity DD %', lambda x: round(x.mean(), 2)),
        Sharpe_25=('Sharpe Ratio', lambda x: round(x.mean(), 2)),
        PF_25=('Profit Factor', lambda x: round(x.mean(), 2))
    )
    g26 = df_2026.groupby(p).agg(
        WinRate_26=('Profit', lambda x: round((x > 0).mean() * 100, 1)),
        Profit_26=('Profit', lambda x: round(x.mean(), 1)),
        DD_26=('Equity DD %', lambda x: round(x.mean(), 2)),
        Sharpe_26=('Sharpe Ratio', lambda x: round(x.mean(), 2)),
        PF_26=('Profit Factor', lambda x: round(x.mean(), 2))
    )
    combined = pd.concat([g25, g26], axis=1)
    print(f"\n--- PARAMETRO: {p} ---")
    print(combined)

# Merge 2025 and 2026
m = pd.merge(df_2025, df_2026, on=param_cols, suffixes=('_2025', '_2026'))
m['Combined_Profit'] = m['Profit_2025'] + m['Profit_2026']
m['Both_Profitable'] = (m['Profit_2025'] > 0) & (m['Profit_2026'] > 0)
m['Max_DD'] = np.maximum(m['Equity DD %_2025'], m['Equity DD %_2026'])
m['Avg_Sharpe'] = (m['Sharpe Ratio_2025'] + m['Sharpe Ratio_2026']) / 2.0
m['Total_Trades'] = m['Trades_2025'] + m['Trades_2026']

print("\n" + "="*80)
print(f"ANÁLISIS CRUZADO (2025 + 2026): {len(m)} COMBINACIONES TOTALES")
print("="*80)
both_pos = m[m['Both_Profitable']]
print(f"Combinaciones rentables en AMBOS años (2025 Y 2026): {len(both_pos)} de {len(m)} ({len(both_pos)/len(m)*100:.1f}%)")
print(f"Combinaciones rentables en 2025: {(m['Profit_2025'] > 0).sum()} ({ (m['Profit_2025'] > 0).mean()*100:.1f}%)")
print(f"Combinaciones rentables en 2026: {(m['Profit_2026'] > 0).sum()} ({ (m['Profit_2026'] > 0).mean()*100:.1f}%)")
print(f"Combinaciones con Profit Combinado > 0: {(m['Combined_Profit'] > 0).sum()} ({ (m['Combined_Profit'] > 0).mean()*100:.1f}%)")

print("\n--- TOP 15 MEJORES COMBINACIONES POR COMBINED PROFIT (con ambos años positivos) ---")
top_profit = both_pos.sort_values(by='Combined_Profit', ascending=False).head(15)
display_cols = param_cols + ['Profit_2025', 'Profit_2026', 'Combined_Profit', 'Equity DD %_2025', 'Equity DD %_2026', 'Sharpe Ratio_2025', 'Sharpe Ratio_2026']
print(top_profit[display_cols].to_string(index=False))

print("\n--- TOP 15 MEJORES COMBINACIONES POR RATIO PROFIT / MAX DD (con ambos años positivos) ---")
both_pos['Profit_to_MaxDD'] = both_pos['Combined_Profit'] / both_pos['Max_DD']
top_ratio = both_pos.sort_values(by='Profit_to_MaxDD', ascending=False).head(15)
display_cols_ratio = param_cols + ['Combined_Profit', 'Max_DD', 'Profit_to_MaxDD', 'Sharpe Ratio_2025', 'Sharpe Ratio_2026', 'Total_Trades']
print(top_ratio[display_cols_ratio].to_string(index=False))

