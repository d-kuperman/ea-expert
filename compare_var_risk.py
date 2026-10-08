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

df_var = parse_xml('Optimizacion/ReportOptimizer-2026 Riesgo variable.xml')
param_keys = ['InpUseRangeA', 'InpCancelSecondEntry', 'InpStopLossPips', 'InpRiskReward', 'InpAutoBreakeven', 'InpBreakevenPips']

df_false = df_var[df_var['InpVariableRisk'] == 'false'].copy()
df_true = df_var[df_var['InpVariableRisk'] == 'true'].copy()

comp = pd.merge(df_false, df_true, on=param_keys, suffixes=('_FixedRisk', '_VarRisk'))
print(f"Total matching setups: {len(comp)}")

comp['Profit_Diff'] = comp['Profit_VarRisk'] - comp['Profit_FixedRisk']
comp['DD_Diff'] = comp['Equity DD %_VarRisk'] - comp['Equity DD %_FixedRisk']
comp['Sharpe_Diff'] = comp['Sharpe Ratio_VarRisk'] - comp['Sharpe Ratio_FixedRisk']
comp['PF_Diff'] = comp['Profit Factor_VarRisk'] - comp['Profit Factor_FixedRisk']

print("\n=== COMPARATIVA DIRECTA: RIESGO FIJO VS RIESGO VARIABLE (2026) ===")
print(f"Setups donde Riesgo Variable obtuvo MAYOR Profit: {(comp['Profit_Diff'] > 0).sum()} / {len(comp)} ({(comp['Profit_Diff'] > 0).mean()*100:.1f}%)")
print(f"Setups donde Riesgo Variable tuvo MAYOR Drawdown: {(comp['DD_Diff'] > 0).sum()} / {len(comp)} ({(comp['DD_Diff'] > 0).mean()*100:.1f}%)")
print(f"Setups donde Riesgo Variable mejoró el Sharpe: {(comp['Sharpe_Diff'] > 0).sum()} / {len(comp)} ({(comp['Sharpe_Diff'] > 0).mean()*100:.1f}%)")
print(f"Setups donde Riesgo Variable mejoró el Profit Factor: {(comp['PF_Diff'] > 0).sum()} / {len(comp)} ({(comp['PF_Diff'] > 0).mean()*100:.1f}%)")

print("\n--- Promedios Generales ---")
print(f"Profit Promedio: Fijo = ${comp['Profit_FixedRisk'].mean():,.1f} vs Variable = ${comp['Profit_VarRisk'].mean():,.1f} (Dif: ${comp['Profit_Diff'].mean():+,.1f})")
print(f"Drawdown Promedio: Fijo = {comp['Equity DD %_FixedRisk'].mean():.2f}% vs Variable = {comp['Equity DD %_VarRisk'].mean():.2f}% (Dif: {comp['DD_Diff'].mean():+.2f}%)")
print(f"Sharpe Promedio: Fijo = {comp['Sharpe Ratio_FixedRisk'].mean():.2f} vs Variable = {comp['Sharpe Ratio_VarRisk'].mean():.2f} (Dif: {comp['Sharpe_Diff'].mean():+.2f})")
print(f"Worst-Case DD: Fijo = {comp['Equity DD %_FixedRisk'].max():.2f}% vs Variable = {comp['Equity DD %_VarRisk'].max():.2f}%")
print(f"Worst-Case Profit: Fijo = ${comp['Profit_FixedRisk'].min():,.1f} vs Variable = ${comp['Profit_VarRisk'].min():,.1f}")

# Distribución de la diferencia de DD
print("\n--- Distribución del Aumento de Drawdown en Riesgo Variable ---")
print(comp['DD_Diff'].describe())

# Ratios de Eficiencia (Profit / DD)
comp['Eff_Fixed'] = comp['Profit_FixedRisk'] / comp['Equity DD %_FixedRisk']
comp['Eff_Var'] = comp['Profit_VarRisk'] / comp['Equity DD %_VarRisk']
print("\n--- Ratio Profit / DD (Calmar / Eficiencia de Capital) ---")
print(f"Media Ratio Fijo: {comp['Eff_Fixed'].mean():.1f} vs Media Ratio Variable: {comp['Eff_Var'].mean():.1f}")
print(f"Setups donde Fijo tuvo MEJOR Ratio Profit/DD: {(comp['Eff_Fixed'] > comp['Eff_Var']).sum()} / {len(comp)} ({(comp['Eff_Fixed'] > comp['Eff_Var']).mean()*100:.1f}%)")

# Top 10 con mayor ganancia en variable y cuánto arriesgó de DD
print("\n--- TOP 10 SETUPS CON MAYOR GANANCIA EN RIESGO VARIABLE ---")
top_var = comp.sort_values(by='Profit_VarRisk', ascending=False).head(10)
cols_show = param_keys + ['Profit_FixedRisk', 'Profit_VarRisk', 'Equity DD %_FixedRisk', 'Equity DD %_VarRisk', 'Sharpe Ratio_FixedRisk', 'Sharpe Ratio_VarRisk']
print(top_var[cols_show].to_string(index=False))

# Peores 5 caídas en Riesgo Variable
print("\n--- PEORES 5 CAÍDAS / CASOS DE RUINA EN RIESGO VARIABLE ---")
worst_var = comp.sort_values(by='DD_Diff', ascending=False).head(5)
print(worst_var[cols_show].to_string(index=False))

