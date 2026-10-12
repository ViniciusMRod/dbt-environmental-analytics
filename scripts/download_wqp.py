"""Download a Lucas County, OH extract from the Water Quality Portal (WQX 3.0
profile) and write it as a dbt seed, keeping only the columns the project uses.

This documents where the seed came from. It is not an ingestion pipeline:
the CSV it produces is committed and loaded with `dbt seed`.
"""
import csv
import io
import urllib.parse
import urllib.request
from collections import Counter
from pathlib import Path

BASE_URL = "https://www.waterqualitydata.us/wqx3/Result/search"
CHARACTERISTICS = [
    "pH", "Dissolved oxygen (DO)", "Specific conductance", "Turbidity",
    "Nitrate", "Phosphorus", "Iron", "Manganese",
]
QUERY = [
    ("countycode", "US:39:095"),      # Lucas County, Ohio
    ("startDateLo", "01-01-2020"),
    ("startDateHi", "12-31-2025"),
    ("dataProfile", "basicPhysChem"),
    ("mimeType", "csv"),
] + [("characteristicName", c) for c in CHARACTERISTICS]

KEEP = [
    "Org_Identifier", "Location_Identifier", "Location_Name", "Location_Type",
    "Location_LatitudeStandardized", "Location_LongitudeStandardized",
    "Location_HUCEightDigitCode", "Activity_ActivityIdentifier",
    "Activity_StartDate", "Activity_StartTime", "Activity_Media",
    "Result_Characteristic", "Result_SampleFraction", "Result_MeasureIdentifier",
    "Result_Measure", "Result_MeasureUnit", "Result_ResultDetectionCondition",
    "Result_MeasureQualifierCode", "DetectionLimit_MeasureA",
    "DetectionLimit_MeasureUnitA", "ProviderName",
]
OUT = Path(__file__).resolve().parent.parent / "seeds" / "raw_wqp_results.csv"


def main() -> None:
    url = BASE_URL + "?" + urllib.parse.urlencode(QUERY)
    with urllib.request.urlopen(url, timeout=600) as resp:
        text = resp.read().decode("utf-8-sig")

    rows = list(csv.DictReader(io.StringIO(text)))

    missing = [c for c in KEEP if rows and c not in rows[0]]
    if missing:
        raise SystemExit(f"Columns not found in response: {missing}")

    total = len(rows)
    rows = [r for r in rows if r.get("Activity_StartDate") and r.get("Result_Characteristic")]
    print(f"dropped {total - len(rows)} empty/short row(s)")

    print("media in response:", dict(Counter(r["Activity_Media"] for r in rows)))
    rows = [r for r in rows if r["Activity_Media"] == "Water"]
    print(f"kept {len(rows)} water rows (sediment and other media are out of scope for v1)")

    with OUT.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow([c.lower() for c in KEEP])
        for r in rows:
            writer.writerow([r[c] for c in KEEP])

    dates = sorted(r["Activity_StartDate"] for r in rows if r["Activity_StartDate"])
    print(f"rows: {len(rows)} | sites: {len({r['Location_Identifier'] for r in rows})}")
    print(f"dates: {dates[0]} -> {dates[-1]} | size: {OUT.stat().st_size / 1e6:.2f} MB")
    for name, n in Counter(r["Result_Characteristic"] for r in rows).most_common():
        print(f"  {n:5d}  {name}")


if __name__ == "__main__":
    main()