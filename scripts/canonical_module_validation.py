#!/usr/bin/env python3
"""Plan and report portable canonical-module validation runs.

The GitHub workflow deliberately delegates module-specific commands to a
small, committed JSON manifest under ``modules/<name>/tests``.  This helper
keeps the shared workflow generic while recording the exact module, runtime,
commands, and output artifacts used for each run.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shlex
import stat
import subprocess
import sys
from pathlib import Path
from typing import Any


MANIFEST_NAME = "validation.json"
MODULE_NAME_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]*")
SHARED_VALIDATION_PATHS = {
    "scripts/canonical_module_validation.py",
    ".github/workflows/validate-canonical-module.yml",
    "tests/test_canonical_module_validation.py",
}
SHARED_VALIDATION_PREFIXES = ("templates/canonical-module-validation/",)


def abort(message: str) -> None:
    """Exit with one actionable validation error."""
    raise SystemExit(f"ERROR: {message}")


def repo_root() -> Path:
    """Resolve the repository root from this script, not the caller's CWD."""
    return Path(__file__).resolve().parents[1]


def module_directory(root: Path, module: str) -> Path:
    """Return a safe canonical-module directory for one public module name."""
    if not MODULE_NAME_PATTERN.fullmatch(module):
        abort(f"Invalid module name: {module}")
    directory = root / "modules" / module
    if not (directory / "module.yml").is_file():
        abort(f"No canonical module metadata found for {module}: {directory / 'module.yml'}")
    return directory


def read_runtime_profile(module_yml: Path) -> str:
    """Read the simple scalar runtime_profile field from module metadata."""
    matches = re.findall(r"^runtime_profile:\s*([^\s#]+)\s*$", module_yml.read_text(), re.MULTILINE)
    if len(matches) != 1:
        abort(f"{module_yml} must declare exactly one scalar runtime_profile")
    return matches[0]


def read_json(path: Path) -> dict[str, Any]:
    """Read a JSON object with a clear path-specific error."""
    try:
        value = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as error:
        abort(f"Could not read JSON from {path}: {error}")
    if not isinstance(value, dict):
        abort(f"{path} must contain a JSON object")
    return value


def relative_artifact(path: str) -> str:
    """Reject artifacts that could escape the workflow-owned output directory."""
    candidate = Path(path)
    if candidate.is_absolute() or ".." in candidate.parts or path in {"", "."}:
        abort(f"Artifact paths must be non-empty relative paths: {path!r}")
    return candidate.as_posix()


def fixture_identity(root: Path, path: str) -> dict[str, Any]:
    """Identify one committed fixture file without allowing a path escape."""
    relative = relative_artifact(path)
    fixture = root / relative
    if not fixture.is_file():
        abort(f"Fixture inputs must name committed files: {fixture}")
    return {"path": relative, "sha256": sha256(fixture), "bytes": fixture.stat().st_size}


def checked_out_commit(root: Path) -> str:
    """Record the repository commit that supplied the tested module and fixture."""
    result = subprocess.run(
        ["git", "rev-parse", "HEAD"],
        cwd=root,
        text=True,
        check=True,
        capture_output=True,
    )
    return result.stdout.strip()


def validation_plan(root: Path, module: str) -> dict[str, Any]:
    """Validate one module manifest and expand it into a runtime-bound plan."""
    directory = module_directory(root, module)
    manifest_path = directory / "tests" / MANIFEST_NAME
    if not manifest_path.is_file():
        abort(f"{module} has no opt-in validation manifest: {manifest_path}")
    manifest = read_json(manifest_path)
    required = {
        "schema_version", "module", "runtime_profile", "test_commands",
        "fixture_command", "fixture_inputs", "expected_artifacts",
    }
    missing = sorted(required - set(manifest))
    if missing:
        abort(f"{manifest_path} is missing required field(s): {', '.join(missing)}")
    if manifest["schema_version"] != 1:
        abort(f"{manifest_path} must use schema_version 1")
    if manifest["module"] != module:
        abort(f"{manifest_path} names {manifest['module']!r}; expected {module!r}")

    profile = read_runtime_profile(directory / "module.yml")
    if manifest["runtime_profile"] != profile:
        abort(f"{manifest_path} runtime_profile does not match module.yml ({profile})")
    if not isinstance(manifest["test_commands"], list) or not manifest["test_commands"]:
        abort(f"{manifest_path} test_commands must be a non-empty list")
    if not all(isinstance(command, str) and command.strip() for command in manifest["test_commands"]):
        abort(f"{manifest_path} test_commands must contain non-empty strings")
    if not isinstance(manifest["fixture_command"], str) or not manifest["fixture_command"].strip():
        abort(f"{manifest_path} fixture_command must be a non-empty string")
    if not isinstance(manifest["fixture_inputs"], list) or not manifest["fixture_inputs"]:
        abort(f"{manifest_path} fixture_inputs must be a non-empty list")
    if not all(isinstance(path, str) and path.strip() for path in manifest["fixture_inputs"]):
        abort(f"{manifest_path} fixture_inputs must contain non-empty relative file paths")
    if not isinstance(manifest["expected_artifacts"], list) or not manifest["expected_artifacts"]:
        abort(f"{manifest_path} expected_artifacts must be a non-empty list")
    artifacts = [relative_artifact(item) for item in manifest["expected_artifacts"]]
    inputs = [fixture_identity(root, item) for item in manifest["fixture_inputs"]]

    release_manifest = read_json(root / "starter-environments" / "release-manifest.json")
    image = release_manifest.get("images", {}).get(profile, {})
    reference = image.get("immutable_reference")
    if not isinstance(reference, str) or "@sha256:" not in reference:
        abort(f"No immutable runtime reference is recorded for profile {profile}")

    return {
        "schema_version": 1,
        "module": module,
        "module_directory": f"modules/{module}",
        "omix_commit": checked_out_commit(root),
        "runtime_profile": profile,
        "runtime_immutable_reference": reference,
        "test_commands": manifest["test_commands"],
        "fixture_command": manifest["fixture_command"],
        "fixture_inputs": inputs,
        "expected_artifacts": artifacts,
        "known_result_evidence": manifest.get("known_result_evidence", []),
    }


def write_json(path: Path, value: dict[str, Any]) -> None:
    """Write durable JSON without relying on a caller-specific working directory."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def sha256(path: Path) -> str:
    """Calculate a file digest in bounded chunks."""
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def plan_command(arguments: argparse.Namespace) -> None:
    plan = validation_plan(repo_root(), arguments.module)
    if arguments.output:
        write_json(Path(arguments.output), plan)
    if arguments.image_only:
        print(plan["runtime_immutable_reference"])
    elif not arguments.output:
        print(json.dumps(plan, sort_keys=True))


def runner_command(arguments: argparse.Namespace) -> None:
    plan = read_json(Path(arguments.plan))
    runner = Path(arguments.output)
    lines = [
        "#!/usr/bin/env bash",
        "# Generated from a committed module validation manifest; do not edit.",
        "set -euo pipefail",
        "cd /workspace",
        "mkdir -p /artifacts",
        "",
        "# Direct tests establish the module's declared contract before the fixture run.",
    ]
    lines.extend(plan["test_commands"])
    lines.extend([
        "",
        "# The fixture run leaves reviewable outputs in the artifact directory.",
        plan["fixture_command"],
        "",
        "# Fail clearly if the module did not produce every declared review artifact.",
    ])
    lines.extend(f"test -e {shlex.quote('/artifacts/' + artifact)}" for artifact in plan["expected_artifacts"])
    runner.parent.mkdir(parents=True, exist_ok=True)
    runner.write_text("\n".join(lines) + "\n")
    runner.chmod(runner.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def report_command(arguments: argparse.Namespace) -> None:
    plan = read_json(Path(arguments.plan))
    artifact_dir = Path(arguments.artifact_directory)
    reported: list[dict[str, Any]] = []
    for relative in plan["expected_artifacts"]:
        path = artifact_dir / relative
        if not path.exists():
            abort(f"Expected artifact was not produced: {path}")
        if path.is_file():
            reported.append({"path": relative, "kind": "file", "sha256": sha256(path), "bytes": path.stat().st_size})
        elif path.is_dir():
            reported.append({
                "path": relative,
                "kind": "directory",
                "file_count": sum(1 for child in path.rglob("*") if child.is_file()),
            })
        else:
            abort(f"Expected artifact is neither a file nor directory: {path}")
    report = {"validation_plan": plan, "artifacts": reported}
    write_json(artifact_dir / "validation-report.json", report)


def modules_for_changed_paths(root: Path, changed_paths: list[str]) -> list[str]:
    """Select all opt-ins for shared-runner changes, otherwise changed modules only."""
    modules_root = root / "modules"
    shared_change = any(
        path in SHARED_VALIDATION_PATHS or path.startswith(SHARED_VALIDATION_PREFIXES)
        for path in changed_paths
    )
    if shared_change:
        candidates = (entry.name for entry in modules_root.iterdir() if entry.is_dir())
    else:
        candidates = (
            path.split("/")[1]
            for path in changed_paths
            if path.startswith("modules/") and len(path.split("/")) > 2
        )
    return sorted({module for module in candidates if MODULE_NAME_PATTERN.fullmatch(module)})


def discover_command(arguments: argparse.Namespace) -> None:
    root = repo_root()
    modules_root = root / "modules"
    if arguments.module:
        requested = [entry.name for entry in modules_root.iterdir() if entry.is_dir()] if arguments.module == "all" else [arguments.module]
    else:
        result = subprocess.run(
            ["git", "diff", "--name-only", f"{arguments.base}...{arguments.head}"],
            cwd=root,
            text=True,
            check=True,
            capture_output=True,
        )
        requested = modules_for_changed_paths(root, result.stdout.splitlines())
    included = []
    for module in sorted(requested):
        if not MODULE_NAME_PATTERN.fullmatch(module):
            if arguments.module and arguments.module != "all":
                abort(f"Invalid module name: {module}")
            continue
        directory = modules_root / module
        if (directory / "module.yml").is_file() and (directory / "tests" / MANIFEST_NAME).is_file():
            included.append({"module": module})
        elif arguments.module and arguments.module != "all":
            abort(f"{module} has no opt-in validation manifest")
    print(json.dumps({"include": included}, separators=(",", ":")))


def parser() -> argparse.ArgumentParser:
    command_parser = argparse.ArgumentParser(description=__doc__)
    commands = command_parser.add_subparsers(dest="command", required=True)

    plan = commands.add_parser("plan", help="validate one manifest and emit its runtime-bound plan")
    plan.add_argument("--module", required=True)
    plan.add_argument("--output")
    plan.add_argument("--image-only", action="store_true")
    plan.set_defaults(handler=plan_command)

    runner = commands.add_parser("write-runner", help="write a container runner from a validation plan")
    runner.add_argument("--plan", required=True)
    runner.add_argument("--output", required=True)
    runner.set_defaults(handler=runner_command)

    report = commands.add_parser("report", help="write an artifact/provenance report after a successful run")
    report.add_argument("--plan", required=True)
    report.add_argument("--artifact-directory", required=True)
    report.set_defaults(handler=report_command)

    discover = commands.add_parser("discover", help="list changed modules that opt into validation")
    discover.add_argument("--base")
    discover.add_argument("--head")
    discover.add_argument("--module", help="one module name, or all, for workflow_dispatch")
    discover.set_defaults(handler=discover_command)
    return command_parser


def main() -> None:
    arguments = parser().parse_args()
    if arguments.command == "discover" and not arguments.module and (not arguments.base or not arguments.head):
        abort("discover requires --module, or both --base and --head")
    arguments.handler(arguments)


if __name__ == "__main__":
    main()
