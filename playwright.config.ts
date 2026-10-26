import { defineConfig } from '@playwright/test';

// webR の起動とパッケージの読み込みに時間がかかるため、タイムアウトを長めにとる
export default defineConfig({
  testDir: 'tests/e2e',
  timeout: 240_000,
  expect: { timeout: 120_000 },
  workers: 1,
  use: { baseURL: process.env.E2E_BASE_URL ?? 'http://localhost:5178/', trace: 'retain-on-failure' },
  webServer: process.env.E2E_BASE_URL
    ? undefined
    : { command: 'npm run build:r && npx vite --port 5178 --strictPort', url: 'http://localhost:5178/', reuseExistingServer: true },
});
