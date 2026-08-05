import { getMapLabelLayout } from './MapLabels';

describe('getMapLabelLayout', () => {
  it('keeps map labels above a measured bottom overlay on compact screens', () => {
    const layout = getMapLabelLayout({
      bottomOcclusion: 266,
      destinationAnchor: { x: 0.72, y: 0.28 },
      height: 568,
      width: 320,
    });

    const visibleMapBottom = 568 - 266 - 8;

    expect(layout.originTop + 28).toBeLessThanOrEqual(visibleMapBottom);
    expect(layout.destinationTop + 28).toBeLessThanOrEqual(visibleMapBottom);
  });
});
