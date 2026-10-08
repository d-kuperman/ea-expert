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
df_var_false = df_var[df_var['InpVariableRisk'] == 'false'].copy()
df_var_true = df_var[df_var['InpVariableRisk'] == 'true'].copy()

m = pd.merge(df_2025, df_2026, on=param_keys, suffixes=('_25', '_26'))
m = pd.merge(m, df_var_false, on=param_keys, how='left')
m = pd.merge(m, df_var_true, on=param_keys, how='left', suffixes=('_var_f', '_var_t'))

print("=== ANALISIS DE LA 'ZONA O MESETA DE ROBUSTEZ' ===")
print("Filtro: InpUseRangeA = true, InpCancelSecondEntry = false, InpAutoBreakeven = true")

plateau = m[(m['InpUseRangeA'] == 'true') & 
            (m['InpCancelSecondEntry'] == 'false') & 
            (m['InpAutoBreakeven'] == 'true')].copy()

print(f"Total combinaciones en esta meseta: {len(plateau)}")
print(f"Combinaciones con Profit 2025 > 0: {(plateau['Profit_25'] > 0).sum()} / {len(plateau)} ({(plateau['Profit_25'] > 0).mean()*100:.1f}%)")
print(f"Combinaciones con Profit 2026 > 0: {(plateau['Profit_26'] > 0).sum()} / {len(plateau)} ({(plateau['Profit_26'] > 0).mean()*100:.1f}%)")
print(f"Combinaciones con AMBOS años positivos: {((plateau['Profit_25'] > 0) & (plateau['Profit_26'] > 0)).sum()} / {len(plateau)} ({((plateau['Profit_25'] > 0) & (plateau['Profit_26'] > 0)).mean()*100:.1f}%)")

print("\n--- MATRIZ DE PROFIT 2025 EN LA MESETA (SL vs RR, promedio sobre BE Pips) ---")
p25_matrix = plateau.pivot_table(index='InpStopLossPips', columns='InpRiskReward', values='Profit_25', aggfunc='mean')
print(p25_matrix.round(0))

print("\n--- MATRIZ DE PROFIT 2026 FIJO EN LA MESETA (SL vs RR, promedio sobre BE Pips) ---")
p26_matrix = plateau.pivot_table(index='InpStopLossPips', columns='InpRiskReward', values='Profit_26', aggfunc='mean')
print(p26_matrix.round(0))

print("\n--- MATRIZ DE PROFIT COMBINADO (2025 + 2026) EN LA MESETA ---")
plateau['Combined'] = plateau['Profit_25'] + plateau['Profit_26']
p_comb_matrix = plateau.pivot_table(index='InpStopLossPips', columns='InpRiskReward', values='Combined', aggfunc='mean')
print(p_comb_matrix.round(0))

print("\n--- MATRIZ DE DRAWDOWN MAXIMO EN LA MESETA (SL vs RR) ---")
plateau['Max_DD'] = np.maximum(plateau['Equity DD %_25'], plateau['Equity DD %_26'])
dd_matrix = plateau.pivot_table(index='InpStopLossPips', columns='InpRiskReward', values='Max_DD', aggfunc='mean')
print(dd_matrix.round(2))

# Ahora detalle de las 24 combinaciones de esta meseta
print("\n--- DETALLE COMPLETO DE TODAS LAS COMBINACIONES EN LA MESETA ---")
show_cols = ['InpStopLossPips', 'InpRiskReward', 'InpBreakevenPips', 
             'Profit_25', 'Equity DD %_25', 'Profit Factor_25',
             'Profit_26', 'Equity DD %_26', 'Profit Factor_26',
             'Profit_var_f', 'Profit_var_t', 'Equity DD %_var_t']

plateau_sorted = plateau.sort_values(by='Combined', ascending=False)
print(plateau_sorted[show_cols].to_string(index=False))

