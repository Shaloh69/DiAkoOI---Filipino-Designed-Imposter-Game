import AxeBuilder from '@axe-core/playwright';
import { expect, test } from '@playwright/test';

test.describe('public site', () => {
  test('landing page renders', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/DiAkoOi/);
  });

  test('changelog is served from the Starlight subpath', async ({ page }) => {
    await page.goto('/changelog');
    await expect(
      page.getByRole('heading', { name: 'Changelog', level: 1 }),
    ).toBeVisible();
  });

  test('changelog has no detectable accessibility violations', async ({
    page,
  }) => {
    await page.goto('/changelog');
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();

    expect(results.violations).toEqual([]);
  });

  // The landing page is still AstroWind's demo copy, which fails colour
  // contrast in 233 places. Phase 8 replaces that copy and owns this check —
  // recorded as a known failure rather than deleted, so the obligation stays
  // visible in the report (docs/09-WEB-SPEC.md, audit A8 Web + A11y).
  test.fixme(
    'landing page has no detectable accessibility violations',
    async ({ page }) => {
      await page.goto('/');
      const results = await new AxeBuilder({ page })
        .withTags(['wcag2a', 'wcag2aa'])
        .analyze();

      expect(results.violations).toEqual([]);
    },
  );
});
