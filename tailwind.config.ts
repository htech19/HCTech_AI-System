import type { Config } from 'tailwindcss';

const config: Config = {
  darkMode: 'class',
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        brand: { green: '#00A651', silver: '#C0C2C0', dark: '#1A1A1A' },
      },
    },
  },
  plugins: [require('@tailwindcss/typography')],
};

export default config;