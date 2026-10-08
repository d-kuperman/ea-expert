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

print("="*70)
print("1. RESUMEN GLOBAL DE CADA ARCHIVO")
print("="*70)
for name, df in [('2025 Fijo', df_2025), ('2026 Fijo', df_2026), 
                 ('2026 Var (Total)', df_var),
                 ('2026 Var (InpVariableRisk=false)', df_var[df_var['InpVariableRisk'] == 'false']),
                 ('2026 Var (InpVariableRisk=true)', df_var[df_var['InpVariableRisk'] == 'true'])]:
    prof = df[df['Profit'] > 0]
    print(f"-- {name} --")
    print(f"Total pases: {len(df)}")
    print(f"Pases rentables: {len(prof)} ({len(prof)/len(df)*100:.1f}%)")
    print(f"Profit: Media = ${df['Profit'].mean():,.1f}, Mediana = ${df['Profit'].median():,.1f}, Min = ${df['Profit'].min():,.1f}, Max = ${df['Profit'].max():,.1f}")
    print(f"Equity DD %: Media = {df['Equity DD %'].mean():.2f}%, Mediana = {df['Equity DD %'].median():.2f}%, Min = {df['Equity DD %'].min():.2f}%, Max = {df['Equity DD %'].max():.2f}%")
    print(f"Sharpe: Media = {df['Sharpe Ratio'].mean():.2f}, Mediana = {df['Sharpe Ratio'].median():.2f}, Max = {df['Sharpe Ratio'].max():.2f}")
    print(f"Profit Factor: Media = {df['Profit Factor'].mean():.2f}, Mediana = {df['Profit Factor'].median():.2f}, Max = {df['Profit Factor'].max():.2f}")
    print(f"Trades: Media = {df['Trades'].mean():.1f}, Min = {df['Trades'].min()}, Max = {df['Trades'].max()}")
    print()
