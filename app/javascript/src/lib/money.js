// Presentation only. Every authoritative figure is computed in Rails and
// handed to Vue already rounded; these helpers just render it.

export function formatMinor(minorUnits, currency) {
  const exponent = currency?.exponent ?? 2;
  const value = Number(minorUnits || 0) / 10 ** exponent;
  return formatMoney(value, currency);
}

export function formatMoney(amount, currency) {
  const exponent = currency?.exponent ?? 2;
  const symbol = currency?.symbol ?? '';
  const negative = Number(amount) < 0;
  const body = Math.abs(Number(amount) || 0).toLocaleString(undefined, {
    minimumFractionDigits: exponent,
    maximumFractionDigits: exponent,
  });
  return `${negative ? '-' : ''}${symbol}${body}`;
}

export function toMinor(amount, exponent = 2) {
  // Round-half-up on the decimal string avoids float drift for user input.
  const n = Number(amount);
  if (Number.isNaN(n)) return 0;
  return Math.round(n * 10 ** exponent);
}
