from __future__ import annotations

import copy
import math
import tempfile
import unittest
from pathlib import Path

from tools.data_pipeline.validate_catalog import (
    CatalogJsonError,
    load_catalog,
    validate_catalog,
)


PROJECT_ROOT = Path(__file__).resolve().parents[3]
CATALOG_PATH = PROJECT_ROOT / "data" / "solar_system_catalog.json"


def valid_catalog() -> dict[str, object]:
    return {
        "version": "test-v1",
        "sources": [
            {
                "id": "science-source",
                "label": "Science source",
                "url": "https://example.org/science",
                "accessedAtUtc": "2026-08-05T00:00:00Z",
            },
            {
                "id": "model-source",
                "label": "Teaching model",
                "url": "urn:astronav:test-model",
                "accessedAtUtc": "2026-08-05T00:00:00Z",
            },
        ],
        "objects": [
            {
                "id": "test/star",
                "systemId": "test",
                "parentId": None,
                "nameZh": "测试恒星",
                "nameEn": "Test Star",
                "aliases": ["test star"],
                "kind": "star",
                "descriptionZh": "用于目录校验测试的恒星。",
                "accentArgb": 0xFFFFAA00,
                "mapRadius": 12.0,
                "reachable": False,
                "statusZh": "测试数据",
                "orbit": None,
                "facts": [
                    {
                        "key": "radiusKm",
                        "labelZh": "半径",
                        "value": 1000.0,
                        "unit": "km",
                        "displayZh": "1,000 km",
                        "provenance": {
                            "nature": "observed",
                            "sourceId": "science-source",
                            "noteZh": "测试观测值",
                        },
                    },
                    {
                        "key": "estimatedAgeYears",
                        "labelZh": "估计年龄",
                        "value": 1.0,
                        "unit": "年",
                        "displayZh": "1 年",
                        "provenance": {
                            "nature": "derived",
                            "sourceId": "model-source",
                            "noteZh": "测试推导值",
                        },
                    },
                    {
                        "key": "projectedTemperatureC",
                        "labelZh": "模拟温度",
                        "value": 20.0,
                        "unit": "°C",
                        "displayZh": "20 °C",
                        "provenance": {
                            "nature": "simulated",
                            "sourceId": "model-source",
                            "noteZh": "测试模拟值",
                        },
                    },
                ],
                "provenance": {
                    "nature": "observed",
                    "sourceId": "science-source",
                    "noteZh": "测试天体",
                },
            },
            {
                "id": "test/star/station",
                "systemId": "test",
                "parentId": "test/star",
                "nameZh": "测试空间站",
                "nameEn": "Test Station",
                "aliases": ["station"],
                "kind": "orbitalStation",
                "descriptionZh": "用于目录校验测试的空间站。",
                "accentArgb": 0xFF00AAFF,
                "mapRadius": 4.0,
                "reachable": True,
                "statusZh": "模拟设施",
                "orbit": {
                    "parentId": "test/star",
                    "semiMajorAxisAu": 1.0,
                    "eccentricity": 0.01,
                    "orbitalPeriodDays": 365.0,
                    "inclinationDeg": 0.0,
                    "phaseAtJ2000Rad": 0.0,
                    "provenance": {
                        "nature": "fictional",
                        "sourceId": "model-source",
                        "noteZh": "测试虚构轨道设定",
                    },
                },
                "facts": [
                    {
                        "key": "travelTimeDays",
                        "labelZh": "模拟航时",
                        "value": 30.0,
                        "unit": "天",
                        "displayZh": "30 天",
                        "provenance": {
                            "nature": "fictional",
                            "sourceId": "model-source",
                            "noteZh": "测试虚构值",
                        },
                    },
                    {
                        "key": "crewCapacity",
                        "labelZh": "设定乘员容量",
                        "value": 8.0,
                        "unit": "人",
                        "displayZh": "8 人",
                        "provenance": {
                            "nature": "fictional",
                            "sourceId": "model-source",
                            "noteZh": "测试虚构值",
                        },
                    },
                ],
                "provenance": {
                    "nature": "fictional",
                    "sourceId": "model-source",
                    "noteZh": "测试设施",
                },
            },
        ],
    }


def issue_codes(document: object) -> set[str]:
    return {issue.code for issue in validate_catalog(document)}


class CatalogValidatorTests(unittest.TestCase):
    def test_repository_catalog_is_valid(self) -> None:
        document = load_catalog(CATALOG_PATH)

        self.assertEqual(validate_catalog(document), [])

    def test_valid_catalog_accepts_all_data_natures(self) -> None:
        document = valid_catalog()

        self.assertEqual(validate_catalog(document), [])

    def test_reports_missing_core_fields_with_json_path(self) -> None:
        document = valid_catalog()
        del document["version"]
        del document["objects"][0]["nameZh"]  # type: ignore[index]

        issues = validate_catalog(document)

        self.assertTrue(
            any(issue.code == "missing_field" and issue.path == "$.version" for issue in issues)
        )
        self.assertTrue(
            any(
                issue.code == "missing_field"
                and issue.path == "$.objects[0].nameZh"
                for issue in issues
            )
        )

    def test_reports_duplicate_source_object_and_fact_ids(self) -> None:
        document = valid_catalog()
        sources = document["sources"]  # type: ignore[assignment]
        objects = document["objects"]  # type: ignore[assignment]
        sources.append(copy.deepcopy(sources[0]))
        objects.append(copy.deepcopy(objects[0]))
        first_object = document["objects"][0]  # type: ignore[index]
        first_object["facts"].append(copy.deepcopy(first_object["facts"][0]))

        codes = issue_codes(document)

        self.assertIn("duplicate_source_id", codes)
        self.assertIn("duplicate_object_id", codes)
        self.assertIn("duplicate_fact_key", codes)

    def test_reports_parent_orbit_and_system_reference_errors(self) -> None:
        document = valid_catalog()
        station = document["objects"][1]  # type: ignore[index]
        station["parentId"] = "missing/body"
        station["orbit"]["parentId"] = "other/star"  # type: ignore[index]
        station["systemId"] = "other"

        codes = issue_codes(document)

        self.assertIn("unknown_parent", codes)
        self.assertIn("unknown_orbit_parent", codes)
        self.assertIn("object_outside_system_namespace", codes)

    def test_requires_provenance_for_orbit_parameters(self) -> None:
        document = valid_catalog()
        station = document["objects"][1]  # type: ignore[index]
        del station["orbit"]["provenance"]  # type: ignore[index]

        issues = validate_catalog(document)

        self.assertTrue(
            any(
                issue.code == "missing_field"
                and issue.path == "$.objects[1].orbit.provenance"
                for issue in issues
            )
        )

    def test_reports_cross_system_parent_and_parent_cycles(self) -> None:
        document = valid_catalog()
        second_root = copy.deepcopy(document["objects"][0])  # type: ignore[index]
        second_root["id"] = "other/star"
        second_root["systemId"] = "other"
        second_root["parentId"] = "test/star"
        document["objects"].append(second_root)  # type: ignore[union-attr,index]
        station = document["objects"][1]  # type: ignore[index]
        station["parentId"] = "other/star"
        station["orbit"]["parentId"] = "other/star"  # type: ignore[index]
        document["objects"][0]["parentId"] = "test/star/station"  # type: ignore[index]

        codes = issue_codes(document)

        self.assertIn("cross_system_parent", codes)
        self.assertIn("cross_system_orbit_parent", codes)
        self.assertIn("parent_cycle", codes)

    def test_reports_unknown_nature_and_source(self) -> None:
        document = valid_catalog()
        first_object = document["objects"][0]  # type: ignore[index]
        first_object["provenance"]["nature"] = "estimated"
        first_object["facts"][0]["provenance"]["sourceId"] = "missing-source"

        codes = issue_codes(document)

        self.assertIn("invalid_data_nature", codes)
        self.assertIn("unknown_source", codes)

    def test_observed_values_require_a_public_http_source(self) -> None:
        document = valid_catalog()
        first_object = document["objects"][0]  # type: ignore[index]
        first_object["provenance"]["sourceId"] = "model-source"

        issues = validate_catalog(document)

        self.assertTrue(
            any(
                issue.code == "observed_requires_public_source"
                and issue.path == "$.objects[0].provenance.sourceId"
                for issue in issues
            )
        )

    def test_observed_values_require_a_valid_source_access_time(self) -> None:
        document = valid_catalog()
        science_source = document["sources"][0]  # type: ignore[index]
        science_source["accessedAtUtc"] = ""

        issues = validate_catalog(document)

        self.assertTrue(
            any(
                issue.code == "observed_source_requires_access_time"
                and issue.path == "$.objects[0].provenance.sourceId"
                for issue in issues
            )
        )

    def test_fictional_objects_keep_orbits_and_facts_fictional(self) -> None:
        document = valid_catalog()
        station = document["objects"][1]  # type: ignore[index]
        station["orbit"]["provenance"]["nature"] = "derived"  # type: ignore[index]
        station["facts"][0]["provenance"]["nature"] = "simulated"

        issues = validate_catalog(document)

        self.assertTrue(
            any(
                issue.code == "fictional_orbit_requires_fictional_provenance"
                and issue.path == "$.objects[1].orbit.provenance.nature"
                for issue in issues
            )
        )
        self.assertTrue(
            any(
                issue.code == "fictional_fact_requires_fictional_provenance"
                and issue.path == "$.objects[1].facts[0].provenance.nature"
                for issue in issues
            )
        )

    def test_reports_cycles_in_orbit_parent_references(self) -> None:
        document = valid_catalog()
        station = document["objects"][1]  # type: ignore[index]
        second_station = copy.deepcopy(station)
        second_station["id"] = "test/star/station-two"
        second_station["nameZh"] = "测试空间站二号"
        second_station["nameEn"] = "Test Station Two"
        station["orbit"]["parentId"] = second_station["id"]  # type: ignore[index]
        second_station["orbit"]["parentId"] = station["id"]
        document["objects"].append(second_station)  # type: ignore[union-attr]

        codes = issue_codes(document)

        self.assertIn("orbit_parent_cycle", codes)

    def test_reports_cycles_mixing_orbit_and_hierarchy_parents(self) -> None:
        document = valid_catalog()
        star = document["objects"][0]  # type: ignore[index]
        station = document["objects"][1]  # type: ignore[index]
        star["parentId"] = station["id"]
        station["parentId"] = None

        codes = issue_codes(document)

        self.assertNotIn("parent_cycle", codes)
        self.assertIn("orbit_parent_cycle", codes)

    def test_reports_invalid_source_metadata(self) -> None:
        document = valid_catalog()
        source = document["sources"][0]  # type: ignore[index]
        source["url"] = "not a URL"
        source["accessedAtUtc"] = "2026-08-05"

        codes = issue_codes(document)

        self.assertIn("invalid_source_url", codes)
        self.assertIn("invalid_utc_timestamp", codes)

    def test_reports_non_finite_numbers_at_any_depth(self) -> None:
        document = valid_catalog()
        first_object = document["objects"][0]  # type: ignore[index]
        station = document["objects"][1]  # type: ignore[index]
        first_object["mapRadius"] = math.inf
        first_object["facts"][0]["value"] = math.nan
        station["orbit"]["semiMajorAxisAu"] = -math.inf

        issues = validate_catalog(document)
        non_finite_paths = {
            issue.path for issue in issues if issue.code == "non_finite_number"
        }

        self.assertEqual(
            non_finite_paths,
            {
                "$.objects[0].mapRadius",
                "$.objects[0].facts[0].value",
                "$.objects[1].orbit.semiMajorAxisAu",
            },
        )

    def test_loader_wraps_malformed_json_with_path(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "catalog.json"
            path.write_text('{"version":', encoding="utf-8")

            with self.assertRaisesRegex(CatalogJsonError, "catalog.json"):
                load_catalog(path)


if __name__ == "__main__":
    unittest.main()
