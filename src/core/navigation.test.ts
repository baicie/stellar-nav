import {
  estimateRoute,
  rankRoutes,
  sampleRoute,
  type RoutePath,
  type VesselProfile,
} from './navigation';

const vessel: VesselProfile = {
  cruiseSpeedC: 2,
  fuelPerLightYear: 3,
  jumpCooldownYears: 1,
  reliability: 0.9,
};

function createRoute(overrides: Partial<RoutePath> = {}): RoutePath {
  return {
    id: 'balanced',
    label: '推荐',
    strategy: 'balanced',
    waypoints: [
      { x: 0, y: 0, z: 0 },
      { x: 3, y: 4, z: 0 },
      { x: 3, y: 4, z: 12 },
    ],
    hazardExposure: 0.4,
    speedMultiplier: 1,
    fuelMultiplier: 1.2,
    riskMultiplier: 1.25,
    ...overrides,
  };
}

describe('estimateRoute', () => {
  it('derives distance, duration, fuel, and risk from route geometry', () => {
    const metrics = estimateRoute(createRoute(), vessel);

    expect(metrics.distanceLy).toBe(17);
    expect(metrics.estimatedYears).toBe(9.5);
    expect(metrics.fuelUnits).toBeCloseTo(61.2);
    expect(metrics.riskScore).toBeCloseTo(0.55);
  });

  it('rejects invalid vessel and route inputs instead of returning misleading values', () => {
    expect(() => estimateRoute(createRoute(), { ...vessel, cruiseSpeedC: 0 })).toThrow(RangeError);
    expect(() => estimateRoute(createRoute({ hazardExposure: 1.2 }), vessel)).toThrow(RangeError);
    expect(() => estimateRoute(createRoute({ waypoints: [{ x: 0, y: 0, z: 0 }] }), vessel)).toThrow(
      RangeError,
    );
  });
});

describe('rankRoutes', () => {
  const recommended = createRoute({
    id: 'recommended',
    waypoints: [
      { x: 0, y: 0, z: 0 },
      { x: 120, y: 0, z: 0 },
    ],
    hazardExposure: 0.2,
    fuelMultiplier: 0.85,
  });
  const fastest = createRoute({
    id: 'fastest',
    strategy: 'fastest',
    waypoints: [
      { x: 0, y: 0, z: 0 },
      { x: 90, y: 0, z: 0 },
    ],
    hazardExposure: 0.8,
    fuelMultiplier: 1.3,
  });
  const safest = createRoute({
    id: 'safest',
    strategy: 'safest',
    waypoints: [
      { x: 0, y: 0, z: 0 },
      { x: 130, y: 0, z: 0 },
    ],
    hazardExposure: 0.05,
    fuelMultiplier: 1.1,
  });

  it('orders the same candidates deterministically for each navigation preference', () => {
    const routes = [safest, fastest, recommended];

    expect(rankRoutes(routes, vessel, 'fastest')[0]?.route.id).toBe('fastest');
    expect(rankRoutes(routes, vessel, 'safest')[0]?.route.id).toBe('safest');
    expect(rankRoutes(routes, vessel, 'balanced')[0]?.route.id).toBe('recommended');
  });
});

describe('sampleRoute', () => {
  const waypoints = [
    { x: 0, y: 0, z: 0 },
    { x: 10, y: 0, z: 0 },
    { x: 10, y: 20, z: 0 },
  ];

  it('interpolates by traveled distance rather than waypoint index', () => {
    expect(sampleRoute(waypoints, 0)).toEqual(waypoints[0]);
    expect(sampleRoute(waypoints, 0.5)).toEqual({ x: 10, y: 5, z: 0 });
    expect(sampleRoute(waypoints, 1)).toEqual(waypoints[2]);
  });

  it('clamps finite progress and rejects non-finite progress', () => {
    expect(sampleRoute(waypoints, -1)).toEqual(waypoints[0]);
    expect(sampleRoute(waypoints, 4)).toEqual(waypoints[2]);
    expect(() => sampleRoute(waypoints, Number.NaN)).toThrow(RangeError);
  });
});
