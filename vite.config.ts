import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// GitHub Pages では https://<user>.github.io/r108/ に置く。ローカルでは / で動かす
export default defineConfig(({ command, isPreview }) => ({
  base: process.env.R108_BASE ?? (command === 'build' || isPreview ? '/r108/' : '/'),
  plugins: [react()],
  optimizeDeps: { exclude: ['webr'] },
  server: { fs: { allow: ['.'] } },
  test: { include: ['tests/unit/**/*.test.ts'], environment: 'node' },
}));
