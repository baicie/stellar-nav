export interface Vector3 {
  x: number;
  y: number;
  z: number;
}

export type RoutePreference = 'balanced' | 'fastest' | 'safest';

export interface RoutePath {
  id: string;
  label: string;
  strategy: RoutePreference;
  waypoints: readonly Vector3[];
  hazardExposure: number;
  speedMultiplier: number;
  fuelMultiplier: number;
  riskMultiplier: number;
}

export interface VesselProfile {
  cruiseSpeedC: number;
  fuelPerLightYear: number;
  jumpCooldownYears: number;
  reliability: number;
}

export interface RouteMetrics {
  distanceLy: number;
  estimatedYears: number;
  fuelUnits: number;
  riskScore: number;
}

export interface RankedRoute {
  route: RoutePath;
  metrics: RouteMetrics;
  score: number;
}

function assertFinitePositive(value: number, name: string): void {
  if (!Number.isFinite(value) || value <= 0) {
    throw new RangeError(`${name} must be a finite positive number`);
  }
}

function assertUnitInterval(value: number, name: string): void {
  if (!Number.isFinite(value) || value < 0 || value > 1) {
    throw new RangeError(`${name} must be between 0 and 1`);
  }
}

function distanceBetween(from: Vector3, to: Vector3): number {
  return Math.hypot(to.x - from.x, to.y - from.y, to.z - from.z);
}

function validateWaypoints(waypoints: readonly Vector3[]): void {
  if (waypoints.length < 2) {
    throw new RangeError('A route requires at least two waypoints');
  }

  for (const waypoint of waypoints) {
    if (![waypoint.x, waypoint.y, waypoint.z].every(Number.isFinite)) {
      throw new RangeError('Waypoint coordinates must be finite');
    }
  }
}

export function calculateRouteDistance(waypoints: readonly Vector3[]): number {
  validateWaypoints(waypoints);

  let distance = 0;
  for (let index = 1; index < waypoints.length; index += 1) {
    distance += distanceBetween(waypoints[index - 1]!, waypoints[index]!);
  }

  if (distance <= 0) {
    throw new RangeError('A route must cover a positive distance');
  }

  return distance;
}

export function estimateRoute(route: RoutePath, vessel: VesselProfile): RouteMetrics {
  assertFinitePositive(vessel.cruiseSpeedC, 'cruiseSpeedC');
  assertFinitePositive(vessel.fuelPerLightYear, 'fuelPerLightYear');
  if (!Number.isFinite(vessel.jumpCooldownYears) || vessel.jumpCooldownYears < 0) {
    throw new RangeError('jumpCooldownYears must be a finite non-negative number');
  }
  assertUnitInterval(vessel.reliability, 'reliability');
  assertUnitInterval(route.hazardExposure, 'hazardExposure');
  assertFinitePositive(route.speedMultiplier, 'speedMultiplier');
  assertFinitePositive(route.fuelMultiplier, 'fuelMultiplier');
  assertFinitePositive(route.riskMultiplier, 'riskMultiplier');

  const distanceLy = calculateRouteDistance(route.waypoints);
  const intermediateJumps = Math.max(0, route.waypoints.length - 2);
  const estimatedYears =
    distanceLy / (vessel.cruiseSpeedC * route.speedMultiplier) +
    intermediateJumps * vessel.jumpCooldownYears;
  const fuelUnits = distanceLy * vessel.fuelPerLightYear * route.fuelMultiplier;
  const riskScore = Math.min(
    1,
    route.hazardExposure * route.riskMultiplier * (2 - vessel.reliability),
  );

  return { distanceLy, estimatedYears, fuelUnits, riskScore };
}

function normalize(value: number, minimum: number, maximum: number): number {
  return maximum === minimum ? 0 : (value - minimum) / (maximum - minimum);
}

export function rankRoutes(
  routes: readonly RoutePath[],
  vessel: VesselProfile,
  preference: RoutePreference,
): RankedRoute[] {
  const candidates = routes.map((route) => ({ route, metrics: estimateRoute(route, vessel) }));
  if (candidates.length === 0) {
    return [];
  }

  const durations = candidates.map(({ metrics }) => metrics.estimatedYears);
  const fuels = candidates.map(({ metrics }) => metrics.fuelUnits);
  const risks = candidates.map(({ metrics }) => metrics.riskScore);
  const durationRange = [Math.min(...durations), Math.max(...durations)] as const;
  const fuelRange = [Math.min(...fuels), Math.max(...fuels)] as const;
  const riskRange = [Math.min(...risks), Math.max(...risks)] as const;

  return candidates
    .map(({ route, metrics }) => {
      const durationScore = normalize(metrics.estimatedYears, ...durationRange);
      const fuelScore = normalize(metrics.fuelUnits, ...fuelRange);
      const riskScore = normalize(metrics.riskScore, ...riskRange);
      const score =
        preference === 'fastest'
          ? durationScore
          : preference === 'safest'
            ? riskScore
            : durationScore * 0.42 + fuelScore * 0.25 + riskScore * 0.33;

      return { route, metrics, score };
    })
    .sort((left, right) => left.score - right.score || left.route.id.localeCompare(right.route.id));
}

export function sampleRoute(waypoints: readonly Vector3[], progress: number): Vector3 {
  if (!Number.isFinite(progress)) {
    throw new RangeError('progress must be finite');
  }

  const totalDistance = calculateRouteDistance(waypoints);
  const targetDistance = Math.min(1, Math.max(0, progress)) * totalDistance;
  let traveledDistance = 0;

  for (let index = 1; index < waypoints.length; index += 1) {
    const from = waypoints[index - 1]!;
    const to = waypoints[index]!;
    const segmentDistance = distanceBetween(from, to);

    if (segmentDistance > 0 && targetDistance <= traveledDistance + segmentDistance) {
      const segmentProgress = (targetDistance - traveledDistance) / segmentDistance;
      return {
        x: from.x + (to.x - from.x) * segmentProgress,
        y: from.y + (to.y - from.y) * segmentProgress,
        z: from.z + (to.z - from.z) * segmentProgress,
      };
    }

    traveledDistance += segmentDistance;
  }

  return { ...waypoints[waypoints.length - 1]! };
}
