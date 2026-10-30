// ==UserScript==
// @name         tinct live colours
// @namespace    tinct-quickshell
// @version      1.2.0
// @description  Keeps the tinct website style in step with the wallpaper: reads the live palette from the local theme server and sets the --m3-* colours on every page. Also applies Palette > Glass to websites.
// @match        *://*/*
// @grant        GM_xmlhttpRequest
// @connect      localhost
// @run-at       document-start
// @noframes
// @updateURL    http://localhost:8787/tinct-live.user.js
// @downloadURL  http://localhost:8787/tinct-live.user.js
// ==/UserScript==

// The Stylus style holds the per-site rules and only fallback colours; Stylus
// stops re-reading it once its install tab is closed. Inline custom properties
// on <html> beat the style's :root values, so setting them here recolours the
// page the moment tinct writes a new palette.
//
// Glass (glass.json, written by the shell's Palette > Glass "Websites" row):
// surface and background colours get the chosen opacity and the page itself
// stops painting a solid background. Only visible once the browser window is
// see-through (tela-zen TASKS.md #38); harmless before that.
(() => {
    const BASE = 'http://localhost:8787/';
    const EVERY_MS = 1500;
    const root = document.documentElement;
    let lastText = '', lastGlass = '';
    let vars = null, glass = { enabled: false, opacity: 1 };
    let glassStyle = null;

    const isSurface = k => /^--m3-(surface|background)/.test(k);
    const withAlpha = (v, a) => /^#[0-9a-fA-F]{6}$/.test(v)
        ? v + Math.round(a * 255).toString(16).padStart(2, '0') : v;

    function apply() {
        if (!vars) return;
        const g = glass.enabled ? Math.max(0.2, Math.min(1, glass.opacity)) : 1;
        for (const [k, v] of Object.entries(vars))
            if (k.startsWith('--m3') && v)
                root.style.setProperty(k, g < 1 && isSurface(k) ? withAlpha(v, g) : v);
        // Light palette -> light form controls and scrollbars.
        const n = parseInt((vars['--m3-surface'] || '#000000').slice(1, 7), 16);
        const lum = 0.2126 * (n >> 16 & 255) + 0.7152 * (n >> 8 & 255) + 0.0722 * (n & 255);
        root.style.setProperty('color-scheme', lum > 128 ? 'light' : 'dark');
        // The page's own solid background would hide everything behind it.
        if (g < 1 && !glassStyle) {
            glassStyle = document.createElement('style');
            glassStyle.id = 'tinct-glass';
            glassStyle.textContent = 'html, body { background-color: transparent !important; }';
            (document.head || root).appendChild(glassStyle);
        } else if (g >= 1 && glassStyle) {
            glassStyle.remove();
            glassStyle = null;
        }
    }

    function get(name, onText) {
        GM_xmlhttpRequest({
            method: 'GET', url: BASE + name + '?t=' + Date.now(), timeout: 1000,
            onload: r => { if (r.status === 200) onText(r.responseText); },
        });
    }

    function poll() {
        if (document.hidden) return;
        get('vars.json', text => {
            if (text !== lastText) {
                try { vars = JSON.parse(text); } catch (e) { return; }
                lastText = text;
                apply();
            } else if (vars && !glass.enabled && root.style.getPropertyValue('--m3-surface') !== vars['--m3-surface']) {
                // The site rewrote <html style=...>; put the colours back.
                apply();
            }
        });
        get('glass.json', text => {
            if (text === lastGlass) return;
            try { glass = JSON.parse(text); } catch (e) { return; }
            lastGlass = text;
            apply();
        });
    }

    poll();
    setInterval(poll, EVERY_MS);
    document.addEventListener('visibilitychange', poll);
})();
