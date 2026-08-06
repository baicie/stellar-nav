use astro_core::{catalog, provenance, CelestialObject, DataNature, Orbit, Provenance};
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::f64::consts::TAU;
use std::fmt;

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ObjectPosition {
    pub id: String,
    pub x_au: f64,
    pub y_au: f64,
    pub z_au: f64,
    pub distance_to_parent_au: f64,
    pub day_from_j2000: f64,
    pub provenance: Provenance,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum EphemerisError {
    CoordinateReferenceCycle { object_id: String },
}

impl fmt::Display for EphemerisError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::CoordinateReferenceCycle { object_id } => {
                write!(formatter, "coordinate reference cycle through {object_id}")
            }
        }
    }
}

impl std::error::Error for EphemerisError {}

pub fn positions_at(day_from_j2000: f64) -> Vec<ObjectPosition> {
    try_positions_at(day_from_j2000).unwrap_or_default()
}

pub fn try_positions_at(day_from_j2000: f64) -> Result<Vec<ObjectPosition>, EphemerisError> {
    let mut cache = HashMap::new();
    let mut visiting = HashSet::new();
    let catalog = catalog();
    let lookup = |id: &str| catalog.object(id);
    catalog
        .objects()
        .iter()
        .map(|object| resolve_position(object, day_from_j2000, &mut cache, &mut visiting, &lookup))
        .collect()
}

pub fn position_at(id: &str, day_from_j2000: f64) -> Option<ObjectPosition> {
    try_position_at(id, day_from_j2000).ok().flatten()
}

pub fn try_position_at(
    id: &str,
    day_from_j2000: f64,
) -> Result<Option<ObjectPosition>, EphemerisError> {
    let catalog = catalog();
    let Some(object) = catalog.object(id) else {
        return Ok(None);
    };
    let lookup = |parent_id: &str| catalog.object(parent_id);
    resolve_position(
        object,
        day_from_j2000,
        &mut HashMap::new(),
        &mut HashSet::new(),
        &lookup,
    )
    .map(Some)
}

fn resolve_position<'a, F>(
    object: &'a CelestialObject,
    day_from_j2000: f64,
    cache: &mut HashMap<String, ObjectPosition>,
    visiting: &mut HashSet<String>,
    lookup: &F,
) -> Result<ObjectPosition, EphemerisError>
where
    F: Fn(&str) -> Option<&'a CelestialObject>,
{
    if let Some(position) = cache.get(&object.id) {
        return Ok(position.clone());
    }
    if !visiting.insert(object.id.clone()) {
        return Err(EphemerisError::CoordinateReferenceCycle {
            object_id: object.id.clone(),
        });
    }

    let result = (|| {
        let parent_position = match coordinate_parent_id(object).and_then(lookup) {
            Some(parent) => Some(resolve_position(
                parent,
                day_from_j2000,
                cache,
                visiting,
                lookup,
            )?),
            None => None,
        };

        let (local_x, local_y, local_z, distance) = object
            .orbit
            .as_ref()
            .map(|orbit| local_position(orbit, day_from_j2000))
            .unwrap_or_else(|| anchored_offset(object));

        let position_provenance = match &object.provenance.nature {
            DataNature::Fictional => provenance(
                DataNature::Fictional,
                &object.provenance.source_id,
                "虚构对象的地图示意位置；不代表现实坐标",
            ),
            DataNature::Simulated => provenance(
                DataNature::Simulated,
                &object.provenance.source_id,
                "模拟对象的位置由教学模型计算",
            ),
            DataNature::Observed | DataNature::Derived => provenance(
                DataNature::Derived,
                "astronav-derived-v1",
                "由 J2000 教学轨道要素和确定性开普勒模型推导；不是实时星历",
            ),
        };
        Ok(ObjectPosition {
            id: object.id.clone(),
            x_au: parent_position
                .as_ref()
                .map_or(local_x, |parent| parent.x_au + local_x),
            y_au: parent_position
                .as_ref()
                .map_or(local_y, |parent| parent.y_au + local_y),
            z_au: parent_position
                .as_ref()
                .map_or(local_z, |parent| parent.z_au + local_z),
            distance_to_parent_au: distance,
            day_from_j2000,
            provenance: position_provenance,
        })
    })();

    visiting.remove(&object.id);
    if let Ok(position) = &result {
        cache.insert(object.id.clone(), position.clone());
    }
    result
}

fn coordinate_parent_id(object: &CelestialObject) -> Option<&str> {
    object
        .orbit
        .as_ref()
        .map(|orbit| orbit.parent_id.as_str())
        .or(object.parent_id.as_deref())
}

fn local_position(orbit: &Orbit, day_from_j2000: f64) -> (f64, f64, f64, f64) {
    let mean_anomaly = (orbit.phase_at_j2000_rad
        + TAU * day_from_j2000 / orbit.orbital_period_days)
        .rem_euclid(TAU);
    let eccentric_anomaly = solve_eccentric_anomaly(mean_anomaly, orbit.eccentricity);
    let x_orbit = orbit.semi_major_axis_au * (eccentric_anomaly.cos() - orbit.eccentricity);
    let y_orbit = orbit.semi_major_axis_au
        * (1.0 - orbit.eccentricity.powi(2)).sqrt()
        * eccentric_anomaly.sin();
    let inclination = orbit.inclination_deg.to_radians();
    let y = y_orbit * inclination.cos();
    let z = y_orbit * inclination.sin();
    let distance = (x_orbit.powi(2) + y.powi(2) + z.powi(2)).sqrt();
    (x_orbit, y, z, distance)
}

fn solve_eccentric_anomaly(mean_anomaly: f64, eccentricity: f64) -> f64 {
    let mut eccentric_anomaly = mean_anomaly;
    for _ in 0..8 {
        eccentric_anomaly -=
            (eccentric_anomaly - eccentricity * eccentric_anomaly.sin() - mean_anomaly)
                / (1.0 - eccentricity * eccentric_anomaly.cos());
    }
    eccentric_anomaly
}

fn anchored_offset(object: &CelestialObject) -> (f64, f64, f64, f64) {
    if object.parent_id.is_none() {
        return (0.0, 0.0, 0.0, 0.0);
    }

    let hash = object.id.bytes().fold(0_u32, |accumulator, value| {
        accumulator.wrapping_mul(31).wrapping_add(value as u32)
    });
    let angle = (hash % 360) as f64 * TAU / 360.0;
    let distance = 0.00000008;
    (
        distance * angle.cos(),
        distance * angle.sin(),
        0.0,
        distance,
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use astro_core::ObjectKind;

    #[test]
    fn identical_time_produces_identical_positions() {
        assert_eq!(positions_at(9_350.25), positions_at(9_350.25));
    }

    #[test]
    fn moon_position_includes_earth_translation() {
        let earth = position_at("sol/earth", 9_350.0).unwrap();
        let moon = position_at("sol/earth/moon", 9_350.0).unwrap();
        let separation = ((earth.x_au - moon.x_au).powi(2)
            + (earth.y_au - moon.y_au).powi(2)
            + (earth.z_au - moon.z_au).powi(2))
        .sqrt();

        assert!((separation - moon.distance_to_parent_au).abs() < 1.0e-10);
        assert!(separation > 0.0023 && separation < 0.0029);
    }

    #[test]
    fn fictional_facility_positions_remain_fictional() {
        let earth = position_at("sol/earth", 9_350.0).unwrap();
        let lunar_base = position_at("sol/earth/moon/artemis-base", 9_350.0).unwrap();

        assert_eq!(earth.provenance.nature, DataNature::Derived);
        assert_eq!(lunar_base.provenance.nature, DataNature::Fictional);
    }

    #[test]
    fn orbit_reference_parent_takes_precedence_over_hierarchy_parent() {
        let object = CelestialObject {
            id: "test/facility".into(),
            system_id: "test".into(),
            parent_id: Some("test/hierarchy-parent".into()),
            name_zh: "测试设施".into(),
            name_en: "Test Facility".into(),
            aliases: vec![],
            kind: ObjectKind::Relay,
            description_zh: "测试".into(),
            accent_argb: 0,
            map_radius: 1.0,
            reachable: true,
            status_zh: "测试".into(),
            orbit: Some(Orbit {
                parent_id: "test/orbit-parent".into(),
                semi_major_axis_au: 1.0,
                eccentricity: 0.0,
                orbital_period_days: 1.0,
                inclination_deg: 0.0,
                phase_at_j2000_rad: 0.0,
                provenance: provenance(DataNature::Fictional, "test", "测试"),
            }),
            facts: vec![],
            provenance: provenance(DataNature::Fictional, "test", "测试"),
        };

        assert_eq!(coordinate_parent_id(&object), Some("test/orbit-parent"));
    }

    #[test]
    fn coordinate_reference_cycle_returns_an_error() {
        let first = CelestialObject {
            id: "test/first".into(),
            system_id: "test".into(),
            parent_id: None,
            name_zh: "测试对象一".into(),
            name_en: "Test Object One".into(),
            aliases: vec![],
            kind: ObjectKind::Relay,
            description_zh: "测试".into(),
            accent_argb: 0,
            map_radius: 1.0,
            reachable: true,
            status_zh: "测试".into(),
            orbit: Some(Orbit {
                parent_id: "test/second".into(),
                semi_major_axis_au: 1.0,
                eccentricity: 0.0,
                orbital_period_days: 1.0,
                inclination_deg: 0.0,
                phase_at_j2000_rad: 0.0,
                provenance: provenance(DataNature::Fictional, "test", "测试"),
            }),
            facts: vec![],
            provenance: provenance(DataNature::Fictional, "test", "测试"),
        };
        let second = CelestialObject {
            id: "test/second".into(),
            orbit: Some(Orbit {
                parent_id: "test/first".into(),
                ..first.orbit.clone().unwrap()
            }),
            ..first.clone()
        };
        let objects = HashMap::from([(first.id.clone(), first), (second.id.clone(), second)]);

        let result = resolve_position(
            objects.get("test/first").unwrap(),
            0.0,
            &mut HashMap::new(),
            &mut HashSet::new(),
            &|id| objects.get(id),
        );

        assert!(matches!(
            result,
            Err(EphemerisError::CoordinateReferenceCycle { object_id })
                if object_id == "test/first"
        ));
    }
}
