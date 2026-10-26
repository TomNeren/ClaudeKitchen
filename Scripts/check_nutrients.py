"""Checks every nutrient value in food-catalog.json against the USDA FoodData Central SR Legacy CSV files.

Usage:
    mkdir -p /tmp/fdc && cd /tmp/fdc
    curl -sSLO https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip
    unzip -q FoodData_Central_sr_legacy_food_csv_2018-04.zip
    python3 -I Scripts/check_nutrients.py Sources/KitchenCore/Resources/Evidence/food-catalog.json \
        /tmp/fdc/FoodData_Central_sr_legacy_food_csv_2018-04

Prints the USDA description next to each food so the match can be judged by eye. Exits non-zero on any mismatch.
"""
import csv
import json
import sys

catalog_path, csv_dir = sys.argv[1], sys.argv[2]
fields = {"1008": "kcal", "1003": "protein", "1004": "fat", "1258": "saturatedFat", "1005": "carbohydrate",
          "1079": "fiber", "1093": "sodiumMilligrams"}
foods = [f for f in json.load(open(catalog_path, encoding="utf-8"))["foods"] if "nutrients" in f]
ids = {str(f["nutrients"]["fdcID"]) for f in foods}
descriptions = {r["fdc_id"]: r["description"] for r in csv.DictReader(open(csv_dir + "/food.csv", encoding="utf-8"))
                if r["fdc_id"] in ids}
values = {}
for row in csv.DictReader(open(csv_dir + "/food_nutrient.csv", encoding="utf-8")):
    if row["fdc_id"] in ids and row["nutrient_id"] in fields:
        values.setdefault(row["fdc_id"], {})[fields[row["nutrient_id"]]] = float(row["amount"])
failures = 0
for food in foods:
    fdc_id = str(food["nutrients"]["fdcID"])
    if fdc_id not in descriptions:
        failures += 1
        print("UNKNOWN FDC ID", food["id"], fdc_id)
        continue
    source = values.get(fdc_id, {})
    for name in fields.values():
        ours, theirs = food["nutrients"].get(name), source.get(name)
        if ours != theirs:
            failures += 1
            print("MISMATCH", food["id"], name, ours, theirs)
    print("ok" if all(food["nutrients"].get(n) == source.get(n) for n in fields.values()) else "FAIL",
          food["id"], "->", descriptions[fdc_id])
print("failures:", failures)
sys.exit(1 if failures else 0)
