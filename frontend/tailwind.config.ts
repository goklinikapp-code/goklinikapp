import type { Config } from 'tailwindcss'

const config: Config = {
  darkMode: 'class',
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: 'rgb(var(--gk-primary-rgb) / <alpha-value>)',
          light: 'rgb(var(--gk-primary-rgb) / 0.12)',
        },
        secondary: {
          DEFAULT: 'rgb(var(--gk-secondary-rgb) / <alpha-value>)',
          light: 'rgb(var(--gk-secondary-rgb) / 0.12)',
        },
        accent: {
          DEFAULT: 'rgb(var(--gk-accent-rgb) / <alpha-value>)',
          light: 'rgb(var(--gk-accent-rgb) / 0.12)',
        },
        mist: 'var(--gk-mist)',
        night: 'var(--gk-night)',
        tealIce: 'var(--gk-teal-ice)',
        danger: '#DC2626',
        neutral: '#6B7280',
      },
      fontFamily: {
        sans: ['Inter', 'sans-serif'],
      },
      borderRadius: {
        card: '12px',
      },
      boxShadow: {
        card: '0 6px 16px rgba(26, 31, 46, 0.08)',
      },
      spacing: {
        sidebar: '220px',
      },
    },
  },
  plugins: [],
}

export default config
