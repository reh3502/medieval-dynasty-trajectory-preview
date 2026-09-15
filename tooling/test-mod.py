#!/usr/bin/env python3
"""Run Lua checks in isolation; optionally select test names without .lua."""
import argparse
import json
from pathlib import Path

from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "mod/TrajectoryPreview/Scripts"


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().package.path = str(SCRIPTS / "?.lua") + ";" + lua.globals().package.path
    return lua


def check_json():
    # Use an independent decoder, including controls and non-finite numbers.
    lua = runtime()
    encoder = lua.eval('require("telemetry").encode')
    message = 'quoted " value \\ ' + ''.join(chr(n) for n in range(32))
    encoded = encoder(lua.table_from({"message": message, "value": 1/240, "invalid": float("nan")}))
    assert json.loads(encoded) == {"message": message, "value": 1/240, "invalid": None}
    print("PASS telemetry JSON round-trip with control characters and finite numbers", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tests", nargs="*", help="test stems, e.g. weapon_families preview; default: all")
    parser.add_argument("--list", action="store_true", help="list available tests")
    args = parser.parse_args()
    available = {path.stem: path for path in sorted((ROOT / "tests").glob("*.lua"))}
    if args.list:
        print("\n".join(available))
        return
    unknown = set(args.tests) - available.keys()
    if unknown:
        parser.error("unknown tests: " + ", ".join(sorted(unknown)))
    selected = [available[name] for name in args.tests] if args.tests else list(available.values())

    lua = runtime()
    compile_lua = lua.eval('function(source,name) local f,e=load(source,name); assert(f,e) end')
    for path in sorted((ROOT / "mod").rglob("*.lua")):
        compile_lua(path.read_text(), "@" + str(path))
    print("PASS all mod Lua files compile under Lua 5.4", flush=True)
    for test in selected:
        print("RUN " + test.stem, flush=True)
        # Modules, caches, mocks and engine globals cannot leak between tests.
        lua = runtime()
        lua.execute(test.read_text(), name="@" + str(test))
    check_json()
    print(f"PASS {len(selected)} isolated Lua test files", flush=True)


if __name__ == "__main__":
    main()
