// ==UserScript==
// @name         GravityDrop - Universal Local Download Manager
// @namespace    http://tampermonkey.net/
// @version      3.1
// @description  Send downloads from any website straight to specific folders. Add site rules to auto-detect and route downloads persistently.
// @author       KIEFR
// @match        *://*/*
// @grant        GM_xmlhttpRequest
// @grant        GM_registerMenuCommand
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_addStyle
// @connect      localhost
// @connect      127.0.0.1
// ==/UserScript==

(function() {
    'use strict';

    const API_URL = "http://127.0.0.1:18188/download";
    let lastPlayingUrl = "";
    let uiInitialized = false;

    let root = null;
    let panel = null;
    let fab = null;

    // ── Persistent Site Rules ──────────────────────────────────────────
    // Each rule: { id, hostname, category, customPath, label, enabled, fileTypes }
    function loadRules() {
        try { return JSON.parse(GM_getValue('gd_site_rules', '[]')); }
        catch(e) { return []; }
    }
    function saveRules(rules) { GM_setValue('gd_site_rules', JSON.stringify(rules)); }
    function genId() { return Date.now().toString(36) + Math.random().toString(36).substr(2, 5); }

    function getMatchingRule() {
        const rules = loadRules();
        const host = window.location.hostname;
        for (const rule of rules) {
            if (!rule.enabled) continue;
            try {
                const rh = new URL(rule.hostname.startsWith('http') ? rule.hostname : 'https://' + rule.hostname).hostname;
                if (host === rh || host.endsWith('.' + rh)) return rule;
            } catch(e) {
                if (host.includes(rule.hostname)) return rule;
            }
        }
        return null;
    }

    // ── Styles ─────────────────────────────────────────────────────────
    let stylesInjected = false;
    function injectStyles() {
        if (stylesInjected) return;
        stylesInjected = true;
        GM_addStyle(`
            @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
            #gd-root *, #gd-root { font-family:'Inter',system-ui,-apple-system,sans-serif; box-sizing:border-box; }
            .gd-modal *, .gd-modal { font-family:'Inter',system-ui,-apple-system,sans-serif; box-sizing:border-box; }

            @keyframes gdUp   { from{opacity:0;transform:translateY(12px) scale(.97)} to{opacity:1;transform:translateY(0) scale(1)} }
            @keyframes gdFade { from{opacity:0} to{opacity:1} }
            @keyframes gdPulse{ 0%,100%{box-shadow:0 0 0 0 rgba(99,102,241,.4)} 50%{box-shadow:0 0 0 8px rgba(99,102,241,0)} }
            @keyframes gdSpin { to{transform:rotate(360deg)} }

            .gd-panel {
                width:280px;
                background:linear-gradient(165deg,rgba(15,15,22,.97),rgba(22,22,35,.97));
                border:1px solid rgba(255,255,255,.08);
                border-radius:14px; padding:14px;
                box-shadow:0 20px 50px rgba(0,0,0,.5), 0 0 0 1px rgba(99,102,241,.08), inset 0 1px 0 rgba(255,255,255,.04);
                color:#e2e8f0; backdrop-filter:blur(20px);
                animation:gdUp .25s cubic-bezier(.22,1,.36,1);
            }
            .gd-input {
                width:100%; background:rgba(0,0,0,.35); border:1px solid rgba(255,255,255,.08);
                border-radius:8px; padding:8px 10px; color:#e2e8f0; font-size:11px; outline:none;
                transition:border-color .2s, box-shadow .2s;
            }
            .gd-input:focus { border-color:rgba(99,102,241,.5); box-shadow:0 0 0 3px rgba(99,102,241,.1); }
            .gd-input::placeholder { color:rgba(255,255,255,.25); }
            .gd-select {
                width:100%; background:rgba(0,0,0,.35); border:1px solid rgba(255,255,255,.08);
                border-radius:8px; padding:8px 10px; color:#e2e8f0; font-size:11px; outline:none;
                cursor:pointer; -webkit-appearance:none; appearance:none;
                background-image:url("data:image/svg+xml,%3Csvg width='10' height='6' viewBox='0 0 10 6' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M1 1L5 5L9 1' stroke='%23666' stroke-width='1.5' stroke-linecap='round'/%3E%3C/svg%3E");
                background-repeat:no-repeat; background-position:right 10px center;
                transition:border-color .2s;
            }
            .gd-select:focus { border-color:rgba(99,102,241,.5); }
            .gd-label { display:block; font-size:10px; font-weight:500; color:rgba(255,255,255,.45); margin-bottom:4px; text-transform:uppercase; letter-spacing:.5px; }

            .gd-btn-primary {
                width:100%; background:linear-gradient(135deg,#6366f1,#4f46e5); color:white;
                border:none; border-radius:8px; padding:9px 14px; font-size:12px; font-weight:600;
                cursor:pointer; transition:all .2s; overflow:hidden;
            }
            .gd-btn-primary:hover { background:linear-gradient(135deg,#818cf8,#6366f1); transform:translateY(-1px); box-shadow:0 4px 15px rgba(99,102,241,.35); }
            .gd-btn-primary:active { transform:translateY(0); }

            .gd-btn-secondary {
                background:rgba(255,255,255,.06); color:#94a3b8; border:1px solid rgba(255,255,255,.08);
                border-radius:8px; padding:7px 12px; font-size:11px; font-weight:500; cursor:pointer; transition:all .2s;
            }
            .gd-btn-secondary:hover { background:rgba(255,255,255,.1); color:#e2e8f0; border-color:rgba(255,255,255,.15); }

            .gd-tabs { display:flex; gap:2px; background:rgba(0,0,0,.3); border-radius:8px; padding:3px; margin-bottom:12px; }
            .gd-tab {
                flex:1; background:transparent; border:none; color:rgba(255,255,255,.4);
                font-size:10px; font-weight:600; padding:6px 8px; border-radius:6px;
                cursor:pointer; transition:all .2s; text-transform:uppercase; letter-spacing:.3px;
            }
            .gd-tab:hover { color:rgba(255,255,255,.7); }
            .gd-tab.active { background:rgba(99,102,241,.2); color:#a5b4fc; }

            .gd-rule-card {
                background:rgba(255,255,255,.03); border:1px solid rgba(255,255,255,.06);
                border-radius:10px; padding:10px 12px; margin-bottom:8px; transition:all .2s; animation:gdFade .2s ease;
            }
            .gd-rule-card:hover { border-color:rgba(99,102,241,.2); background:rgba(255,255,255,.05); }
            .gd-rule-card.disabled { opacity:.4; }

            .gd-toggle {
                position:relative; width:32px; height:18px; background:rgba(255,255,255,.1);
                border-radius:9px; cursor:pointer; transition:background .25s; flex-shrink:0;
            }
            .gd-toggle.active { background:#6366f1; }
            .gd-toggle::after {
                content:''; position:absolute; top:2px; left:2px; width:14px; height:14px;
                background:white; border-radius:50%; transition:transform .25s cubic-bezier(.34,1.56,.64,1);
            }
            .gd-toggle.active::after { transform:translateX(14px); }

            .gd-fab {
                width:44px; height:44px; border-radius:50%;
                background:linear-gradient(135deg,#6366f1,#4f46e5); border:none; color:white;
                font-size:20px; cursor:pointer; display:flex; align-items:center; justify-content:center;
                box-shadow:0 4px 20px rgba(99,102,241,.4);
                transition:all .3s cubic-bezier(.34,1.56,.64,1); position:relative;
            }
            .gd-fab:hover { transform:scale(1.1); box-shadow:0 6px 25px rgba(99,102,241,.5); }
            .gd-fab:active { transform:scale(.95); }
            .gd-fab.has-match { animation:gdPulse 2s infinite; }
            .gd-match-dot { position:absolute; top:-2px; right:-2px; width:12px; height:12px; background:#34d399; border-radius:50%; border:2px solid rgba(15,15,22,.97); }

            .gd-toast {
                position:fixed; bottom:70px; right:15px;
                background:linear-gradient(165deg,rgba(15,15,22,.97),rgba(22,22,35,.97));
                border:1px solid rgba(99,102,241,.3); border-radius:10px; padding:10px 14px;
                z-index:999999; color:#e2e8f0; font-size:11px;
                box-shadow:0 8px 30px rgba(0,0,0,.5); display:flex; align-items:center; gap:10px;
                animation:gdUp .3s cubic-bezier(.22,1,.36,1); backdrop-filter:blur(20px);
            }
            .gd-toast-btn {
                background:linear-gradient(135deg,#6366f1,#4f46e5); color:white; border:none;
                padding:5px 10px; border-radius:6px; cursor:pointer; font-size:10px; font-weight:600;
                transition:all .2s; white-space:nowrap;
            }
            .gd-toast-btn:hover { background:linear-gradient(135deg,#818cf8,#6366f1); transform:translateY(-1px); }
            .gd-toast-btn.alt { background:rgba(59,130,246,.2); color:#93c5fd; border:1px solid rgba(59,130,246,.3); }
            .gd-toast-btn.alt:hover { background:rgba(59,130,246,.3); }

            .gd-link-badge {
                cursor:pointer; font-size:12px; margin-left:4px; display:inline-flex;
                align-items:center; justify-content:center; width:20px; height:20px; border-radius:4px;
                background:rgba(99,102,241,.15); transition:all .2s; vertical-align:middle; text-decoration:none;
            }
            .gd-link-badge:hover { background:rgba(99,102,241,.3); transform:scale(1.15); }

            .gd-scroll::-webkit-scrollbar { width:4px; }
            .gd-scroll::-webkit-scrollbar-track { background:transparent; }
            .gd-scroll::-webkit-scrollbar-thumb { background:rgba(255,255,255,.1); border-radius:2px; }

            .gd-modal-overlay { position:fixed; inset:0; background:rgba(0,0,0,.6); z-index:9999998; animation:gdFade .2s ease; backdrop-filter:blur(4px); }
            .gd-modal {
                position:fixed; top:50%; left:50%; transform:translate(-50%,-50%);
                width:420px; max-height:80vh;
                background:linear-gradient(165deg,rgba(15,15,22,.98),rgba(22,22,35,.98));
                border:1px solid rgba(255,255,255,.08); border-radius:16px; padding:0;
                z-index:9999999; color:#e2e8f0;
                box-shadow:0 25px 60px rgba(0,0,0,.6); backdrop-filter:blur(20px);
                animation:gdUp .3s cubic-bezier(.22,1,.36,1); overflow:hidden;
                display:flex; flex-direction:column;
            }
            .gd-modal-header { padding:16px 18px 12px; border-bottom:1px solid rgba(255,255,255,.06); display:flex; align-items:center; justify-content:space-between; flex-shrink:0; }
            .gd-modal-body { padding:14px 18px; overflow-y:auto; flex:1; }
            .gd-modal-footer { padding:12px 18px; border-top:1px solid rgba(255,255,255,.06); flex-shrink:0; }

            .gd-status-success { color:#34d399; }
            .gd-status-error   { color:#f87171; }
            .gd-status-loading { color:#60a5fa; }
        `);
    }

    // ── Category Config ─────────────────────────────────────────────────
    const CATS = {
        tooown:    { icon:'🗣️', label:'TOoOwn Vocals' },
        rvc:       { icon:'🎭', label:'RVC Models' },
        voices:    { icon:'🎙️', label:'ComfyUI Voices' },
        downloads: { icon:'📥', label:'Downloads' },
        music:     { icon:'🎵', label:'Music' },
        videos:    { icon:'🎬', label:'Videos' },
        documents: { icon:'📄', label:'Documents' },
        custom:    { icon:'⚙️', label:'Custom Path' }
    };
    function catOpts(sel) {
        return Object.entries(CATS).map(([k,{icon,label}]) =>
            `<option value="${k}" ${k===sel?'selected':''}>${icon} ${label}</option>`
        ).join('');
    }

    // ── Download Request ────────────────────────────────────────────────
    // Keeps status element updated inside UI panels
    function sendDL(url, filename, category, customPath, statusEl) {
        if (statusEl) { statusEl.className='gd-status-loading'; statusEl.innerHTML='<span style="display:inline-block;animation:gdSpin .8s linear infinite">⏳</span> Slinging...'; }
        GM_xmlhttpRequest({
            method:"POST", url:API_URL,
            data:JSON.stringify({url, filename, category, custom_path:customPath}),
            headers:{"Content-Type":"application/json"},
            onload(res) {
                try {
                    const r = JSON.parse(res.responseText);
                    if (res.status===200) { if(statusEl){statusEl.className='gd-status-success'; statusEl.textContent='✓ Saved!'; setTimeout(()=>statusEl.textContent='',3500);} }
                    else { if(statusEl){statusEl.className='gd-status-error'; statusEl.textContent='✗ '+(r.error||'Server error');} }
                } catch(e) { if(statusEl){statusEl.className='gd-status-error'; statusEl.textContent='✗ Bad response';} }
            },
            onerror() { if(statusEl){statusEl.className='gd-status-error'; statusEl.textContent='✗ Offline — run gravity_drop.py';} }
        });
    }

    // ── Intercept Audio Playback ────────────────────────────────────────
    const origPlay = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function() {
        const hasMatch = getMatchingRule() !== null;
        const src = this.currentSrc || this.src;
        if (src && src !== lastPlayingUrl && (hasMatch || uiInitialized)) {
            lastPlayingUrl = src;
            console.log("☄️ GravityDrop captured audio:", lastPlayingUrl);
            
            initUI();
            
            const urlIn = document.querySelector('#gd-url');
            if (urlIn) {
                urlIn.value = lastPlayingUrl;
                const raw = document.querySelector('h1')?.innerText || document.title;
                const clean = raw.trim().replace(/[^a-z0-9]/gi,'_').toLowerCase();
                const ext = lastPlayingUrl.split('.').pop().split('?')[0]||'mp3';
                const fn = document.querySelector('#gd-filename');
                if(fn) fn.value = `${clean}_preview.${ext}`;
                const rule = getMatchingRule();
                if(rule){ const cs=document.querySelector('#gd-category'); if(cs){cs.value=rule.category; cs.dispatchEvent(new Event('change'));} }
            }
            showAudioToast(lastPlayingUrl);
        } else if (hasMatch || uiInitialized) {
            const self = this;
            const captureSrc = () => {
                const s = self.currentSrc || self.src;
                if (s && s !== lastPlayingUrl) {
                    lastPlayingUrl = s;
                    console.log("☄️ GravityDrop captured audio via event:", lastPlayingUrl);
                    
                    initUI();
                    
                    const urlIn = document.querySelector('#gd-url');
                    if (urlIn) {
                        urlIn.value = lastPlayingUrl;
                        const raw = document.querySelector('h1')?.innerText || document.title;
                        const clean = raw.trim().replace(/[^a-z0-9]/gi,'_').toLowerCase();
                        const ext = lastPlayingUrl.split('.').pop().split('?')[0]||'mp3';
                        const fn = document.querySelector('#gd-filename');
                        if(fn) fn.value = `${clean}_preview.${ext}`;
                        const rule = getMatchingRule();
                        if(rule){ const cs=document.querySelector('#gd-category'); if(cs){cs.value=rule.category; cs.dispatchEvent(new Event('change'));} }
                    }
                    showAudioToast(lastPlayingUrl);
                }
            };
            this.addEventListener('loadstart', captureSrc, { once: true });
            this.addEventListener('play', captureSrc, { once: true });
        }
        return origPlay.apply(this,arguments);
    };

    // ── Build DOM Elements ──────────────────────────────────────────────
    function buildDomElements() {
        if (document.getElementById('gd-root')) return;

        root = document.createElement('div');
        root.id = 'gd-root';
        root.style.cssText = 'position:fixed;bottom:15px;right:15px;z-index:999999;display:flex;flex-direction:column;align-items:flex-end;gap:10px;';
        document.body.appendChild(root);

        const matchRule = getMatchingRule();
        panel = document.createElement('div');
        panel.className = 'gd-panel';
        panel.style.display = 'none';
        const defCat = matchRule ? matchRule.category : 'downloads';

        panel.innerHTML = `
            <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:10px;padding-bottom:8px;border-bottom:1px solid rgba(255,255,255,.06);">
                <div style="display:flex;align-items:center;gap:7px;">
                    <span style="font-size:16px;">☄️</span>
                    <div>
                        <div style="font-size:13px;font-weight:700;letter-spacing:-.3px;">GravityDrop</div>
                        <div style="font-size:9px;color:rgba(255,255,255,.3);font-weight:500;">v3.1 · Port 18188</div>
                    </div>
                </div>
                <div style="display:flex;align-items:center;gap:6px;">
                    <button id="gd-rules-btn" class="gd-btn-secondary" style="padding:5px 8px;font-size:10px;" title="Manage Site Rules">⚙ Rules</button>
                    <span id="gd-close-btn" style="cursor:pointer;color:rgba(255,255,255,.3);font-size:18px;line-height:1;transition:color .2s;">&times;</span>
                </div>
            </div>

            ${matchRule ? `
            <div id="gd-auto-route-badge" style="background:rgba(99,102,241,.1);border:1px solid rgba(99,102,241,.2);border-radius:8px;padding:8px 10px;margin-bottom:10px;display:flex;align-items:center;gap:7px;">
                <span style="font-size:10px;color:#a5b4fc;">🔗 Auto-routing: <strong>${matchRule.label||matchRule.hostname}</strong></span>
            </div>` : ''}

            <div class="gd-tabs">
                <button class="gd-tab active" data-tab="download">⬇ Download</button>
                <button class="gd-tab" data-tab="quick">⚡ Quick Add</button>
            </div>

            <div id="gd-tab-download">
                <div style="margin-bottom:8px;"><label class="gd-label">URL</label><input type="text" id="gd-url" class="gd-input" placeholder="Paste or captured URL..."></div>
                <div style="margin-bottom:8px;"><label class="gd-label">Filename</label><input type="text" id="gd-filename" class="gd-input" placeholder="Auto-detect from URL"></div>
                <div style="margin-bottom:8px;"><label class="gd-label">Category</label><select id="gd-category" class="gd-select">${catOpts(defCat)}</select></div>
                <div id="gd-custom-path-container" style="margin-bottom:8px;display:none;"><label class="gd-label">Custom Path</label><input type="text" id="gd-custom-path" class="gd-input" placeholder="/absolute/path/to/folder"></div>
                <button id="gd-send-btn" class="gd-btn-primary">☄️ Sling File</button>
                <div id="gd-status" style="margin-top:8px;font-size:10px;min-height:14px;text-align:center;transition:all .2s;"></div>
            </div>

            <div id="gd-tab-quick" style="display:none;">
                <div style="text-align:center;padding:8px 0;">
                    <p style="font-size:11px;color:rgba(255,255,255,.5);margin:0 0 10px;">Save <strong style="color:#a5b4fc;">${window.location.hostname}</strong> as a download rule?</p>
                    <div style="margin-bottom:8px;"><label class="gd-label">Label</label><input type="text" id="gd-quick-label" class="gd-input" value="${document.title.substring(0,30)}" placeholder="Rule name"></div>
                    <div style="margin-bottom:8px;"><label class="gd-label">Default Category</label><select id="gd-quick-category" class="gd-select">${catOpts('downloads')}</select></div>
                    <div id="gd-quick-custom-container" style="margin-bottom:8px;display:none;"><label class="gd-label">Custom Path</label><input type="text" id="gd-quick-custom-path" class="gd-input" placeholder="/absolute/path"></div>
                    <div style="margin-bottom:8px;"><label class="gd-label">File Types (comma-separated)</label><input type="text" id="gd-quick-filetypes" class="gd-input" value="mp3,wav,flac,pth,index,zip,safetensors" placeholder="mp3,wav,zip..."></div>
                    <button id="gd-quick-save-btn" class="gd-btn-primary">💾 Save Rule for This Site</button>
                    <div id="gd-quick-status" style="margin-top:8px;font-size:10px;min-height:14px;text-align:center;"></div>
                </div>
            </div>
        `;
        root.appendChild(panel);

        // FAB
        fab = document.createElement('button');
        fab.className = 'gd-fab' + (matchRule ? ' has-match' : '');
        fab.innerHTML = '☄️';
        fab.title = 'GravityDrop';
        if (matchRule) { const d=document.createElement('span'); d.className='gd-match-dot'; fab.appendChild(d); }
        root.appendChild(fab);

        // ── Tab switching ───────────────────────────────────────────────────
        panel.querySelectorAll('.gd-tab').forEach(tab => {
            tab.onclick = () => {
                panel.querySelectorAll('.gd-tab').forEach(t=>t.classList.remove('active'));
                tab.classList.add('active');
                const t = tab.dataset.tab;
                panel.querySelector('#gd-tab-download').style.display = t==='download' ? 'block' : 'none';
                panel.querySelector('#gd-tab-quick').style.display    = t==='quick'    ? 'block' : 'none';
            };
        });

        // Toggle panel display
        fab.onclick = () => { panel.style.display = panel.style.display==='none' ? 'block' : 'none'; };
        panel.querySelector('#gd-close-btn').onclick = () => panel.style.display='none';
        panel.querySelector('#gd-close-btn').onmouseenter = function(){this.style.color='#fff';};
        panel.querySelector('#gd-close-btn').onmouseleave = function(){this.style.color='rgba(255,255,255,.3)';};

        // Category → custom path visibility listeners
        const catSel = panel.querySelector('#gd-category');
        const custBox = panel.querySelector('#gd-custom-path-container');
        catSel.onchange = () => { custBox.style.display = catSel.value==='custom' ? 'block' : 'none'; };

        const qCatSel = panel.querySelector('#gd-quick-category');
        const qCustBox = panel.querySelector('#gd-quick-custom-container');
        qCatSel.onchange = () => { qCustBox.style.display = qCatSel.value==='custom' ? 'block' : 'none'; };

        // ── Send button ─────────────────────────────────────────────────────
        const statusDiv = panel.querySelector('#gd-status');
        panel.querySelector('#gd-send-btn').onclick = () => {
            const url = panel.querySelector('#gd-url').value.trim();
            const filename = panel.querySelector('#gd-filename').value.trim();
            const cat = catSel.value;
            const cpath = panel.querySelector('#gd-custom-path').value.trim();
            if (!url) { statusDiv.className='gd-status-error'; statusDiv.textContent='✗ Please enter a URL'; return; }
            sendDL(url, filename, cat, cat==='custom' ? cpath : null, statusDiv);
        };

        // ── Quick save rule ─────────────────────────────────────────────────
        panel.querySelector('#gd-quick-save-btn').onclick = () => {
            const label     = panel.querySelector('#gd-quick-label').value.trim();
            const category  = qCatSel.value;
            const cpath     = panel.querySelector('#gd-quick-custom-path')?.value.trim()||'';
            const fileTypes = panel.querySelector('#gd-quick-filetypes').value.trim();
            const qStatus   = panel.querySelector('#gd-quick-status');
            const hostname  = window.location.hostname;
            const rules     = loadRules();

            const idx = rules.findIndex(r => {
                try { return new URL(r.hostname.startsWith('http')?r.hostname:'https://'+r.hostname).hostname === hostname; }
                catch(e) { return r.hostname===hostname; }
            });

            const newRule = {
                id: idx>=0 ? rules[idx].id : genId(),
                hostname, category,
                customPath: category==='custom' ? cpath : '',
                label: label||hostname,
                enabled: true,
                fileTypes
            };
            if (idx>=0) rules[idx]=newRule; else rules.push(newRule);
            saveRules(rules);

            qStatus.className='gd-status-success';
            qStatus.textContent='✓ Rule saved! Downloads from this site auto-route.';
            setTimeout(()=>qStatus.textContent='',4000);

            if (!fab.classList.contains('has-match')) {
                fab.classList.add('has-match');
                if (!fab.querySelector('.gd-match-dot')) { const d=document.createElement('span'); d.className='gd-match-dot'; fab.appendChild(d); }
            }

            // Update panel auto-route badge
            let ab = panel.querySelector('#gd-auto-route-badge');
            if (!ab) {
                ab = document.createElement('div');
                ab.id = 'gd-auto-route-badge';
                ab.style.cssText = 'background:rgba(99,102,241,.1);border:1px solid rgba(99,102,241,.2);border-radius:8px;padding:8px 10px;margin-bottom:10px;display:flex;align-items:center;gap:7px;';
                panel.insertBefore(ab, panel.querySelector('.gd-tabs'));
            }
            ab.innerHTML = `<span style="font-size:10px;color:#a5b4fc;">🔗 Auto-routing: <strong>${newRule.label||newRule.hostname}</strong></span>`;

            // Start scanning and integrations for this newly configured site!
            startAutoScan();
            startSiteIntegrations();
        };

        // Open Rules modal bind
        panel.querySelector('#gd-rules-btn').onclick = () => openRulesModal();
    }

    // ── Rules Manager Modal ─────────────────────────────────────────────
    function openRulesModal() {
        document.querySelectorAll('.gd-modal-overlay,.gd-modal').forEach(el=>el.remove());

        const overlay = document.createElement('div');
        overlay.className='gd-modal-overlay';
        document.body.appendChild(overlay);

        const modal = document.createElement('div');
        modal.className='gd-modal';
        const rules = loadRules();

        modal.innerHTML = `
            <div class="gd-modal-header">
                <div>
                    <div style="font-size:15px;font-weight:700;letter-spacing:-.3px;">⚙️ Site Rules</div>
                    <div style="font-size:10px;color:rgba(255,255,255,.35);margin-top:2px;">${rules.length} rule${rules.length!==1?'s':''} configured</div>
                </div>
                <span id="gd-modal-close" style="cursor:pointer;color:rgba(255,255,255,.3);font-size:22px;line-height:1;transition:color .2s;">&times;</span>
            </div>
            <div class="gd-modal-body gd-scroll" id="gd-rules-list">
                ${rules.length===0 ? `
                    <div style="text-align:center;padding:30px 10px;">
                        <div style="font-size:28px;margin-bottom:10px;">🌐</div>
                        <div style="font-size:12px;color:rgba(255,255,255,.4);">No site rules yet</div>
                        <div style="font-size:10px;color:rgba(255,255,255,.25);margin-top:4px;">Use "Quick Add" or add one below.</div>
                    </div>
                ` : rules.map(rule => `
                    <div class="gd-rule-card ${rule.enabled?'':'disabled'}" data-rule-id="${rule.id}">
                        <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:6px;">
                            <div style="display:flex;align-items:center;gap:8px;min-width:0;">
                                <span style="font-size:13px;">${CATS[rule.category]?.icon||'📁'}</span>
                                <div style="min-width:0;">
                                    <div style="font-size:12px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${rule.label||rule.hostname}</div>
                                    <div style="font-size:9px;color:rgba(255,255,255,.3);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${rule.hostname}</div>
                                </div>
                            </div>
                            <div style="display:flex;align-items:center;gap:8px;flex-shrink:0;">
                                <div class="gd-toggle ${rule.enabled?'active':''}" data-toggle-id="${rule.id}" title="${rule.enabled?'Disable':'Enable'}"></div>
                                <span class="gd-rule-delete" data-delete-id="${rule.id}" style="cursor:pointer;color:rgba(255,255,255,.2);font-size:14px;transition:color .2s;" title="Delete">🗑</span>
                            </div>
                        </div>
                        <div style="display:flex;gap:6px;flex-wrap:wrap;">
                            <span style="font-size:9px;background:rgba(99,102,241,.15);color:#a5b4fc;padding:2px 6px;border-radius:4px;">${CATS[rule.category]?.label||rule.category}</span>
                            ${rule.fileTypes ? rule.fileTypes.split(',').slice(0,5).map(ft=>`<span style="font-size:9px;background:rgba(255,255,255,.06);color:rgba(255,255,255,.4);padding:2px 6px;border-radius:4px;">.${ft.trim()}</span>`).join('') : ''}
                            ${rule.fileTypes&&rule.fileTypes.split(',').length>5 ? `<span style="font-size:9px;color:rgba(255,255,255,.25);">+${rule.fileTypes.split(',').length-5}</span>` : ''}
                        </div>
                        ${rule.customPath ? `<div style="font-size:9px;color:rgba(255,255,255,.2);margin-top:5px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">📂 ${rule.customPath}</div>` : ''}
                    </div>
                `).join('')}
            </div>
            <div class="gd-modal-footer">
                <div style="margin-bottom:10px;padding-top:10px;border-top:1px solid rgba(255,255,255,.06);">
                    <div style="font-size:10px;font-weight:600;color:rgba(255,255,255,.5);margin-bottom:8px;text-transform:uppercase;letter-spacing:.5px;">Add New Rule</div>
                    <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-bottom:6px;">
                        <div><label class="gd-label">Site URL</label><input type="text" id="gd-new-hostname" class="gd-input" placeholder="e.g. weights.gg"></div>
                        <div><label class="gd-label">Label</label><input type="text" id="gd-new-label" class="gd-input" placeholder="My Label"></div>
                    </div>
                    <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-bottom:6px;">
                        <div><label class="gd-label">Category</label><select id="gd-new-category" class="gd-select">${catOpts('downloads')}</select></div>
                        <div><label class="gd-label">File Types</label><input type="text" id="gd-new-filetypes" class="gd-input" value="mp3,wav,zip,pth" placeholder="mp3,wav..."></div>
                    </div>
                    <div id="gd-new-custom-container" style="margin-bottom:6px;display:none;">
                        <label class="gd-label">Custom Path</label><input type="text" id="gd-new-custom-path" class="gd-input" placeholder="/absolute/path">
                    </div>
                    <button id="gd-add-rule-btn" class="gd-btn-primary" style="font-size:11px;padding:8px;">＋ Add Rule</button>
                </div>
            </div>
        `;
        document.body.appendChild(modal);

        // Close bindings
        const closeModal = () => { overlay.remove(); modal.remove(); };
        overlay.onclick = closeModal;
        modal.querySelector('#gd-modal-close').onclick = closeModal;
        modal.querySelector('#gd-modal-close').onmouseenter = function(){this.style.color='#fff';};
        modal.querySelector('#gd-modal-close').onmouseleave = function(){this.style.color='rgba(255,255,255,.3)';};

        // Toggle rules
        modal.querySelectorAll('.gd-toggle').forEach(tog => {
            tog.onclick = () => {
                const id = tog.dataset.toggleId;
                const rs = loadRules();
                const r = rs.find(x=>x.id===id);
                if(r){
                    r.enabled=!r.enabled;
                    saveRules(rs);
                    tog.classList.toggle('active');
                    tog.closest('.gd-rule-card').classList.toggle('disabled');
                    
                    // Update current site scanner status in case we just toggled the rule for the current site
                    const match = getMatchingRule();
                    if (fab) {
                        if (match) {
                            if (!fab.classList.contains('has-match')) {
                                fab.classList.add('has-match');
                                if (!fab.querySelector('.gd-match-dot')) { const d=document.createElement('span'); d.className='gd-match-dot'; fab.appendChild(d); }
                            }
                            startAutoScan();
                            startSiteIntegrations();
                        } else {
                            fab.classList.remove('has-match');
                            const dot = fab.querySelector('.gd-match-dot');
                            if (dot) dot.remove();
                            // Stop scans
                            if (autoScanInterval) { clearInterval(autoScanInterval); autoScanInterval = null; }
                            stopSiteIntegrations();
                        }
                    }
                }
            };
        });

        // Delete rules
        modal.querySelectorAll('.gd-rule-delete').forEach(btn => {
            btn.onmouseenter = function(){this.style.color='#f87171';};
            btn.onmouseleave = function(){this.style.color='rgba(255,255,255,.2)';};
            btn.onclick = () => {
                const id = btn.dataset.deleteId;
                let rs = loadRules().filter(r=>r.id!==id);
                saveRules(rs);
                const card = btn.closest('.gd-rule-card');
                card.style.opacity='0'; card.style.transform='translateX(20px)'; card.style.transition='all .25s';
                setTimeout(()=>{
                    card.remove();
                    const cnt = modal.querySelector('.gd-modal-header div:first-child > div:last-child');
                    if(cnt) cnt.textContent=`${rs.length} rule${rs.length!==1?'s':''} configured`;
                    if(rs.length===0) modal.querySelector('#gd-rules-list').innerHTML=`<div style="text-align:center;padding:30px 10px;"><div style="font-size:28px;margin-bottom:10px;">🌐</div><div style="font-size:12px;color:rgba(255,255,255,.4);">No site rules</div></div>`;
                    
                    // Update current site scanner status
                    const match = getMatchingRule();
                    if (fab) {
                        if (match) {
                            if (!fab.classList.contains('has-match')) {
                                fab.classList.add('has-match');
                                if (!fab.querySelector('.gd-match-dot')) { const d=document.createElement('span'); d.className='gd-match-dot'; fab.appendChild(d); }
                            }
                            startAutoScan();
                            startSiteIntegrations();
                        } else {
                            fab.classList.remove('has-match');
                            const dot = fab.querySelector('.gd-match-dot');
                            if (dot) dot.remove();
                            // Stop scans
                            if (autoScanInterval) { clearInterval(autoScanInterval); autoScanInterval = null; }
                            stopSiteIntegrations();
                        }
                    }
                },250);
            };
        });

        // New rule: custom path visibility
        const nCatSel = modal.querySelector('#gd-new-category');
        const nCustBox = modal.querySelector('#gd-new-custom-container');
        nCatSel.onchange = () => { nCustBox.style.display = nCatSel.value==='custom' ? 'block' : 'none'; };

        // Add new rule
        modal.querySelector('#gd-add-rule-btn').onclick = () => {
            const hostname  = modal.querySelector('#gd-new-hostname').value.trim();
            const label     = modal.querySelector('#gd-new-label').value.trim();
            const category  = nCatSel.value;
            const cpath     = modal.querySelector('#gd-new-custom-path')?.value.trim()||'';
            const fileTypes = modal.querySelector('#gd-new-filetypes').value.trim();

            if(!hostname){ modal.querySelector('#gd-new-hostname').style.borderColor='#f87171'; setTimeout(()=>modal.querySelector('#gd-new-hostname').style.borderColor='',2000); return; }

            const rs = loadRules();
            rs.push({ id:genId(), hostname, category, customPath:category==='custom'?cpath:'', label:label||hostname, enabled:true, fileTypes });
            saveRules(rs);
            closeModal();
            openRulesModal();

            // Check if matches the current site and updates it on the fly
            const match = getMatchingRule();
            if (match && fab) {
                if (!fab.classList.contains('has-match')) {
                    fab.classList.add('has-match');
                    if (!fab.querySelector('.gd-match-dot')) { const d=document.createElement('span'); d.className='gd-match-dot'; fab.appendChild(d); }
                }
                startAutoScan();
                startSiteIntegrations();
            }
        };
    }

    // ── Audio Toast ─────────────────────────────────────────────────────
    function showAudioToast(audioUrl) {
        document.querySelectorAll('.gd-toast').forEach(t=>t.remove());
        const toast = document.createElement('div');
        toast.className = 'gd-toast';
        const fname = decodeURIComponent(audioUrl.split('/').pop().split('?')[0])||'voice_sample.mp3';
        const rule = getMatchingRule();
        const tCat = rule ? rule.category : 'tooown';
        const tLabel = CATS[tCat]?.label||tCat;

        toast.innerHTML = `
            <span style="font-size:14px;">🎵</span>
            <div style="flex:1;min-width:0;">
                <div style="font-size:10px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Captured Audio</div>
                <div style="font-size:9px;color:rgba(255,255,255,.35);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${fname}</div>
            </div>
            <button class="gd-toast-btn" id="gd-toast-primary">Save → ${tLabel}</button>
            ${!rule?'<button class="gd-toast-btn alt" id="gd-toast-comfy">ComfyUI</button>':''}
            <span id="gd-toast-close" style="cursor:pointer;color:rgba(255,255,255,.25);font-size:16px;transition:color .2s;">&times;</span>
        `;
        document.body.appendChild(toast);

        const dismiss = () => { toast.style.opacity='0'; toast.style.transform='translateY(10px)'; toast.style.transition='all .3s'; setTimeout(()=>toast.remove(),300); };

        toast.querySelector('#gd-toast-primary').onclick = () => { sendDL(audioUrl,fname,tCat,rule?.customPath||null,null); dismiss(); };
        const cb = toast.querySelector('#gd-toast-comfy');
        if(cb) cb.onclick = () => { sendDL(audioUrl,fname,'voices',null,null); dismiss(); };
        toast.querySelector('#gd-toast-close').onclick = dismiss;
        toast.querySelector('#gd-toast-close').onmouseenter = function(){this.style.color='#fff';};

        setTimeout(()=>{ if(toast.parentNode) dismiss(); }, 8000);
    }

    // ── Link Hover Badges ────────────────────────────────────────────────
    let hoverListenerRegistered = false;
    function registerHoverBadges() {
        if (hoverListenerRegistered) return;
        hoverListenerRegistered = true;

        const fileExts = /\.(pth|index|wav|mp3|flac|safetensors|ckpt|zip|tar|gz|mp4|mkv|ogg|aac|m4a|pdf)$/i;
        const hfRe = /huggingface\.co\/.*\/resolve\/[^\/]+\/(.+)$/i;

        document.addEventListener('mouseover', (e) => {
            const link = e.target.closest('a');
            if (!link || link.dataset.gdChecked) return;
            const url = link.href;
            if (!url) return;
            const isHF = hfRe.test(url);

            const rule = getMatchingRule();
            let matchesRule = false;
            if (rule?.fileTypes) {
                const exts = rule.fileTypes.split(',').map(s=>s.trim().toLowerCase());
                matchesRule = exts.some(ext=>url.toLowerCase().endsWith('.'+ext));
            }

            if (fileExts.test(url) || isHF || url.includes('download') || matchesRule) {
                link.dataset.gdChecked = 'true';
                const badge = document.createElement('span');
                badge.className = 'gd-link-badge';
                badge.innerHTML = '☄️';
                badge.title = 'Drop locally with GravityDrop';

                badge.onclick = (ev) => {
                    ev.preventDefault(); ev.stopPropagation();
                    initUI();
                    panel.style.display='block';
                    panel.querySelector('#gd-url').value = url;
                    panel.querySelector('#gd-filename').value = decodeURIComponent(url.split('/').pop().split('?')[0]);

                    const catSel = panel.querySelector('#gd-category');
                    if (rule) {
                        catSel.value = rule.category;
                        if (rule.category==='custom' && rule.customPath) {
                            panel.querySelector('#gd-custom-path').value = rule.customPath;
                        }
                    } else if (isHF) {
                        const m=url.match(hfRe); const fp=m?m[1]:'';
                        if (/\.(wav|mp3|flac)$/i.test(fp)) catSel.value='tooown';
                        else if (/\.(pth|index|safetensors|ckpt)$/i.test(fp)) catSel.value='rvc';
                        else catSel.value='downloads';
                    } else {
                        if (/\.(wav|mp3|flac)$/i.test(url)) catSel.value='tooown';
                        else if (/\.(pth|index|safetensors|ckpt)$/i.test(url)) catSel.value='rvc';
                        else if (/\.(mp4|mkv)$/i.test(url)) catSel.value='videos';
                        else catSel.value='downloads';
                    }
                    catSel.dispatchEvent(new Event('change'));
                };
                link.appendChild(badge);
            }
        });
    }

    // ── Auto-scan Badges ─────────────────────────────────────────────────
    let autoScanInterval = null;
    function startAutoScan() {
        if (autoScanInterval) {
            clearInterval(autoScanInterval);
            autoScanInterval = null;
        }
        const autoRule = getMatchingRule();
        if (autoRule?.fileTypes) {
            const rExts = autoRule.fileTypes.split(',').map(s=>s.trim().toLowerCase());
            const scan = () => {
                document.querySelectorAll('a[href]').forEach(link => {
                    if(link.dataset.gdChecked) return;
                    const href=link.href.toLowerCase();
                    if(rExts.some(ext=>href.endsWith('.'+ext))||href.includes('download')) {
                        link.dataset.gdChecked='true';
                        const badge=document.createElement('span');
                        badge.className='gd-link-badge'; badge.innerHTML='☄️';
                        badge.title=`Drop to ${CATS[autoRule.category]?.label||autoRule.category}`;
                        badge.onclick=(ev)=>{
                            ev.preventDefault();ev.stopPropagation();
                            const fn=decodeURIComponent(link.href.split('/').pop().split('?')[0]);
                            sendDL(link.href,fn,autoRule.category,autoRule.customPath||null,null);
                            badge.innerHTML='✓'; badge.style.background='rgba(52,211,153,.2)'; badge.style.color='#34d399';
                            setTimeout(()=>{badge.innerHTML='☄️';badge.style.background='';badge.style.color='';},2500);
                        };
                        link.appendChild(badge);
                    }
                });
            };
            setTimeout(scan,800);
            autoScanInterval = setInterval(scan,2000);
        }
    }

    // ── Voice-Models / Weights.gg Integrations ───────────────────────────
    let siteIntegrationsStarted = false;
    let siteIntegrationsInterval = null;

    function findModelDownloadLinks(doc = document) {
        const links = [];
        const seen = new Set();
        const anchors = doc.querySelectorAll('a[href]');
        
        const hostPattern = /(huggingface\.co|drive\.google\.com|mega\.nz|pixeldrain\.com|mediafire\.com)/i;
        const extPattern = /\.(zip|pth|index|rar|tar|gz|ckpt|safetensors)$/i;
        
        for (const a of anchors) {
            const href = a.href;
            if (seen.has(href)) continue;
            
            let score = 0;
            if (extPattern.test(href)) score += 10;
            if (hostPattern.test(href)) score += 5;
            if (href.includes('/resolve/')) score += 3;
            
            const text = a.textContent.trim().toLowerCase();
            if (text.includes('download')) score += 4;
            if (text.includes('model')) score += 2;
            if (text.includes('rvc')) score += 2;
            
            const className = (a.className || '').toLowerCase();
            if (className.includes('download')) score += 3;
            if (className.includes('btn')) score += 1;
            
            if (score >= 5) {
                links.push({ element: a, url: href, score });
                seen.add(href);
            }
        }
        
        links.sort((x, y) => y.score - x.score);
        return links;
    }

    function getDetailLink(card) {
        const anchors = card.querySelectorAll('a[href]');
        for (const a of anchors) {
            const href = a.getAttribute('href') || '';
            if (href.includes('/model/') || href.includes('/model-details/')) {
                return a.href;
            }
        }
        if (card.tagName === 'A') {
            const href = card.getAttribute('href') || '';
            if (href.includes('/model/') || href.includes('/model-details/')) {
                return card.href;
            }
        }
        return null;
    }

    function injectDetailPageButtons() {
        const links = findModelDownloadLinks(document);
        for (const item of links) {
            const originalLink = item.element;
            if (originalLink.dataset.gdBtnInjected) continue;
            originalLink.dataset.gdBtnInjected = 'true';
            
            const slingBtn = document.createElement('button');
            slingBtn.className = 'gd-btn-primary';
            slingBtn.style.cssText = 'width:auto; display:inline-flex; align-items:center; gap:5px; margin-left:8px; padding:6px 12px; font-size:11px; vertical-align:middle;';
            slingBtn.innerHTML = '☄️ Sling Model';
            slingBtn.title = 'Sling this file directly to RVC folder';
            
            slingBtn.onclick = (e) => {
                e.preventDefault(); e.stopPropagation();
                slingBtn.innerHTML = '⏳ Slinging...';
                slingBtn.disabled = true;
                
                const url = item.url;
                const fn = decodeURIComponent(url.split('/').pop().split('?')[0]);
                
                sendDL(url, fn, 'rvc', null, {
                    set className(val) {},
                    set textContent(val) {
                        if (val.includes('✓') || val.includes('Saved')) {
                            slingBtn.innerHTML = '✓ Saved!';
                            slingBtn.style.background = '#10b981';
                            setTimeout(() => {
                                slingBtn.innerHTML = '☄️ Sling Model';
                                slingBtn.style.background = '';
                                slingBtn.disabled = false;
                            }, 3000);
                        } else if (val.includes('✗') || val.includes('error') || val.includes('Offline')) {
                            slingBtn.innerHTML = '✗ Failed';
                            slingBtn.style.background = '#ef4444';
                            setTimeout(() => {
                                slingBtn.innerHTML = '☄️ Sling Model';
                                slingBtn.style.background = '';
                                slingBtn.disabled = false;
                            }, 3000);
                        }
                    }
                });
            };
            
            originalLink.parentNode.insertBefore(slingBtn, originalLink.nextSibling);
        }
    }

    function injectCardListButtons() {
        const sBase = {
            female:'https://s3.us-west-000.backblazeb2.com/bbvoe3/samples2/',
            male:  'https://s3.us-west-000.backblazeb2.com/bbvoe3/samples/'
        };
        
        document.querySelectorAll('.model-card').forEach(card => {
            if (card.dataset.gdBtnInjected) return;
            card.dataset.gdBtnInjected = 'true';
            
            const sn = card.dataset.sampleName;
            const te = card.querySelector('.model-title');
            let vn = 'voice_preview';
            if (te) vn = te.innerText.trim().replace(/[^a-z0-9]/gi,'_').toLowerCase().replace(/_+$/,'');
            
            const badgeContainer = document.createElement('span');
            badgeContainer.style.cssText = 'display:inline-flex; gap:4px; align-items:center; margin-right:8px; vertical-align:middle;';
            
            if (sn) {
                const st = window.location.pathname.includes('/male') ? 'male' : 'female';
                const aUrl = sBase[st] + encodeURIComponent(sn) + '.mp3';
                const previewBtn = document.createElement('a');
                previewBtn.href = 'javascript:void(0)';
                previewBtn.className = 'gd-link-badge';
                previewBtn.innerHTML = '🗣️';
                previewBtn.title = 'Sling Audio Preview to TOoOwn';
                previewBtn.onclick = (e) => {
                    e.preventDefault(); e.stopPropagation();
                    sendDL(aUrl, `${vn}_preview.mp3`, 'tooown', null, null);
                    previewBtn.innerHTML = '✓';
                    previewBtn.style.background = 'rgba(52,211,153,.2)';
                    setTimeout(() => { previewBtn.innerHTML = '🗣️'; previewBtn.style.background = ''; }, 2000);
                };
                badgeContainer.appendChild(previewBtn);
            }
            
            const detailUrl = getDetailLink(card);
            if (detailUrl) {
                const modelBtn = document.createElement('a');
                modelBtn.href = 'javascript:void(0)';
                modelBtn.className = 'gd-link-badge';
                modelBtn.innerHTML = '☄️';
                modelBtn.title = 'Sling Model (RVC) to Local Folder';
                
                modelBtn.onclick = (e) => {
                    e.preventDefault(); e.stopPropagation();
                    modelBtn.innerHTML = '⏳';
                    
                    GM_xmlhttpRequest({
                        method: "GET",
                        url: detailUrl,
                        onload(res) {
                            try {
                                const parser = new DOMParser();
                                const doc = parser.parseFromString(res.responseText, "text/html");
                                const links = findModelDownloadLinks(doc);
                                
                                if (links.length > 0) {
                                    const zipLink = links.find(l => l.url.toLowerCase().endsWith('.zip'));
                                    if (zipLink) {
                                        const fn = decodeURIComponent(zipLink.url.split('/').pop().split('?')[0]);
                                        sendDL(zipLink.url, fn, 'rvc', null, null);
                                    } else {
                                        const pthLink = links.find(l => l.url.toLowerCase().endsWith('.pth'));
                                        const indexLink = links.find(l => l.url.toLowerCase().endsWith('.index'));
                                        if (pthLink) {
                                            const fn = decodeURIComponent(pthLink.url.split('/').pop().split('?')[0]);
                                            sendDL(pthLink.url, fn, 'rvc', null, null);
                                        }
                                        if (indexLink) {
                                            const fn = decodeURIComponent(indexLink.url.split('/').pop().split('?')[0]);
                                            sendDL(indexLink.url, fn, 'rvc', null, null);
                                        }
                                        if (!pthLink && !indexLink) {
                                            const topLink = links[0];
                                            const fn = decodeURIComponent(topLink.url.split('/').pop().split('?')[0]);
                                            sendDL(topLink.url, fn, 'rvc', null, null);
                                        }
                                    }
                                    modelBtn.innerHTML = '✓';
                                    modelBtn.style.background = 'rgba(52,211,153,.2)';
                                } else {
                                    modelBtn.innerHTML = '✗';
                                    modelBtn.style.background = 'rgba(239,68,68,.2)';
                                }
                            } catch(err) {
                                modelBtn.innerHTML = '✗';
                                modelBtn.style.background = 'rgba(239,68,68,.2)';
                            }
                            setTimeout(() => { modelBtn.innerHTML = '☄️'; modelBtn.style.background = ''; }, 2500);
                        },
                        onerror() {
                            modelBtn.innerHTML = '✗';
                            modelBtn.style.background = 'rgba(239,68,68,.2)';
                            setTimeout(() => { modelBtn.innerHTML = '☄️'; modelBtn.style.background = ''; }, 2500);
                        }
                    });
                };
                badgeContainer.appendChild(modelBtn);
            }
            
            const cb = card.querySelector('.add-to-compare-btn') || card.querySelector('button, a');
            if (cb) {
                cb.parentNode.insertBefore(badgeContainer, cb);
            } else {
                card.appendChild(badgeContainer);
            }
        });

        document.querySelectorAll('.model-sample-btn').forEach(btn => {
            if (btn.dataset.gdBtnInjected) return;
            btn.dataset.gdBtnInjected = 'true';
            
            const sn = btn.dataset.sampleName;
            const row = btn.closest('tr, li, div[class*="row"]');
            let vn = 'voice_preview', isMale = false;
            
            if (row) {
                const te = row.querySelector('h3, span, div, a');
                if (te && te.innerText.trim().length > 2) {
                    vn = te.innerText.trim().replace(/[^a-z0-9]/gi,'_').toLowerCase();
                    const textLower = te.innerText.toLowerCase();
                    isMale = ['man','boy','hector','benson','don','stewie','roger','mr.'].some(k=>textLower.includes(k)) || (textLower.includes('male') && !textLower.includes('female'));
                }
            }
            
            const badgeContainer = document.createElement('span');
            badgeContainer.style.cssText = 'display:inline-flex; gap:4px; align-items:center; margin-left:8px; vertical-align:middle;';
            
            if (sn) {
                const aUrl = sBase[isMale ? 'male' : 'female'] + encodeURIComponent(sn) + '.mp3';
                const previewBtn = document.createElement('a');
                previewBtn.href = 'javascript:void(0)';
                previewBtn.className = 'gd-link-badge';
                previewBtn.innerHTML = '🗣️';
                previewBtn.title = 'Sling Audio Preview to TOoOwn';
                previewBtn.onclick = (e) => {
                    e.preventDefault(); e.stopPropagation();
                    sendDL(aUrl, `${vn}_preview.mp3`, 'tooown', null, null);
                    previewBtn.innerHTML = '✓';
                    previewBtn.style.background = 'rgba(52,211,153,.2)';
                    setTimeout(() => { previewBtn.innerHTML = '🗣️'; previewBtn.style.background = ''; }, 2000);
                };
                badgeContainer.appendChild(previewBtn);
            }
            
            const detailUrl = row ? getDetailLink(row) : null;
            if (detailUrl) {
                const modelBtn = document.createElement('a');
                modelBtn.href = 'javascript:void(0)';
                modelBtn.className = 'gd-link-badge';
                modelBtn.innerHTML = '☄️';
                modelBtn.title = 'Sling Model (RVC) to Local Folder';
                
                modelBtn.onclick = (e) => {
                    e.preventDefault(); e.stopPropagation();
                    modelBtn.innerHTML = '⏳';
                    
                    GM_xmlhttpRequest({
                        method: "GET",
                        url: detailUrl,
                        onload(res) {
                            try {
                                const parser = new DOMParser();
                                const doc = parser.parseFromString(res.responseText, "text/html");
                                const links = findModelDownloadLinks(doc);
                                
                                if (links.length > 0) {
                                    const zipLink = links.find(l => l.url.toLowerCase().endsWith('.zip'));
                                    if (zipLink) {
                                        const fn = decodeURIComponent(zipLink.url.split('/').pop().split('?')[0]);
                                        sendDL(zipLink.url, fn, 'rvc', null, null);
                                    } else {
                                        const pthLink = links.find(l => l.url.toLowerCase().endsWith('.pth'));
                                        const indexLink = links.find(l => l.url.toLowerCase().endsWith('.index'));
                                        if (pthLink) {
                                            const fn = decodeURIComponent(pthLink.url.split('/').pop().split('?')[0]);
                                            sendDL(pthLink.url, fn, 'rvc', null, null);
                                        }
                                        if (indexLink) {
                                            const fn = decodeURIComponent(indexLink.url.split('/').pop().split('?')[0]);
                                            sendDL(indexLink.url, fn, 'rvc', null, null);
                                        }
                                        if (!pthLink && !indexLink) {
                                            const topLink = links[0];
                                            const fn = decodeURIComponent(topLink.url.split('/').pop().split('?')[0]);
                                            sendDL(topLink.url, fn, 'rvc', null, null);
                                        }
                                    }
                                    modelBtn.innerHTML = '✓';
                                    modelBtn.style.background = 'rgba(52,211,153,.2)';
                                } else {
                                    modelBtn.innerHTML = '✗';
                                    modelBtn.style.background = 'rgba(239,68,68,.2)';
                                }
                            } catch(err) {
                                modelBtn.innerHTML = '✗';
                                modelBtn.style.background = 'rgba(239,68,68,.2)';
                            }
                            setTimeout(() => { modelBtn.innerHTML = '☄️'; modelBtn.style.background = ''; }, 2500);
                        },
                        onerror() {
                            modelBtn.innerHTML = '✗';
                            modelBtn.style.background = 'rgba(239,68,68,.2)';
                            setTimeout(() => { modelBtn.innerHTML = '☄️'; modelBtn.style.background = ''; }, 2500);
                        }
                    });
                };
                badgeContainer.appendChild(modelBtn);
            }
            
            btn.parentNode.insertBefore(badgeContainer, btn.nextSibling);
        });
    }

    function startSiteIntegrations() {
        if (siteIntegrationsStarted) return;
        const isVMP = window.location.hostname.includes('voice-models.com') || window.location.hostname.includes('weights.gg');
        if (isVMP) {
            siteIntegrationsStarted = true;
            const runInjections = () => {
                injectDetailPageButtons();
                injectCardListButtons();
            };
            setTimeout(runInjections, 1000);
            siteIntegrationsInterval = setInterval(runInjections, 1500);
        }
    }

    function stopSiteIntegrations() {
        if (siteIntegrationsInterval) {
            clearInterval(siteIntegrationsInterval);
            siteIntegrationsInterval = null;
        }
        siteIntegrationsStarted = false;
    }

    // ── Main UI Init ────────────────────────────────────────────────────
    function initUI() {
        if (uiInitialized) return;
        uiInitialized = true;

        injectStyles();
        buildDomElements();
        registerHoverBadges();
        startAutoScan();
        startSiteIntegrations();
    }

    // ── Startup Execution ───────────────────────────────────────────────
    // Check if the current site has a matching rule configured & enabled.
    // If it does, auto-initialize the UI. If not, do NOT inject anything.
    const initialMatch = getMatchingRule();
    if (initialMatch) {
        initUI();
    }

    // ── Tampermonkey Menu Commands ──────────────────────────────────────
    // These allow the user to open/configure GravityDrop even on unconfigured sites
    GM_registerMenuCommand("☄️ Open GravityDrop", () => {
        initUI();
        if (panel) {
            panel.style.display = panel.style.display==='none' ? 'block' : 'none';
        }
    });
    GM_registerMenuCommand("⚙️ Manage Site Rules", () => {
        initUI();
        openRulesModal();
    });
})();
