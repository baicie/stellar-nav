use astro_engine::api::engine::{
    catalog_json, engine_manifest_json, plan_routes_json, positions_json, search_json,
};
use serde_json::Value;

fn decode(payload: &str) -> Value {
    serde_json::from_str(payload).expect("engine payload should be valid JSON")
}

#[test]
fn catalog_preserves_scope_and_data_nature() {
    let catalog = decode(&catalog_json());
    let objects = catalog["data"].as_array().expect("catalog data");

    assert!(objects.len() >= 14);
    assert!(objects.iter().any(|item| item["id"] == "sol/earth"));
    assert!(objects.iter().any(|item| item["id"] == "sol/mars"));
    assert!(objects
        .iter()
        .any(|item| item["id"] == "sol/earth/moon/artemis-base"));

    for object in objects {
        assert_eq!(object["systemId"], "sol");
        assert!(object.get("provenance").is_some());
        if let Some(orbit) = object.get("orbit").and_then(Value::as_object) {
            let orbit_provenance = orbit
                .get("provenance")
                .and_then(Value::as_object)
                .expect("orbit provenance");
            assert!(orbit_provenance
                .get("nature")
                .and_then(Value::as_str)
                .is_some());
            assert!(orbit_provenance
                .get("sourceId")
                .and_then(Value::as_str)
                .is_some_and(|source_id| !source_id.is_empty()));
            assert!(orbit_provenance
                .get("noteZh")
                .and_then(Value::as_str)
                .is_some_and(|note| !note.is_empty()));
        }
        assert!(object["facts"]
            .as_array()
            .is_some_and(|facts| facts.len() >= 3));
    }

    let fictional_relay = objects
        .iter()
        .find(|object| object["id"] == "sol/earth-moon-l1/relay")
        .expect("fictional relay");
    assert_eq!(
        fictional_relay["orbit"]["provenance"]["nature"],
        "fictional"
    );
}

#[test]
fn positions_are_deterministic_and_time_dependent() {
    let first = positions_json(9_350.0);
    let repeated = positions_json(9_350.0);
    let later = positions_json(9_351.0);

    assert_eq!(first, repeated);
    assert_ne!(first, later);
}

#[test]
fn route_planner_returns_three_science_labeled_strategies() {
    let routes = decode(&plan_routes_json(
        "sol/earth".into(),
        "sol/mars".into(),
        9_350.0,
        "aurora-demo".into(),
    ));
    let data = routes["data"].as_array().expect("route data");

    assert_eq!(routes["schemaVersion"], 1);
    assert_eq!(routes["catalogVersion"], "2026.08-solar-mvp");
    assert!(routes.get("schema_version").is_none());
    assert_eq!(data.len(), 3);
    assert!(data.iter().any(|route| route["strategy"] == "fastest"));
    assert!(data
        .iter()
        .any(|route| route["strategy"] == "fuelEfficient"));
    assert!(data.iter().any(|route| route["strategy"] == "safest"));
    assert!(data
        .iter()
        .all(|route| route["provenance"]["nature"] == "simulated"));
    assert!(data.iter().all(|route| route["provenance"]["noteZh"]
        .as_str()
        .is_some_and(|note| note.contains("航路图") && note.contains("载具"))));
    assert!(data.iter().all(|route| route["disclaimerZh"]
        .as_str()
        .is_some_and(|disclaimer| disclaimer.contains("教学模拟")
            && disclaimer.contains("不可用于真实航天任务"))));
    assert!(data
        .iter()
        .all(|route| route["window"]["provenance"]["nature"] == "simulated"));
    assert!(data.iter().all(|route| route["window"]
        .get("daysToBestWindow")
        .and_then(Value::as_f64)
        .is_some()));
    assert!(data
        .iter()
        .all(|route| route["window"]["provenance"]["noteZh"]
            .as_str()
            .is_some_and(|note| note.contains("教学") && note.contains("不是任务级"))));
}

#[test]
fn cislunar_contract_exposes_strategy_paths_and_rejects_unknown_vehicles() {
    let routes = decode(&plan_routes_json(
        "sol/earth/iss".into(),
        "sol/earth/moon/artemis-base".into(),
        9_350.0,
        "aurora-demo".into(),
    ));
    let data = routes["data"].as_array().expect("cislunar route data");
    let route_for = |strategy: &str| {
        data.iter()
            .find(|route| route["strategy"] == strategy)
            .unwrap_or_else(|| panic!("missing {strategy} route"))
    };
    let uses_l1 = |route: &Value| {
        route["waypoints"].as_array().is_some_and(|waypoints| {
            waypoints
                .iter()
                .any(|waypoint| waypoint["objectId"] == "sol/earth-moon-l1/relay")
        })
    };

    assert_eq!(route_for("fastest")["stops"], 0);
    assert!(!uses_l1(route_for("fastest")));
    assert_eq!(route_for("fuelEfficient")["stops"], 0);
    assert!(!uses_l1(route_for("fuelEfficient")));
    assert_eq!(route_for("safest")["stops"], 1);
    assert!(uses_l1(route_for("safest")));

    let unsupported = decode(&plan_routes_json(
        "sol/earth".into(),
        "sol/mars".into(),
        9_350.0,
        "unknown-craft".into(),
    ));
    assert_eq!(unsupported["data"], serde_json::json!([]));
}

#[test]
fn search_supports_chinese_and_english_aliases() {
    let chinese = decode(&search_json("火星".into()));
    let english = decode(&search_json("mars".into()));

    assert_eq!(chinese["data"][0]["id"], "sol/mars");
    assert_eq!(english["data"][0]["id"], "sol/mars");
}

#[test]
fn manifest_versions_the_bridge_contract() {
    let manifest = decode(&engine_manifest_json());

    assert_eq!(manifest["schemaVersion"], 1);
    assert_eq!(manifest["catalogVersion"], "2026.08-solar-mvp");
    assert_eq!(
        manifest["capabilities"],
        serde_json::json!([
            "catalog",
            "ephemerisApproximation",
            "transferWindows",
            "multiStrategyRoutes",
            "search"
        ])
    );
}
