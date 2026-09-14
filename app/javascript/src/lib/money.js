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

// Shifts the decimal point by manipulating the digits rather than multiplying,
// and rounds half up on the first dropped digit - the same rule Ruby's
// BigDecimal uses on the server.
//
// Multiplying went wrong exactly where money does: 1.005 * 100 is
// 100.49999999999999 in binary floating point, so the preview said ₱1.00
// while the server stored ₱1.01.
export function toMinor(amount, exponent = 2) {
  const text = String(amount ?? '').trim();
  if (!/^-?\d*\.?\d*$/.test(text) || !/\d/.test(text)) return 0;

  const negative = text.startsWith('-');
  const [whole = '', fraction = ''] = text.replace('-', '').split('.');

  // One digit past what we keep, so we can see whether to round up.
  const padded = `${fraction}${'0'.repeat(exponent + 1)}`.slice(0, exponent + 1);
  const kept = padded.slice(0, exponent);
  const dropped = Number(padded[exponent] || '0');

  let value = Number(`${whole || '0'}${kept}`);
  if (dropped >= 5) value += 1;

  return negative ? -value : value;
}
