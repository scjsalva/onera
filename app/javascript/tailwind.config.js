/** @type {import('tailwindcss').Config} */

// Colours are CSS variables rather than literals so light and dark are the
// same class names with different values. `text-ink-900` is the primary text
// colour in both themes; only what it resolves to changes.
const withVar = (name) => ({ opacityValue }) =>
  opacityValue === undefined ? `rgb(var(${name}))` : `rgb(var(${name}) / ${opacityValue})`;

const scale = (prefix, steps) =>
  Object.fromEntries(steps.map((step) => [step, withVar(`--${prefix}-${step}`)]));

module.exports = {
  darkMode: 'class',
  content: [
    './app/views/**/*.{haml,erb}',
    './app/helpers/**/*.rb',
    './app/presenters/**/*.rb',
    './app/javascript/**/*.{js,vue}',
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          '-apple-system', 'BlinkMacSystemFont', 'SF Pro Text', 'Inter var', 'Inter',
          'ui-sans-serif', 'system-ui', 'sans-serif',
        ],
        mono: ['ui-monospace', 'SFMono-Regular', 'Menlo', 'monospace'],
      },
      colors: {
        // Neutral ramp. Inverts between themes.
        ink: scale('ink', [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]),
        // Accent. Stays a blue in both themes, brightened slightly in dark.
        brand: scale('brand', [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950]),
        positive: scale('positive', [50, 100, 600, 700, 900]),
        negative: scale('negative', [50, 100, 600, 700, 900]),
        sand: scale('sand', [50, 100, 200, 400, 600]),

        // Filled brand surfaces that always carry white text. These must not
        // invert with the ramp - a deep blue panel stays deep blue in dark.
        'brand-solid': withVar('--brand-solid'),
        'brand-solid-deep': withVar('--brand-solid-deep'),

        // Layered materials.
        surface: withVar('--surface'),
        'surface-raised': withVar('--surface-raised'),
        'surface-sunken': withVar('--surface-sunken'),
        hairline: withVar('--hairline'),

        // Identity colours for avatars. Fixed on purpose: they must stay the
        // same person's colour in both themes, and they always carry white
        // text, so they can't be part of an inverting ramp.
        avatar: {
          1: '#2f6bed', 2: '#12a594', 3: '#c2410c', 4: '#7c3aed',
          5: '#0891b2', 6: '#be123c', 7: '#4d7c0f', 8: '#9333ea',
        },
      },
      boxShadow: {
        card: '0 1px 2px 0 rgb(var(--shadow) / 0.04), 0 1px 3px 0 rgb(var(--shadow) / 0.05)',
        lift: '0 8px 24px -6px rgb(var(--shadow) / 0.14), 0 2px 8px -2px rgb(var(--shadow) / 0.08)',
        glass: '0 1px 0 0 rgb(255 255 255 / 0.06) inset, 0 8px 32px -8px rgb(var(--shadow) / 0.18)',
      },
      borderRadius: {
        card: '1rem',
      },
      backdropBlur: {
        glass: '20px',
      },
    },
  },
  plugins: [],
};
