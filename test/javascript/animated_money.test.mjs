import { describe, it, expect, vi, beforeEach } from 'vitest';
import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import AnimatedMoney from '@/components/AnimatedMoney.vue';

// Props arrive from HTML attributes as strings; the component has to cope.
beforeEach(() => {
  window.matchMedia = vi.fn().mockReturnValue({ matches: true, addEventListener: vi.fn() });
});

// The value settles in onMounted, so the DOM needs a tick before it reads
// as anything but zero.
async function mountMoney(props) {
  const wrapper = mount(AnimatedMoney, { props });
  await nextTick();
  return wrapper;
}

describe('AnimatedMoney', () => {
  it('formats a number prop', async () => {
    expect((await mountMoney({ minor: 123456, symbol: '₱', exponent: 2 })).text()).toBe('₱1,234.56');
  });

  it('formats string props, which is how HAML passes them', async () => {
    expect((await mountMoney({ minor: '123456', symbol: '₱', exponent: '2' })).text()).toBe('₱1,234.56');
  });

  it('does not pad a zero-decimal currency', async () => {
    expect((await mountMoney({ minor: '8400', symbol: '¥', exponent: '0' })).text()).toBe('¥8,400');
  });

  it('renders a negative amount with one leading sign', async () => {
    expect((await mountMoney({ minor: '-2500', symbol: '₱', exponent: '2' })).text()).toBe('-₱25.00');
  });

  it('adds a plus only when asked', async () => {
    expect((await mountMoney({ minor: '2500', symbol: '₱', exponent: '2', sign: true })).text()).toBe('+₱25.00');
  });

  it('shows zero as zero', async () => {
    expect((await mountMoney({ minor: '0', symbol: '₱', exponent: '2' })).text()).toBe('₱0.00');
  });
});
