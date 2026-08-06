use astro_core::{catalog, CATALOG_VERSION, SCHEMA_VERSION};
use ephemeris_engine::positions_at;
use flutter_rust_bridge::frb;
use route_engine::plan_routes;
use search_core::search;
use serde::Serialize;
use time_engine::transfer_window;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Envelope<T: Serialize> {
    schema_version: u16,
    catalog_version: &'static str,
    data: T,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct TimedEnvelope<T: Serialize> {
    schema_version: u16,
    catalog_version: &'static str,
    day_from_j2000: f64,
    data: T,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct EngineManifest {
    schema_version: u16,
    catalog_version: &'static str,
    engine_version: &'static str,
    system_id: &'static str,
    capabilities: [&'static str; 5],
}

#[frb(sync)]
pub fn engine_manifest_json() -> String {
    encode(&EngineManifest {
        schema_version: SCHEMA_VERSION,
        catalog_version: CATALOG_VERSION,
        engine_version: env!("CARGO_PKG_VERSION"),
        system_id: "sol",
        capabilities: [
            "catalog",
            "ephemerisApproximation",
            "transferWindows",
            "multiStrategyRoutes",
            "search",
        ],
    })
}

#[frb(sync)]
pub fn catalog_json() -> String {
    encode(&Envelope {
        schema_version: SCHEMA_VERSION,
        catalog_version: CATALOG_VERSION,
        data: catalog().objects(),
    })
}

#[frb(sync)]
pub fn sources_json() -> String {
    encode(&Envelope {
        schema_version: SCHEMA_VERSION,
        catalog_version: CATALOG_VERSION,
        data: catalog().sources(),
    })
}

#[frb(sync)]
pub fn search_json(query: String) -> String {
    encode(&Envelope {
        schema_version: SCHEMA_VERSION,
        catalog_version: CATALOG_VERSION,
        data: search(&query, 16),
    })
}

#[frb(sync)]
pub fn positions_json(day_from_j2000: f64) -> String {
    encode(&TimedEnvelope {
        schema_version: SCHEMA_VERSION,
        catalog_version: CATALOG_VERSION,
        day_from_j2000,
        data: positions_at(day_from_j2000),
    })
}

#[frb(sync)]
pub fn plan_routes_json(
    origin_id: String,
    destination_id: String,
    departure_day_from_j2000: f64,
    vehicle_id: String,
) -> String {
    encode(&TimedEnvelope {
        schema_version: SCHEMA_VERSION,
        catalog_version: CATALOG_VERSION,
        day_from_j2000: departure_day_from_j2000,
        data: plan_routes(
            &origin_id,
            &destination_id,
            departure_day_from_j2000,
            &vehicle_id,
        )
        .unwrap_or_default(),
    })
}

#[frb(sync)]
pub fn transfer_window_json(
    origin_id: String,
    destination_id: String,
    day_from_j2000: f64,
) -> String {
    encode(&TimedEnvelope {
        schema_version: SCHEMA_VERSION,
        catalog_version: CATALOG_VERSION,
        day_from_j2000,
        data: transfer_window(&origin_id, &destination_id, day_from_j2000),
    })
}

#[frb(init, sync)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
    let _ = catalog();
}

fn encode(value: &impl Serialize) -> String {
    serde_json::to_string(value).expect("engine response serialization must succeed")
}
