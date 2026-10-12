/* Development-only checks against real shared shell output and isolated fixtures. */
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {spawn} = require('node:child_process');
const {chromium} = require('playwright');

async function wait_for_server(child) {
    for (let attempt = 0; attempt < 100; attempt += 1) {
        if (child.exitCode !== null) throw new Error('Fixture server exited before readiness');
        try {
            const response = await fetch('http://127.0.0.1:8080/pages/smb.cgi.html');
            if (response.ok) return;
        } catch (error) {
            if (!error.cause || error.cause.code !== 'ECONNREFUSED') throw error;
        }
        await new Promise(resolve => setTimeout(resolve, 200));
    }
    throw new Error('Fixture server readiness timeout');
}

async function check_layout(page, width, route) {
    await page.setViewportSize({width, height: 900});
    await page.goto('http://127.0.0.1:8080/pages/' + route + '.html');
    await page.waitForSelector('main');
    const sizes = await page.evaluate(() => ({width: innerWidth, document: document.documentElement.scrollWidth}));
    assert(sizes.document <= sizes.width + 1, `${route}: page overflow at ${width}px (${sizes.document})`);
    assert.equal(await page.locator('main').count(), 1);
    assert.equal(await page.locator('frameset').count(), 0);
    assert.equal(await page.locator('table.data-table th').count(), 9);
}

async function check_mobile_menu(page) {
    await check_layout(page, 360, 'smb.cgi');
    assert.equal(await page.locator('#site-navigation').isVisible(), false);
    await page.getByRole('button', {name: 'Menu', exact: true}).click();
    assert.equal(await page.locator('#site-navigation').isVisible(), true);
    assert.equal(await page.getByRole('link', {name: 'Status', exact: true}).count(), 1);
    const axe = require.resolve('axe-core/axe.min.js');
    await page.addScriptTag({path: axe});
    const report = await page.evaluate(() => axe.run(document, {runOnly: ['wcag2a', 'wcag2aa']}));
    assert.deepEqual(report.violations.map(item => item.id), [], 'Accessible fixture shell');
}

async function check_service_embed(page) {
    await page.setViewportSize({width: 1280, height: 900});
    await page.goto('http://127.0.0.1:8080/pages/embed-example.html');
    const bounds = await page.locator('iframe').boundingBox();
    assert(bounds.height >= 540, 'Embedded service retains useful viewport height');
}

async function check_forms(page) {
    await check_layout(page, 1280, 'smb.cgi');
    await page.getByRole('button', {name: 'Submit', exact: true}).click();
    await page.waitForURL('**/fixture_submit.cgi');
    assert.equal(await page.locator('#submitted').textContent(), 'Submit');
    await page.goto('http://127.0.0.1:8080/pages/settings.cgi.html');
    await page.setInputFiles('input[type=file]', {name: 'fixture.txt', mimeType: 'text/plain', buffer: Buffer.from('sample upload')});
    await page.getByRole('button', {name: 'Upload', exact: true}).click();
    await page.waitForURL('**/fixture_upload.cgi');
    assert((await page.textContent('body')).includes('sample upload'));
    await page.goto('http://127.0.0.1:8080/pages/settings.cgi.html');
    const event = page.waitForEvent('download');
    await page.getByRole('link', {name: 'Download fixture'}).click();
    const download = await event;
    assert.equal(download.suggestedFilename(), 'settings.txt');
}

async function main() {
    const server = spawn('python3', ['fixture_server.py'], {stdio: ['ignore', 'inherit', 'inherit']});
    let browser;
    try {
        await wait_for_server(server);
        browser = await chromium.launch({headless: true});
        const page = await browser.newPage();
        const errors = [];
        page.on('pageerror', error => errors.push(error.message));
        const coverage = JSON.parse(fs.readFileSync('/tmp/ui-coverage.json'));
        const rendered = coverage.filter(entry => entry.mode.startsWith('shared-shell'));
        for (const item of rendered) await check_layout(page, 360, item.route);
        for (const width of [768, 1280]) await check_layout(page, width, 'smb.cgi');
        await check_mobile_menu(page);
        await check_forms(page);
        await check_service_embed(page);
        assert.deepEqual(errors, [], 'No browser exceptions');
        fs.mkdirSync('/tests/.playwright-mcp', {recursive: true});
        await check_layout(page, 1280, 'smb.cgi');
        await page.screenshot({path: '/tests/.playwright-mcp/desktop.png', fullPage: true});
        await check_layout(page, 360, 'smb.cgi');
        await page.screenshot({path: '/tests/.playwright-mcp/mobile.png', fullPage: true});
        fs.writeFileSync('/tests/.playwright-mcp/coverage.json', JSON.stringify(coverage, null, 2));
        console.log(`PASS: ${rendered.length} route shell fixtures, three widths, menu, axe, POST, multipart and download`);
        console.log('LIMITATION: synthetic page bodies, not execution of all original NAS handlers');
    } finally {
        if (browser) await browser.close();
        server.kill();
    }
}

main().catch(error => {console.error(error); process.exitCode = 1;});
