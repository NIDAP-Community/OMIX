#!/usr/bin/env python3
"""Validate the reviewed OMIX-to-adapter transition preparation contract.

This checker deliberately validates policy, immutable Git evidence, complete
canonical R-tree mappings, and optional local adapter baselines. It does not
implement a Syncweaver API, generate `.syncweaver-lock.json`, modify an
adapter, or make a release decision.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path, PurePosixPath
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
CONTRACT_PATH = ROOT / "docs" / "syncweaver-transition-wave1.json"
SHA_PATTERN = re.compile(r"^[0-9a-f]{40}$")
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
SEMVER_PATTERN = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")

REQUIRED_STOP_CONDITIONS = {
    "dirty_worktree",
    "unexpected_head",
    "divergent_history",
    "host_scientific_edit",
    "managed_tree_mismatch",
    "source_record_disagreement",
    "protected_path_change",
    "validation_failure",
}
REQUIRED_PRE_CHECKS = {
    "clean_worktrees",
    "exact_commits",
    "non_divergent_history",
    "module_and_interface_versions",
    "complete_source_and_destination_trees",
    "baseline_sha256_parity",
    "source_record_consistency",
    "canonical_module_tests",
    "adapter_contract_and_fixture_tests",
}
REQUIRED_POST_CHECKS = {
    "proposed_sha256_parity",
    "managed_tree_completeness",
    "protected_paths_unchanged",
    "source_record_and_generated_lock_consistency",
    "canonical_module_tests",
    "adapter_contract_and_fixture_tests",
    "omix_contract_checker",
    "beacon_independent_parity_review",
}
REQUIRED_EXTERNAL_GATES = {
    "code_ocean_validation",
    "immutable_runtime_digest",
    "explicit_release_approval",
}


class ContractError(ValueError):
    """A transition-contract invariant was not satisfied."""


def fail(message: str) -> None:
    raise ContractError(message)


def run_git(root: Path, *args: str, check: bool = True) -> subprocess.CompletedProcess:
    result = subprocess.run(
        ["git", *args],
        cwd=root,
        capture_output=True,
        check=False,
    )
    if check and result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        fail(f"git {' '.join(args)} failed in {root}: {detail}")
    return result


def git_text(root: Path, *args: str) -> str:
    return run_git(root, *args).stdout.decode("utf-8").strip()


def sha256_bytes(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def sha256_path(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def require_relative_path(value: Any, label: str) -> PurePosixPath:
    if not isinstance(value, str) or not value:
        fail(f"{label} must be a non-empty relative POSIX path")
    path = PurePosixPath(value)
    if path.is_absolute() or any(part in {"", ".", ".."} for part in path.parts):
        fail(f"{label} must be a safe relative POSIX path: {value!r}")
    return path


def require_unique_strings(values: Any, label: str) -> list[str]:
    if not isinstance(values, list) or not values:
        fail(f"{label} must be a non-empty array")
    if not all(isinstance(value, str) and value for value in values):
        fail(f"{label} must contain non-empty strings")
    if len(values) != len(set(values)):
        fail(f"{label} contains duplicates")
    return values


def parse_module_manifest(text: str, label: str) -> tuple[str, int]:
    version_match = re.search(r"(?m)^version:\s*(\S+)\s*$", text)
    interface_match = re.search(r"(?m)^interface_version:\s*([1-9][0-9]*)\s*$", text)
    if not version_match or not interface_match:
        fail(f"{label}: module manifest lacks version or interface_version")
    return version_match.group(1), int(interface_match.group(1))


def git_blob(root: Path, commit: str, path: str) -> bytes:
    return run_git(root, "show", f"{commit}:{path}").stdout


def git_tree_files(root: Path, commit: str, tree_path: str) -> set[str]:
    output = git_text(root, "ls-tree", "-r", "--name-only", commit, "--", tree_path)
    return {line for line in output.splitlines() if line}


def validate_policy(policy: Any) -> None:
    if not isinstance(policy, dict):
        fail("policy must be an object")
    expected_scalars = {
        "scientific_flow": "canonical_to_adapter_only",
        "scientific_authority": "canonical_commit_and_sha256",
        "conflict_resolution": "stop_and_review",
        "timestamp_resolution_allowed": False,
        "all_unlisted_adapter_paths_protected": True,
    }
    for field, expected in expected_scalars.items():
        if policy.get(field) != expected:
            fail(f"policy.{field} must be {expected!r}")
    if policy.get("automation_metadata_paths") != [".syncweaver-lock.json"]:
        fail("policy.automation_metadata_paths must contain only .syncweaver-lock.json")

    conditions = policy.get("stop_conditions")
    if not isinstance(conditions, list):
        fail("policy.stop_conditions must be an array")
    condition_ids = [item.get("id") for item in conditions if isinstance(item, dict)]
    if len(condition_ids) != len(conditions) or len(condition_ids) != len(set(condition_ids)):
        fail("policy.stop_conditions must contain uniquely identified objects")
    if set(condition_ids) != REQUIRED_STOP_CONDITIONS:
        fail("policy.stop_conditions do not match the required safety set")
    for condition in conditions:
        if not isinstance(condition.get("description"), str) or not condition["description"]:
            fail(f"stop condition {condition.get('id')!r} lacks a description")

    check_sets = (
        ("required_pre_sync_checks", REQUIRED_PRE_CHECKS),
        ("required_post_sync_checks", REQUIRED_POST_CHECKS),
        ("external_release_gates", REQUIRED_EXTERNAL_GATES),
    )
    for field, required in check_sets:
        actual = set(require_unique_strings(policy.get(field), f"policy.{field}"))
        if actual != required:
            fail(f"policy.{field} does not match the required gate set")


def validate_adapter_record(record: Any, root: Path) -> None:
    if not isinstance(record, dict):
        fail("each adapters entry must be an object")
    adapter_id = record.get("id")
    if not isinstance(adapter_id, str) or not adapter_id.startswith("OMIX-"):
        fail("adapter id must start with OMIX-")

    canonical = record.get("canonical")
    adapter = record.get("adapter")
    mappings = record.get("mappings")
    if not isinstance(canonical, dict) or not isinstance(adapter, dict):
        fail(f"{adapter_id}: canonical and adapter must be objects")
    if not isinstance(mappings, list) or not mappings:
        fail(f"{adapter_id}: mappings must be a non-empty array")

    module_path = require_relative_path(canonical.get("module_path"), f"{adapter_id}.canonical.module_path")
    source_root = require_relative_path(canonical.get("source_root"), f"{adapter_id}.canonical.source_root")
    schema_path = require_relative_path(canonical.get("schema_path"), f"{adapter_id}.canonical.schema_path")
    source_commit = canonical.get("source_commit")
    version = canonical.get("module_version")
    interface_version = canonical.get("interface_version")
    if not isinstance(source_commit, str) or not SHA_PATTERN.fullmatch(source_commit):
        fail(f"{adapter_id}: source_commit must be a full lowercase Git SHA")
    if not isinstance(version, str) or not SEMVER_PATTERN.fullmatch(version):
        fail(f"{adapter_id}: module_version must be semantic X.Y.Z")
    if not isinstance(interface_version, int) or isinstance(interface_version, bool) or interface_version < 1:
        fail(f"{adapter_id}: interface_version must be a positive integer")
    if source_root != module_path / "R":
        fail(f"{adapter_id}: source_root must be the canonical module R directory")
    if schema_path != module_path / "schemas" / "interface.yml":
        fail(f"{adapter_id}: schema_path must name the canonical interface schema")

    run_git(root, "cat-file", "-e", f"{source_commit}^{{commit}}")
    run_git(root, "merge-base", "--is-ancestor", source_commit, "HEAD")
    manifest_path = f"{module_path}/module.yml"
    manifest_text = git_blob(root, source_commit, manifest_path).decode("utf-8")
    recorded_version, recorded_interface = parse_module_manifest(manifest_text, adapter_id)
    if recorded_version != version or recorded_interface != interface_version:
        fail(f"{adapter_id}: declared versions disagree with module.yml at source_commit")
    git_blob(root, source_commit, str(schema_path))

    repository = adapter.get("repository")
    baseline_commit = adapter.get("baseline_commit")
    destination_root = require_relative_path(
        adapter.get("managed_destination_root"),
        f"{adapter_id}.adapter.managed_destination_root",
    )
    source_record = require_relative_path(
        adapter.get("source_record_path"), f"{adapter_id}.adapter.source_record_path"
    )
    lock_path = require_relative_path(
        adapter.get("generated_lock_path"), f"{adapter_id}.adapter.generated_lock_path"
    )
    if not isinstance(repository, str) or not repository.startswith("https://github.com/"):
        fail(f"{adapter_id}: adapter repository must be a GitHub HTTPS URL")
    if not isinstance(baseline_commit, str) or not SHA_PATTERN.fullmatch(baseline_commit):
        fail(f"{adapter_id}: baseline_commit must be a full lowercase Git SHA")
    if destination_root != PurePosixPath("code/functions"):
        fail(f"{adapter_id}: managed destination root must be code/functions")
    if source_record != PurePosixPath("OMIX_MODULE_SOURCE.md"):
        fail(f"{adapter_id}: source record must be OMIX_MODULE_SOURCE.md")
    if lock_path != PurePosixPath(".syncweaver-lock.json"):
        fail(f"{adapter_id}: generated lock path must be .syncweaver-lock.json")

    source_paths: set[str] = set()
    destination_paths: set[str] = set()
    for mapping in mappings:
        if not isinstance(mapping, dict):
            fail(f"{adapter_id}: every mapping must be an object")
        source_path = str(require_relative_path(mapping.get("source_path"), f"{adapter_id}.source_path"))
        destination_path = str(require_relative_path(mapping.get("destination_path"), f"{adapter_id}.destination_path"))
        source_hash = mapping.get("source_sha256")
        destination_hash = mapping.get("expected_destination_sha256")
        if not source_path.startswith(f"{source_root}/"):
            fail(f"{adapter_id}: source path escapes source_root: {source_path}")
        if not destination_path.startswith(f"{destination_root}/"):
            fail(f"{adapter_id}: destination path escapes managed_destination_root: {destination_path}")
        if source_path in source_paths or destination_path in destination_paths:
            fail(f"{adapter_id}: mapping paths must be unique")
        source_paths.add(source_path)
        destination_paths.add(destination_path)
        if not isinstance(source_hash, str) or not SHA256_PATTERN.fullmatch(source_hash):
            fail(f"{adapter_id}: source_sha256 is invalid for {source_path}")
        if not isinstance(destination_hash, str) or not SHA256_PATTERN.fullmatch(destination_hash):
            fail(f"{adapter_id}: expected_destination_sha256 is invalid for {destination_path}")
        actual_source_hash = sha256_bytes(git_blob(root, source_commit, source_path))
        if actual_source_hash != source_hash:
            fail(f"{adapter_id}: canonical hash mismatch for {source_path}")
        if destination_hash != source_hash:
            fail(f"{adapter_id}: baseline destination hash must equal canonical source hash")

    canonical_tree = git_tree_files(root, source_commit, str(source_root))
    if canonical_tree != source_paths:
        fail(
            f"{adapter_id}: mapping is not the complete canonical R tree; "
            f"missing={sorted(canonical_tree - source_paths)}, extra={sorted(source_paths - canonical_tree)}"
        )

    exclusions = require_unique_strings(
        record.get("platform_owned_exclusion_paths"),
        f"{adapter_id}.platform_owned_exclusion_paths",
    )
    if any(path in exclusions for path in destination_paths):
        fail(f"{adapter_id}: a managed destination is also platform-owned")
    if str(lock_path) in exclusions:
        fail(f"{adapter_id}: generated lock path cannot be platform-owned")

    tests = record.get("test_commands")
    if not isinstance(tests, dict):
        fail(f"{adapter_id}: test_commands must be an object")
    require_unique_strings(tests.get("canonical"), f"{adapter_id}.test_commands.canonical")
    require_unique_strings(tests.get("adapter"), f"{adapter_id}.test_commands.adapter")


def validate_contract(contract: Any, root: Path = ROOT) -> None:
    if not isinstance(contract, dict):
        fail("contract must be an object")
    if contract.get("schema_version") != "1.0.0":
        fail("schema_version must be 1.0.0")
    if contract.get("contract_kind") != "omix-syncweaver-transition-preparation":
        fail("contract_kind is not the OMIX transition-preparation contract")
    if contract.get("status") != "preparation_only":
        fail("status must remain preparation_only")
    if contract.get("work_item") != "https://github.com/NIDAP-Community/OMIX/issues/44":
        fail("work_item must be OMIX issue #44")
    preparation_commit = contract.get("preparation_commit")
    if not isinstance(preparation_commit, str) or not SHA_PATTERN.fullmatch(preparation_commit):
        fail("preparation_commit must be a full lowercase Git SHA")
    run_git(root, "cat-file", "-e", f"{preparation_commit}^{{commit}}")
    run_git(root, "merge-base", "--is-ancestor", preparation_commit, "HEAD")
    validate_policy(contract.get("policy"))

    adapters = contract.get("adapters")
    if not isinstance(adapters, list) or not adapters:
        fail("adapters must be a non-empty array")
    ids = [record.get("id") for record in adapters if isinstance(record, dict)]
    repositories = [
        record.get("adapter", {}).get("repository")
        for record in adapters
        if isinstance(record, dict)
    ]
    if len(ids) != len(adapters) or len(ids) != len(set(ids)):
        fail("adapter ids must be unique")
    if len(repositories) != len(adapters) or len(repositories) != len(set(repositories)):
        fail("adapter repositories must be unique")
    for record in adapters:
        validate_adapter_record(record, root)


def normalize_remote(value: str) -> str:
    return value.removesuffix(".git").rstrip("/")


def validate_source_record(record: dict[str, Any], checkout: Path) -> None:
    adapter_id = record["id"]
    source_record = checkout / record["adapter"]["source_record_path"]
    if not source_record.is_file():
        fail(f"{adapter_id}: missing {source_record.relative_to(checkout)}")
    text = source_record.read_text(encoding="utf-8")
    expected_tokens = {
        record["canonical"]["source_commit"],
        record["canonical"]["module_version"],
        str(record["canonical"]["interface_version"]),
    }
    for mapping in record["mappings"]:
        expected_tokens.update(
            {
                PurePosixPath(mapping["source_path"]).name,
                mapping["destination_path"],
                mapping["source_sha256"],
            }
        )
    missing = sorted(token for token in expected_tokens if token not in text)
    if missing:
        fail(f"{adapter_id}: source record lacks pinned evidence: {missing}")


def validate_adapter_checkout(record: dict[str, Any], checkout: Path) -> None:
    adapter_id = record["id"]
    if not checkout.is_dir():
        fail(f"{adapter_id}: adapter checkout does not exist: {checkout}")
    actual_head = git_text(checkout, "rev-parse", "HEAD")
    expected_head = record["adapter"]["baseline_commit"]
    if actual_head != expected_head:
        fail(f"{adapter_id}: expected adapter HEAD {expected_head}, found {actual_head}")
    if git_text(checkout, "status", "--porcelain", "--untracked-files=all"):
        fail(f"{adapter_id}: adapter checkout is dirty")
    branch = git_text(checkout, "branch", "--show-current")
    if branch and branch != record["adapter"]["default_branch"]:
        fail(f"{adapter_id}: expected branch {record['adapter']['default_branch']}, found {branch}")
    remote = normalize_remote(git_text(checkout, "remote", "get-url", "origin"))
    expected_remote = normalize_remote(record["adapter"]["repository"])
    if remote != expected_remote:
        fail(f"{adapter_id}: origin does not match the declared adapter repository")

    destination_root = checkout / record["adapter"]["managed_destination_root"]
    expected_paths = {mapping["destination_path"] for mapping in record["mappings"]}
    actual_paths: set[str] = set()
    if destination_root.is_dir():
        for path in destination_root.rglob("*"):
            if path.is_symlink():
                fail(f"{adapter_id}: managed tree contains a symlink: {path.relative_to(checkout)}")
            if path.is_file():
                actual_paths.add(path.relative_to(checkout).as_posix())
    if actual_paths != expected_paths:
        fail(
            f"{adapter_id}: adapter managed tree differs from mapping; "
            f"missing={sorted(expected_paths - actual_paths)}, extra={sorted(actual_paths - expected_paths)}"
        )
    for mapping in record["mappings"]:
        actual_hash = sha256_path(checkout / mapping["destination_path"])
        if actual_hash != mapping["expected_destination_sha256"]:
            fail(f"{adapter_id}: destination hash mismatch for {mapping['destination_path']}")
    validate_source_record(record, checkout)


def parse_adapter_roots(values: list[str]) -> dict[str, Path]:
    roots: dict[str, Path] = {}
    for value in values:
        adapter_id, separator, raw_path = value.partition("=")
        if not separator or not adapter_id or not raw_path:
            fail("--adapter-root must use ID=/absolute/or/relative/path")
        if adapter_id in roots:
            fail(f"duplicate --adapter-root for {adapter_id}")
        roots[adapter_id] = Path(raw_path).expanduser().resolve()
    return roots


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--contract", type=Path, default=CONTRACT_PATH)
    parser.add_argument(
        "--adapter-root",
        action="append",
        default=[],
        metavar="ID=PATH",
        help="Validate one pinned adapter checkout; repeat for multiple adapters.",
    )
    parser.add_argument(
        "--require-all-adapters",
        action="store_true",
        help="Fail unless a local checkout is supplied for every adapter record.",
    )
    args = parser.parse_args()

    contract = json.loads(args.contract.read_text(encoding="utf-8"))
    validate_contract(contract, ROOT)
    records = {record["id"]: record for record in contract["adapters"]}
    roots = parse_adapter_roots(args.adapter_root)
    unknown = sorted(set(roots) - set(records))
    if unknown:
        fail(f"unknown adapter root ids: {unknown}")
    if args.require_all_adapters and set(roots) != set(records):
        fail(f"missing adapter roots: {sorted(set(records) - set(roots))}")
    for adapter_id, checkout in roots.items():
        validate_adapter_checkout(records[adapter_id], checkout)

    print(
        "Syncweaver transition preparation contract passed: "
        f"{len(records)} mappings, {len(roots)} local adapter baselines verified"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ContractError, json.JSONDecodeError, OSError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(2)
