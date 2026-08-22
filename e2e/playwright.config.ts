import { defineConfig, devices } from '@playwright/test';

// Playwright drives browsers only. The Flutter app is covered by flutter test,
// Alchemist goldens and integration_test — never from here
// (CLAUDE.md §Hard rules, docs/06-TESTING-STRATEGY.md §1).
//
// PLAYWRIGHT PIN 2 of 2. @playwright/test in e2e/package.json is pinned to an
// EXACT version (no caret) because the CI container image
// mcr.microsoft.com/playwright:v<version>-noble ships only that release's
// browsers. A caret let the package float to 1.62.1 against a 1.56.1 image and
// the e2e job failed with "Executable doesn't exist". Change the version and
// the image tag in .github/workflows/ci.yml together, in the same commit.

const isCI = Boolean(process.env.CI);

const SITE_URL = process.env.SITE_URL ?? 'http://localhost:4321';
const ADMIN_URL = process.env.ADMIN_URL ?? 'http://localhost:3001';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: isCI,
  retries: isCI ? 2 : 0,
  workers: isCI ? 1 : undefined,
  reporter: isCI ? [['github'], ['html', { open: 'never' }]] : [['list']],

  // A missing baseline must fail loudly rather than being written on the fly.
  updateSnapshots: 'none',

  expect: {
    toHaveScreenshot: {
      maxDiffPixelRatio: 0.01,
      animations: 'disabled',
      scale: 'device',
    },
  },

  use: {
    baseURL: SITE_URL,
    viewport: { width: 1280, height: 720 },
    reducedMotion: 'reduce',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },

  // Baselines are platform-locked: they are generated in the Playwright Docker
  // image and committed, never regenerated on a laptop
  // (docs/06-TESTING-STRATEGY.md §4).
  snapshotPathTemplate:
    '{testDir}/__screenshots__/{testFilePath}/{arg}{-projectName}{ext}',

  projects: [
    {
      name: 'site',
      use: { ...devices['Desktop Chrome'], baseURL: SITE_URL },
      testMatch: /site\/.*\.spec\.ts/,
    },
    {
      name: 'admin',
      use: { ...devices['Desktop Chrome'], baseURL: ADMIN_URL },
      testMatch: /admin\/.*\.spec\.ts/,
    },
  ],

  // The site is `output: 'static'`, so it is served as plain files rather than
  // through `astro preview` — fewer moving parts, and identical bytes to what
  // ships. Run `pnpm --filter @diakooi/site build` first.
  webServer: [
    {
      command: 'pnpm exec sirv ../site/dist --port 4321 --quiet',
      url: SITE_URL,
      reuseExistingServer: !isCI,
      timeout: 120_000,
    },
  ],
});
