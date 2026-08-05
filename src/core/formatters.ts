function assertFiniteNonNegative(value: number, name: string): void {
  if (!Number.isFinite(value) || value < 0) {
    throw new RangeError(`${name} must be a finite non-negative number`);
  }
}

function trimTrailingZeros(value: number, fractionDigits: number): string {
  return value.toFixed(fractionDigits).replace(/\.0+$|(?<=\.[0-9]*)0+$/, '');
}

export function formatDistance(distanceLy: number): string {
  assertFiniteNonNegative(distanceLy, 'distanceLy');
  if (distanceLy >= 10_000) {
    return `${trimTrailingZeros(distanceLy / 10_000, 2)}万光年`;
  }

  return `${trimTrailingZeros(distanceLy, distanceLy < 10 ? 2 : 0)}光年`;
}

export function formatDuration(years: number): string {
  assertFiniteNonNegative(years, 'years');
  if (years >= 100_000_000) {
    return `${trimTrailingZeros(years / 100_000_000, 1)}亿年`;
  }
  if (years >= 10_000) {
    return `${trimTrailingZeros(years / 10_000, 1)}万年`;
  }

  return `${Math.round(years)}年`;
}

export function formatFuel(fuelUnits: number): string {
  assertFiniteNonNegative(fuelUnits, 'fuelUnits');
  if (fuelUnits >= 10_000) {
    return `${trimTrailingZeros(fuelUnits / 10_000, 1)}万单位`;
  }

  return `${Math.round(fuelUnits)}单位`;
}

export function formatRisk(riskScore: number): string {
  if (!Number.isFinite(riskScore) || riskScore < 0 || riskScore > 1) {
    throw new RangeError('riskScore must be between 0 and 1');
  }

  return `${Math.round(riskScore * 100)}%`;
}
