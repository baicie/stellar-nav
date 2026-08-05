import { formatDistance, formatDuration, formatFuel, formatRisk } from './formatters';

describe('cosmic value formatting', () => {
  it('uses compact Chinese units without hiding useful nearby-star precision', () => {
    expect(formatDistance(2_540_000)).toBe('254万光年');
    expect(formatDistance(4.2465)).toBe('4.25光年');
    expect(formatDistance(999)).toBe('999光年');
  });

  it('formats travel duration and fuel consistently across scales', () => {
    expect(formatDuration(2_540_000_000)).toBe('25.4亿年');
    expect(formatDuration(4_390)).toBe('4390年');
    expect(formatFuel(1_245_000)).toBe('124.5万单位');
  });

  it('formats a normalized risk score as a percentage', () => {
    expect(formatRisk(0)).toBe('0%');
    expect(formatRisk(0.1664)).toBe('17%');
    expect(formatRisk(1)).toBe('100%');
  });

  it('rejects negative and non-finite values', () => {
    expect(() => formatDistance(-1)).toThrow(RangeError);
    expect(() => formatDuration(Number.POSITIVE_INFINITY)).toThrow(RangeError);
    expect(() => formatRisk(1.01)).toThrow(RangeError);
  });
});
