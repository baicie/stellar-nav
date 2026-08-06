from __future__ import annotations

import argparse
import json
import math
import sys
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any
from urllib.parse import urlparse


DATA_NATURES = frozenset({"observed", "derived", "simulated", "fictional"})
OBJECT_KINDS = frozenset(
    {
        "star",
        "planet",
        "dwarfPlanet",
        "moon",
        "asteroid",
        "orbitalStation",
        "surfaceBase",
        "relay",
    }
)

SOURCE_FIELDS = ("id", "label", "url", "accessedAtUtc")
OBJECT_FIELDS = (
    "id",
    "systemId",
    "parentId",
    "nameZh",
    "nameEn",
    "aliases",
    "kind",
    "descriptionZh",
    "accentArgb",
    "mapRadius",
    "reachable",
    "statusZh",
    "orbit",
    "facts",
    "provenance",
)
ORBIT_FIELDS = (
    "parentId",
    "semiMajorAxisAu",
    "eccentricity",
    "orbitalPeriodDays",
    "inclinationDeg",
    "phaseAtJ2000Rad",
    "provenance",
)
FACT_FIELDS = ("key", "labelZh", "value", "unit", "displayZh", "provenance")
PROVENANCE_FIELDS = ("nature", "sourceId", "noteZh")


@dataclass(frozen=True, slots=True)
class ValidationIssue:
    code: str
    path: str
    message: str

    def __str__(self) -> str:
        return f"{self.path}: [{self.code}] {self.message}"


@dataclass(frozen=True, slots=True)
class SourceMetadata:
    url: str | None
    accessed_at_utc: str | None


class CatalogJsonError(ValueError):
    """Raised when a catalog file cannot be read as JSON."""


def load_catalog(path: str | Path) -> Any:
    catalog_path = Path(path)
    try:
        with catalog_path.open(encoding="utf-8") as catalog_file:
            return json.load(catalog_file)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise CatalogJsonError(f"Cannot load {catalog_path}: {error}") from error


def validate_catalog(document: object) -> list[ValidationIssue]:
    issues: list[ValidationIssue] = []
    _validate_finite_numbers(document, "$", issues)

    if not isinstance(document, Mapping):
        _add_issue(issues, "invalid_type", "$", "catalog must be an object")
        return issues

    _require_fields(document, ("version", "sources", "objects"), "$", issues)
    _expect_non_empty_string(document.get("version"), "$.version", issues)

    sources_by_id = _validate_sources(document.get("sources"), issues)
    _validate_objects(document.get("objects"), sources_by_id, issues)
    return issues


def _validate_sources(
    value: object, issues: list[ValidationIssue]
) -> dict[str, SourceMetadata]:
    path = "$.sources"
    if not _is_sequence(value):
        _add_issue(issues, "invalid_type", path, "sources must be an array")
        return {}
    if not value:
        _add_issue(issues, "empty_collection", path, "sources must not be empty")

    sources_by_id: dict[str, SourceMetadata] = {}
    for index, source in enumerate(value):
        source_path = f"{path}[{index}]"
        if not isinstance(source, Mapping):
            _add_issue(issues, "invalid_type", source_path, "source must be an object")
            continue

        _require_fields(source, SOURCE_FIELDS, source_path, issues)
        source_id = _expect_non_empty_string(source.get("id"), f"{source_path}.id", issues)
        _expect_non_empty_string(source.get("label"), f"{source_path}.label", issues)
        source_url = _expect_non_empty_string(source.get("url"), f"{source_path}.url", issues)
        accessed_at = _expect_non_empty_string(
            source.get("accessedAtUtc"), f"{source_path}.accessedAtUtc", issues
        )

        if source_id is not None:
            if source_id in sources_by_id:
                _add_issue(
                    issues,
                    "duplicate_source_id",
                    f"{source_path}.id",
                    f"source id {source_id!r} is already declared",
                )
            else:
                sources_by_id[source_id] = SourceMetadata(
                    url=source_url,
                    accessed_at_utc=accessed_at,
                )
        if source_url is not None and not _is_supported_source_url(source_url):
            _add_issue(
                issues,
                "invalid_source_url",
                f"{source_path}.url",
                "source URL must be an absolute HTTP(S) URL or URN",
            )
        if accessed_at is not None and not _is_utc_timestamp(accessed_at):
            _add_issue(
                issues,
                "invalid_utc_timestamp",
                f"{source_path}.accessedAtUtc",
                "source access time must be an ISO-8601 UTC timestamp",
            )
    return sources_by_id


def _validate_objects(
    value: object,
    sources_by_id: Mapping[str, SourceMetadata],
    issues: list[ValidationIssue],
) -> None:
    path = "$.objects"
    if not _is_sequence(value):
        _add_issue(issues, "invalid_type", path, "objects must be an array")
        return
    if not value:
        _add_issue(issues, "empty_collection", path, "objects must not be empty")

    object_ids: set[str] = set()
    object_records: list[tuple[str, str, str | None, str | None, str]] = []

    for index, item in enumerate(value):
        object_path = f"{path}[{index}]"
        if not isinstance(item, Mapping):
            _add_issue(issues, "invalid_type", object_path, "object must be an object")
            continue

        _require_fields(item, OBJECT_FIELDS, object_path, issues)
        object_id = _expect_non_empty_string(item.get("id"), f"{object_path}.id", issues)
        system_id = _expect_non_empty_string(
            item.get("systemId"), f"{object_path}.systemId", issues
        )
        parent_id = _expect_nullable_string(
            item.get("parentId"), f"{object_path}.parentId", issues
        )

        if object_id is not None:
            if object_id in object_ids:
                _add_issue(
                    issues,
                    "duplicate_object_id",
                    f"{object_path}.id",
                    f"object id {object_id!r} is already declared",
                )
            object_ids.add(object_id)
        if object_id is not None and system_id is not None:
            if not object_id.startswith(f"{system_id}/"):
                _add_issue(
                    issues,
                    "object_outside_system_namespace",
                    f"{object_path}.systemId",
                    f"object id {object_id!r} is outside system {system_id!r}",
                )

        _expect_non_empty_string(item.get("nameZh"), f"{object_path}.nameZh", issues)
        _expect_non_empty_string(item.get("nameEn"), f"{object_path}.nameEn", issues)
        _expect_string_array(item.get("aliases"), f"{object_path}.aliases", issues)
        kind = _expect_non_empty_string(item.get("kind"), f"{object_path}.kind", issues)
        if kind is not None and kind not in OBJECT_KINDS:
            _add_issue(
                issues,
                "invalid_object_kind",
                f"{object_path}.kind",
                f"unsupported object kind {kind!r}",
            )
        _expect_non_empty_string(
            item.get("descriptionZh"), f"{object_path}.descriptionZh", issues
        )
        _expect_argb(item.get("accentArgb"), f"{object_path}.accentArgb", issues)
        map_radius = _expect_number(
            item.get("mapRadius"), f"{object_path}.mapRadius", issues
        )
        if map_radius is not None and math.isfinite(map_radius) and map_radius <= 0:
            _add_issue(
                issues,
                "invalid_number_range",
                f"{object_path}.mapRadius",
                "map radius must be greater than zero",
            )
        _expect_bool(item.get("reachable"), f"{object_path}.reachable", issues)
        _expect_non_empty_string(item.get("statusZh"), f"{object_path}.statusZh", issues)

        object_nature = _validate_provenance(
            item.get("provenance"),
            f"{object_path}.provenance",
            sources_by_id,
            issues,
        )
        orbit_parent = _validate_orbit(
            item.get("orbit"),
            object_path,
            object_nature,
            sources_by_id,
            issues,
        )
        _validate_facts(
            item.get("facts"),
            object_path,
            object_nature,
            sources_by_id,
            issues,
        )

        if object_id is not None and system_id is not None:
            object_records.append(
                (object_id, system_id, parent_id, orbit_parent, object_path)
            )

    systems_by_object = {
        object_id: system_id
        for object_id, system_id, _, _, _ in object_records
    }
    parents_by_object = {
        object_id: parent_id
        for object_id, _, parent_id, _, _ in object_records
    }
    coordinate_parents_by_object = {
        object_id: orbit_parent if orbit_parent is not None else parent_id
        for object_id, _, parent_id, orbit_parent, _ in object_records
    }
    system_ids = {system_id for _, system_id, _, _, _ in object_records}
    rooted_system_ids = {
        system_id
        for _, system_id, parent_id, _, _ in object_records
        if parent_id is None
    }

    for _, system_id, parent_id, orbit_parent, object_path in object_records:
        _validate_parent_reference(
            parent_id,
            system_id,
            systems_by_object,
            f"{object_path}.parentId",
            "parent",
            issues,
        )
        _validate_parent_reference(
            orbit_parent,
            system_id,
            systems_by_object,
            f"{object_path}.orbit.parentId",
            "orbit_parent",
            issues,
        )
    for system_id in sorted(system_ids - rooted_system_ids):
        _add_issue(
            issues,
            "missing_system_root",
            "$.objects",
            f"system {system_id!r} has no root object",
        )

    _validate_reference_cycles(
        parents_by_object,
        "parent_cycle",
        "parent hierarchy",
        issues,
    )
    _validate_reference_cycles(
        coordinate_parents_by_object,
        "orbit_parent_cycle",
        "coordinate parent graph",
        issues,
    )


def _validate_orbit(
    value: object,
    object_path: str,
    object_nature: str | None,
    sources_by_id: Mapping[str, SourceMetadata],
    issues: list[ValidationIssue],
) -> str | None:
    path = f"{object_path}.orbit"
    if value is None:
        return None
    if not isinstance(value, Mapping):
        _add_issue(issues, "invalid_type", path, "orbit must be an object or null")
        return None

    _require_fields(value, ORBIT_FIELDS, path, issues)
    parent_id = _expect_non_empty_string(value.get("parentId"), f"{path}.parentId", issues)
    semi_major_axis = _expect_number(
        value.get("semiMajorAxisAu"), f"{path}.semiMajorAxisAu", issues
    )
    eccentricity = _expect_number(
        value.get("eccentricity"), f"{path}.eccentricity", issues
    )
    period = _expect_number(
        value.get("orbitalPeriodDays"), f"{path}.orbitalPeriodDays", issues
    )
    _expect_number(value.get("inclinationDeg"), f"{path}.inclinationDeg", issues)
    _expect_number(value.get("phaseAtJ2000Rad"), f"{path}.phaseAtJ2000Rad", issues)
    orbit_nature = _validate_provenance(
        value.get("provenance"),
        f"{path}.provenance",
        sources_by_id,
        issues,
    )
    if object_nature == "fictional" and orbit_nature not in {None, "fictional"}:
        _add_issue(
            issues,
            "fictional_orbit_requires_fictional_provenance",
            f"{path}.provenance.nature",
            "a fictional object's orbit must remain fictional",
        )

    if semi_major_axis is not None and math.isfinite(semi_major_axis) and semi_major_axis <= 0:
        _add_issue(
            issues,
            "invalid_number_range",
            f"{path}.semiMajorAxisAu",
            "semi-major axis must be greater than zero",
        )
    if eccentricity is not None and math.isfinite(eccentricity) and not 0 <= eccentricity < 1:
        _add_issue(
            issues,
            "invalid_number_range",
            f"{path}.eccentricity",
            "elliptic orbit eccentricity must be in [0, 1)",
        )
    if period is not None and math.isfinite(period) and period <= 0:
        _add_issue(
            issues,
            "invalid_number_range",
            f"{path}.orbitalPeriodDays",
            "orbital period must be greater than zero",
        )
    return parent_id


def _validate_facts(
    value: object,
    object_path: str,
    object_nature: str | None,
    sources_by_id: Mapping[str, SourceMetadata],
    issues: list[ValidationIssue],
) -> None:
    path = f"{object_path}.facts"
    if not _is_sequence(value):
        _add_issue(issues, "invalid_type", path, "facts must be an array")
        return
    if not value:
        _add_issue(issues, "empty_collection", path, "facts must not be empty")

    fact_keys: set[str] = set()
    for index, fact in enumerate(value):
        fact_path = f"{path}[{index}]"
        if not isinstance(fact, Mapping):
            _add_issue(issues, "invalid_type", fact_path, "fact must be an object")
            continue

        _require_fields(fact, FACT_FIELDS, fact_path, issues)
        fact_key = _expect_non_empty_string(fact.get("key"), f"{fact_path}.key", issues)
        if fact_key is not None:
            if fact_key in fact_keys:
                _add_issue(
                    issues,
                    "duplicate_fact_key",
                    f"{fact_path}.key",
                    f"fact key {fact_key!r} is already declared on this object",
                )
            fact_keys.add(fact_key)
        _expect_non_empty_string(fact.get("labelZh"), f"{fact_path}.labelZh", issues)
        _expect_number(fact.get("value"), f"{fact_path}.value", issues)
        _expect_non_empty_string(fact.get("unit"), f"{fact_path}.unit", issues)
        _expect_non_empty_string(fact.get("displayZh"), f"{fact_path}.displayZh", issues)
        fact_nature = _validate_provenance(
            fact.get("provenance"),
            f"{fact_path}.provenance",
            sources_by_id,
            issues,
        )
        if object_nature == "fictional" and fact_nature not in {None, "fictional"}:
            _add_issue(
                issues,
                "fictional_fact_requires_fictional_provenance",
                f"{fact_path}.provenance.nature",
                "a fictional object's science facts must remain fictional",
            )


def _validate_provenance(
    value: object,
    path: str,
    sources_by_id: Mapping[str, SourceMetadata],
    issues: list[ValidationIssue],
) -> str | None:
    if not isinstance(value, Mapping):
        _add_issue(issues, "invalid_type", path, "provenance must be an object")
        return None

    _require_fields(value, PROVENANCE_FIELDS, path, issues)
    nature = _expect_non_empty_string(value.get("nature"), f"{path}.nature", issues)
    source_id = _expect_non_empty_string(value.get("sourceId"), f"{path}.sourceId", issues)
    _expect_non_empty_string(value.get("noteZh"), f"{path}.noteZh", issues)

    valid_nature = nature if nature in DATA_NATURES else None
    if nature is not None and valid_nature is None:
        _add_issue(
            issues,
            "invalid_data_nature",
            f"{path}.nature",
            f"data nature must be one of {sorted(DATA_NATURES)}",
        )
    if source_id is not None:
        source = sources_by_id.get(source_id)
        if source is None:
            _add_issue(
                issues,
                "unknown_source",
                f"{path}.sourceId",
                f"source {source_id!r} is not declared in $.sources",
            )
        elif valid_nature == "observed":
            if source.url is None or not _is_public_http_source_url(source.url):
                _add_issue(
                    issues,
                    "observed_requires_public_source",
                    f"{path}.sourceId",
                    "observed data must reference an absolute public HTTP(S) source",
                )
            if source.accessed_at_utc is None or not _is_utc_timestamp(
                source.accessed_at_utc
            ):
                _add_issue(
                    issues,
                    "observed_source_requires_access_time",
                    f"{path}.sourceId",
                    "observed data source must include a valid UTC access timestamp",
                )
    return valid_nature


def _validate_parent_reference(
    parent_id: str | None,
    system_id: str,
    systems_by_object: Mapping[str, str],
    path: str,
    relationship: str,
    issues: list[ValidationIssue],
) -> None:
    if parent_id is None:
        return
    parent_system_id = systems_by_object.get(parent_id)
    if parent_system_id is None:
        code = "unknown_parent" if relationship == "parent" else "unknown_orbit_parent"
        _add_issue(
            issues,
            code,
            path,
            f"referenced object {parent_id!r} does not exist",
        )
        return
    if parent_system_id != system_id:
        code = (
            "cross_system_parent"
            if relationship == "parent"
            else "cross_system_orbit_parent"
        )
        _add_issue(
            issues,
            code,
            path,
            f"referenced object belongs to system {parent_system_id!r}, not {system_id!r}",
        )


def _validate_reference_cycles(
    references_by_object: Mapping[str, str | None],
    issue_code: str,
    relationship_label: str,
    issues: list[ValidationIssue],
) -> None:
    reported: set[frozenset[str]] = set()
    for start_id in references_by_object:
        order: list[str] = []
        positions: dict[str, int] = {}
        current_id: str | None = start_id
        while current_id is not None and current_id in references_by_object:
            if current_id in positions:
                cycle = frozenset(order[positions[current_id] :])
                if cycle and cycle not in reported:
                    reported.add(cycle)
                    _add_issue(
                        issues,
                        issue_code,
                        "$.objects",
                        f"{relationship_label} contains a cycle through {sorted(cycle)!r}",
                    )
                break
            positions[current_id] = len(order)
            order.append(current_id)
            current_id = references_by_object[current_id]


def _validate_finite_numbers(
    value: object, path: str, issues: list[ValidationIssue]
) -> None:
    if _is_number(value):
        try:
            finite = math.isfinite(value)
        except OverflowError:
            finite = False
        if not finite:
            _add_issue(
                issues,
                "non_finite_number",
                path,
                "numeric values must be finite",
            )
        return
    if isinstance(value, Mapping):
        for key, child in value.items():
            child_path = f"{path}.{key}" if isinstance(key, str) else f"{path}[{key!r}]"
            _validate_finite_numbers(child, child_path, issues)
    elif _is_sequence(value):
        for index, child in enumerate(value):
            _validate_finite_numbers(child, f"{path}[{index}]", issues)


def _require_fields(
    value: Mapping[object, object],
    fields: Sequence[str],
    path: str,
    issues: list[ValidationIssue],
) -> None:
    for field in fields:
        if field not in value:
            _add_issue(
                issues,
                "missing_field",
                f"{path}.{field}",
                f"required field {field!r} is missing",
            )


def _expect_non_empty_string(
    value: object, path: str, issues: list[ValidationIssue]
) -> str | None:
    if not isinstance(value, str):
        _add_issue(issues, "invalid_type", path, "value must be a string")
        return None
    if not value.strip():
        _add_issue(issues, "empty_string", path, "value must not be empty")
        return None
    return value


def _expect_nullable_string(
    value: object, path: str, issues: list[ValidationIssue]
) -> str | None:
    if value is None:
        return None
    return _expect_non_empty_string(value, path, issues)


def _expect_string_array(
    value: object, path: str, issues: list[ValidationIssue]
) -> None:
    if not _is_sequence(value):
        _add_issue(issues, "invalid_type", path, "value must be an array of strings")
        return
    for index, item in enumerate(value):
        _expect_non_empty_string(item, f"{path}[{index}]", issues)


def _expect_argb(value: object, path: str, issues: list[ValidationIssue]) -> None:
    if not isinstance(value, int) or isinstance(value, bool):
        _add_issue(issues, "invalid_type", path, "ARGB value must be an integer")
        return
    if not 0 <= value <= 0xFFFFFFFF:
        _add_issue(
            issues,
            "invalid_number_range",
            path,
            "ARGB value must fit an unsigned 32-bit integer",
        )


def _expect_bool(value: object, path: str, issues: list[ValidationIssue]) -> None:
    if not isinstance(value, bool):
        _add_issue(issues, "invalid_type", path, "value must be a boolean")


def _expect_number(
    value: object, path: str, issues: list[ValidationIssue]
) -> int | float | None:
    if not _is_number(value):
        _add_issue(issues, "invalid_type", path, "value must be a number")
        return None
    return value


def _is_number(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def _is_sequence(value: object) -> bool:
    return isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray))


def _is_supported_source_url(value: str) -> bool:
    parsed = urlparse(value)
    if parsed.scheme in {"http", "https"}:
        return bool(parsed.netloc)
    if parsed.scheme == "urn":
        return bool(parsed.path and ":" in parsed.path)
    return False


def _is_public_http_source_url(value: str) -> bool:
    parsed = urlparse(value)
    return parsed.scheme in {"http", "https"} and bool(parsed.netloc)


def _is_utc_timestamp(value: str) -> bool:
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return False
    return parsed.tzinfo is not None and parsed.utcoffset() == timedelta(0)


def _add_issue(
    issues: list[ValidationIssue], code: str, path: str, message: str
) -> None:
    issues.append(ValidationIssue(code=code, path=path, message=message))


def main(argv: Sequence[str] | None = None) -> int:
    default_catalog = Path(__file__).resolve().parents[2] / "data" / "solar_system_catalog.json"
    parser = argparse.ArgumentParser(description="Validate the AstroNav catalog JSON.")
    parser.add_argument("catalog", nargs="?", type=Path, default=default_catalog)
    arguments = parser.parse_args(argv)

    try:
        document = load_catalog(arguments.catalog)
    except CatalogJsonError as error:
        print(error, file=sys.stderr)
        return 2

    issues = validate_catalog(document)
    if issues:
        for issue in issues:
            print(issue, file=sys.stderr)
        print(
            f"Catalog validation failed with {len(issues)} issue(s).",
            file=sys.stderr,
        )
        return 1

    print(f"Catalog is valid: {arguments.catalog}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
