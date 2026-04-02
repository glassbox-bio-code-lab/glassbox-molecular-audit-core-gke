import os
import subprocess
import sys
from pathlib import Path

import yaml


def _run_bash(script: str, env: dict) -> int:
    # The test scripts already include their own strict-mode setup.
    p = subprocess.run(["bash", "-lc", script], env=env)
    return int(p.returncode)


def main() -> int:
    test_dir = Path("/tests")
    env = os.environ.copy()

    yamls = sorted(list(test_dir.glob("*.yaml")) + list(test_dir.glob("*.yml")))
    if not yamls:
        print("No test specs found under /tests", file=sys.stderr)
        return 1

    for spec_path in yamls:
        print(f"=== SPEC START: {spec_path.name} ===", flush=True)
        with spec_path.open("r", encoding="utf-8") as f:
            spec = yaml.safe_load(f) or {}

        actions = spec.get("actions") or []
        if not isinstance(actions, list):
            print(f"{spec_path}: 'actions' must be a list", file=sys.stderr)
            return 1

        for idx, action in enumerate(actions, start=1):
            name = action.get("name") or "<unnamed action>"
            bash_test = (action.get("bashTest") or {}) if isinstance(action, dict) else {}
            script = bash_test.get("script") if isinstance(bash_test, dict) else None

            if not script:
                print(f"SKIP[{idx}]: {name} (no bashTest.script)", flush=True)
                continue

            print(f"--- ACTION {idx} START: {name} ---", flush=True)
            rc = _run_bash(str(script), env)
            if rc != 0:
                print(
                    f"FAIL[{idx}]: {name} (exit={rc}, spec={spec_path.name})",
                    file=sys.stderr,
                    flush=True,
                )
                return rc

            print(f"PASS[{idx}]: {name}", flush=True)

        print(f"=== SPEC PASS: {spec_path.name} ===", flush=True)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
