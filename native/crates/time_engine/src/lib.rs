use astro_core::{catalog, provenance, DataNature, Orbit, Provenance};
use serde::{Deserialize, Serialize};
use std::f64::consts::{PI, TAU};

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum WindowRating {
    Excellent,
    Good,
    Limited,
    Closed,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct WindowAssessment {
    pub quality: f64,
    pub rating: WindowRating,
    pub rating_zh: String,
    pub cycle_days: f64,
    pub days_to_best_window: f64,
    pub provenance: Provenance,
}

#[derive(Clone, Copy, Debug)]
struct WindowGeometry {
    cycle_days: f64,
    phase_at_j2000_rad: f64,
    relative_rate_rad_per_day: f64,
    target_phase_rad: f64,
    provenance_note_zh: &'static str,
}

pub fn transfer_window(
    origin_id: &str,
    destination_id: &str,
    day_from_j2000: f64,
) -> Option<WindowAssessment> {
    if !day_from_j2000.is_finite() {
        return None;
    }
    let origin = catalog().object(origin_id)?;
    let destination = catalog().object(destination_id)?;
    let origin_body = navigation_body(origin.id.as_str())?;
    let destination_body = navigation_body(destination.id.as_str())?;
    let geometry = if origin_body.id != destination_body.id {
        let origin_orbit = origin_body.orbit.as_ref()?;
        let destination_orbit = destination_body.orbit.as_ref()?;
        interplanetary_geometry(origin_orbit, destination_orbit)?
    } else {
        let local_reference = [
            local_orbit_body(origin.id.as_str(), &origin_body.id),
            local_orbit_body(destination.id.as_str(), &origin_body.id),
        ]
        .into_iter()
        .flatten()
        .filter(|body| body.id != origin_body.id)
        .filter_map(|body| body.orbit.as_ref())
        .max_by(|left, right| {
            left.orbital_period_days
                .total_cmp(&right.orbital_period_days)
        });
        local_geometry(local_reference)?
    };
    let current_phase = (geometry.phase_at_j2000_rad
        + geometry.relative_rate_rad_per_day * day_from_j2000)
        .rem_euclid(TAU);
    let phase_error = signed_angle(current_phase - geometry.target_phase_rad);
    let quality = ((phase_error.cos() + 1.0) * 0.5).clamp(0.0, 1.0);
    let raw_days = (geometry.target_phase_rad - current_phase) / geometry.relative_rate_rad_per_day;
    let mut days_to_best_window = raw_days.rem_euclid(geometry.cycle_days);
    if days_to_best_window < 1.0e-8 || geometry.cycle_days - days_to_best_window < 1.0e-8 {
        days_to_best_window = 0.0;
    }
    let (rating, rating_zh) = if quality >= 0.82 {
        (WindowRating::Excellent, "窗口优秀")
    } else if quality >= 0.58 {
        (WindowRating::Good, "窗口良好")
    } else if quality >= 0.28 {
        (WindowRating::Limited, "窗口受限")
    } else {
        (WindowRating::Closed, "暂不推荐")
    };

    Some(WindowAssessment {
        quality,
        rating,
        rating_zh: rating_zh.to_owned(),
        cycle_days: geometry.cycle_days,
        days_to_best_window,
        provenance: provenance(
            DataNature::Simulated,
            "astronav-simulation-v1",
            geometry.provenance_note_zh,
        ),
    })
}

fn interplanetary_geometry(
    origin_orbit: &Orbit,
    destination_orbit: &Orbit,
) -> Option<WindowGeometry> {
    let cycle_days = synodic_period(
        origin_orbit.orbital_period_days,
        destination_orbit.orbital_period_days,
    );
    let relative_rate_rad_per_day =
        TAU / destination_orbit.orbital_period_days - TAU / origin_orbit.orbital_period_days;
    if !cycle_days.is_finite()
        || !relative_rate_rad_per_day.is_finite()
        || relative_rate_rad_per_day.abs() < f64::EPSILON
    {
        return None;
    }

    Some(WindowGeometry {
        cycle_days,
        phase_at_j2000_rad: destination_orbit.phase_at_j2000_rad - origin_orbit.phase_at_j2000_rad,
        relative_rate_rad_per_day,
        target_phase_rad: hohmann_target_phase_rad(origin_orbit, destination_orbit)?,
        provenance_note_zh:
            "基于圆轨道霍曼转移目标相位与目录演示基准相位生成的教学窗口模拟；不是任务级发射窗口",
    })
}

fn local_geometry(local_reference: Option<&Orbit>) -> Option<WindowGeometry> {
    let (cycle_days, phase_at_j2000_rad) = local_reference.map_or((27.321_661, 0.0), |orbit| {
        (orbit.orbital_period_days.max(1.0), orbit.phase_at_j2000_rad)
    });
    if !cycle_days.is_finite() || cycle_days <= 0.0 {
        return None;
    }

    Some(WindowGeometry {
        cycle_days,
        phase_at_j2000_rad,
        relative_rate_rad_per_day: TAU / cycle_days,
        target_phase_rad: 0.0,
        provenance_note_zh:
            "基于局部轨道周期与目录演示基准相位生成的教学时机模拟；不是任务级发射窗口",
    })
}

fn hohmann_target_phase_rad(origin_orbit: &Orbit, destination_orbit: &Orbit) -> Option<f64> {
    let origin_mu = implied_primary_mu(origin_orbit)?;
    let destination_mu = implied_primary_mu(destination_orbit)?;
    let primary_mu = (origin_mu + destination_mu) * 0.5;
    let transfer_axis_au =
        (origin_orbit.semi_major_axis_au + destination_orbit.semi_major_axis_au) * 0.5;
    let transfer_days = PI * (transfer_axis_au.powi(3) / primary_mu).sqrt();
    if !transfer_days.is_finite() {
        return None;
    }

    Some((PI - TAU * transfer_days / destination_orbit.orbital_period_days).rem_euclid(TAU))
}

fn implied_primary_mu(orbit: &Orbit) -> Option<f64> {
    if !orbit.semi_major_axis_au.is_finite()
        || orbit.semi_major_axis_au <= 0.0
        || !orbit.orbital_period_days.is_finite()
        || orbit.orbital_period_days <= 0.0
    {
        return None;
    }
    Some(TAU.powi(2) * orbit.semi_major_axis_au.powi(3) / orbit.orbital_period_days.powi(2))
}

fn signed_angle(angle: f64) -> f64 {
    (angle + PI).rem_euclid(TAU) - PI
}

pub fn synodic_period(first_period_days: f64, second_period_days: f64) -> f64 {
    1.0 / (1.0 / first_period_days - 1.0 / second_period_days).abs()
}

fn navigation_body(id: &str) -> Option<&'static astro_core::CelestialObject> {
    let mut current = catalog().object(id)?;
    loop {
        if current
            .orbit
            .as_ref()
            .is_some_and(|orbit| orbit.parent_id == "sol/sun")
        {
            return Some(current);
        }
        let Some(parent_id) = current.parent_id.as_deref() else {
            return Some(current);
        };
        current = catalog().object(parent_id)?;
    }
}

fn local_orbit_body(id: &str, anchor_id: &str) -> Option<&'static astro_core::CelestialObject> {
    let mut current = catalog().object(id)?;
    loop {
        if current.id == anchor_id {
            return Some(current);
        }
        if current
            .orbit
            .as_ref()
            .is_some_and(|orbit| orbit.parent_id == anchor_id)
        {
            return Some(current);
        }
        current = catalog().object(current.parent_id.as_deref()?)?;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn day_for_relative_phase(origin_id: &str, destination_id: &str, target_phase_rad: f64) -> f64 {
        let origin_orbit = catalog().object(origin_id).unwrap().orbit.as_ref().unwrap();
        let destination_orbit = catalog()
            .object(destination_id)
            .unwrap()
            .orbit
            .as_ref()
            .unwrap();
        let relative_rate =
            TAU / destination_orbit.orbital_period_days - TAU / origin_orbit.orbital_period_days;
        let phase_at_j2000 = destination_orbit.phase_at_j2000_rad - origin_orbit.phase_at_j2000_rad;
        ((target_phase_rad - phase_at_j2000) / relative_rate).rem_euclid(synodic_period(
            origin_orbit.orbital_period_days,
            destination_orbit.orbital_period_days,
        ))
    }

    #[test]
    fn earth_mars_synodic_period_is_about_780_days() {
        let value = synodic_period(365.256, 686.98);
        assert!((value - 779.9).abs() < 1.0);
    }

    #[test]
    fn window_quality_stays_bounded() {
        let window = transfer_window("sol/earth", "sol/mars", 9_350.0).unwrap();
        assert!((0.0..=1.0).contains(&window.quality));
        assert!(window.cycle_days > 700.0);
    }

    #[test]
    fn earth_to_mars_prefers_the_hohmann_target_phase_over_conjunction() {
        let earth_orbit = catalog()
            .object("sol/earth")
            .unwrap()
            .orbit
            .as_ref()
            .unwrap();
        let mars_orbit = catalog()
            .object("sol/mars")
            .unwrap()
            .orbit
            .as_ref()
            .unwrap();
        let model_phase_rad = hohmann_target_phase_rad(earth_orbit, mars_orbit).unwrap();
        assert!((model_phase_rad.to_degrees() - 44.35).abs() < 0.02);
        let hohmann_day = day_for_relative_phase("sol/earth", "sol/mars", model_phase_rad);
        let conjunction_day = day_for_relative_phase("sol/earth", "sol/mars", 0.0);

        let hohmann_window = transfer_window("sol/earth", "sol/mars", hohmann_day).unwrap();
        let conjunction_window = transfer_window("sol/earth", "sol/mars", conjunction_day).unwrap();

        assert!(hohmann_window.quality > 0.999);
        assert!(hohmann_window.days_to_best_window < 0.01);
        assert!(conjunction_window.quality < hohmann_window.quality - 0.1);
    }

    #[test]
    fn teaching_window_with_demonstration_phases_is_simulated() {
        let window = transfer_window("sol/earth", "sol/mars", 9_350.0).unwrap();

        assert_eq!(window.provenance.nature, DataNature::Simulated);
        assert_eq!(window.provenance.source_id, "astronav-simulation-v1");
        assert!(window.provenance.note_zh.contains("教学"));
        assert!(window.provenance.note_zh.contains("不是任务级"));
    }

    #[test]
    fn local_lunar_route_uses_the_moons_orbital_cycle() {
        let window =
            transfer_window("sol/earth/iss", "sol/earth/moon/artemis-base", 9_350.0).unwrap();

        assert!((window.cycle_days - 27.321_661).abs() < 0.01);
    }
}
