import { getDataNatureLabel, isScientificData } from './provenance';

describe('data provenance boundaries', () => {
  it('provides concise labels for every supported nature', () => {
    expect(getDataNatureLabel('observed')).toBe('观测');
    expect(getDataNatureLabel('derived')).toBe('推导');
    expect(getDataNatureLabel('simulated')).toBe('模拟');
    expect(getDataNatureLabel('fictional')).toBe('设定');
  });

  it('never presents simulated or fictional values as scientific data', () => {
    expect(isScientificData('observed')).toBe(true);
    expect(isScientificData('derived')).toBe(true);
    expect(isScientificData('simulated')).toBe(false);
    expect(isScientificData('fictional')).toBe(false);
  });
});
