#!/usr/bin/env python3
"""Regression tests for bounded deployment-adapter manifest parsing."""

from __future__ import annotations

import importlib.util
import tempfile
import time
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "check_deployment_adapter_inventory.py"
SPEC = importlib.util.spec_from_file_location("deployment_inventory", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Could not load {SCRIPT}")
inventory = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(inventory)


class DeploymentAdapterParserTests(unittest.TestCase):
    def test_missing_and_explicitly_empty_blocks_have_no_adapters(self) -> None:
        self.assertEqual(inventory.parse_deployment_adapter_repositories("name: demo\n"), [])
        self.assertEqual(
            inventory.parse_deployment_adapter_repositories(
                "name: demo\ndeployment_adapters: []\n"
            ),
            [],
        )

    def test_parser_is_bounded_to_top_level_adapter_block(self) -> None:
        text = """\
name: demo
metadata:
  deployment_adapters:
    - repository: https://example.invalid/nested
deployment_adapters:
  - platform: code-ocean
    repository: https://example.org/primary # deployment target
next_top_level:
  repository: https://example.invalid/outside
"""
        self.assertEqual(
            inventory.parse_deployment_adapter_repositories(text),
            ["https://example.org/primary"],
        )

    def test_future_multi_entry_list_retains_repository_order(self) -> None:
        text = """\
deployment_adapters:
  - platform: code-ocean
    repository: https://example.org/code-ocean
  - platform: galaxy
    repository: 'https://example.org/galaxy'
"""
        self.assertEqual(
            inventory.parse_deployment_adapter_repositories(text),
            ["https://example.org/code-ocean", "https://example.org/galaxy"],
        )

    def test_registered_adapters_preserves_first_repository_behavior(self) -> None:
        adapter_manifest = """\
display_name: Demo
version: 1.2.3
interface_version: 4
deployment_adapters:
  - platform: code-ocean
    repository: https://example.org/first
  - platform: galaxy
    repository: https://example.org/second
"""
        empty_manifest = """\
display_name: Empty
version: 1.0.0
interface_version: 1
deployment_adapters: []
"""
        missing_manifest = """\
display_name: Missing
version: 1.0.0
interface_version: 1
"""
        with tempfile.TemporaryDirectory() as directory:
            temporary_root = Path(directory)
            for module_name, manifest in {
                "Demo": adapter_manifest,
                "Empty": empty_manifest,
                "Missing": missing_manifest,
            }.items():
                module_dir = temporary_root / "modules" / module_name
                module_dir.mkdir(parents=True)
                (module_dir / "module.yml").write_text(manifest, encoding="utf-8")
            original_root = inventory.ROOT
            try:
                inventory.ROOT = temporary_root
                records = inventory.registered_adapters()
            finally:
                inventory.ROOT = original_root

        self.assertEqual(set(records), {"Demo"})
        self.assertEqual(records["Demo"]["repository"], "https://example.org/first")

    def test_many_newlines_complete_promptly_without_repository(self) -> None:
        text = "deployment_adapters:\n" + ("\n" * 100_000) + "name: after\n"
        started = time.monotonic()
        self.assertEqual(inventory.parse_deployment_adapter_repositories(text), [])
        elapsed = time.monotonic() - started
        self.assertLess(elapsed, 2.0, f"bounded parser took {elapsed:.3f} seconds")


class DeploymentAdapterRendererTests(unittest.TestCase):
    @staticmethod
    def adapter(
        adapter_id: str,
        *,
        schema_status: str = "verified",
        app_panel_status: str = "verified",
    ) -> dict:
        return {
            "id": adapter_id,
            "canonical": {"module_version": "1.0.0", "interface_version": 1},
            "deployment": {
                "repository": f"https://example.org/{adapter_id}",
                "default_branch": "main",
                "default_branch_commit": "a" * 40,
            },
            "scientific_export": {
                "recorded_parity": {"status": "verified"},
                "current_parity": {"status": "verified"},
                "extra_files_in_code_functions": [],
            },
            "schema_completeness": {"status": schema_status},
            "app_panel": {"coverage": {"status": app_panel_status}},
            "runtime": {"provenance": {"status": "partial"}},
            "code_ocean_validation": {"status": "pending"},
            "work_tracking": {"pull_requests": []},
            "syncweaver": {
                "lockfile_on_default_branch": False,
                "readiness": {"status": "pending"},
            },
        }

    @staticmethod
    def inventory(adapters: list[dict]) -> dict:
        return {
            "snapshot": {
                "date": "2026-09-28",
                "canonical_repository_commit": "b" * 40,
                "canonical_repository_url": "https://example.org/OMIX",
                "work_item": "https://example.org/OMIX/issues/39",
            },
            "adapters": adapters,
        }

    def test_renderer_uses_dynamic_issue_and_current_statuses(self) -> None:
        rendered = inventory.render(
            self.inventory(
                [
                    self.adapter("Adapter-A", app_panel_status="outdated"),
                    self.adapter("Adapter-B", app_panel_status="blocked"),
                    self.adapter("Adapter-C"),
                ]
            )
        )

        self.assertIn("[issue #39](https://example.org/OMIX/issues/39)", rendered)
        self.assertNotIn("issue #26", rendered)
        self.assertIn(
            "Canonical schema completeness:** verified for all 3 registered adapters.",
            rendered,
        )
        self.assertIn(
            "App Panels needing remediation:** Adapter-A (outdated), Adapter-B (blocked).",
            rendered,
        )
        self.assertNotIn("pending a parameter-level contract audit for every adapter", rendered)

    def test_renderer_reports_each_non_verified_schema_state(self) -> None:
        rendered = inventory.render(
            self.inventory(
                [
                    self.adapter("Adapter-A"),
                    self.adapter("Adapter-B", schema_status="pending"),
                    self.adapter("Adapter-C", schema_status="blocked"),
                ]
            )
        )

        self.assertIn(
            "Canonical schemas needing completion:** Adapter-B (pending), Adapter-C (blocked).",
            rendered,
        )
        self.assertNotIn("verified for all 3 registered adapters", rendered)


if __name__ == "__main__":
    unittest.main()
