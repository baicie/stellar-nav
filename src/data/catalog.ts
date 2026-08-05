import type { RoutePath, Vector3, VesselProfile } from '../core/navigation';
import type { Provenance } from '../core/provenance';

export interface MapPoint {
  x: number;
  y: number;
}

export interface RouteVisual {
  start: MapPoint;
  control1: MapPoint;
  control2: MapPoint;
  end: MapPoint;
}

export interface RouteOption extends RoutePath {
  summary: string;
  detail: string;
  badge: string;
  accent: 'cyan' | 'amber' | 'coral';
  visual: RouteVisual;
  provenance: Provenance;
}

export interface Destination {
  id: string;
  name: string;
  subtitle: string;
  category: string;
  distanceLy: number;
  description: string;
  mapAnchor: MapPoint;
  catalogProvenance: Provenance;
  mapProvenance: Provenance;
  descriptionProvenance: Provenance;
  routes: readonly RouteOption[];
}

export interface VesselPreset {
  profile: VesselProfile;
  provenance: Provenance;
}

export const DEFAULT_VESSEL: VesselPreset = {
  profile: {
    cruiseSpeedC: 0.001,
    fuelPerLightYear: 0.38,
    jumpCooldownYears: 3,
    reliability: 0.93,
  },
  provenance: {
    nature: 'fictional',
    datasetId: 'vessel-preset-wayward-01',
    sourceName: '缺德导航飞船设定',
    sourceRelease: 'mvp-0.1',
  },
};

const EARTH: Vector3 = { x: 0, y: 0, z: 0 };

function routeProvenance(id: string): Provenance {
  return {
    nature: 'simulated',
    datasetId: `route-sim-${id}`,
    sourceName: '缺德导航演示航路模型',
    sourceRelease: 'mvp-0.1',
    calculationModel: 'deterministic-route-v1',
  };
}

function makeRoute(
  destinationId: string,
  distanceLy: number,
  anchor: MapPoint,
  strategy: RouteOption['strategy'],
): RouteOption {
  const id = `${destinationId}-${strategy === 'balanced' ? 'recommended' : strategy}`;
  const routeConfig = {
    balanced: {
      label: '推荐',
      summary: '燃料与稳定性的中间解',
      detail: '沿着低密度星际走廊，给引擎留一点余量。',
      badge: '综合最优',
      accent: 'cyan' as const,
      hazardExposure: 0.16,
      speedMultiplier: 1,
      fuelMultiplier: 1,
      riskMultiplier: 1,
      visual: {
        start: { x: 0.16, y: 0.72 },
        control1: { x: 0.31, y: 0.61 },
        control2: { x: anchor.x - 0.08, y: anchor.y + 0.08 },
        end: anchor,
      },
      waypoints: [
        EARTH,
        { x: distanceLy * 0.42, y: distanceLy * 0.08, z: distanceLy * 0.03 },
        { x: distanceLy * 0.76, y: distanceLy * -0.04, z: distanceLy * 0.01 },
        { x: distanceLy, y: 0, z: 0 },
      ],
    },
    fastest: {
      label: '最快',
      summary: '直穿高密度引力潮汐区',
      detail: '少绕一点路，多看一眼仪表盘上的红色警告。',
      badge: '时间最短',
      accent: 'amber' as const,
      hazardExposure: 0.78,
      speedMultiplier: 1.85,
      fuelMultiplier: 1.32,
      riskMultiplier: 1.35,
      visual: {
        start: { x: 0.16, y: 0.72 },
        control1: { x: 0.42, y: 0.69 },
        control2: { x: anchor.x - 0.14, y: anchor.y + 0.16 },
        end: anchor,
      },
      waypoints: [
        EARTH,
        { x: distanceLy * 0.54, y: distanceLy * 0.015, z: 0 },
        { x: distanceLy, y: 0, z: 0 },
      ],
    },
    safest: {
      label: '避开黑洞',
      summary: '绕开已知的引力异常区',
      detail: '牺牲一点时间，换来不必和奇点讲道理。',
      badge: '风险最低',
      accent: 'coral' as const,
      hazardExposure: 0.06,
      speedMultiplier: 0.86,
      fuelMultiplier: 1.28,
      riskMultiplier: 0.72,
      visual: {
        start: { x: 0.16, y: 0.72 },
        control1: { x: 0.26, y: 0.83 },
        control2: { x: anchor.x - 0.12, y: anchor.y - 0.11 },
        end: anchor,
      },
      waypoints: [
        EARTH,
        { x: distanceLy * 0.3, y: distanceLy * -0.2, z: distanceLy * 0.05 },
        { x: distanceLy * 0.68, y: distanceLy * 0.22, z: distanceLy * -0.02 },
        { x: distanceLy, y: 0, z: 0 },
      ],
    },
  } satisfies Record<RouteOption['strategy'], Omit<RouteOption, 'id' | 'strategy' | 'provenance'>>;

  return {
    id,
    strategy,
    ...routeConfig[strategy],
    provenance: routeProvenance(id),
  };
}

function makeDestination(
  id: string,
  name: string,
  subtitle: string,
  category: string,
  distanceLy: number,
  description: string,
  mapAnchor: MapPoint,
): Destination {
  return {
    id,
    name,
    subtitle,
    category,
    distanceLy,
    description,
    mapAnchor,
    catalogProvenance: {
      nature: 'derived',
      datasetId: 'stellar-nav-demo-catalog-v0.1',
      sourceName: 'MVP 演示星表',
      sourceRelease: 'approximate-nearby-objects',
      calculationModel: 'catalog-normalized-v1',
    },
    mapProvenance: {
      nature: 'fictional',
      datasetId: 'stellar-nav-map-layout-v0.1',
      sourceName: '缺德导航手工星图布局',
      sourceRelease: 'mvp-0.1',
    },
    descriptionProvenance: {
      nature: 'fictional',
      datasetId: 'stellar-nav-product-copy-v0.1',
      sourceName: '缺德导航产品文案',
      sourceRelease: 'mvp-0.1',
    },
    routes: [
      makeRoute(id, distanceLy, mapAnchor, 'balanced'),
      makeRoute(id, distanceLy, mapAnchor, 'fastest'),
      makeRoute(id, distanceLy, mapAnchor, 'safest'),
    ],
  };
}

export const DESTINATIONS: readonly Destination[] = [
  makeDestination(
    'andromeda',
    '仙女座星系',
    'M31 · 本星系群',
    '河外星系',
    2_540_000,
    '一条还没有人类签收回执的长途线。',
    { x: 0.78, y: 0.28 },
  ),
  makeDestination(
    'proxima',
    '比邻星',
    'Proxima Centauri · 红矮星',
    '邻近恒星',
    4.2465,
    '离家最近的下一站，适合拿来测试跃迁按钮。',
    { x: 0.76, y: 0.25 },
  ),
  makeDestination(
    'sirius',
    '天狼星',
    'Sirius · A/B 双星',
    '邻近恒星',
    8.611,
    '亮得像一个不太会隐藏自己的目的地。',
    { x: 0.72, y: 0.32 },
  ),
  makeDestination(
    'trappist-1',
    'TRAPPIST-1',
    'TRAPPIST-1 · 七行星系统',
    '系外行星系统',
    39.6,
    '七颗行星，八个理由让你先检查燃料。',
    { x: 0.68, y: 0.4 },
  ),
];

export function getDestination(id: string): Destination {
  return DESTINATIONS.find((destination) => destination.id === id) ?? DESTINATIONS[0]!;
}
