use astro_core::{catalog, provenance, DataNature, Provenance};
use ephemeris_engine::position_at;
use serde::{Deserialize, Serialize};
use std::cmp::Ordering;
use std::collections::{BTreeMap, BTreeSet};
use time_engine::{transfer_window, WindowAssessment};

const AU_KM: f64 = 149_597_870.7;
const SUN_MU_KM3_S2: f64 = 132_712_440_018.0;
const SECONDS_PER_DAY: f64 = 86_400.0;
const LIGHT_SECONDS_PER_AU: f64 = 499.004_783_8;
const MOON_ID: &str = "sol/earth/moon";
const L1_RELAY_ID: &str = "sol/earth-moon-l1/relay";
const SCORE_EPSILON: f64 = 1.0e-12;

#[derive(Clone, Copy, Debug, Deserialize, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub enum RouteStrategy {
    Fastest,
    FuelEfficient,
    Safest,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct RouteWaypoint {
    pub label_zh: String,
    pub object_id: Option<String>,
    pub progress: f64,
    pub action_zh: String,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct RoutePlan {
    pub id: String,
    pub strategy: RouteStrategy,
    pub title_zh: String,
    pub summary_zh: String,
    pub origin_id: String,
    pub destination_id: String,
    pub departure_day_from_j2000: f64,
    pub duration_days: f64,
    pub distance_au: f64,
    pub delta_v_kms: f64,
    pub communication_delay_min_seconds: f64,
    pub communication_delay_max_seconds: f64,
    pub risk_score: f64,
    pub recommendation_score: f64,
    pub stops: u8,
    pub window: WindowAssessment,
    pub waypoints: Vec<RouteWaypoint>,
    pub provenance: Provenance,
    pub disclaimer_zh: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum RouteNodeRole {
    Endpoint,
    Relay,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RouteNode {
    pub object_id: String,
    pub role: RouteNodeRole,
    pub waypoint_label_zh: String,
    pub action_zh: String,
}

impl RouteNode {
    fn endpoint(object_id: &str, label_zh: &str) -> Self {
        Self {
            object_id: object_id.into(),
            role: RouteNodeRole::Endpoint,
            waypoint_label_zh: label_zh.into(),
            action_zh: "进入目标影响域并执行制动".into(),
        }
    }

    fn relay(object_id: &str, label_zh: &str, action_zh: &str) -> Self {
        Self {
            object_id: object_id.into(),
            role: RouteNodeRole::Relay,
            waypoint_label_zh: label_zh.into(),
            action_zh: action_zh.into(),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct EdgeCosts {
    pub duration_days: f64,
    pub delta_v_kms: f64,
    pub distance_au: f64,
    pub risk_score: f64,
    pub communication_proxy: f64,
    pub window_proxy: f64,
}

impl EdgeCosts {
    const fn zero() -> Self {
        Self {
            duration_days: 0.0,
            delta_v_kms: 0.0,
            distance_au: 0.0,
            risk_score: 0.0,
            communication_proxy: 0.0,
            window_proxy: 0.0,
        }
    }

    fn add(self, other: Self) -> Self {
        Self {
            duration_days: self.duration_days + other.duration_days,
            delta_v_kms: self.delta_v_kms + other.delta_v_kms,
            distance_au: self.distance_au + other.distance_au,
            risk_score: self.risk_score + other.risk_score,
            communication_proxy: self.communication_proxy + other.communication_proxy,
            window_proxy: self.window_proxy + other.window_proxy,
        }
    }

    fn is_valid(self) -> bool {
        self.duration_days.is_finite()
            && self.duration_days > 0.0
            && self.delta_v_kms.is_finite()
            && self.delta_v_kms >= 0.0
            && self.distance_au.is_finite()
            && self.distance_au >= 0.0
            && self.risk_score.is_finite()
            && self.risk_score >= 0.0
            && self.communication_proxy.is_finite()
            && self.communication_proxy >= 0.0
            && self.window_proxy.is_finite()
            && self.window_proxy >= 0.0
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TransferMode {
    Express,
    Efficient,
    Conservative,
    RelayChecked,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VehicleRange {
    LocalSystem,
    Interplanetary,
}

impl VehicleRange {
    fn allows(self, required: Self) -> bool {
        matches!(
            (self, required),
            (Self::Interplanetary, _) | (Self::LocalSystem, Self::LocalSystem)
        )
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct RouteEdge {
    pub id: String,
    pub from: String,
    pub to: String,
    pub mode: TransferMode,
    pub required_range: VehicleRange,
    pub costs: EdgeCosts,
}

#[derive(Clone, Debug, Default)]
pub struct RouteGraph {
    nodes: BTreeMap<String, RouteNode>,
    edges: Vec<RouteEdge>,
}

impl RouteGraph {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add_node(&mut self, node: RouteNode) -> bool {
        let id = node.object_id.clone();
        if self.nodes.contains_key(&id) {
            return false;
        }
        self.nodes.insert(id, node);
        true
    }

    pub fn add_edge(&mut self, edge: RouteEdge) -> bool {
        if !self.nodes.contains_key(&edge.from)
            || !self.nodes.contains_key(&edge.to)
            || edge.from == edge.to
            || !edge.costs.is_valid()
            || self.edges.iter().any(|existing| existing.id == edge.id)
        {
            return false;
        }
        self.edges.push(edge);
        true
    }
}

#[derive(Clone, Copy, Debug)]
pub struct VehicleProfile {
    pub id: &'static str,
    pub range: VehicleRange,
    pub allowed_anchor_ids: &'static [&'static str],
    pub duration_factor: f64,
    pub delta_v_factor: f64,
    pub risk_factor: f64,
    pub max_delta_v_per_edge_kms: f64,
    pub supported_modes: &'static [TransferMode],
}

impl VehicleProfile {
    fn allows_route(&self, origin_id: &str, destination_id: &str) -> bool {
        if self.allowed_anchor_ids.is_empty() {
            return true;
        }
        let Some(origin_anchor) = heliocentric_anchor(origin_id) else {
            return false;
        };
        let Some(destination_anchor) = heliocentric_anchor(destination_id) else {
            return false;
        };
        origin_anchor == destination_anchor && self.allowed_anchor_ids.contains(&origin_anchor)
    }
}

const ALL_TRANSFER_MODES: &[TransferMode] = &[
    TransferMode::Express,
    TransferMode::Efficient,
    TransferMode::Conservative,
    TransferMode::RelayChecked,
];

const VEHICLE_PROFILES: &[VehicleProfile] = &[
    VehicleProfile {
        id: "aurora-demo",
        range: VehicleRange::Interplanetary,
        allowed_anchor_ids: &[],
        duration_factor: 1.0,
        delta_v_factor: 1.0,
        risk_factor: 1.0,
        max_delta_v_per_edge_kms: 48.0,
        supported_modes: ALL_TRANSFER_MODES,
    },
    VehicleProfile {
        id: "luna-shuttle-demo",
        range: VehicleRange::LocalSystem,
        allowed_anchor_ids: &["sol/earth"],
        duration_factor: 0.92,
        delta_v_factor: 1.06,
        risk_factor: 0.86,
        max_delta_v_per_edge_kms: 6.0,
        supported_modes: ALL_TRANSFER_MODES,
    },
];

pub fn vehicle_profile(id: &str) -> Option<&'static VehicleProfile> {
    VEHICLE_PROFILES.iter().find(|profile| profile.id == id)
}

#[derive(Clone, Copy, Debug)]
struct TransitNodeSpec {
    object_id: &'static str,
    boundary_root_id: &'static str,
    waypoint_label_zh: &'static str,
    action_zh: &'static str,
}

const TRANSIT_NODES: &[TransitNodeSpec] = &[TransitNodeSpec {
    object_id: L1_RELAY_ID,
    boundary_root_id: MOON_ID,
    waypoint_label_zh: "L1 通信确认",
    action_zh: "通过中继站完成状态复核",
}];

#[derive(Clone, Copy, Debug)]
struct TransferBaseline {
    duration_days: f64,
    delta_v_kms: f64,
    distance_au: f64,
    required_range: VehicleRange,
}

#[derive(Clone, Copy, Debug)]
struct StrategyWeights {
    duration: f64,
    delta_v: f64,
    risk: f64,
    communication: f64,
    window: f64,
}

impl StrategyWeights {
    fn for_strategy(strategy: RouteStrategy) -> Self {
        match strategy {
            RouteStrategy::Fastest => Self {
                duration: 0.72,
                delta_v: 0.12,
                risk: 0.08,
                communication: 0.03,
                window: 0.05,
            },
            RouteStrategy::FuelEfficient => Self {
                duration: 0.15,
                delta_v: 0.65,
                risk: 0.08,
                communication: 0.04,
                window: 0.08,
            },
            RouteStrategy::Safest => Self {
                duration: 0.10,
                delta_v: 0.08,
                risk: 0.55,
                communication: 0.20,
                window: 0.07,
            },
        }
    }
}

#[derive(Clone, Debug)]
struct SearchPath {
    node_ids: Vec<String>,
    edge_indices: Vec<usize>,
    costs: EdgeCosts,
}

struct PlanningContext<'a> {
    graph: &'a RouteGraph,
    origin_id: &'a str,
    destination_id: &'a str,
    departure_day_from_j2000: f64,
    window: &'a WindowAssessment,
    vehicle: &'a VehicleProfile,
    reference: TransferBaseline,
}

pub fn plan_routes(
    origin_id: &str,
    destination_id: &str,
    departure_day_from_j2000: f64,
    vehicle_id: &str,
) -> Option<Vec<RoutePlan>> {
    if !departure_day_from_j2000.is_finite() || origin_id == destination_id {
        return None;
    }
    let origin = catalog().object(origin_id)?;
    let destination = catalog().object(destination_id)?;
    if !origin.reachable || !destination.reachable {
        return None;
    }
    let vehicle = vehicle_profile(vehicle_id)?;
    if !vehicle.allows_route(origin_id, destination_id) {
        return None;
    }
    let window = transfer_window(origin_id, destination_id, departure_day_from_j2000)?;
    let baseline = transfer_baseline(origin_id, destination_id, departure_day_from_j2000)?;
    let graph = build_route_graph(
        origin_id,
        destination_id,
        departure_day_from_j2000,
        &window,
        baseline,
    )?;
    let context = PlanningContext {
        graph: &graph,
        origin_id,
        destination_id,
        departure_day_from_j2000,
        window: &window,
        vehicle,
        reference: baseline,
    };

    [
        RouteStrategy::Fastest,
        RouteStrategy::FuelEfficient,
        RouteStrategy::Safest,
    ]
    .into_iter()
    .map(|strategy| {
        let path = shortest_path(
            context.graph,
            context.origin_id,
            context.destination_id,
            strategy,
            context.vehicle,
            context.reference,
        )?;
        Some(build_plan(&context, &path, strategy))
    })
    .collect()
}

fn build_route_graph(
    origin_id: &str,
    destination_id: &str,
    day_from_j2000: f64,
    window: &WindowAssessment,
    direct_baseline: TransferBaseline,
) -> Option<RouteGraph> {
    let origin = catalog().object(origin_id)?;
    let destination = catalog().object(destination_id)?;
    let mut graph = RouteGraph::new();
    graph.add_node(RouteNode::endpoint(origin_id, &origin.name_zh));
    graph.add_node(RouteNode::endpoint(destination_id, &destination.name_zh));

    for mode in [
        TransferMode::Express,
        TransferMode::Efficient,
        TransferMode::Conservative,
    ] {
        let added = graph.add_edge(direct_edge(
            origin_id,
            destination_id,
            mode,
            direct_baseline,
            window,
        ));
        debug_assert!(added);
    }

    for spec in TRANSIT_NODES {
        if origin_id == spec.object_id
            || destination_id == spec.object_id
            || !crosses_boundary(origin_id, destination_id, spec.boundary_root_id)
        {
            continue;
        }
        let relay = catalog().object(spec.object_id)?;
        let first_baseline = transfer_baseline(origin_id, spec.object_id, day_from_j2000)?;
        let second_baseline = transfer_baseline(spec.object_id, destination_id, day_from_j2000)?;
        graph.add_node(RouteNode::relay(
            spec.object_id,
            spec.waypoint_label_zh,
            spec.action_zh,
        ));
        let first_added = graph.add_edge(relay_edge(
            &format!("relay:{}:entry", relay.id),
            origin_id,
            spec.object_id,
            first_baseline,
            window,
        ));
        let second_added = graph.add_edge(relay_edge(
            &format!("relay:{}:exit", relay.id),
            spec.object_id,
            destination_id,
            second_baseline,
            window,
        ));
        debug_assert!(first_added && second_added);
    }
    Some(graph)
}

fn direct_edge(
    origin_id: &str,
    destination_id: &str,
    mode: TransferMode,
    baseline: TransferBaseline,
    window: &WindowAssessment,
) -> RouteEdge {
    let (duration_factor, delta_v_factor, risk_score, communication, sensitivity) = match mode {
        TransferMode::Express => (0.68, 1.28, 46.0, 0.30, 1.25),
        TransferMode::Efficient => (1.00, 0.92, 28.0, 0.24, 1.00),
        TransferMode::Conservative => (1.10, 1.05, 22.0, 0.16, 0.80),
        TransferMode::RelayChecked => unreachable!("relay edges use relay_edge"),
    };
    RouteEdge {
        id: format!("direct:{mode:?}").to_lowercase(),
        from: origin_id.into(),
        to: destination_id.into(),
        mode,
        required_range: baseline.required_range,
        costs: EdgeCosts {
            duration_days: baseline.duration_days * duration_factor,
            delta_v_kms: baseline.delta_v_kms * delta_v_factor,
            distance_au: baseline.distance_au,
            risk_score,
            communication_proxy: communication,
            window_proxy: (1.0 - window.quality).clamp(0.0, 1.0) * sensitivity,
        },
    }
}

fn relay_edge(
    id: &str,
    from: &str,
    to: &str,
    baseline: TransferBaseline,
    window: &WindowAssessment,
) -> RouteEdge {
    RouteEdge {
        id: id.into(),
        from: from.into(),
        to: to.into(),
        mode: TransferMode::RelayChecked,
        required_range: baseline.required_range,
        costs: EdgeCosts {
            duration_days: baseline.duration_days * 0.82,
            delta_v_kms: baseline.delta_v_kms * 0.72,
            distance_au: baseline.distance_au,
            risk_score: 6.0,
            communication_proxy: 0.025,
            window_proxy: (1.0 - window.quality).clamp(0.0, 1.0) * 0.4,
        },
    }
}

fn transfer_baseline(
    origin_id: &str,
    destination_id: &str,
    day_from_j2000: f64,
) -> Option<TransferBaseline> {
    let origin_anchor = heliocentric_anchor(origin_id)?;
    let destination_anchor = heliocentric_anchor(destination_id)?;
    if origin_anchor == destination_anchor {
        let separation = spatial_separation(origin_id, destination_id, day_from_j2000)?;
        let distance_au = separation.max(0.000_05);
        return Some(TransferBaseline {
            duration_days: (0.72 + distance_au * 1_200.0).clamp(0.8, 8.0),
            delta_v_kms: (2.35 + distance_au.sqrt() * 19.5).clamp(2.4, 5.5),
            distance_au,
            required_range: VehicleRange::LocalSystem,
        });
    }

    let origin_orbit = catalog().object(origin_anchor)?.orbit.as_ref()?;
    let destination_orbit = catalog().object(destination_anchor)?.orbit.as_ref()?;
    let radius_1 = origin_orbit.semi_major_axis_au * AU_KM;
    let radius_2 = destination_orbit.semi_major_axis_au * AU_KM;
    let transfer_axis = (radius_1 + radius_2) * 0.5;
    let transfer_seconds = std::f64::consts::PI * (transfer_axis.powi(3) / SUN_MU_KM3_S2).sqrt();
    let velocity_1 = (SUN_MU_KM3_S2 / radius_1).sqrt();
    let velocity_2 = (SUN_MU_KM3_S2 / radius_2).sqrt();
    let transfer_velocity_1 = (SUN_MU_KM3_S2 * (2.0 / radius_1 - 1.0 / transfer_axis)).sqrt();
    let transfer_velocity_2 = (SUN_MU_KM3_S2 * (2.0 / radius_2 - 1.0 / transfer_axis)).sqrt();
    let delta_v_kms =
        (transfer_velocity_1 - velocity_1).abs() + (velocity_2 - transfer_velocity_2).abs();
    let separation = spatial_separation(origin_id, destination_id, day_from_j2000)?;

    Some(TransferBaseline {
        duration_days: transfer_seconds / SECONDS_PER_DAY,
        delta_v_kms,
        distance_au: separation.max((radius_2 - radius_1).abs() / AU_KM),
        required_range: VehicleRange::Interplanetary,
    })
}

fn spatial_separation(origin_id: &str, destination_id: &str, day: f64) -> Option<f64> {
    let origin = position_at(origin_id, day)?;
    let destination = position_at(destination_id, day)?;
    Some(
        ((origin.x_au - destination.x_au).powi(2)
            + (origin.y_au - destination.y_au).powi(2)
            + (origin.z_au - destination.z_au).powi(2))
        .sqrt(),
    )
}

fn crosses_boundary(origin_id: &str, destination_id: &str, boundary_root_id: &str) -> bool {
    is_descendant_or_self(origin_id, boundary_root_id)
        != is_descendant_or_self(destination_id, boundary_root_id)
}

fn is_descendant_or_self(object_id: &str, ancestor_id: &str) -> bool {
    let mut current = catalog().object(object_id);
    while let Some(object) = current {
        if object.id == ancestor_id {
            return true;
        }
        current = object
            .parent_id
            .as_deref()
            .and_then(|parent_id| catalog().object(parent_id));
    }
    false
}

fn shortest_path(
    graph: &RouteGraph,
    origin_id: &str,
    destination_id: &str,
    strategy: RouteStrategy,
    vehicle: &VehicleProfile,
    reference: TransferBaseline,
) -> Option<SearchPath> {
    if !graph.nodes.contains_key(origin_id) || !graph.nodes.contains_key(destination_id) {
        return None;
    }
    let weights = StrategyWeights::for_strategy(strategy);
    let mut distances = graph
        .nodes
        .keys()
        .map(|id| (id.clone(), f64::INFINITY))
        .collect::<BTreeMap<_, _>>();
    distances.insert(origin_id.into(), 0.0);
    let mut visited = BTreeSet::new();
    let mut predecessors = BTreeMap::<String, usize>::new();

    loop {
        let current = graph
            .nodes
            .keys()
            .filter(|id| !visited.contains(*id))
            .min_by(|left, right| {
                let left_distance = distances.get(*left).copied().unwrap_or(f64::INFINITY);
                let right_distance = distances.get(*right).copied().unwrap_or(f64::INFINITY);
                left_distance
                    .partial_cmp(&right_distance)
                    .unwrap_or(Ordering::Equal)
                    .then_with(|| left.cmp(right))
            })?
            .clone();
        let current_distance = distances[&current];
        if !current_distance.is_finite() {
            return None;
        }
        if current == destination_id {
            break;
        }
        visited.insert(current.clone());

        for (edge_index, edge) in graph
            .edges
            .iter()
            .enumerate()
            .filter(|(_, edge)| edge.from == current)
        {
            let Some(costs) = effective_costs(edge, vehicle) else {
                continue;
            };
            let candidate = current_distance + weighted_score(costs, reference, weights);
            let existing = distances[&edge.to];
            let tie_breaks_before = predecessors
                .get(&edge.to)
                .is_none_or(|existing_index| edge.id < graph.edges[*existing_index].id);
            if candidate + SCORE_EPSILON < existing
                || ((candidate - existing).abs() <= SCORE_EPSILON && tie_breaks_before)
            {
                distances.insert(edge.to.clone(), candidate);
                predecessors.insert(edge.to.clone(), edge_index);
            }
        }
    }

    let mut node_ids = vec![destination_id.into()];
    let mut edge_indices = Vec::new();
    let mut current = destination_id;
    while current != origin_id {
        let edge_index = *predecessors.get(current)?;
        let edge = &graph.edges[edge_index];
        edge_indices.push(edge_index);
        node_ids.push(edge.from.clone());
        current = &edge.from;
    }
    node_ids.reverse();
    edge_indices.reverse();

    let costs = edge_indices
        .iter()
        .try_fold(EdgeCosts::zero(), |total, index| {
            Some(total.add(effective_costs(&graph.edges[*index], vehicle)?))
        })?;
    Some(SearchPath {
        node_ids,
        edge_indices,
        costs,
    })
}

fn effective_costs(edge: &RouteEdge, vehicle: &VehicleProfile) -> Option<EdgeCosts> {
    if !vehicle.range.allows(edge.required_range) || !vehicle.supported_modes.contains(&edge.mode) {
        return None;
    }
    let costs = EdgeCosts {
        duration_days: edge.costs.duration_days * vehicle.duration_factor,
        delta_v_kms: edge.costs.delta_v_kms * vehicle.delta_v_factor,
        distance_au: edge.costs.distance_au,
        risk_score: edge.costs.risk_score * vehicle.risk_factor,
        communication_proxy: edge.costs.communication_proxy,
        window_proxy: edge.costs.window_proxy,
    };
    (costs.delta_v_kms <= vehicle.max_delta_v_per_edge_kms).then_some(costs)
}

fn weighted_score(costs: EdgeCosts, reference: TransferBaseline, weights: StrategyWeights) -> f64 {
    weights.duration * costs.duration_days / reference.duration_days.max(0.001)
        + weights.delta_v * costs.delta_v_kms / reference.delta_v_kms.max(0.001)
        + weights.risk * costs.risk_score / 100.0
        + weights.communication * costs.communication_proxy
        + weights.window * costs.window_proxy
}

fn build_plan(
    context: &PlanningContext<'_>,
    path: &SearchPath,
    strategy: RouteStrategy,
) -> RoutePlan {
    let (title_zh, base_summary_zh) = match strategy {
        RouteStrategy::Fastest => ("最快到达", "缩短巡航时间，接受更高能量与风险余量"),
        RouteStrategy::FuelEfficient => ("最省燃料", "优先选择低 Delta-v 教学转移边"),
        RouteStrategy::Safest => ("最低风险", "增加检查窗口与通信冗余，适合科普任务模拟"),
    };
    let uses_relay = path
        .edge_indices
        .iter()
        .any(|index| context.graph.edges[*index].mode == TransferMode::RelayChecked);
    let summary_zh = if uses_relay {
        format!("{base_summary_zh}；经通信中继节点复核")
    } else {
        format!("{base_summary_zh}；采用直达转移边")
    };
    let risk_score = (path.costs.risk_score + path.costs.window_proxy * 18.0).clamp(3.0, 96.0);
    let duration_ratio = path.costs.duration_days / context.reference.duration_days.max(0.001);
    let delta_v_ratio = path.costs.delta_v_kms / context.reference.delta_v_kms.max(0.001);
    let recommendation_score = (100.0
        - risk_score * 0.48
        - (duration_ratio - 0.68).max(0.0) * 8.0
        - (delta_v_ratio - 0.85).max(0.0) * 10.0)
        .clamp(10.0, 98.0);
    let delay = path.costs.distance_au * LIGHT_SECONDS_PER_AU;
    let waypoints = build_waypoints(
        context.graph,
        path,
        context.origin_id,
        context.destination_id,
        context.vehicle,
    );
    let stops = u8::try_from(path.node_ids.len().saturating_sub(2)).unwrap_or(u8::MAX);

    RoutePlan {
        id: format!(
            "{}:{}:{:?}",
            context.origin_id, context.destination_id, strategy
        )
        .to_lowercase(),
        strategy,
        title_zh: title_zh.into(),
        summary_zh,
        origin_id: context.origin_id.into(),
        destination_id: context.destination_id.into(),
        departure_day_from_j2000: context.departure_day_from_j2000,
        duration_days: path.costs.duration_days,
        distance_au: path.costs.distance_au,
        delta_v_kms: path.costs.delta_v_kms,
        communication_delay_min_seconds: delay * 0.82,
        communication_delay_max_seconds: delay * 1.18,
        risk_score,
        recommendation_score,
        stops,
        window: context.window.clone(),
        waypoints,
        provenance: provenance(
            DataNature::Simulated,
            "astronav-simulation-v1",
            &format!(
                "声明载具 {} 能力约束下，对显式航路图执行确定性多目标搜索；边成本为科普代理",
                context.vehicle.id
            ),
        ),
        disclaimer_zh: "教学模拟，不可用于真实航天任务设计或飞行控制。".into(),
    }
}

fn build_waypoints(
    graph: &RouteGraph,
    path: &SearchPath,
    origin_id: &str,
    destination_id: &str,
    vehicle: &VehicleProfile,
) -> Vec<RouteWaypoint> {
    let mut waypoints = vec![RouteWaypoint {
        label_zh: "离轨机动".into(),
        object_id: Some(origin_id.into()),
        progress: 0.0,
        action_zh: "完成系统检查并执行离轨点火".into(),
    }];
    let mut elapsed = 0.0;
    for (leg_index, edge_index) in path.edge_indices.iter().enumerate() {
        let edge = &graph.edges[*edge_index];
        let costs = effective_costs(edge, vehicle).expect("selected edge remains available");
        elapsed += costs.duration_days;
        let next_id = &path.node_ids[leg_index + 1];
        if next_id == destination_id {
            continue;
        }
        let node = &graph.nodes[next_id];
        waypoints.push(RouteWaypoint {
            label_zh: node.waypoint_label_zh.clone(),
            object_id: Some(node.object_id.clone()),
            progress: (elapsed / path.costs.duration_days).clamp(0.05, 0.95),
            action_zh: node.action_zh.clone(),
        });
    }
    if path.node_ids.len() == 2 {
        waypoints.push(RouteWaypoint {
            label_zh: "转移中段".into(),
            object_id: None,
            progress: 0.5,
            action_zh: "修正航向并更新通信时延".into(),
        });
    }
    waypoints.push(RouteWaypoint {
        label_zh: "抵达制动".into(),
        object_id: Some(destination_id.into()),
        progress: 1.0,
        action_zh: "进入目标影响域并执行制动".into(),
    });
    waypoints
}

fn heliocentric_anchor(id: &str) -> Option<&str> {
    let mut current = catalog().object(id)?;
    loop {
        if current
            .orbit
            .as_ref()
            .is_some_and(|orbit| orbit.parent_id == "sol/sun")
        {
            return Some(current.id.as_str());
        }
        current = catalog().object(current.parent_id.as_deref()?)?;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn earth_to_mars_offers_three_distinct_tradeoffs() {
        let plans = plan_routes("sol/earth", "sol/mars", 9_350.0, "aurora-demo").unwrap();
        assert_eq!(plans.len(), 3);
        assert!(plans[0].duration_days < plans[1].duration_days);
        assert!(plans[1].delta_v_kms < plans[0].delta_v_kms);
        assert!(plans[2].risk_score < plans[0].risk_score);
    }

    #[test]
    fn every_plan_is_clearly_simulated() {
        let plans = plan_routes(
            "sol/earth/iss",
            "sol/earth/moon/artemis-base",
            9_350.0,
            "aurora-demo",
        )
        .unwrap();
        assert!(plans
            .iter()
            .all(|plan| plan.provenance.nature == DataNature::Simulated));
    }

    #[test]
    fn stop_counts_and_provenance_describe_the_generated_route() {
        let plans = plan_routes("sol/earth", "sol/mars", 9_350.0, "aurora-demo").unwrap();

        for plan in plans {
            let intermediate_stops = plan
                .waypoints
                .iter()
                .filter_map(|waypoint| waypoint.object_id.as_deref())
                .filter(|id| *id != plan.origin_id && *id != plan.destination_id)
                .count() as u8;
            assert_eq!(plan.stops, intermediate_stops);
            assert!(plan.provenance.note_zh.contains("航路图"));
            assert!(plan.provenance.note_zh.contains("多目标搜索"));
        }
    }

    #[test]
    fn unknown_nodes_and_vehicles_are_not_supported() {
        assert!(plan_routes("sol/missing", "sol/mars", 9_350.0, "aurora-demo").is_none());
        assert!(plan_routes("sol/earth", "sol/mars", 9_350.0, "unknown-craft").is_none());
    }

    #[test]
    fn declared_vehicle_capabilities_change_availability_and_cost() {
        let aurora = plan_routes(
            "sol/earth/iss",
            "sol/earth/moon/artemis-base",
            9_350.0,
            "aurora-demo",
        )
        .unwrap();
        let lunar_shuttle = plan_routes(
            "sol/earth/iss",
            "sol/earth/moon/artemis-base",
            9_350.0,
            "luna-shuttle-demo",
        )
        .unwrap();

        assert_ne!(aurora[0].duration_days, lunar_shuttle[0].duration_days);
        assert_ne!(aurora[0].delta_v_kms, lunar_shuttle[0].delta_v_kms);
        assert!(plan_routes("sol/earth", "sol/mars", 9_350.0, "luna-shuttle-demo").is_none());
    }

    #[test]
    fn cislunar_vehicle_cannot_execute_a_mars_local_route() {
        assert!(plan_routes(
            "sol/mars",
            "sol/mars/morning-star-port",
            9_350.0,
            "luna-shuttle-demo",
        )
        .is_none());
    }

    #[test]
    fn cislunar_safety_path_uses_l1_in_both_directions_but_fastest_is_direct() {
        for (origin, destination) in [
            ("sol/earth/iss", "sol/earth/moon/artemis-base"),
            ("sol/earth/moon/artemis-base", "sol/earth/iss"),
        ] {
            let plans = plan_routes(origin, destination, 9_350.0, "aurora-demo").unwrap();
            let fastest = plans
                .iter()
                .find(|plan| plan.strategy == RouteStrategy::Fastest)
                .unwrap();
            let safest = plans
                .iter()
                .find(|plan| plan.strategy == RouteStrategy::Safest)
                .unwrap();

            assert_eq!(fastest.stops, 0);
            assert!(!fastest.waypoints.iter().any(|waypoint| {
                waypoint.object_id.as_deref() == Some("sol/earth-moon-l1/relay")
            }));
            assert_eq!(safest.stops, 1);
            assert!(safest.waypoints.iter().any(|waypoint| {
                waypoint.object_id.as_deref() == Some("sol/earth-moon-l1/relay")
            }));
        }
    }

    #[test]
    fn strategy_weights_choose_distinct_parallel_edges() {
        let day = 9_350.0;
        let origin = "sol/earth";
        let destination = "sol/mars";
        let window = transfer_window(origin, destination, day).unwrap();
        let reference = transfer_baseline(origin, destination, day).unwrap();
        let graph = build_route_graph(origin, destination, day, &window, reference).unwrap();
        let vehicle = vehicle_profile("aurora-demo").unwrap();

        let chosen_mode = |strategy| {
            let path =
                shortest_path(&graph, origin, destination, strategy, vehicle, reference).unwrap();
            assert_eq!(path.edge_indices.len(), 1);
            graph.edges[path.edge_indices[0]].mode
        };

        assert_eq!(chosen_mode(RouteStrategy::Fastest), TransferMode::Express);
        assert_eq!(
            chosen_mode(RouteStrategy::FuelEfficient),
            TransferMode::Efficient
        );
        assert_eq!(
            chosen_mode(RouteStrategy::Safest),
            TransferMode::Conservative
        );
    }

    #[test]
    fn graph_search_accepts_a_new_safe_relay_without_a_planner_branch() {
        let mut graph = RouteGraph::new();
        assert!(graph.add_node(RouteNode::endpoint("test/origin", "测试起点")));
        assert!(graph.add_node(RouteNode::endpoint("test/destination", "测试终点")));
        assert!(graph.add_node(RouteNode::relay("test/relay", "测试中继", "执行通信复核")));
        assert!(graph.add_edge(RouteEdge {
            id: "test/direct".into(),
            from: "test/origin".into(),
            to: "test/destination".into(),
            mode: TransferMode::Conservative,
            required_range: VehicleRange::Interplanetary,
            costs: EdgeCosts {
                duration_days: 0.7,
                delta_v_kms: 1.0,
                distance_au: 1.0,
                risk_score: 70.0,
                communication_proxy: 0.5,
                window_proxy: 0.0,
            },
        }));
        for (id, from, to) in [
            ("test/relay-entry", "test/origin", "test/relay"),
            ("test/relay-exit", "test/relay", "test/destination"),
        ] {
            assert!(graph.add_edge(RouteEdge {
                id: id.into(),
                from: from.into(),
                to: to.into(),
                mode: TransferMode::RelayChecked,
                required_range: VehicleRange::Interplanetary,
                costs: EdgeCosts {
                    duration_days: 0.5,
                    delta_v_kms: 0.8,
                    distance_au: 0.5,
                    risk_score: 4.0,
                    communication_proxy: 0.02,
                    window_proxy: 0.0,
                },
            }));
        }
        let reference = TransferBaseline {
            duration_days: 1.0,
            delta_v_kms: 1.0,
            distance_au: 1.0,
            required_range: VehicleRange::Interplanetary,
        };
        let vehicle = vehicle_profile("aurora-demo").unwrap();

        let fastest = shortest_path(
            &graph,
            "test/origin",
            "test/destination",
            RouteStrategy::Fastest,
            vehicle,
            reference,
        )
        .unwrap();
        let safest = shortest_path(
            &graph,
            "test/origin",
            "test/destination",
            RouteStrategy::Safest,
            vehicle,
            reference,
        )
        .unwrap();

        assert_eq!(fastest.node_ids, ["test/origin", "test/destination"]);
        assert_eq!(
            safest.node_ids,
            ["test/origin", "test/relay", "test/destination"]
        );
    }

    #[test]
    fn route_graph_rejects_non_finite_or_negative_edge_costs() {
        let mut graph = RouteGraph::new();
        assert!(graph.add_node(RouteNode::endpoint("test/origin", "测试起点")));
        assert!(graph.add_node(RouteNode::endpoint("test/destination", "测试终点")));

        let edge = |id: &str, costs: EdgeCosts| RouteEdge {
            id: id.into(),
            from: "test/origin".into(),
            to: "test/destination".into(),
            mode: TransferMode::Efficient,
            required_range: VehicleRange::LocalSystem,
            costs,
        };
        let valid_costs = EdgeCosts {
            duration_days: 1.0,
            delta_v_kms: 1.0,
            distance_au: 0.01,
            risk_score: 10.0,
            communication_proxy: 0.1,
            window_proxy: 0.1,
        };

        assert!(!graph.add_edge(edge(
            "test/non-finite",
            EdgeCosts {
                duration_days: f64::NAN,
                ..valid_costs
            },
        )));
        assert!(!graph.add_edge(edge(
            "test/negative",
            EdgeCosts {
                risk_score: -1.0,
                ..valid_costs
            },
        )));
        assert!(graph.add_edge(edge("test/valid", valid_costs)));
    }
}
