import { describe, it, expect } from 'vitest';
import { formatMinor, formatMoney, toMinor } from '@/lib/money';

const php = { code: 'PHP', symbol: '₱', exponent: 2 };
const jpy = { code: 'JPY', symbol: '¥', exponent: 0 };

describe('money formatting', () => {
  it('renders two-decimal currencies', () => {
    expect(formatMinor(123456, php)).toBe('₱1,234.56');
  });

  it('renders zero-decimal currencies without a point', () => {
    expect(formatMinor(8400, jpy)).toBe('¥8,400');
  });

  it('puts a negative sign outside the symbol', () => {
    expect(formatMinor(-500, php)).toBe('-₱5.00');
  });

  it('only shows a plus when asked', () => {
    expect(formatMoney(5, php)).toBe('₱5.00');
  });

  it('treats a missing amount as zero rather than NaN', () => {
    expect(formatMinor(undefined, php)).toBe('₱0.00');
    expect(formatMinor(null, php)).toBe('₱0.00');
  });

  it('falls back to two decimals when the currency is unknown', () => {
    expect(formatMinor(100)).toBe('1.00');
  });

  it('converts a typed amount to minor units, rounding half up', () => {
    expect(toMinor('12.345', 2)).toBe(1235);
    expect(toMinor('12.344', 2)).toBe(1234);
    expect(toMinor('8400', 0)).toBe(8400);
  });

  it('treats nonsense input as zero', () => {
    expect(toMinor('abc', 2)).toBe(0);
  });
});
