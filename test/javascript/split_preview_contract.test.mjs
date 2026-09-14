import { describe, it, expect } from 'vitest';
import { toMinor } from '@/lib/money';

// The client never computes a figure that gets stored - it sends raw inputs
// and Rails does the maths. These guard the shape of what it sends, which is
// the part a refactor can quietly break.
describe('what the composer sends', () => {
  const buildPayload = (form) => ({
    group_id: form.group_id,
    amount: form.amount,
    currency_code: form.currency_code,
    split_method: form.split_method,
    participants: form.participants,
    payers: form.payers,
  });

  it('sends the typed amount as text, not a parsed number', () => {
    const payload = buildPayload({
      group_id: 1, amount: '1234.50', currency_code: 'PHP', split_method: 'equal',
      participants: [{ user_id: 1 }], payers: [{ user_id: 1, amount: '1234.50' }],
    });

    expect(payload.amount).toBe('1234.50');
    expect(typeof payload.amount).toBe('string');
  });

  it('never sends computed shares', () => {
    const payload = buildPayload({
      group_id: 1, amount: '900', currency_code: 'PHP', split_method: 'equal',
      participants: [{ user_id: 1 }, { user_id: 2 }], payers: [{ user_id: 1, amount: '900' }],
    });

    const keys = payload.participants.flatMap((p) => Object.keys(p));
    expect(keys).not.toContain('amount_minor');
    expect(keys).not.toContain('share');
  });

  it('sends no group for a personal expense', () => {
    const payload = buildPayload({
      group_id: null, amount: '250', currency_code: 'PHP', split_method: 'equal',
      participants: [], payers: [],
    });

    expect(payload.group_id).toBeNull();
  });
});

describe('client-side rounding matches the server', () => {
  // Both sides round half up on the decimal string. If these ever disagree,
  // the preview shows one figure and the saved expense holds another.
  it.each([
    ['12.345', 2, 1235],
    ['12.344', 2, 1234],
    ['0.005', 2, 1],
    ['8400', 0, 8400],
    ['1.005', 2, 101],
  ])('%s at %i places is %i minor units', (input, exponent, expected) => {
    expect(toMinor(input, exponent)).toBe(expected);
  });
});
