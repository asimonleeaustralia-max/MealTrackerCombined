#!/usr/bin/env python3
"""Verify every food metric stays in sync across the three layers that define it:

  1. iOS Core Data model   (ios/.../MealTracker.xcdatamodel/contents)
  2. Backend Pydantic schema (libs/shared/.../schemas.py  -> MealBase)
  3. iOS sync manifest      (ios/MealTracker/CloudModels.swift -> MealFieldManifest)

The manifest drives the iOS <-> web sync codec, so if these three ever diverge a
metric could be silently dropped. This script fails (exit 1) with a readable diff
if any layer is missing a field the others have.

Run from the repo root:  python3 scripts/check_metric_parity.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MODEL = ROOT / "ios/MealTracker/MealTracker.xcdatamodeld/MealTracker.xcdatamodel/contents"
SCHEMA = ROOT / "libs/shared/src/mealtracker_shared/schemas.py"
MANIFEST = ROOT / "ios/MealTracker/CloudModels.swift"

# Fields that exist in the Core Data model but are intentionally NOT synced.
# `mealDescription` is used by neither the iOS UI nor the web app and has no
# backend column; `lastSyncGUID` is a client-managed sync marker.
IOS_ONLY_EXCLUSIONS = {"meal_description", "last_sync_guid"}


def camel_to_snake(name: str) -> str:
    s = re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", name)
    s = re.sub(r"(?<=[A-Z])(?=[A-Z][a-z])", "_", s)
    return s.lower()


def ios_model_fields() -> tuple[set[str], set[str]]:
    text = MODEL.read_text()
    block = text.split('name="Meal"')[1].split("</entity>")[0]
    doubles = {
        camel_to_snake(m)
        for m in re.findall(r'name="(\w+)"[^>]*attributeType="Double"', block)
    }
    bools = {
        camel_to_snake(m)
        for m in re.findall(r'name="(\w+)"[^>]*attributeType="Boolean"', block)
    }
    return doubles, bools


def backend_schema_fields() -> tuple[set[str], set[str]]:
    text = SCHEMA.read_text()
    block = text.split("class MealBase")[1].split("class MealCreate")[0]
    floats = set(re.findall(r"^\s{4}(\w+):\s*float", block, re.M))
    bools = set(re.findall(r"^\s{4}(\w+):\s*bool", block, re.M))
    return floats, bools


def swift_manifest_fields() -> tuple[set[str], set[str]]:
    text = MANIFEST.read_text()

    def snakes(array_name: str) -> set[str]:
        # Capture from the declaration up to the next `static let` (or end of file),
        # then collect every snake name. Splitting on "]" would stop early because the
        # tuple type annotation `[(snake: String, camel: String)]` contains a bracket.
        after = text.split(f"static let {array_name}")[1]
        block = re.split(r"\n\s*static let ", after, maxsplit=1)[0]
        return set(re.findall(r'snake:\s*"([a-z0-9_]+)"', block))

    return snakes("doubleFields"), snakes("boolFields")


def report(label: str, a: set[str], b: set[str], a_name: str, b_name: str) -> bool:
    only_a = sorted(a - b)
    only_b = sorted(b - a)
    if not only_a and not only_b:
        print(f"  OK   {label}: {len(a)} fields match")
        return True
    print(f"  FAIL {label}:")
    if only_a:
        print(f"       in {a_name} but not {b_name}: {only_a}")
    if only_b:
        print(f"       in {b_name} but not {a_name}: {only_b}")
    return False


def main() -> int:
    ios_d, ios_b = ios_model_fields()
    ios_d -= IOS_ONLY_EXCLUSIONS
    ios_b -= IOS_ONLY_EXCLUSIONS

    be_d, be_b = backend_schema_fields()
    sw_d, sw_b = swift_manifest_fields()

    print("Numeric metrics:")
    ok = report("iOS model  vs backend schema", ios_d, be_d, "iOS", "backend")
    ok &= report("iOS model  vs Swift manifest", ios_d, sw_d, "iOS", "manifest")
    print("Accuracy flags (*IsGuess):")
    ok &= report("iOS model  vs backend schema", ios_b, be_b, "iOS", "backend")
    ok &= report("iOS model  vs Swift manifest", ios_b, sw_b, "iOS", "manifest")

    print()
    if ok:
        print(f"PASS — all {len(ios_d)} metrics + {len(ios_b)} guess-flags in sync "
              "across iOS, backend, and the sync manifest.")
        return 0
    print("FAIL — metric sets diverged. See diffs above.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
