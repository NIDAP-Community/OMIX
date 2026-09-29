#!/usr/bin/env python3

import importlib.util
import json
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "check_deployment_adapter_contracts.py"
FIXTURES = ROOT / "tests" / "fixtures" / "deployment_adapter_contracts" / "cases.json"
SPEC = importlib.util.spec_from_file_location("adapter_contracts", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


def control(value):
    return MODULE.Control(
        name=value["name"],
        cli=value["cli"],
        type=value["type"],
        default=value.get("default"),
        allowed=tuple(value.get("allowed", [])),
        item_allowed=tuple(value.get("item_allowed", [])),
        classification=value.get("classification"),
    )


def option(value, order):
    return MODULE.ROption(value["name"], value.get("type"), value.get("default"), order)


def panel(value, order):
    return MODULE.PanelControl(
        value.get("name"), value.get("type"), value.get("default"),
        tuple(value.get("allowed", [])), order
    )


class ContractComparisonTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cases = json.loads(FIXTURES.read_text())

    def compare(self, name, exceptions=None, internal_bindings=None):
        value = self.cases[name]
        exceptions = exceptions or {"aliases": {}, "hidden_inputs": {}}
        return MODULE.compare_controls(
            [control(item) for item in value["canonical"]],
            [option(item, index) for index, item in enumerate(value["canonical_cli"])],
            [option(item, index) for index, item in enumerate(value["adapter_cli"])],
            True,
            [panel(item, index) for index, item in enumerate(value["panel"])],
            exceptions,
            internal_bindings,
        )

    def test_exact_contract_has_no_findings_and_internal_may_be_platform_managed(self):
        findings, aliases, candidates = self.compare("exact")
        self.assertEqual([], findings)
        self.assertEqual({}, aliases)
        self.assertEqual([], candidates)

    def test_missing_extra_alias_defaults_choices_and_internal_extra_are_reported(self):
        findings, aliases, _ = self.compare("drift")
        codes = [item["code"] for item in findings]
        self.assertEqual("input_file", aliases["input"])
        self.assertIn("undocumented_alias_candidate", codes)
        self.assertIn("adapter_cli_extra", codes)
        self.assertIn("app_panel_extra", codes)
        self.assertIn("adapter_cli_default_mismatch", codes)
        self.assertIn("app_panel_default_mismatch", codes)
        self.assertIn("app_panel_choices_mismatch", codes)

    def test_explicit_alias_is_accepted_without_undocumented_alias_finding(self):
        findings, aliases, _ = self.compare(
            "drift", {"aliases": {"input": "input_file"}, "hidden_inputs": {}}
        )
        self.assertEqual("input_file", aliases["input"])
        self.assertNotIn("undocumented_alias_candidate", [item["code"] for item in findings])

    def test_documented_hidden_input_is_not_reported_missing(self):
        value = self.cases["hidden"]
        exceptions = MODULE.parse_source_record_exceptions(value["source_record"])
        findings, _, _ = self.compare("hidden", exceptions)
        self.assertNotIn("adapter_cli_missing", [item["code"] for item in findings])
        self.assertNotIn("app_panel_missing", [item["code"] for item in findings])

    def test_undocumented_hidden_input_is_reported_missing(self):
        findings, _, _ = self.compare("hidden")
        codes = [item["code"] for item in findings]
        self.assertIn("adapter_cli_missing", codes)
        self.assertIn("app_panel_missing", codes)

    def test_managed_hash_drift_distinguishes_recorded_and_current(self):
        result = MODULE.managed_hash_result(b"old", b"new", b"old")
        self.assertTrue(result["matches_recorded"])
        self.assertFalse(result["matches_current"])

    def test_r_parser_handles_multiline_null_boolean_integer_and_infinity(self):
        text = '''
        list(
          make_option(c("--path"), type = "character", default = NULL),
          make_option("--enabled", type = "logical", default = TRUE),
          make_option("--count", type = "integer", default = 20L),
          make_option("--limit", type = "double", default = Inf)
        )
        '''
        values = {item.name: item for item in MODULE.parse_r_options(text)}
        self.assertIsNone(values["path"].default)
        self.assertIs(values["enabled"].default, True)
        self.assertEqual(20, values["count"].default)
        self.assertEqual(float("inf"), values["limit"].default)

    def test_source_record_prose_does_not_grant_an_exception(self):
        value = MODULE.parse_source_record_exceptions(
            "The adapter hides database input and auto-discovers it."
        )
        self.assertEqual({"aliases": {}, "hidden_inputs": {}}, value)

    def test_stale_explicit_alias_is_reported(self):
        findings, _, _ = self.compare(
            "exact", {"aliases": {"removed": "old_name"}, "hidden_inputs": {}}
        )
        self.assertIn("stale_alias_exception", [item["code"] for item in findings])

    def test_source_record_metadata_and_hash_manifest_are_detected(self):
        value = MODULE.parse_source_record_metadata(
            """
            - **Canonical module version:** `1.2.3`
            - **Canonical interface version:** `2`
            - **Canonical source reference:** [`0123456789abcdef0123456789abcdef01234567`](url)
            | file | sha256 |
            | x.R | aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |
            """
        )
        self.assertEqual("0123456789abcdef0123456789abcdef01234567", value["canonical_source_commit"])
        self.assertEqual("1.2.3", value["module_version"])
        self.assertEqual(2, value["interface_version"])
        self.assertTrue(value["has_per_file_sha256"])

    def test_internal_binding_is_classified_and_user_exposure_is_reported(self):
        value = json.loads(json.dumps(self.cases["exact"]))
        value["adapter_cli"].append(
            {"name": "derived_value", "type": "character", "default": "fixed"}
        )
        value["panel"].append(
            {"name": "derived_value", "type": "text", "default": "fixed", "allowed": []}
        )
        self.cases["internal_binding"] = value
        findings, _, _ = self.compare(
            "internal_binding", internal_bindings={"derived_value": {"classification": "internal"}}
        )
        codes = [item["code"] for item in findings]
        self.assertIn("app_panel_internal_exposed", codes)
        self.assertNotIn("adapter_cli_extra", codes)


if __name__ == "__main__":
    unittest.main()
