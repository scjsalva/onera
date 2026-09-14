import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import SplitEditor from '@/components/SplitEditor.vue';

const people = [
  { id: 1, name: 'John Salva', initials: 'JS', tone: 'bg-avatar-1' },
  { id: 2, name: 'Alice Cruz', initials: 'AC', tone: 'bg-avatar-2' },
];
const php = { code: 'PHP', symbol: '₱', exponent: 2 };

const preview = {
  valid: true,
  errors: [],
  splits: [
    { user_id: 1, minor: 5000, formatted: '₱50.00' },
    { user_id: 2, minor: 5000, formatted: '₱50.00' },
  ],
};

function mountEditor(overrides = {}) {
  return mount(SplitEditor, {
    props: {
      modelValue: [{ user_id: 1, split_value: null }, { user_id: 2, split_value: null }],
      people,
      method: 'equal',
      preview,
      previewing: false,
      currency: php,
      ...overrides,
    },
  });
}

describe('SplitEditor', () => {
  it('shows the server-computed share for each person', () => {
    const text = mountEditor().text();
    expect(text).toContain('₱50.00');
    expect(text).toContain('John Salva');
  });

  it('offers no value input for an equal split', () => {
    expect(mountEditor().findAll('input')).toHaveLength(0);
  });

  it('offers one input per person for other methods', () => {
    expect(mountEditor({ method: 'shares' }).findAll('input')).toHaveLength(2);
  });

  it('labels the unit for each method', () => {
    expect(mountEditor({ method: 'percentage' }).text()).toContain('%');
    expect(mountEditor({ method: 'shares' }).text()).toContain('shares');
    expect(mountEditor({ method: 'fixed' }).text()).toContain('₱');
  });

  it('reserves room for a long unit so it cannot sit on the value', () => {
    const input = mountEditor({ method: 'shares' }).find('input');
    // "shares" is six characters, so the padding must be well past a symbol's.
    expect(input.attributes('style')).toContain('6ch');
  });

  it('surfaces validation errors from the server', () => {
    const failing = { ...preview, valid: false, errors: ['Percentages must add up to 100%'] };
    expect(mountEditor({ method: 'percentage', preview: failing }).text()).toContain('add up to 100%');
  });

  it('renders nothing when nobody is sharing the expense', () => {
    expect(mountEditor({ modelValue: [] }).text()).toBe('');
  });

  it('says when it is waiting for the server rather than showing stale figures', () => {
    expect(mountEditor({ previewing: true, preview: null }).text()).toContain('Checking');
  });
});
