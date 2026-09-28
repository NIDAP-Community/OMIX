#!/usr/bin/env python3
"""Validate and render the OMIX deployment-adapter inventory."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INVENTORY_PATH = ROOT / "docs" / "deployment-adapter-inventory.json"
SUMMARY_PATH = ROOT / "docs" / "deployment-adapter-inventory.md"
ALLOWED_STATUSES = {
    "verified",
    "outdated",
    "partial",
    "pending",
    "unknown",
    "blocked",
    "not_applicable",
}
STATUS_FIELDS = (
    "schema_completeness",
    "scientific_export.recorded_parity",
    "scientific_export.current_parity",
    "scientific_export.source_record",
    "scientific_export.hash_manifest",
    "app_panel.coverage",
    "runtime.provenance",
    "local_tests",
    "code_ocean_validation",
    "syncweaver.readiness",
)


def fail(message: str) -> None:
    raise ValueError(message)


def nested(record: dict, dotted_path: str) -> dict:
    value = record
    for component in dotted_path.split("."):
        if component not in value:
            fail(f"{record.get('id', '<unknown>')}: missing {dotted_path}")
        value = value[component]
    if not isinstance(value, dict):
        fail(f"{record.get('id', '<unknown>')}: {dotted_path} must be an object")
    return value


def parse_scalar(value: str):
    value = value.strip()
    if re.fullmatch(r"[0-9]+", value):
        return int(value)
    return value


def parse_deployment_adapter_repositories(text: str) -> list[str]:
    """Return repository values from the top-level deployment adapter list.

    OMIX module manifests use a small, predictable YAML fragment for this
    registry. Parse that fragment line by line so lookup is bounded by the
    manifest length and cannot backtrack across an arbitrary number of lines.
    The list return type retains every repository in a future multi-adapter
    block; callers that implement today's one-adapter inventory may select the
    first entry explicitly.
    """

    lines = text.splitlines()
    block_start = None
    inline_value = ""
    for index, line in enumerate(lines):
        if line[:1].isspace():
            continue
        key, separator, value = line.partition(":")
        if separator and key.strip() == "deployment_adapters":
            block_start = index + 1
            inline_value = value.strip()
            break

    if block_start is None:
        return []
    if inline_value:
        # The canonical empty-list form is `deployment_adapters: []`. Other
        # inline YAML forms were not recognized by the previous registry
        # lookup and remain outside this deliberately small parser.
        return []

    repositories: list[str] = []
    for line in lines[block_start:]:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if not line[:1].isspace():
            break

        content = line.lstrip()
        if content.startswith("- "):
            content = content[2:].lstrip()
        key, separator, value = content.partition(":")
        if not separator or key.strip() != "repository":
            continue

        repository = value.strip()
        comment_index = repository.find(" #")
        if comment_index >= 0:
            repository = repository[:comment_index].rstrip()
        if (
            len(repository) >= 2
            and repository[0] == repository[-1]
            and repository[0] in {"'", '"'}
        ):
            repository = repository[1:-1]
        if repository:
            repositories.append(repository)

    return repositories


def registered_adapters() -> dict[str, dict]:
    records: dict[str, dict] = {}
    for module_file in sorted((ROOT / "modules").glob("*/module.yml")):
        text = module_file.read_text(encoding="utf-8")
        repositories = parse_deployment_adapter_repositories(text)
        if not repositories:
            continue
        values = {}
        for key in ("display_name", "version", "interface_version"):
            match = re.search(rf"(?m)^{key}:\s*(.+?)\s*$", text)
            if not match:
                fail(f"{module_file}: missing {key}")
            values[key] = parse_scalar(match.group(1))
        # The current inventory has one deployment record per canonical
        # module, matching the first repository selected by the former lookup.
        # The parser retains later entries so a future inventory schema can
        # represent multiple deployment targets without another parser change.
        values["repository"] = repositories[0]
        values["module_path"] = str(module_file.parent.relative_to(ROOT))
        records[module_file.parent.name] = values
    return records


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate(inventory: dict) -> None:
    if inventory.get("schema_version") != 1:
        fail("schema_version must be 1")
    snapshot = inventory.get("snapshot")
    if not isinstance(snapshot, dict):
        fail("snapshot must be an object")
    snapshot_commit = snapshot.get("canonical_repository_commit", "")
    if not re.fullmatch(r"[0-9a-f]{40}", snapshot_commit):
        fail("snapshot.canonical_repository_commit must be a full Git SHA")

    adapters = inventory.get("adapters")
    if not isinstance(adapters, list) or not adapters:
        fail("adapters must be a non-empty array")

    ids = [item.get("id") for item in adapters]
    repositories = [item.get("deployment", {}).get("repository") for item in adapters]
    if len(ids) != len(set(ids)):
        fail("duplicate adapter id")
    if len(repositories) != len(set(repositories)):
        fail("duplicate deployment repository")

    registry = registered_adapters()
    if set(ids) != set(registry):
        fail(
            "inventory/module.yml adapter mismatch: "
            f"missing={sorted(set(registry) - set(ids))}, "
            f"extra={sorted(set(ids) - set(registry))}"
        )

    for adapter in adapters:
        adapter_id = adapter["id"]
        expected = registry[adapter_id]
        canonical = adapter.get("canonical", {})
        deployment = adapter.get("deployment", {})
        if canonical.get("module_path") != expected["module_path"]:
            fail(f"{adapter_id}: canonical module_path does not match module.yml")
        if canonical.get("module_version") != expected["version"]:
            fail(f"{adapter_id}: module_version does not match module.yml")
        if canonical.get("interface_version") != expected["interface_version"]:
            fail(f"{adapter_id}: interface_version does not match module.yml")
        if canonical.get("source_commit") != snapshot_commit:
            fail(f"{adapter_id}: source_commit must match snapshot commit")
        if deployment.get("repository") != expected["repository"]:
            fail(f"{adapter_id}: deployment repository does not match module.yml")
        if not deployment.get("default_branch"):
            fail(f"{adapter_id}: deployment default_branch is required")
        if not re.fullmatch(r"[0-9a-f]{40}", deployment.get("default_branch_commit", "")):
            fail(f"{adapter_id}: default_branch_commit must be a full Git SHA")

        schema_path = ROOT / canonical.get("schema_path", "")
        if not schema_path.is_file():
            fail(f"{adapter_id}: schema_path does not exist: {schema_path}")

        for dotted_path in STATUS_FIELDS:
            status_record = nested(adapter, dotted_path)
            status = status_record.get("status")
            evidence = status_record.get("evidence")
            if status not in ALLOWED_STATUSES:
                fail(f"{adapter_id}: invalid status {status!r} at {dotted_path}")
            if not isinstance(evidence, list):
                fail(f"{adapter_id}: {dotted_path}.evidence must be an array")
            if status == "verified" and not evidence:
                fail(f"{adapter_id}: verified {dotted_path} requires evidence")
            if not isinstance(status_record.get("note"), str) or not status_record["note"]:
                fail(f"{adapter_id}: {dotted_path}.note is required")

        managed_files = adapter["scientific_export"].get("managed_files")
        if not isinstance(managed_files, list) or not managed_files:
            fail(f"{adapter_id}: scientific_export.managed_files must be non-empty")
        seen_sources = set()
        seen_targets = set()
        for item in managed_files:
            source_path = item.get("canonical_path")
            target_path = item.get("adapter_path")
            if source_path in seen_sources or target_path in seen_targets:
                fail(f"{adapter_id}: duplicate managed file mapping")
            seen_sources.add(source_path)
            seen_targets.add(target_path)
            source_file = ROOT / source_path
            if not source_file.is_file():
                fail(f"{adapter_id}: missing canonical file {source_path}")
            current_hash = item.get("current_source_sha256", "")
            if current_hash != sha256(source_file):
                fail(f"{adapter_id}: stale current_source_sha256 for {source_path}")
            for hash_field in (
                "recorded_source_sha256",
                "adapter_sha256",
                "current_source_sha256",
            ):
                if not re.fullmatch(r"[0-9a-f]{64}", item.get(hash_field, "")):
                    fail(f"{adapter_id}: invalid {hash_field} for {source_path}")
            for match_field in ("matches_recorded", "matches_current"):
                if not isinstance(item.get(match_field), bool):
                    fail(f"{adapter_id}: {match_field} must be boolean")


def link(label: str, url: str | None) -> str:
    return f"[{label}]({url})" if url else "None recorded"


def render(inventory: dict) -> str:
    snapshot = inventory["snapshot"]
    lines = [
        "# Deployment adapter inventory",
        "",
        "This is Beacon's evidence-based snapshot of deployment adapters registered in canonical `module.yml` files. It is an audit index, not release authorization. `Pending` and `Unknown` are intentional when durable evidence is absent.",
        "",
        f"- **Snapshot date:** {snapshot['date']}",
        f"- **Canonical OMIX commit:** [`{snapshot['canonical_repository_commit'][:12]}`]({snapshot['canonical_repository_url']}/commit/{snapshot['canonical_repository_commit']})",
        f"- **Tracked work item:** {link('OMIX issue #26', snapshot['work_item'])}",
        f"- **Machine-readable source:** [`deployment-adapter-inventory.json`](deployment-adapter-inventory.json)",
        f"- **Validation/render command:** `python3 scripts/check_deployment_adapter_inventory.py --write-summary`",
        "",
        "## Current status",
        "",
        "| Adapter | Canonical | Deployment | Recorded export | Current parity | Schema | App Panel | Runtime | Code Ocean | Syncweaver | Active work |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for item in inventory["adapters"]:
        canonical = item["canonical"]
        deployment = item["deployment"]
        work = item["work_tracking"]
        prs = ", ".join(link(f"PR #{pr['number']}", pr["url"]) for pr in work["pull_requests"])
        if not prs:
            prs = "None recorded"
        lines.append(
            "| "
            + " | ".join(
                [
                    link(item["id"], deployment["repository"]),
                    f"v{canonical['module_version']} / interface {canonical['interface_version']}",
                    f"`{deployment['default_branch']}` @ `{deployment['default_branch_commit'][:8]}`",
                    item["scientific_export"]["recorded_parity"]["status"],
                    item["scientific_export"]["current_parity"]["status"],
                    item["schema_completeness"]["status"],
                    item["app_panel"]["coverage"]["status"],
                    item["runtime"]["provenance"]["status"],
                    item["code_ocean_validation"]["status"],
                    item["syncweaver"]["readiness"]["status"],
                    prs,
                ]
            )
            + " |"
        )

    outdated = [
        item["id"]
        for item in inventory["adapters"]
        if item["scientific_export"]["current_parity"]["status"] == "outdated"
    ]
    colocated = [
        item["id"]
        for item in inventory["adapters"]
        if item["scientific_export"]["extra_files_in_code_functions"]
    ]
    no_lock = [
        item["id"]
        for item in inventory["adapters"]
        if not item["syncweaver"]["lockfile_on_default_branch"]
    ]
    lines.extend(
        [
            "",
            "## Priority findings",
            "",
            f"- **Adapters behind current canonical science:** {', '.join(outdated) if outdated else 'None'}.",
            f"- **Adapters with adapter-only or legacy files co-located in `code/functions/`:** {', '.join(colocated) if colocated else 'None'}.",
            f"- **Adapters without a Syncweaver lockfile on the default branch:** {', '.join(no_lock) if no_lock else 'None'}.",
            "- **Schema completeness and App Panel coverage:** pending a parameter-level contract audit for every adapter; file presence alone is not counted as completeness.",
            "- **Runtime provenance:** no adapter source record in this snapshot supplies both a pinned runtime tag and immutable digest.",
            "",
            "## Reading the statuses",
            "",
            "- `verified`: direct evidence supports the claim at the recorded commits.",
            "- `outdated`: the adapter matches its recorded source but not the canonical snapshot.",
            "- `partial`: some evidence exists, but a required identifier or validation is missing.",
            "- `pending`: the required audit or evidence has not been completed.",
            "- `unknown`: the snapshot found no durable evidence either way.",
            "- `blocked`: a known structural conflict must be resolved before proceeding.",
            "",
            "## Update protocol",
            "",
            "Beacon updates the JSON after a reviewed adapter or canonical change, runs the validator, regenerates this page, and links the corresponding issue, PR, CI run, Code Ocean run, runtime tag, or digest. Harbor supplies deployment facts; domain owners supply scientific-interface evidence; Forge supplies runtime provenance. Atlas coordinates review and merge order.",
            "",
            "Do not replace a `Pending` or `Unknown` value with an inference. Add an immutable or reviewable evidence URL first.",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--write-summary",
        action="store_true",
        help="write the generated Markdown summary after validation",
    )
    args = parser.parse_args()
    inventory = json.loads(INVENTORY_PATH.read_text(encoding="utf-8"))
    validate(inventory)
    summary = render(inventory)
    if args.write_summary:
        SUMMARY_PATH.write_text(summary, encoding="utf-8")
    elif SUMMARY_PATH.read_text(encoding="utf-8") != summary:
        fail("deployment-adapter-inventory.md is stale; run with --write-summary")
    print(f"Deployment adapter inventory validated: {len(inventory['adapters'])} adapters")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (KeyError, json.JSONDecodeError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
