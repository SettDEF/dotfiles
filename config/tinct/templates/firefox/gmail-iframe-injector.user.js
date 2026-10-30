// ==UserScript==
// @name         Gmail Dark Iframe Injector
// @namespace    tinct-quickshell
// @version      1.0.0
// @description  Injects dark theme CSS into Gmail email content iframes. Backup for Stylus.
// @match        https://mail.google.com/*
// @grant        none
// @run-at       document-end
// ==/UserScript==

(function() {
    'use strict';

    const DARK_CSS = `
        body, html {
            background-color: #1a1a2e !important;
            color: #e0e0e0 !important;
        }
        * {
            background-color: inherit !important;
        }
        div[style*="background-color: white"],
        div[style*="background: white"],
        div[style*="background-color: #fff"],
        div[style*="background: #fff"],
        div[style*="background-color: #ffffff"],
        div[style*="background: #ffffff"],
        div[style*="background-color: rgb(255, 255, 255)"],
        div[style*="background: rgb(255, 255, 255)"] {
            background-color: #2a2a3e !important;
            color: #e0e0e0 !important;
        }
        .msg, .gmail_default, .gmail_attr, .gmail_quote,
        .a3s, .ii, .gt, .g6, .h7, .gs {
            background-color: #2a2a3e !important;
            color: #e0e0e0 !important;
        }
        a, a:visited {
            color: #8ab4f8 !important;
        }
    `;

    function injectIntoIframe(iframe) {
        try {
            const doc = iframe.contentDocument || iframe.contentWindow.document;
            if (!doc) return;
            // Check if already injected
            if (doc.getElementById('tinct-gmail-dark')) return;
            const style = doc.createElement('style');
            style.id = 'tinct-gmail-dark';
            style.textContent = DARK_CSS;
            if (doc.head) {
                doc.head.appendChild(style);
            } else {
                doc.documentElement.appendChild(style);
            }
        } catch (e) {
            // Cross-origin or not ready yet
        }
    }

    function scanIframes() {
        document.querySelectorAll('iframe').forEach(injectIntoIframe);
    }

    // Initial scan
    scanIframes();

    // Watch for new iframes (Gmail is an SPA)
    const observer = new MutationObserver(() => {
        scanIframes();
    });
    observer.observe(document.body, { childList: true, subtree: true });

    // Also check periodically (Gmail loads iframes lazily)
    setInterval(scanIframes, 1000);
})();