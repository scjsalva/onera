/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './app/views/**/*.{haml,erb}',
    './app/helpers/**/*.rb',
    './app/presenters/**/*.rb',
    './app/javascript/**/*.{js,vue}',
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Inter var', 'Inter', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        mono: ['ui-monospace', 'SFMono-Regular', 'Menlo', 'monospace'],
      },
      colors: {
        // Onera brand — plum. Deliberately not the green/blue of the category,
        // so positive/negative money colours never collide with brand colour.
        brand: {
          50: '#faf6fd',
          100: '#f3ebfa',
          200: '#e8d8f5',
          300: '#d6b8ec',
          400: '#bc8ddd',
          500: '#a166c9',
          600: '#8748ad',
          700: '#71398f',
          800: '#5e3175',
          900: '#4e2a60',
          950: '#33123f',
        },
        ink: {
          50: '#f8f8f7',
          100: '#f1f0ee',
          200: '#e4e2df',
          300: '#cfccc7',
          400: '#a8a49d',
          500: '#827d75',
          600: '#67625b',
          700: '#524e48',
          800: '#3c3935',
          900: '#2a2825',
          950: '#1a1917',
        },
        positive: {
          50: '#ecfdf5',
          100: '#d1fae5',
          600: '#059669',
          700: '#047857',
          900: '#064e3b',
        },
        negative: {
          50: '#fff1f2',
          100: '#ffe4e6',
          600: '#e11d48',
          700: '#be123c',
          900: '#881337',
        },
        sand: {
          50: '#fdf9ef',
          100: '#faf0d7',
          200: '#f4dfae',
          400: '#e8b955',
          600: '#c8902b',
        },
      },
      boxShadow: {
        card: '0 1px 2px 0 rgb(26 25 23 / 0.04), 0 1px 3px 0 rgb(26 25 23 / 0.06)',
        lift: '0 4px 12px -2px rgb(26 25 23 / 0.10), 0 2px 6px -2px rgb(26 25 23 / 0.06)',
      },
      borderRadius: {
        card: '0.875rem',
      },
    },
  },
  plugins: [],
};
