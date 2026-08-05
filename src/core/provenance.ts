export type DataNature = 'observed' | 'derived' | 'simulated' | 'fictional';

export interface Provenance {
  nature: DataNature;
  datasetId: string;
  sourceName?: string;
  sourceRelease?: string;
  sourceObjectId?: string;
  retrievedAt?: string;
  calculationModel?: string;
  confidence?: number;
}

const dataNatureLabels: Record<DataNature, string> = {
  observed: '观测',
  derived: '推导',
  simulated: '模拟',
  fictional: '设定',
};

export function getDataNatureLabel(nature: DataNature): string {
  return dataNatureLabels[nature];
}

export function isScientificData(nature: DataNature): boolean {
  return nature === 'observed' || nature === 'derived';
}
