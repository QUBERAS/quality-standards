#!/usr/bin/env python3
"""Validate quality-standards configs and workflows."""

import glob
import re
import sys

try:
    import tomllib
except ImportError:
    try:
        import tomli as tomllib  # type: ignore[no-redefine]
    except ImportError:
        print("ERROR: Need Python 3.11+ or 'pip install tomli'")
        sys.exit(1)

import yaml  # type: ignore[import-untyped]


def validate_toml(path: str) -> bool:
    try:
        with open(path, "rb") as f:
            tomllib.load(f)
        print(f"  OK: {path}")
        return True
    except Exception as e:
        print(f"  FAIL: {path} — {e}")
        return False


def validate_yaml(path: str) -> bool:
    try:
        with open(path) as f:
            yaml.safe_load(f)
        print(f"  OK: {path}")
        return True
    except Exception as e:
        print(f"  FAIL: {path} — {e}")
        return False


def check_action_pins() -> bool:
    ok = True
    for path in glob.glob(".github/workflows/*.yml"):
        with open(path) as f:
            content = f.read()
        for bad_pin in ["@master", "@latest"]:
            if bad_pin in content:
                lines = [
                    f"{i + 1}: {line.strip()}"
                    for i, line in enumerate(content.splitlines())
                    if bad_pin in line
                ]
                for line in lines:
                    print(f"  FAIL: {path}:{line} — uses {bad_pin} (pin to version tag)")
                ok = False
    if ok:
        print("  OK: No @master or @latest pins")
    return ok


def check_relative_refs() -> bool:
    ok = True
    for path in glob.glob(".github/workflows/*.yml"):
        with open(path) as f:
            content = f.read()
        matches = [
            f"{i + 1}: {line.strip()}"
            for i, line in enumerate(content.splitlines())
            if re.search(r"uses:\s+\./", line)
        ]
        if matches:
            for m in matches:
                print(f"  FAIL: {path}:{m} — relative ./ ref (must be absolute)")
            ok = False
    if ok:
        print("  OK: No relative workflow refs")
    return ok


def check_level_consistency() -> bool:
    levels = {}
    for name in ["minimal", "standard", "strict"]:
        with open(f"configs/python/levels/{name}.toml", "rb") as f:
            levels[name] = tomllib.load(f)

    with open("configs/python/ruff.reference.toml", "rb") as f:
        ref = tomllib.load(f)

    ok = True

    for name, cfg in levels.items():
        if cfg.get("line-length") != 120:
            print(f"  WARN: {name} has non-standard line-length: {cfg.get('line-length')}")
        if "format" not in cfg:
            print(f"  WARN: {name} missing [format] section")
            ok = False

    strict_sel = set(levels["strict"]["lint"]["select"])
    ref_sel = set(ref["lint"]["select"])
    if strict_sel != ref_sel:
        print(f"  WARN: strict.toml select != reference.toml select")
        print(f"    strict only: {strict_sel - ref_sel}")
        print(f"    reference only: {ref_sel - strict_sel}")
        ok = False
    else:
        print("  OK: strict.toml select matches reference.toml")

    strict_ign = set(levels["strict"]["lint"]["ignore"])
    ref_ign = set(ref["lint"]["ignore"])
    if strict_ign != ref_ign:
        print(f"  WARN: strict.toml ignore != reference.toml ignore")
        print(f"    strict only: {strict_ign - ref_ign}")
        print(f"    reference only: {ref_ign - strict_ign}")
        ok = False
    else:
        print("  OK: strict.toml ignore matches reference.toml")

    if ok:
        print("  OK: All level configs consistent")
    return ok


def main() -> int:
    failed = False

    print("=== Validating TOML configs ===")
    for f in sorted(glob.glob("configs/python/levels/*.toml")) + ["configs/python/ruff.reference.toml"]:
        if not validate_toml(f):
            failed = True

    print("\n=== Validating YAML configs ===")
    if not validate_yaml("configs/python/.pre-commit-config.yaml"):
        failed = True

    print("\n=== Validating workflow YAML ===")
    for f in sorted(glob.glob(".github/workflows/*.yml")):
        if not validate_yaml(f):
            failed = True

    print("\n=== Checking action version pins ===")
    if not check_action_pins():
        failed = True

    print("\n=== Checking for relative workflow refs ===")
    if not check_relative_refs():
        failed = True

    print("\n=== Checking level config consistency ===")
    if not check_level_consistency():
        failed = True

    print()
    if failed:
        print("FAILED — see errors above.")
        return 1
    print("All validations passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
