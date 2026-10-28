#!/usr/bin/env python3
"""Contract tests for the generic canonical-module validation helper."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "canonical_module_validation.py"


class CanonicalModuleValidationTests(unittest.TestCase):
    def invoke(self, *arguments: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), *arguments],
            cwd=ROOT,
            check=True,
            text=True,
            capture_output=True,
        )

    def test_pca_plan_runner_and_report(self) -> None:
        """The PCA pilot expands into a runtime-bound, reviewable validation plan."""
        with tempfile.TemporaryDirectory() as temporary:
            temporary_path = Path(temporary)
            plan_path = temporary_path / "plan.json"
            runner_path = temporary_path / "run-validation.sh"
            artifacts = temporary_path / "artifacts"

            self.invoke("plan", "--module", "OMIX-PCA-3D", "--output", str(plan_path))
            plan = json.loads(plan_path.read_text())
            self.assertEqual(plan["module"], "OMIX-PCA-3D")
            self.assertEqual(plan["runtime_profile"], "r-visualization")
            self.assertIn("@sha256:", plan["runtime_immutable_reference"])
            self.assertTrue(plan["known_result_evidence"])

            self.invoke("write-runner", "--plan", str(plan_path), "--output", str(runner_path))
            runner = runner_path.read_text()
            self.assertIn("test-pca-preparation.R", runner)
            self.assertIn("run_pca_3d.R", runner)

            for relative in plan["expected_artifacts"]:
                output = artifacts / relative
                if Path(relative).suffix:
                    output.parent.mkdir(parents=True, exist_ok=True)
                    output.write_text("fixture output\n")
                else:
                    output.mkdir(parents=True, exist_ok=True)
                    (output / "asset.js").write_text("fixture asset\n")
            self.invoke("report", "--plan", str(plan_path), "--artifact-directory", str(artifacts))
            report = json.loads((artifacts / "validation-report.json").read_text())
            self.assertEqual(report["validation_plan"]["module"], "OMIX-PCA-3D")
            self.assertEqual(len(report["artifacts"]), len(plan["expected_artifacts"]))

    def test_explicit_discovery_selects_opted_in_module(self) -> None:
        """Maintainers can run the same pilot manually from Actions dispatch."""
        result = self.invoke("discover", "--module", "OMIX-PCA-3D")
        self.assertEqual(json.loads(result.stdout), {"include": [{"module": "OMIX-PCA-3D"}]})


if __name__ == "__main__":
    unittest.main()
