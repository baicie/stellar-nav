use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::OnceLock;

pub const CATALOG_VERSION: &str = "2026.08-solar-mvp";
pub const SCHEMA_VERSION: u16 = 1;

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum DataNature {
    Observed,
    Derived,
    Simulated,
    Fictional,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct SourceRef {
    pub id: String,
    pub label: String,
    pub url: String,
    pub accessed_at_utc: String,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Provenance {
    pub nature: DataNature,
    pub source_id: String,
    pub note_zh: String,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum ObjectKind {
    Star,
    Planet,
    DwarfPlanet,
    Moon,
    Asteroid,
    OrbitalStation,
    SurfaceBase,
    Relay,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Orbit {
    pub parent_id: String,
    pub semi_major_axis_au: f64,
    pub eccentricity: f64,
    pub orbital_period_days: f64,
    pub inclination_deg: f64,
    pub phase_at_j2000_rad: f64,
    pub provenance: Provenance,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ScienceFact {
    pub key: String,
    pub label_zh: String,
    pub value: f64,
    pub unit: String,
    pub display_zh: String,
    pub provenance: Provenance,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct CelestialObject {
    pub id: String,
    pub system_id: String,
    pub parent_id: Option<String>,
    pub name_zh: String,
    pub name_en: String,
    pub aliases: Vec<String>,
    pub kind: ObjectKind,
    pub description_zh: String,
    pub accent_argb: u32,
    pub map_radius: f64,
    pub reachable: bool,
    pub status_zh: String,
    pub orbit: Option<Orbit>,
    pub facts: Vec<ScienceFact>,
    pub provenance: Provenance,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct CatalogDocument {
    version: String,
    sources: Vec<SourceRef>,
    objects: Vec<CelestialObject>,
}

#[derive(Clone, Debug)]
pub struct Catalog {
    version: String,
    sources: Vec<SourceRef>,
    objects: Vec<CelestialObject>,
    object_index: HashMap<String, usize>,
}

impl Catalog {
    pub fn version(&self) -> &str {
        &self.version
    }

    pub fn sources(&self) -> &[SourceRef] {
        &self.sources
    }

    pub fn objects(&self) -> &[CelestialObject] {
        &self.objects
    }

    pub fn object(&self, id: &str) -> Option<&CelestialObject> {
        self.object_index.get(id).map(|index| &self.objects[*index])
    }

    pub fn source(&self, id: &str) -> Option<&SourceRef> {
        self.sources.iter().find(|source| source.id == id)
    }
}

pub fn catalog() -> &'static Catalog {
    static CATALOG: OnceLock<Catalog> = OnceLock::new();
    CATALOG.get_or_init(|| {
        let document: CatalogDocument =
            serde_json::from_str(include_str!("../../../../data/solar_system_catalog.json"))
                .expect("bundled solar catalog must be valid");
        assert_eq!(document.version, CATALOG_VERSION);

        let object_index = document
            .objects
            .iter()
            .enumerate()
            .map(|(index, object)| (object.id.clone(), index))
            .collect();

        Catalog {
            version: document.version,
            sources: document.sources,
            objects: document.objects,
            object_index,
        }
    })
}

pub fn provenance(nature: DataNature, source_id: &str, note_zh: &str) -> Provenance {
    Provenance {
        nature,
        source_id: source_id.to_owned(),
        note_zh: note_zh.to_owned(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bundled_catalog_is_versioned_and_connected() {
        let catalog = catalog();
        assert_eq!(catalog.version(), CATALOG_VERSION);
        assert!(catalog.objects().len() >= 14);

        for object in catalog.objects() {
            assert_eq!(object.system_id, "sol");
            assert!(object.facts.len() >= 3);
            assert!(catalog.source(&object.provenance.source_id).is_some());
            if let Some(parent_id) = &object.parent_id {
                assert!(catalog.object(parent_id).is_some());
            }
            if let Some(orbit) = &object.orbit {
                assert!(catalog.source(&orbit.provenance.source_id).is_some());
            }
        }
    }

    #[test]
    fn fictional_facilities_never_claim_observed_provenance() {
        for object in catalog()
            .objects()
            .iter()
            .filter(|item| matches!(item.kind, ObjectKind::SurfaceBase | ObjectKind::Relay))
        {
            assert_eq!(object.provenance.nature, DataNature::Fictional);
        }
    }

    #[test]
    fn bundled_observed_values_use_public_sources_with_access_times() {
        let catalog = catalog();
        let assert_observed_source = |provenance: &Provenance| {
            if provenance.nature != DataNature::Observed {
                return;
            }
            let source = catalog
                .source(&provenance.source_id)
                .expect("observed provenance must reference a declared source");
            assert!(source.url.starts_with("http://") || source.url.starts_with("https://"));
            assert!(!source.accessed_at_utc.trim().is_empty());
        };

        for object in catalog.objects() {
            assert_observed_source(&object.provenance);
            if let Some(orbit) = &object.orbit {
                assert_observed_source(&orbit.provenance);
            }
            for fact in &object.facts {
                assert_observed_source(&fact.provenance);
            }
        }
    }

    #[test]
    fn bundled_fictional_objects_keep_orbits_and_facts_fictional() {
        for object in catalog()
            .objects()
            .iter()
            .filter(|item| item.provenance.nature == DataNature::Fictional)
        {
            if let Some(orbit) = &object.orbit {
                assert_eq!(orbit.provenance.nature, DataNature::Fictional);
            }
            assert!(
                object
                    .facts
                    .iter()
                    .all(|fact| fact.provenance.nature == DataNature::Fictional),
                "fictional object {} contains a non-fictional fact",
                object.id
            );
        }
    }

    #[test]
    fn earth_status_is_static_object_metadata() {
        assert_eq!(catalog().object("sol/earth").unwrap().status_zh, "自然天体");
    }
}
