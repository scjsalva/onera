// Staggered entrance for server-rendered markup.
//
// Most of the app is HAML, so the reveal is driven by an attribute rather than
// a Vue transition: any element marked `data-reveal` fades and lifts into
// place the first time it scrolls into view, and siblings within a container
// stagger themselves so a list arrives as a wave rather than all at once.

const STAGGER_MS = 45;
const MAX_DELAY_MS = 320;

export function startRevealObserver(root = document) {
  const targets = root.querySelectorAll('[data-reveal]:not(.is-revealed)');
  if (!targets.length) return;

  if (!('IntersectionObserver' in window)) {
    targets.forEach((el) => el.classList.add('is-revealed'));
    return;
  }

  const counters = new Map();

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;

        const el = entry.target;
        const group = el.closest('[data-reveal-group]') || el.parentElement;
        const index = counters.get(group) || 0;
        counters.set(group, index + 1);

        el.style.setProperty('--reveal-delay', `${Math.min(index * STAGGER_MS, MAX_DELAY_MS)}ms`);
        el.classList.add('is-revealed');
        observer.unobserve(el);
      });
    },
    { rootMargin: '0px 0px -8% 0px', threshold: 0.05 }
  );

  targets.forEach((el) => observer.observe(el));
}
