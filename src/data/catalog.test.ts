import { DEFAULT_VESSEL, DESTINATIONS } from './catalog';

describe('demo catalog provenance', () => {
  it('keeps catalog facts, map layout, and product copy distinguishable', () => {
    for (const destination of DESTINATIONS) {
      expect(destination.catalogProvenance.nature).toBe('derived');
      expect(destination.mapProvenance.nature).toBe('fictional');
      expect(destination.descriptionProvenance.nature).toBe('fictional');
      expect(destination.routes.every((route) => route.provenance.nature === 'simulated')).toBe(
        true,
      );
    }
  });

  it('marks the entertainment vessel preset as fictional', () => {
    expect(DEFAULT_VESSEL.provenance.nature).toBe('fictional');
    expect(DEFAULT_VESSEL.profile.cruiseSpeedC).toBeGreaterThan(0);
  });
});
