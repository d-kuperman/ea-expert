"""Verify actual CSVs emitted by the MQL5 synthetic self-tests; no market claims."""
from pathlib import Path
import csv
import math
import shutil

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "validation_mt5/MQL5/Files/AsiaLondonCompression_SelfTests"
DEST = ROOT / "validation"
PREFIX = "EURUSD_AsiaLondonCompression_"


def main():
    source = SOURCE if SOURCE.is_dir() else DEST / "synthetic_csv"
    expected = {
        "Daily": 11, "Summary": 1, "ByCompression": 8,
        "ByLondonPosition": 5, "ByPrice0800Position": 7,
        "CompressionPriceCross": 58, "ByWeekday": 5, "ByVolatility": 18,
    }
    tables = {}
    headers = {}
    assertions = 0

    def check(ok, message):
        nonlocal assertions
        assert ok, message
        assertions += 1

    for path in sorted(source.glob("*.csv")):
        name = path.stem.removeprefix(PREFIX)
        with path.open(encoding="utf-8-sig", newline="") as stream:
            rows = list(csv.reader(stream))
        check(bool(rows), f"empty file {name}")
        head, data = rows[0], rows[1:]
        check(len(head) == len(set(head)), f"duplicate columns: {name}")
        check(all(len(r) == len(head) for r in data), f"ragged rows: {name}")
        if name in expected:
            check(len(data) == expected[name], f"wrong row count: {name}")
        headers[name] = head
        tables[name] = [dict(zip(head, r)) for r in data]
    check(set(tables) == set(expected) | {"RunMetadata"}, "expected nine CSVs")
    summary = tables["Summary"][0]
    for field, value in {
        "TotalDays": 10, "CalendarRows": 11, "WeekendDays": 1,
        "ValidSetups": 7, "InvalidSetups": 2, "UnknownSetupDays": 1,
        "EvaluableSetupDays": 9, "ValidSetupsWithCompleteNY": 6,
        "ValidSetupsMissingNY": 1, "Cases": 6, "HighFirstCount": 2,
        "LowFirstCount": 2, "MFE_Pips_N": 4,
        "FirstBreakMinutesFrom0800_N": 5, "MFE_Pips_Mean": 20,
        "MAE_UpperPips_Mean": 42.5,
    }.items():
        check(math.isclose(float(summary[field]), value, abs_tol=1e-7), field)
    check(math.isclose(float(summary["ValidSetupPercentage"]), 700/9, abs_tol=1e-7), "valid denominator")
    classes = ["HIGH_ONLY", "LOW_ONLY", "HIGH_THEN_LOW", "LOW_THEN_HIGH", "NO_BREAK", "BOTH_ORDER_AMBIGUOUS"]
    check(all(summary[c+"_Count"] == "1" for c in classes), "all six outcome classes")
    check(math.isclose(sum(float(summary[c+"_Pct"]) for c in classes), 100, abs_tol=1e-6), "classification sums to 100")
    daily = tables["Daily"]
    check(len({d["Date"] for d in daily}) == len(daily), "one row per date")
    check(daily[6]["SetupValid"] == "false" and daily[7]["SetupValid"] == "false", "touch invalidates")
    check(daily[8]["SetupValid"] == "true" and daily[8]["OutcomeComplete"] == "false", "NY gap preserves validity")
    check(daily[9]["SetupValid"] == "" and daily[9]["SetupStatus"] == "UNKNOWN", "setup gap is missing")
    check(daily[4]["FirstBreakMFE_Pips"] == "", "ambiguous first side not imputed")
    check(daily[5]["FirstBreakMFE_Pips"] == "", "no breakout not replaced with zero")
    states = {"HIT_BEFORE_SL", "SL_FIRST", "NOT_REACHED", "AMBIGUOUS", "NO_BREAK", "INVALID_RISK", "NA_GAP", "UNAVAILABLE"}
    rcols = [c for c in headers["Daily"] if c.endswith("_Status")]
    check(len(rcols) == 42, "42 R scenarios per daily row")
    for d in daily:
        for col in rcols:
            state = d[col]
            check(state in states, f"unknown R state {state}")
            flag = d[col.removesuffix("_Status") + "_HitBeforeSL"]
            expected_flag = "true" if state == "HIT_BEFORE_SL" else ("false" if state in {"SL_FIRST", "NOT_REACHED"} else "")
            check(flag == expected_flag, "ambiguous R cannot become a boolean loss")
    for table in ["ByCompression", "ByLondonPosition", "ByPrice0800Position", "ByWeekday"]:
        check(sum(int(r["Cases"]) for r in tables[table]) == 6, f"group partition {table}")
    check(sum(int(r["Cases"]) for r in tables["CompressionPriceCross"][:56]) == 6, "base cross partition")
    check(all(r["MFE_Pips_Mean"] == "" for r in tables["ByCompression"] if r["Cases"] == "0"), "empty means stay blank")
    metadata = {r["Key"]: r["Value"] for r in tables["RunMetadata"]}
    check(metadata["RunStatus"] == "SYNTHETIC_TEST_DATA", "synthetic files labeled")
    source_text = (ROOT / "EURUSD_AsiaLondonCompression.mq5").read_text(encoding="utf-8-sig")
    for forbidden in ["OrderSend(", "OrderSendAsync(", "CTrade", "iRSI(", "iMACD(", "iMA(", "iBands(", "iATR("]:
        check(forbidden not in source_text, f"unexpected trading/indicator API {forbidden}")
    check("CopyRates(StudySymbol,PERIOD_M1" in source_text, "M1 explicit")
    check("_Period" not in source_text, "independent of chart timeframe")
    DEST.mkdir(exist_ok=True)
    saved = DEST / "synthetic_csv"
    saved.mkdir(exist_ok=True)
    if source.resolve() != saved.resolve():
        for path in source.glob("*.csv"):
            shutil.copy2(path, saved / path.name)
    logs = ROOT / "validation_mt5/MQL5/Logs"
    if logs.is_dir():
        lines = []
        for path in logs.glob("*.log"):
            text = path.read_text(encoding="utf-16", errors="replace")
            lines.extend(line for line in text.splitlines() if "CompressionSelfTest" in line)
        check(any("ALL PASSED, failures=0" in line for line in lines), "native MQL5 selftests passed")
        check(not any("\tFAIL " in line for line in lines), "no native test failure")
        (DEST / "MQL5_selftests.log").write_text("\n".join(lines) + "\n", encoding="utf-8")
    # Literal, ordered inventory from actual MQL5 output, not a parallel schema implementation.
    output = ["# Columnas literales de los CSV", "", "Esquema extraído de archivos emitidos por las pruebas nativas del script. Consultar la guía para fórmulas, unidades, denominadores e incertidumbre M1.", ""]
    for name in ["Daily", "Summary", "ByCompression", "ByLondonPosition", "ByPrice0800Position", "CompressionPriceCross", "ByWeekday", "ByVolatility", "RunMetadata"]:
        output.extend([f"## {PREFIX}{name}.csv", "", f"{len(headers[name])} columnas, en orden:", "", "```text", *headers[name], "```", ""])
    (ROOT / "EURUSD_AsiaLondonCompression_Columnas.md").write_text("\n".join(output), encoding="utf-8")
    report = f"PASS: {assertions} CSV/source assertions. Nine native-generated CSV files validated.\n"
    report += "These files contain synthetic prices, not market results.\n"
    report += "\n".join(f"{name}: {len(tables[name])} rows, {len(headers[name])} columns" for name in headers)
    (DEST / "CSV_validation.txt").write_text(report + "\n", encoding="utf-8")
    print(report)


if __name__ == "__main__":
    main()
