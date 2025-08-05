import { test, expect } from '@playwright/test';

test('Frontend page should load', async ({ page }) => {
  console.log('Starting Playwright test for frontend');  
  try {
    await page.goto('http://localhost:4200'); 
    await expect(page).toHaveTitle(/AngularReportDesigner/i);

    console.log('✅ Test passed: Frontend loaded - ok');
  } catch (error) {
    console.error('❌ Test failed: Frontend loading test - failed');
    console.error('Error details:', error.message);
    throw error; // Re-throw to ensure test fails
  }
});

test('DevExpress Report Designer should exist', async ({ page }) => {
  console.log('Starting Playwright test for DevExpress Report Designer');
    await page.goto('http://localhost:4200');

    // Check if the DevExpress Report Designer markup exists
    const reportDesigner = page.locator('app-root div dx-report-designer');
    await expect(reportDesigner).toBeVisible({ timeout: 5000 });
    console.log('✅ Test passed: DevExpress Report Designer exists - ok');
});

test('Preview, Design and Menu buttons should be clickable', async ({ page }) => {
  console.log('Starting Playwright test for Preview, Design and Menu buttons');
    await page.goto('http://localhost:4200');

    // Wait for the page to load
    await page.waitForLoadState('networkidle');

    // Find and click the Preview button
    const previewButton = page.locator('div[title="Preview"]');
    await expect(previewButton).toBeVisible({ timeout: 5000 });
    await previewButton.click();
    console.log('Preview button clicked - ok');
    
    // Find and click the Design button
    const designerButton = page.locator('div[title="Design"]');
    await expect(designerButton).toBeVisible({ timeout: 5000 });
    await designerButton.click();
    console.log('Design button clicked - ok');
    
    // Find and click the Menu button
    const menuButton = page.locator('div.dxrd-menu-button');
    await expect(menuButton).toBeVisible({ timeout: 5000 });
    await menuButton.click();
    console.log('Menu button clicked - ok');

    console.log('Test passed: Preview, Design and Menu buttons are clickable');
});