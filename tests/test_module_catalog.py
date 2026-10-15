#!/usr/bin/env python3
"""Keep the README module catalog synchronized with canonical manifests."""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ALLOWED_STATUSES = {"development", "review", "active"}
LINK = re.compile(r"^\[([^]]+)]\(([^)]+)\)$")


def top_level_scalars(text: str) -> dict[str, str]:
    """Read the small top-level scalar subset used by OMIX module manifests."""
    values: dict[str, str] = {}
    for line in text.splitlines():
        if not line or line[0].isspace() or line.lstrip().startswith("#"):
            continue
        key, separator, value = line.partition(":")
        if separator and value.strip():
            values[key.strip()] = value.strip().strip('"\'')
    return values


def deployment_repository(text: str) -> str:
    match = re.search(r"(?m)^\s+repository:\s*(\S+)\s*$", text)
    if not match:
        raise AssertionError("module.yml has no registered deployment repository")
    return match.group(1).strip('"\'')


def manifest_records() -> dict[str, dict[str, str]]:
    records: dict[str, dict[str, str]] = {}
    for manifest in sorted((ROOT / "modules").glob("*/module.yml")):
        text = manifest.read_text(encoding="utf-8")
        values = top_level_scalars(text)
        required = {"display_name", "description", "status"}
        missing = required - values.keys()
        if missing:
            raise AssertionError(f"{manifest}: missing {sorted(missing)}")
        if values["status"] not in ALLOWED_STATUSES:
            raise AssertionError(
                f"{manifest}: status {values['status']!r} is not one of "
                f"{sorted(ALLOWED_STATUSES)}"
            )
        module_id = manifest.parent.name
        records[module_id] = {
            "module_path": f"modules/{module_id}",
            "deployment_repository": deployment_repository(text),
            "description": values["description"],
            "status": values["status"].title(),
        }
    return records


def readme_records() -> dict[str, dict[str, str]]:
    records: dict[str, dict[str, str]] = {}
    for line in (ROOT / "README.md").read_text(encoding="utf-8").splitlines():
        if not line.startswith("| [") or "](modules/" not in line:
            continue
        cells = line[2:-2].split(" | ")
        if len(cells) != 4:
            raise AssertionError(f"Malformed README module-catalog row: {line}")
        module_link = LINK.fullmatch(cells[0])
        deployment_link = LINK.fullmatch(cells[1])
        if not module_link or not deployment_link:
            raise AssertionError(f"Malformed README catalog link: {line}")
        module_label, module_path = module_link.groups()
        deployment_label, deployment_url = deployment_link.groups()
        module_id = Path(module_path).name
        if module_label != module_id or deployment_label != module_id:
            raise AssertionError(
                f"{module_id}: README link labels must use the canonical module directory name"
            )
        if module_id in records:
            raise AssertionError(f"Duplicate README catalog row for {module_id}")
        records[module_id] = {
            "module_path": module_path,
            "deployment_repository": deployment_url,
            "description": cells[2],
            "status": cells[3],
        }
    return records


expected = manifest_records()
observed = readme_records()
if set(observed) != set(expected):
    raise AssertionError(
        "README/module.yml catalog mismatch: "
        f"missing={sorted(set(expected) - set(observed))}, "
        f"extra={sorted(set(observed) - set(expected))}"
    )

for module_id, expected_record in expected.items():
    if observed[module_id] != expected_record:
        raise AssertionError(
            f"{module_id}: README catalog differs from module.yml\n"
            f"expected={expected_record}\nobserved={observed[module_id]}"
        )

policy = (ROOT / "docs" / "module-lifecycle.md").read_text(encoding="utf-8")
for status in sorted(ALLOWED_STATUSES):
    if f"`{status}`" not in policy:
        raise AssertionError(f"Lifecycle policy does not define {status}")

print("OMIX canonical module lifecycle and README catalog checks passed")
