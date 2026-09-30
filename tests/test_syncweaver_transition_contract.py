#!/usr/bin/env python3
"""Regression tests for the Syncweaver transition preparation contract."""

from __future__ import annotations

import copy
import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "check_syncweaver_transition_contract.py"
CONTRACT = ROOT / "docs" / "syncweaver-transition-wave1.json"
SPEC = importlib.util.spec_from_file_location("syncweaver_transition", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Could not load {SCRIPT}")
transition = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(transition)


def git(root: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=root,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip()


class SyncweaverTransitionContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.contract = json.loads(CONTRACT.read_text(encoding="utf-8"))

    def test_committed_contract_and_canonical_evidence_pass(self) -> None:
        transition.validate_contract(self.contract, ROOT)
        self.assertEqual(
            {record["id"] for record in self.contract["adapters"]},
            {
                "OMIX-DEG-Analysis",
                "OMIX-Volcano-Plot",
                "OMIX-GSEA-Filters-Legacy",
            },
        )

    def test_timestamp_conflict_resolution_is_rejected(self) -> None:
        modified = copy.deepcopy(self.contract)
        modified["policy"]["timestamp_resolution_allowed"] = True
        with self.assertRaisesRegex(transition.ContractError, "timestamp_resolution_allowed"):
            transition.validate_contract(modified, ROOT)

    def test_incomplete_mapping_is_rejected(self) -> None:
        modified = copy.deepcopy(self.contract)
        modified["adapters"][0]["mappings"] = []
        with self.assertRaisesRegex(transition.ContractError, "mappings must be a non-empty array"):
            transition.validate_contract(modified, ROOT)

    def test_dirty_adapter_baseline_is_a_stop_condition(self) -> None:
        record = copy.deepcopy(self.contract["adapters"][1])
        mapping = record["mappings"][0]
        source = ROOT / mapping["source_path"]
        with tempfile.TemporaryDirectory() as directory:
            checkout = Path(directory)
            destination = checkout / mapping["destination_path"]
            destination.parent.mkdir(parents=True)
            destination.write_bytes(source.read_bytes())
            source_record = checkout / record["adapter"]["source_record_path"]
            source_record.write_text(
                "\n".join(
                    [
                        record["canonical"]["source_commit"],
                        record["canonical"]["module_version"],
                        str(record["canonical"]["interface_version"]),
                        Path(mapping["source_path"]).name,
                        mapping["destination_path"],
                        mapping["source_sha256"],
                    ]
                ),
                encoding="utf-8",
            )
            git(checkout, "init", "-b", record["adapter"]["default_branch"])
            git(checkout, "config", "user.email", "test@example.invalid")
            git(checkout, "config", "user.name", "OMIX Contract Test")
            git(checkout, "remote", "add", "origin", record["adapter"]["repository"])
            git(checkout, "add", ".")
            git(checkout, "commit", "-m", "fixture")
            record["adapter"]["baseline_commit"] = git(checkout, "rev-parse", "HEAD")

            transition.validate_adapter_checkout(record, checkout)
            (checkout / "untracked.txt").write_text("do not overwrite\n", encoding="utf-8")
            with self.assertRaisesRegex(transition.ContractError, "checkout is dirty"):
                transition.validate_adapter_checkout(record, checkout)


if __name__ == "__main__":
    unittest.main()
