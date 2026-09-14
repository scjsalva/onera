import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import AvatarBubble from '@/components/AvatarBubble.vue';

const withAvatar = { id: 1, name: 'John Salva', initials: 'JS', tone: 'bg-avatar-1',
                     avatar: 'https://api.dicebear.com/9.x/notionists-neutral/svg?seed=scjsalva' };

describe('AvatarBubble', () => {
  it('always renders initials, so there is something if the image fails', () => {
    expect(mount(AvatarBubble, { props: { user: withAvatar } }).text()).toBe('JS');
  });

  it('layers the illustrated avatar on top when there is one', () => {
    const img = mount(AvatarBubble, { props: { user: withAvatar } }).find('img');
    expect(img.exists()).toBe(true);
    expect(img.attributes('src')).toContain('dicebear');
    expect(img.attributes('aria-hidden')).toBe('true');
  });

  it('renders no image for someone without one', () => {
    const user = { id: 2, name: 'Removed person 1', initials: 'R1', tone: 'bg-avatar-2', avatar: null };
    expect(mount(AvatarBubble, { props: { user } }).find('img').exists()).toBe(false);
  });

  it('keeps each person their own colour', () => {
    expect(mount(AvatarBubble, { props: { user: withAvatar } }).classes()).toContain('bg-avatar-1');
  });

  it('falls back to a brand colour when no tone is given', () => {
    const user = { id: 3, name: 'X', initials: 'X' };
    expect(mount(AvatarBubble, { props: { user } }).classes()).toContain('bg-brand-600');
  });
});
