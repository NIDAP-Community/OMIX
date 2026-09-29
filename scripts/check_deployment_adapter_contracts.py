#!/usr/bin/env python3
"""Audit canonical OMIX contracts against pinned deployment adapters.

The deployment inventory is the evidence ledger.  This checker does not
promote or rewrite any of its states; it independently recomputes structural
contract findings at the exact canonical and adapter commits recorded there.
"""

from __future__ import annotations

import argparse
import base64
import difflib
import hashlib
import json
import math
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
if str(Path(__file__).resolve().parent) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
import check_deployment_adapter_inventory as inventory_checker  # noqa: E402
INVENTORY_PATH = ROOT / "docs" / "deployment-adapter-inventory.json"
REPORT_JSON_PATH = ROOT / "docs" / "deployment-adapter-contract-report.json"
REPORT_MD_PATH = ROOT / "docs" / "deployment-adapter-contract-report.md"
STATUS_VOCABULARY = {
    "verified",
    "outdated",
    "partial",
    "pending",
    "unknown",
    "blocked",
    "not_applicable",
}
INVENTORY_STATE_PATHS = (
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


class AuditError(RuntimeError):
    """Raised when evidence cannot be parsed without guessing."""


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def nested(record: dict[str, Any], dotted: str) -> Any:
    value: Any = record
    for component in dotted.split("."):
        value = value[component]
    return value


def repository_slug(url: str) -> str:
    match = re.fullmatch(r"https://github\.com/([^/]+/[^/]+?)(?:\.git)?/?", url)
    if not match:
        raise AuditError(f"Unsupported GitHub repository URL: {url}")
    return match.group(1)


@dataclass(frozen=True)
class Control:
    name: str
    cli: str
    type: str | None
    default: Any
    allowed: tuple[Any, ...]
    item_allowed: tuple[Any, ...]
    classification: str | None
    delimiter: str | None = None
    preserves_order: bool = False

    def as_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "cli": self.cli,
            "type": self.type,
            "default": json_value(self.default),
            "allowed": list(self.allowed),
            "item_allowed": list(self.item_allowed),
            "classification": self.classification,
            "delimiter": self.delimiter,
            "preserves_order": self.preserves_order,
        }


@dataclass(frozen=True)
class ROption:
    name: str
    type: str | None
    default: Any
    order: int

    def as_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "type": self.type,
            "default": json_value(self.default),
            "order": self.order,
        }


@dataclass(frozen=True)
class PanelControl:
    name: str | None
    type: str | None
    default: Any
    allowed: tuple[Any, ...]
    order: int

    def as_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "type": self.type,
            "default": json_value(self.default),
            "allowed": list(self.allowed),
            "order": self.order,
        }


class GitHubContentSource:
    """Read files from public GitHub repositories at immutable refs."""

    def __init__(self) -> None:
        self._cache: dict[tuple[str, str, str], bytes] = {}

    def get(self, slug: str, path: str, ref: str) -> bytes:
        key = (slug, path, ref)
        if key in self._cache:
            return self._cache[key]
        api_path = f"repos/{slug}/contents/{path}?ref={ref}"
        raw: bytes
        gh = shutil.which("gh")
        if gh:
            result = subprocess.run(
                [gh, "api", api_path], capture_output=True, check=False
            )
            if result.returncode == 0:
                raw = result.stdout
            else:
                raw = self._urllib_get(api_path)
        else:
            raw = self._urllib_get(api_path)
        try:
            payload = json.loads(raw)
            value = base64.b64decode(payload["content"])
        except (KeyError, ValueError, TypeError) as error:
            raise AuditError(f"Malformed GitHub content response for {api_path}") from error
        self._cache[key] = value
        return value

    @staticmethod
    def _urllib_get(api_path: str) -> bytes:
        request = urllib.request.Request(
            f"https://api.github.com/{api_path}",
            headers={
                "Accept": "application/vnd.github+json",
                "User-Agent": "omix-adapter-contract-audit",
                **(
                    {"Authorization": f"Bearer {os.environ['GITHUB_TOKEN']}"}
                    if os.environ.get("GITHUB_TOKEN")
                    else {}
                ),
            },
        )
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read()
        except urllib.error.URLError as error:
            raise AuditError(f"GitHub read failed for {api_path}: {error}") from error


class DirectoryContentSource:
    """Read an adapter fixture stored as <root>/<repository>/<ref>/<path>."""

    def __init__(self, root: Path) -> None:
        self.root = root

    def get(self, slug: str, path: str, ref: str) -> bytes:
        candidate = self.root / slug.replace("/", "__") / ref / path
        try:
            return candidate.read_bytes()
        except FileNotFoundError as error:
            raise AuditError(f"Missing adapter fixture: {candidate}") from error


def load_yaml(path: Path) -> dict[str, Any]:
    """Load YAML through the R dependencies committed for OMIX validation."""
    expression = (
        "x <- yaml::read_yaml(commandArgs(TRUE)[[1]]); "
        "cat(jsonlite::toJSON(x, auto_unbox=TRUE, null='null', digits=NA))"
    )
    result = subprocess.run(
        ["Rscript", "--vanilla", "-e", expression, str(path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode:
        raise AuditError(f"Could not parse {path}: {result.stderr.strip()}")
    value = json.loads(result.stdout)
    if not isinstance(value, dict):
        raise AuditError(f"YAML root must be an object: {path}")
    return value


def flatten_schema_controls(schema: dict[str, Any]) -> list[Control]:
    controls: list[Control] = []

    def visit(value: Any, fallback_name: str | None = None) -> None:
        if not isinstance(value, dict):
            return
        if "type" in value and fallback_name:
            cli = str(value.get("cli") or f"--{fallback_name}").removeprefix("--")
            allowed = value.get("allowed", [])
            if allowed is None:
                allowed = []
            if not isinstance(allowed, list):
                allowed = [allowed]
            item_allowed = value.get("item_allowed", [])
            if item_allowed is None:
                item_allowed = []
            if not isinstance(item_allowed, list):
                item_allowed = [item_allowed]
            controls.append(
                Control(
                    name=fallback_name,
                    cli=cli,
                    type=value.get("type"),
                    default=value.get("default"),
                    allowed=tuple(allowed),
                    item_allowed=tuple(item_allowed),
                    classification=value.get("classification"),
                    delimiter=value.get("delimiter"),
                    preserves_order=bool(value.get("preserves_order", False)),
                )
            )
            return
        for key, child in value.items():
            if key in {"required_when", "description"}:
                continue
            visit(child, key)

    visit(schema.get("inputs", {}))
    for section in ("parameters", "internal_controls"):
        for name, value in (schema.get(section, {}) or {}).items():
            visit(value, name)
    duplicate_cli = sorted(
        cli for cli in {item.cli for item in controls}
        if sum(item.cli == cli for item in controls) > 1
    )
    if duplicate_cli:
        raise AuditError(f"Duplicate schema CLI names: {duplicate_cli}")
    return controls


def schema_internal_bindings(schema: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {
        name: value
        for name, value in (schema.get("internal_controls", {}) or {}).items()
        if isinstance(value, dict)
    }


def balanced_calls(text: str, function: str) -> list[str]:
    """Extract balanced function calls while respecting quoted R strings."""
    calls: list[str] = []
    needle = function + "("
    start = 0
    while True:
        index = text.find(needle, start)
        if index < 0:
            return calls
        depth = 0
        quote: str | None = None
        escaped = False
        end = index
        for end in range(index + len(function), len(text)):
            char = text[end]
            if quote:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == quote:
                    quote = None
                continue
            if char in {"'", '"'}:
                quote = char
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    calls.append(text[index:end + 1])
                    start = end + 1
                    break
        else:
            raise AuditError(f"Unbalanced {function} call near byte {index}")


def parse_r_literal(value: str | None) -> Any:
    if value is None:
        return None
    value = value.strip()
    if re.fullmatch(r"[-+]?\d+[Ll]", value):
        value = value[:-1]
    if value in {"NULL", "NA", "NA_character_"}:
        return None
    if value in {"TRUE", "T"}:
        return True
    if value in {"FALSE", "F"}:
        return False
    if value in {"Inf", ".inf"}:
        return math.inf
    if value in {"-Inf", "-.inf"}:
        return -math.inf
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
        return bytes(value[1:-1], "utf-8").decode("unicode_escape")
    if re.fullmatch(r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][-+]?\d+)?", value):
        number = float(value)
        return int(number) if number.is_integer() else number
    return {"unparsed_r_expression": value}


def named_argument(call: str, name: str) -> str | None:
    match = re.search(
        rf"(?:^|,)\s*{re.escape(name)}\s*=\s*("
        r"(?:'(?:\\.|[^'])*'|\"(?:\\.|[^\"])*\"|[^,)]+))",
        call,
        flags=re.DOTALL,
    )
    return match.group(1).strip() if match else None


def parse_r_options(text: str) -> list[ROption]:
    options: list[ROption] = []
    for call in balanced_calls(text, "make_option"):
        name_match = re.search(r"['\"]--([A-Za-z0-9_]+)['\"]", call)
        if not name_match:
            continue
        option_type = parse_r_literal(named_argument(call, "type"))
        default = parse_r_literal(named_argument(call, "default"))
        options.append(
            ROption(
                name=name_match.group(1),
                type=option_type if isinstance(option_type, str) else None,
                default=default,
                order=len(options),
            )
        )
    names = [item.name for item in options]
    duplicates = sorted({name for name in names if names.count(name) > 1})
    if duplicates:
        raise AuditError(f"Duplicate R CLI options: {duplicates}")
    return options


def parse_panel(text: str) -> tuple[bool, list[PanelControl]]:
    panel = json.loads(text)
    parameters = panel.get("parameters", [])
    if not isinstance(parameters, list):
        raise AuditError("App Panel parameters must be an array")
    controls = []
    for order, value in enumerate(parameters):
        controls.append(
            PanelControl(
                name=value.get("param_name"),
                type=value.get("type"),
                default=value.get("default_value"),
                allowed=tuple(value.get("extra_data") or []),
                order=order,
            )
        )
    return bool(panel.get("named_parameters", False)), controls


def parse_source_record_exceptions(text: str) -> dict[str, Any]:
    """Read explicit machine-readable exceptions; prose never grants one."""
    matches = re.findall(
        r"<!--\s*omix-adapter-contract\s*:\s*(\{.*?\})\s*-->",
        text,
        flags=re.DOTALL,
    )
    aliases: dict[str, str] = {}
    hidden: dict[str, dict[str, Any]] = {}
    for raw in matches:
        try:
            value = json.loads(raw)
        except json.JSONDecodeError as error:
            raise AuditError("Invalid omix-adapter-contract JSON marker") from error
        for canonical, adapter in (value.get("aliases") or {}).items():
            aliases[str(canonical)] = str(adapter)
        for item in value.get("hidden_inputs", []) or []:
            if not isinstance(item, dict) or not item.get("canonical"):
                raise AuditError("Hidden input exceptions require canonical and binding fields")
            if not item.get("binding"):
                raise AuditError("Hidden input exceptions require a non-empty binding")
            hidden[str(item["canonical"])] = item
    return {"aliases": aliases, "hidden_inputs": hidden}


def parse_source_record_metadata(text: str) -> dict[str, Any]:
    commit = re.search(r"Canonical source reference:\*\*\s*\[`([0-9a-f]{40})`\]", text)
    version = re.search(r"Canonical module version:\*\*\s*`([^`]+)`", text)
    interface = re.search(r"Canonical interface version:\*\*\s*`([0-9]+)`", text)
    return {
        "canonical_source_commit": commit.group(1) if commit else None,
        "module_version": version.group(1) if version else None,
        "interface_version": int(interface.group(1)) if interface else None,
        "has_per_file_sha256": bool(re.search(r"\b[0-9a-f]{64}\b", text)),
    }


def json_value(value: Any) -> Any:
    if isinstance(value, float) and math.isinf(value):
        return "Inf" if value > 0 else "-Inf"
    return value


def comparable(value: Any) -> tuple[str, Any]:
    if isinstance(value, dict) and "unparsed_r_expression" in value:
        return ("expression", value["unparsed_r_expression"])
    if value is None or value == "":
        return ("empty", None)
    if isinstance(value, bool):
        return ("boolean", value)
    if isinstance(value, (int, float)):
        return ("number", value)
    text = str(value).strip()
    if text.lower() in {"true", "false"}:
        return ("boolean", text.lower() == "true")
    if text.lower() in {"inf", ".inf"}:
        return ("number", math.inf)
    if re.fullmatch(r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)", text):
        return ("number", float(text))
    return ("string", text)


def defaults_equal(left: Any, right: Any) -> bool:
    return comparable(left) == comparable(right)


def normalized_name(name: str) -> str:
    tokens = [token for token in name.strip("_").lower().split("_") if token]
    substitutions = {"file": "table", "counts": "matrix", "count": "matrix"}
    tokens = [substitutions.get(token, token) for token in tokens]
    if tokens and tokens[-1] == "table":
        tokens = tokens[:-1]
    return "_".join(tokens)


def alias_score(canonical: str, adapter: str) -> float:
    left = normalized_name(canonical)
    right = normalized_name(adapter)
    if left == right:
        return 1.0
    if left.startswith(right + "_to_include"):
        return 0.95
    if left.startswith(right + "_of_genes") or adapter.startswith(canonical + "_of_genes"):
        return 0.95
    left_tokens = set(left.split("_"))
    right_tokens = set(right.split("_"))
    token_score = len(left_tokens & right_tokens) / max(len(left_tokens | right_tokens), 1)
    sequence = difflib.SequenceMatcher(a=left, b=right).ratio()
    return max(token_score, sequence)


def expected_r_types(schema_type: str | None) -> set[str]:
    return {
        "path": {"character"},
        "string": {"character"},
        "boolean_or_auto": {"character"},
        # Portable wrappers sometimes accept character booleans so deployment
        # systems can pass TRUE/FALSE consistently; either is contract-safe.
        "boolean": {"logical", "character"},
        "integer": {"integer"},
        "number": {"double", "numeric", "integer"},
    }.get(schema_type, set())


def expected_panel_types(control: Control) -> set[str]:
    if control.type == "path":
        return {"file"}
    # Code Ocean serializes both list selections and free text as CLI strings.
    # Path controls are the only case where the UI widget changes the binding
    # semantics, so string/numeric/boolean controls accept either representation.
    return {"list", "text"}


def infer_aliases(
    missing: list[str], extras: list[str], explicit: dict[str, str]
) -> tuple[dict[str, str], list[dict[str, Any]]]:
    aliases = {key: value for key, value in explicit.items() if key in missing and value in extras}
    used = set(aliases.values())
    candidates: list[dict[str, Any]] = []
    for canonical in missing:
        if canonical in aliases:
            continue
        ranked = sorted(
            ((alias_score(canonical, adapter), adapter) for adapter in extras if adapter not in used),
            reverse=True,
        )
        if ranked and ranked[0][0] >= 0.78:
            score, adapter = ranked[0]
            aliases[canonical] = adapter
            used.add(adapter)
            candidates.append(
                {"canonical": canonical, "adapter": adapter, "score": round(score, 3)}
            )
    return aliases, candidates


def add_finding(
    findings: list[dict[str, Any]],
    code: str,
    severity: str,
    message: str,
    control: str | None = None,
    expected: Any = None,
    observed: Any = None,
) -> None:
    item = {"code": code, "severity": severity, "message": message}
    if control is not None:
        item["control"] = control
    if expected is not None:
        item["expected"] = json_value(expected)
    if observed is not None:
        item["observed"] = json_value(observed)
    findings.append(item)


def compare_controls(
    canonical: list[Control],
    canonical_cli: list[ROption],
    adapter_cli: list[ROption],
    named_parameters: bool,
    panel: list[PanelControl],
    exceptions: dict[str, Any],
    internal_bindings: dict[str, dict[str, Any]] | None = None,
) -> tuple[list[dict[str, Any]], dict[str, str], list[dict[str, Any]]]:
    findings: list[dict[str, Any]] = []
    schema_by_cli = {item.cli: item for item in canonical}
    canonical_cli_by_name = {item.name: item for item in canonical_cli}
    adapter_by_name = {item.name: item for item in adapter_cli}
    panel_by_name = {item.name: item for item in panel if item.name}

    for control in canonical:
        option = canonical_cli_by_name.get(control.cli)
        if not option:
            add_finding(findings, "canonical_cli_missing", "error", "Schema control is absent from the portable CLI.", control.cli)
            continue
        expected_types = expected_r_types(control.type)
        if expected_types and option.type not in expected_types:
            add_finding(findings, "canonical_cli_type_mismatch", "error", "Portable CLI type is incompatible with the canonical schema.", control.cli, sorted(expected_types), option.type)
        if not defaults_equal(control.default, option.default):
            add_finding(findings, "canonical_cli_default_mismatch", "error", "Schema and portable CLI defaults differ.", control.cli, control.default, option.default)

    for name in sorted(set(canonical_cli_by_name) - set(schema_by_cli)):
        add_finding(findings, "canonical_schema_missing", "error", "Portable CLI control is absent from the canonical schema.", name)

    canonical_names = set(schema_by_cli)
    adapter_names = set(adapter_by_name)
    binding_names = set((internal_bindings or {}).keys())
    missing = sorted(canonical_names - adapter_names)
    extras = sorted(adapter_names - canonical_names - binding_names)
    aliases, candidates = infer_aliases(missing, extras, exceptions["aliases"])
    hidden = exceptions["hidden_inputs"]
    for canonical_name, adapter_name in exceptions["aliases"].items():
        if canonical_name not in canonical_names or adapter_name not in adapter_names:
            add_finding(
                findings,
                "stale_alias_exception",
                "error",
                "Documented alias no longer resolves both a canonical and adapter CLI control.",
                canonical_name,
                canonical_name,
                adapter_name,
            )
    for candidate in candidates:
        add_finding(
            findings,
            "undocumented_alias_candidate",
            "error",
            "A deterministic name match suggests an adapter alias, but the source record does not explicitly authorize it.",
            candidate["canonical"],
            candidate["canonical"],
            candidate["adapter"],
        )

    for control in canonical:
        adapter_name = control.cli if control.cli in adapter_by_name else aliases.get(control.cli)
        if adapter_name is None:
            if control.classification == "internal":
                continue
            if control.cli in hidden:
                continue
            add_finding(findings, "adapter_cli_missing", "error", "Canonical control is absent from the adapter CLI and has no documented hidden binding.", control.cli)
            continue
        option = adapter_by_name[adapter_name]
        if control.classification == "internal":
            # Internal bindings are intentionally adapter-managed. Their
            # presence can be reported, but their platform path/default is not
            # a scientific contract mismatch.
            continue
        expected_types = expected_r_types(control.type)
        if expected_types and option.type not in expected_types:
            add_finding(findings, "adapter_cli_type_mismatch", "error", "Adapter CLI type is incompatible with the canonical schema.", control.cli, sorted(expected_types), option.type)
        if not defaults_equal(control.default, option.default):
            add_finding(findings, "adapter_cli_default_mismatch", "warning", "Adapter CLI default differs from the canonical contract.", control.cli, control.default, option.default)

    alias_values = set(aliases.values())
    for name in sorted(adapter_names - canonical_names - alias_values - binding_names):
        add_finding(findings, "adapter_cli_extra", "warning", "Adapter-only CLI control is not classified by the canonical contract or source-record exceptions.", name)

    if not named_parameters:
        add_finding(findings, "app_panel_unnamed", "error", "App Panel does not enable named parameters; name-level parity cannot be verified.")
    else:
        for control in canonical:
            if control.classification == "internal":
                continue
            adapter_name = control.cli if control.cli in adapter_by_name else aliases.get(control.cli, control.cli)
            panel_control = panel_by_name.get(adapter_name)
            if not panel_control:
                if control.cli in hidden:
                    continue
                add_finding(findings, "app_panel_missing", "error", "Public or advanced canonical control is absent from the App Panel and has no documented hidden binding.", control.cli)
                continue
            expected_types = expected_panel_types(control)
            if panel_control.type not in expected_types:
                add_finding(findings, "app_panel_type_mismatch", "error", "App Panel control type is incompatible with the canonical schema.", control.cli, sorted(expected_types), panel_control.type)
            if not defaults_equal(control.default, panel_control.default):
                add_finding(findings, "app_panel_default_mismatch", "warning", "App Panel default differs from the canonical contract.", control.cli, control.default, panel_control.default)
            if control.allowed and tuple(map(str, control.allowed)) != tuple(map(str, panel_control.allowed)):
                add_finding(findings, "app_panel_choices_mismatch", "warning", "App Panel choices or their order differ from the canonical contract.", control.cli, list(control.allowed), list(panel_control.allowed))
        recognized_panel = set(canonical_names) | alias_values | binding_names
        for name in sorted(set(panel_by_name) - recognized_panel):
            add_finding(findings, "app_panel_extra", "warning", "App Panel exposes a control outside the canonical public/advanced contract.", name)
        for name in sorted(set(panel_by_name) & binding_names):
            add_finding(findings, "app_panel_internal_exposed", "error", "App Panel exposes a canonical internal binding as a user control.", name)

        expected_order = []
        for control in canonical:
            if control.classification == "internal" or control.cli in hidden:
                continue
            expected_order.append(aliases.get(control.cli, control.cli))
        observed_order = [item.name for item in panel if item.name in set(expected_order)]
        comparable_order = [item for item in expected_order if item in set(observed_order)]
        if observed_order != comparable_order:
            add_finding(
                findings,
                "app_panel_order_mismatch",
                "warning",
                "App Panel control order differs from canonical schema order after documented/inferred alias mapping.",
                expected=comparable_order,
                observed=observed_order,
            )

    for name, item in hidden.items():
        if name not in canonical_names:
            add_finding(findings, "stale_hidden_exception", "error", "Source record documents a hidden input that is not in the current canonical schema.", name)
    return findings, aliases, candidates


def git_blob(commit: str, path: str) -> bytes:
    result = subprocess.run(
        ["git", "show", f"{commit}:{path}"],
        cwd=ROOT,
        capture_output=True,
        check=False,
    )
    if result.returncode:
        raise AuditError(f"Cannot read canonical {path} at {commit}: {result.stderr.decode().strip()}")
    return result.stdout


def managed_hash_result(
    adapter_bytes: bytes, current_bytes: bytes, recorded_bytes: bytes
) -> dict[str, Any]:
    result = {
        "recorded_source_sha256": sha256_bytes(recorded_bytes),
        "adapter_sha256": sha256_bytes(adapter_bytes),
        "current_source_sha256": sha256_bytes(current_bytes),
    }
    result["matches_recorded"] = (
        result["adapter_sha256"] == result["recorded_source_sha256"]
    )
    result["matches_current"] = (
        result["adapter_sha256"] == result["current_source_sha256"]
    )
    return result


def preserved_states(adapter: dict[str, Any]) -> dict[str, dict[str, Any]]:
    states = {}
    for path in INVENTORY_STATE_PATHS:
        value = nested(adapter, path)
        if value["status"] not in STATUS_VOCABULARY:
            raise AuditError(f"{adapter['id']}: unsupported inventory status {value['status']}")
        states[path] = {
            "status": value["status"],
            "note": value["note"],
            "evidence": value["evidence"],
        }
    return states


def audit_adapter(adapter: dict[str, Any], source: Any) -> dict[str, Any]:
    canonical = adapter["canonical"]
    deployment = adapter["deployment"]
    slug = repository_slug(deployment["repository"])
    adapter_commit = deployment["default_branch_commit"]
    module_path = ROOT / canonical["module_path"]
    schema = load_yaml(ROOT / canonical["schema_path"])
    controls = flatten_schema_controls(schema)
    internal_bindings = schema_internal_bindings(schema)
    entrypoint = schema.get("entrypoint") or "scripts/run.R"
    canonical_cli_path = module_path / entrypoint
    if not canonical_cli_path.is_file():
        raise AuditError(f"{adapter['id']}: canonical entrypoint does not exist: {canonical_cli_path}")
    canonical_cli = parse_r_options(canonical_cli_path.read_text(encoding="utf-8"))

    adapter_main = source.get(slug, "code/main.R", adapter_commit).decode("utf-8")
    adapter_cli = parse_r_options(adapter_main)
    panel_text = source.get(slug, ".codeocean/app-panel.json", adapter_commit).decode("utf-8")
    named_parameters, panel = parse_panel(panel_text)
    source_record = source.get(slug, "OMIX_MODULE_SOURCE.md", adapter_commit).decode("utf-8")
    exceptions = parse_source_record_exceptions(source_record)
    source_metadata = parse_source_record_metadata(source_record)
    findings, aliases, candidates = compare_controls(
        controls,
        canonical_cli,
        adapter_cli,
        named_parameters,
        panel,
        exceptions,
        internal_bindings,
    )
    expected_source = adapter["scientific_export"]
    for label, expected, observed in (
        ("canonical source commit", expected_source["recorded_source_commit"], source_metadata["canonical_source_commit"]),
        ("module version", str(expected_source["recorded_module_version"]), source_metadata["module_version"]),
        ("interface version", int(expected_source["recorded_interface_version"]), source_metadata["interface_version"]),
    ):
        if expected != observed:
            add_finding(
                findings,
                "source_record_metadata_mismatch",
                "error",
                f"Source-record {label} disagrees with the inventory evidence.",
                expected=expected,
                observed=observed,
            )
    if not source_metadata["has_per_file_sha256"]:
        add_finding(
            findings,
            "source_record_hash_manifest_missing",
            "warning",
            "OMIX_MODULE_SOURCE.md does not record per-file SHA-256 values.",
        )

    managed = []
    for item in adapter["scientific_export"]["managed_files"]:
        adapter_bytes = source.get(slug, item["adapter_path"], adapter_commit)
        current_bytes = (ROOT / item["canonical_path"]).read_bytes()
        recorded_bytes = git_blob(adapter["scientific_export"]["recorded_source_commit"], item["canonical_path"])
        result = {
            "canonical_path": item["canonical_path"],
            "adapter_path": item["adapter_path"],
            **managed_hash_result(adapter_bytes, current_bytes, recorded_bytes),
        }
        for field in ("recorded_source_sha256", "adapter_sha256", "current_source_sha256", "matches_recorded", "matches_current"):
            if result[field] != item[field]:
                add_finding(findings, "inventory_hash_evidence_mismatch", "error", f"Recomputed {field} disagrees with the inventory snapshot.", item["adapter_path"], item[field], result[field])
        if not result["matches_recorded"]:
            add_finding(findings, "managed_source_recorded_drift", "error", "Managed adapter file does not match its recorded canonical source commit.", item["adapter_path"])
        if not result["matches_current"]:
            add_finding(findings, "managed_source_current_drift", "warning", "Managed adapter file does not match the current canonical source.", item["adapter_path"])
        managed.append(result)

    environment = json.loads(
        source.get(slug, ".codeocean/environment.json", adapter_commit).decode("utf-8")
    )
    base_image = environment.get("base_image")
    digest_match = re.search(r"@sha256:[0-9a-f]{64}$", base_image or "")
    digest = digest_match.group(0).removeprefix("@") if digest_match else None
    if not base_image:
        add_finding(findings, "runtime_missing", "error", "Adapter environment does not record a base image.")
    elif not digest:
        add_finding(findings, "runtime_digest_missing", "warning", "Adapter runtime is tag-addressed; no immutable digest is recorded.", observed=base_image)
    inventory_runtime = adapter["runtime"]
    if base_image != inventory_runtime.get("tag"):
        add_finding(
            findings,
            "inventory_runtime_evidence_mismatch",
            "error",
            "Pinned environment base image disagrees with the inventory runtime tag.",
            expected=inventory_runtime.get("tag"),
            observed=base_image,
        )
    if digest != inventory_runtime.get("digest"):
        add_finding(
            findings,
            "inventory_runtime_evidence_mismatch",
            "error",
            "Pinned environment digest disagrees with the inventory runtime digest.",
            expected=inventory_runtime.get("digest"),
            observed=digest,
        )

    inventory_states = preserved_states(adapter)
    if (
        inventory_states["scientific_export.recorded_parity"]["status"] == "verified"
        and not all(item["matches_recorded"] for item in managed)
    ):
        add_finding(findings, "inventory_status_contradiction", "error", "Recorded-parity status is verified but recomputed managed hashes do not match.")
    if (
        inventory_states["scientific_export.current_parity"]["status"] == "verified"
        and not all(item["matches_current"] for item in managed)
    ):
        add_finding(findings, "inventory_status_contradiction", "error", "Current-parity status is verified but recomputed managed hashes do not match.")
    if (
        inventory_states["app_panel.coverage"]["status"] == "verified"
        and any(item["code"].startswith("app_panel_") for item in findings)
    ):
        add_finding(findings, "inventory_status_contradiction", "error", "App Panel coverage is verified but structural App Panel findings remain.")
    if (
        inventory_states["runtime.provenance"]["status"] == "verified"
        and not digest
    ):
        add_finding(findings, "inventory_status_contradiction", "error", "Runtime provenance is verified but no immutable digest is recorded.")

    return {
        "id": adapter["id"],
        "repository": deployment["repository"],
        "canonical_commit": canonical["source_commit"],
        "adapter_commit": adapter_commit,
        "inventory_states": inventory_states,
        "canonical_contract": {
            "schema_path": canonical["schema_path"],
            "entrypoint": str(canonical_cli_path.relative_to(ROOT)),
            "schema_controls": [item.as_dict() for item in controls],
            "internal_bindings": internal_bindings,
            "cli_controls": [item.as_dict() for item in canonical_cli],
        },
        "adapter_contract": {
            "cli_controls": [item.as_dict() for item in adapter_cli],
            "app_panel_named_parameters": named_parameters,
            "app_panel_controls": [item.as_dict() for item in panel],
            "documented_aliases": exceptions["aliases"],
            "documented_hidden_inputs": exceptions["hidden_inputs"],
            "source_record_metadata": source_metadata,
            "inferred_aliases": aliases,
            "alias_candidates": candidates,
            "runtime": {"base_image": base_image, "digest": digest},
        },
        "managed_files": managed,
        "findings": sorted(findings, key=lambda item: (item["severity"], item["code"], item.get("control", ""))),
    }


def build_report(
    inventory: dict[str, Any], source: Any, audit_base_commit: str | None = None
) -> dict[str, Any]:
    adapters = [audit_adapter(adapter, source) for adapter in inventory["adapters"]]
    summary = {
        "adapter_count": len(adapters),
        "finding_count": sum(len(item["findings"]) for item in adapters),
        "error_count": sum(f["severity"] == "error" for item in adapters for f in item["findings"]),
        "warning_count": sum(f["severity"] == "warning" for item in adapters for f in item["findings"]),
    }
    return {
        "schema_version": 1,
        "work_item": "https://github.com/NIDAP-Community/OMIX/issues/42",
        "audit_base_commit": audit_base_commit,
        "inventory_snapshot": inventory["snapshot"],
        "policy": {
            "status_vocabulary": sorted(STATUS_VOCABULARY),
            "note": "Inventory evidence states are copied verbatim. Findings never promote GitHub evidence to Code Ocean validation or release evidence.",
        },
        "summary": summary,
        "adapters": adapters,
    }


def render_markdown(report: dict[str, Any]) -> str:
    summary = report["summary"]
    lines = [
        "# Deployment-adapter contract report",
        "",
        "> Generated by `scripts/check_deployment_adapter_contracts.py` from the",
        "> immutable commits recorded in the deployment-adapter inventory. Findings",
        "> are audit evidence, not Code Ocean validation or release claims.",
        "",
        f"Tracked work item: [OMIX issue #42]({report['work_item']})",
        "",
        f"Canonical snapshot: `{report['inventory_snapshot']['canonical_repository_commit']}`",
        "",
        f"Issue #42 audit base: `{report.get('audit_base_commit') or 'not recorded'}`",
        "",
        f"Adapters: **{summary['adapter_count']}**; findings: **{summary['finding_count']}** "
        f"({summary['error_count']} errors, {summary['warning_count']} warnings).",
        "",
        "| Adapter | Schema controls | Internal bindings | Adapter CLI | App Panel | Managed current | Runtime digest | Errors | Warnings |",
        "| --- | ---: | ---: | ---: | ---: | --- | --- | ---: | ---: |",
    ]
    for adapter in report["adapters"]:
        errors = sum(item["severity"] == "error" for item in adapter["findings"])
        warnings = sum(item["severity"] == "warning" for item in adapter["findings"])
        current = all(item["matches_current"] for item in adapter["managed_files"])
        runtime = adapter["adapter_contract"]["runtime"]
        lines.append(
            "| {id} | {schema} | {bindings} | {cli} | {panel} | {current} | {digest} | {errors} | {warnings} |".format(
                id=adapter["id"],
                schema=len(adapter["canonical_contract"]["schema_controls"]),
                bindings=len(adapter["canonical_contract"]["internal_bindings"]),
                cli=len(adapter["adapter_contract"]["cli_controls"]),
                panel=len(adapter["adapter_contract"]["app_panel_controls"]),
                current="yes" if current else "no",
                digest="yes" if runtime["digest"] else "no",
                errors=errors,
                warnings=warnings,
            )
        )
    for adapter in report["adapters"]:
        lines.extend(["", f"## {adapter['id']}", ""])
        lines.append(
            f"Inventory App Panel state: **{adapter['inventory_states']['app_panel.coverage']['status']}**; "
            f"current-parity state: **{adapter['inventory_states']['scientific_export.current_parity']['status']}**; "
            f"runtime-provenance state: **{adapter['inventory_states']['runtime.provenance']['status']}**."
        )
        lines.append("")
        if not adapter["findings"]:
            lines.append("No structural findings at the pinned commits.")
            continue
        for finding in adapter["findings"]:
            control = f" `{finding['control']}`:" if finding.get("control") else ":"
            lines.append(
                f"- **{finding['severity'].upper()} `{finding['code']}`**{control} {finding['message']}"
            )
    lines.extend([
        "",
        "## Reproduce or refresh",
        "",
        "- CI/read-only check: `python3 scripts/check_deployment_adapter_contracts.py --check`",
        "- Reviewed refresh: `python3 scripts/check_deployment_adapter_contracts.py --write`",
        "- Optional remediation gate: add `--fail-on-findings`.",
        "",
        "## Limitations",
        "",
        "- This is static contract and provenance analysis; it does not execute capsules or validate Code Ocean state.",
        "- Alias candidates are heuristic findings until explicitly recorded in `OMIX_MODULE_SOURCE.md`.",
        "- A tagged runtime without a digest remains partial provenance even if the image currently resolves.",
        "- App Panels without named parameters cannot be verified by control name.",
        "",
    ])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--inventory", type=Path, default=INVENTORY_PATH)
    parser.add_argument("--adapter-snapshot-dir", type=Path)
    output_mode = parser.add_mutually_exclusive_group()
    output_mode.add_argument("--write", action="store_true", help="Write the canonical JSON and Markdown reports.")
    output_mode.add_argument("--check", action="store_true", help="Fail when the committed JSON or Markdown report is stale.")
    parser.add_argument("--json-output", type=Path, default=REPORT_JSON_PATH)
    parser.add_argument("--markdown-output", type=Path, default=REPORT_MD_PATH)
    parser.add_argument("--audit-base-commit", help="Commit that opened this audit transaction; defaults to the existing report value or the branch merge base.")
    parser.add_argument("--fail-on-findings", action="store_true", help="Return nonzero when structural findings exist.")
    args = parser.parse_args()
    inventory = json.loads(args.inventory.read_text(encoding="utf-8"))
    inventory_checker.validate(inventory)
    source = DirectoryContentSource(args.adapter_snapshot_dir) if args.adapter_snapshot_dir else GitHubContentSource()
    audit_base_commit = args.audit_base_commit
    if not audit_base_commit and args.json_output.is_file():
        try:
            audit_base_commit = json.loads(
                args.json_output.read_text(encoding="utf-8")
            ).get("audit_base_commit")
        except (json.JSONDecodeError, OSError):
            audit_base_commit = None
    if not audit_base_commit:
        base = subprocess.run(
            ["git", "merge-base", "HEAD", "origin/main"],
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=False,
        )
        audit_base_commit = base.stdout.strip() if base.returncode == 0 else None
    if audit_base_commit and not re.fullmatch(r"[0-9a-f]{40}", audit_base_commit):
        raise AuditError("--audit-base-commit must be a full lowercase Git SHA")
    report = build_report(inventory, source, audit_base_commit)
    json_text = json.dumps(report, indent=2) + "\n"
    markdown_text = render_markdown(report)
    if args.write:
        args.json_output.write_text(json_text, encoding="utf-8")
        args.markdown_output.write_text(markdown_text, encoding="utf-8")
    elif args.check:
        stale = []
        if not args.json_output.is_file() or args.json_output.read_text(encoding="utf-8") != json_text:
            stale.append(str(args.json_output))
        if not args.markdown_output.is_file() or args.markdown_output.read_text(encoding="utf-8") != markdown_text:
            stale.append(str(args.markdown_output))
        if stale:
            raise AuditError(
                "Stale deployment-adapter contract report: "
                + ", ".join(stale)
                + ". Run with --write after reviewing the pinned evidence."
            )
        print(f"Deployment adapter contract report is current: {report['summary']['adapter_count']} adapters")
    else:
        print(json.dumps(report["summary"], indent=2))
    return 1 if args.fail_on_findings and report["summary"]["finding_count"] else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AuditError, KeyError, json.JSONDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(2)
