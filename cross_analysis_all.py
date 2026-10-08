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

param_keys = ['InpUseRangeA', 'InpCancelSecondEntry', 'InpStopLossPips', 'InpRiskReward', 'InpAutoBreakeven', 'InpBreakevenPips']

# Separate df_var into false and true
df_var_false = df_var[df_var['InpVariableRisk'] == 'false'].copy()
df_var_true = df_var[df_var['InpVariableRisk'] == 'true'].copy()

# Merge all datasets
m_all = pd.merge(df_2025, df_2026, on=param_keys, suffixes=('_25_fix', '_26_fix'))
m_all = pd.merge(m_all, df_var_false, on=param_keys, how='left')
m_all = pd.merge(m_all, df_var_true, on=param_keys, how='left', suffixes=('_26_dyn_false', '_26_dyn_true'))

# Let's inspect the merged columns
cols_clean = {
    'Profit_25_fix': 'P_25_fix',
    'Equity DD %_25_fix': 'DD_25_fix',
    'Sharpe Ratio_25_fix': 'SR_25_fix',
    'Profit Factor_25_fix': 'PF_25_fix',
    
    'Profit_26_fix': 'P_26_fix',
    'Equity DD %_26_fix': 'DD_26_fix',
    'Sharpe Ratio_26_fix': 'SR_26_fix',
    'Profit Factor_26_fix': 'PF_26_fix',
    
    'Profit_26_dyn_false': 'P_26_dyn_fix',
    'Equity DD %_26_dyn_false': 'DD_26_dyn_fix',
    'Sharpe Ratio_26_dyn_false': 'SR_26_dyn_fix',
    
    'Profit_26_dyn_true': 'P_26_dyn_var',
    'Equity DD %_26_dyn_true': 'DD_26_dyn_var',
    'Sharpe Ratio_26_dyn_true': 'SR_26_dyn_var'
}
m_all.rename(columns=cols_clean, inplace=True)

# Filter for setups profitable in 2025
m_robust = m_all[m_all['P_25_fix'] > 0].copy()
m_robust['Combined_Fix'] = m_robust['P_25_fix'] + m_robust['P_26_fix']

print(f"Total setups con Profit > 0 en 2025: {len(m_robust)}")
print("\n--- TOP SETUPS CON MAYOR PROFIT EN 2025 Y SU COMPORTAMIENTO EN 2026 ---")
print(m_robust.sort_values(by='P_25_fix', ascending=False)[param_keys + ['P_25_fix', 'DD_25_fix', 'P_26_fix', 'DD_26_fix', 'P_26_dyn_fix', 'P_26_dyn_var', 'DD_26_dyn_var']].head(15).to_string(index=False))

print("\n--- TOP SETUPS CON MAYOR COMBINED PROFIT FIJO (2025 + 2026) ---")
print(m_robust.sort_values(by='Combined_Fix', ascending=False)[param_keys + ['Combined_Fix', 'P_25_fix', 'DD_25_fix', 'P_26_fix', 'DD_26_fix', 'P_26_dyn_fix', 'P_26_dyn_var', 'DD_26_dyn_var']].head(15).to_string(index=False))

