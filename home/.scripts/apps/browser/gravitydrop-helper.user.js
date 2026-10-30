// ==UserScript==
// @name         GravityDrop - Voice-Models & Weights.gg Helper
// @namespace    http://tampermonkey.net/
// @version      1.2
// @description  Adds direct GravityDrop buttons to voice-models.com and weights.gg model and preview pages.
// @author       KIEFR
// @match        *://*.voice-models.com/*
// @match        *://*.weights.gg/*
// @grant        GM_xmlhttpRequest
// @connect      localhost
// @connect      127.0.0.1
// ==/UserScript==

(function() {
    'use strict';

    const API_URL = "http://127.0.0.1:18188/download";
    let lastPlayingUrl = "";

    // Inject custom CSS styling for toasts and badges without needing @grant GM_addStyle
    const injectStyles = () => {
        if (document.getElementById('gd-helper-styles')) return;
        const style = document.createElement('style');
        style.id = 'gd-helper-styles';
        style.textContent = `
            @keyframes gdUp   { from{opacity:0;transform:translateY(12px) scale(.97)} to{opacity:1;transform:translateY(0) scale(1)} }
            @keyframes gdFade { from{opacity:0} to{opacity:1} }
            .gd-toast {
                position:fixed; bottom:20px; right:20px;
                background:linear-gradient(165deg,rgba(15,15,22,.97),rgba(22,22,35,.97));
                border:1px solid rgba(99,102,241,.3); border-radius:10px; padding:10px 14px;
                z-index:999999; color:#e2e8f0; font-size:11px; font-family:system-ui,-apple-system,sans-serif;
                box-shadow:0 8px 30px rgba(0,0,0,.5); display:flex; align-items:center; gap:10px;
                animation:gdUp .3s cubic-bezier(.22,1,.36,1); backdrop-filter:blur(20px);
            }
            .gd-toast-btn {
                background:linear-gradient(135deg,#6366f1,#4f46e5); color:white; border:none;
                padding:5px 10px; border-radius:6px; cursor:pointer; font-size:10px; font-weight:600;
                transition:all .2s; white-space:nowrap; font-family:system-ui,-apple-system,sans-serif;
            }
            .gd-toast-btn:hover { background:linear-gradient(135deg,#818cf8,#6366f1); transform:translateY(-1px); }
            
            .gd-link-badge {
                cursor:pointer; font-size:12px; margin-left:4px; display:inline-flex;
                align-items:center; justify-content:center; width:20px; height:20px; border-radius:4px;
                background:rgba(99,102,241,.15); transition:all .2s; vertical-align:middle; text-decoration:none;
            }
            .gd-link-badge:hover { background:rgba(99,102,241,.3); transform:scale(1.15); }
        `;
        document.head.appendChild(style);
    };

    // Heuristics link scanner to find actual direct download links inside HTML
    const findModelDownloadLinks = (doc = document) => {
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
                links.push({ url: href, score });
                seen.add(href);
            }
        }
        
        links.sort((x, y) => y.score - x.score);
        return links.map(l => l.url);
    };

    const getDetailLink = (card) => {
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
    };

    // Helper to send the request to gravity_drop.py
    const sendDownload = (url, filename, category, btn) => {
        if (btn) {
            btn.innerHTML = '⏳ Slinging...';
            btn.style.background = '#2563eb';
            if (btn.classList.contains('gd-link-badge')) {
                btn.style.background = 'rgba(37,99,235,.3)';
            }
        }
        GM_xmlhttpRequest({
            method: "POST",
            url: API_URL,
            data: JSON.stringify({ url, filename, category }),
            headers: { "Content-Type": "application/json" },
            onload: function(res) {
                if (res.status === 200) {
                    if (btn) {
                        btn.innerHTML = '✓';
                        btn.style.background = '#10b981';
                        if (btn.classList.contains('gd-link-badge')) {
                            btn.style.background = 'rgba(16,185,129,.3)';
                        } else {
                            btn.innerHTML = '✓ Sent!';
                        }
                        setTimeout(() => {
                            btn.innerHTML = btn.classList.contains('gd-link-badge') ? '🗣️' : '☄️ GravityDrop';
                            btn.style.background = '';
                        }, 3000);
                    }
                } else {
                    if (btn) {
                        btn.innerHTML = '❌';
                        btn.style.background = '#ef4444';
                        if (btn.classList.contains('gd-link-badge')) {
                            btn.style.background = 'rgba(239,68,68,.3)';
                        } else {
                            btn.innerHTML = '❌ Error';
                        }
                        setTimeout(() => {
                            btn.innerHTML = btn.classList.contains('gd-link-badge') ? '🗣️' : '☄️ GravityDrop';
                            btn.style.background = '';
                        }, 3000);
                    }
                    alert(`❌ GravityDrop error: ${res.responseText}`);
                }
            },
            onerror: function() {
                if (btn) {
                    btn.innerHTML = '❌';
                    btn.style.background = '#ef4444';
                    if (btn.classList.contains('gd-link-badge')) {
                        btn.style.background = 'rgba(239,68,68,.3)';
                    } else {
                        btn.innerHTML = '❌ Offline';
                    }
                    setTimeout(() => {
                        btn.innerHTML = btn.classList.contains('gd-link-badge') ? '🗣️' : '☄️ GravityDrop';
                        btn.style.background = '';
                    }, 3000);
                }
                alert("❌ Connection failed. Make sure gravity_drop.py is running in your terminal!");
            }
        });
    };

    // Resolves redirect links and finds direct download files
    const resolveAndDownload = (url, finalFilename, category, btn) => {
        const extPattern = /\.(zip|pth|index|rar|tar|gz|ckpt|safetensors)$/i;
        const hostPattern = /(huggingface\.co|drive\.google\.com|mega\.nz|pixeldrain\.com|mediafire\.com)/i;
        
        // If it's already a direct link, just download it
        if (extPattern.test(url) || hostPattern.test(url)) {
            sendDownload(url, finalFilename, category, btn);
            return;
        }
        
        // Otherwise, resolve the link in the background
        btn.innerHTML = '⏳ Resolving...';
        btn.style.background = '#d97706';
        
        GM_xmlhttpRequest({
            method: "GET",
            url: url,
            onload: function(res) {
                const resolvedUrl = res.finalUrl || url;
                
                // If it redirected to a direct link
                if (extPattern.test(resolvedUrl) || hostPattern.test(resolvedUrl)) {
                    let fn = finalFilename;
                    try {
                        const base = decodeURIComponent(resolvedUrl.split('/').pop().split('?')[0]);
                        if (extPattern.test(base)) {
                            fn = base;
                        }
                    } catch(e) {}
                    
                    sendDownload(resolvedUrl, fn, category, btn);
                } else {
                    // If it resolved to an HTML landing page, parse download links on it
                    const parser = new DOMParser();
                    const doc = parser.parseFromString(res.responseText, "text/html");
                    const directLinks = findModelDownloadLinks(doc);
                    
                    if (directLinks.length > 0) {
                        const zipLink = directLinks.find(l => l.toLowerCase().endsWith('.zip'));
                        if (zipLink) {
                            const fn = decodeURIComponent(zipLink.split('/').pop().split('?')[0]);
                            sendDownload(zipLink, fn, category, btn);
                        } else {
                            const pthLink = directLinks.find(l => l.toLowerCase().endsWith('.pth'));
                            const indexLink = directLinks.find(l => l.toLowerCase().endsWith('.index'));
                            if (pthLink) {
                                const fn = decodeURIComponent(pthLink.split('/').pop().split('?')[0]);
                                sendDownload(pthLink, fn, category, btn);
                            }
                            if (indexLink) {
                                const fn = decodeURIComponent(indexLink.split('/').pop().split('?')[0]);
                                sendDownload(indexLink, fn, category, btn);
                            }
                            if (!pthLink && !indexLink) {
                                const topLink = directLinks[0];
                                const fn = decodeURIComponent(topLink.split('/').pop().split('?')[0]);
                                sendDownload(topLink, fn, category, btn);
                            }
                        }
                    } else {
                        btn.innerHTML = '❌ No Link Found';
                        btn.style.background = '#ef4444';
                        setTimeout(() => {
                            btn.innerHTML = '☄️ GravityDrop';
                            btn.style.background = '#4f46e5';
                        }, 3000);
                    }
                }
            },
            onerror: function() {
                btn.innerHTML = '❌ Failed';
                btn.style.background = '#ef4444';
                setTimeout(() => {
                    btn.innerHTML = '☄️ GravityDrop';
                    btn.style.background = '#4f46e5';
                }, 3000);
            }
        });
    };

    // Heuristic function to reconstruct sample name from Hugging Face URL
    const getSampleNameFromUrl = (hfUrl) => {
        if (!hfUrl) return null;
        try {
            const decoded = decodeURIComponent(hfUrl);
            const match = decoded.match(/huggingface\.co\/([^\/]+)\/([^\/]+)\/(?:resolve|blob|raw)\/[^\/]+\/(.+)$/i);
            if (match) {
                const user = match[1];
                const repo = match[2];
                const filePath = match[3].split('?')[0]; // strip query params like ?download=true
                
                const cleanUser = user.replace(/[^a-zA-Z0-9_\.\-]/g, '');
                const cleanRepo = repo.replace(/[^a-zA-Z0-9_\.\-]/g, '');
                
                let cleanFile = filePath.replace(/ /g, '20');
                cleanFile = cleanFile.replace(/[^a-zA-Z0-9_\.\-]/g, '');
                
                return `${cleanUser}_${cleanRepo}_${cleanFile}`;
            }
        } catch(e) {}
        return null;
    };

    // Intercept audio playback to grab preview MP3 URLs automatically
    const origPlay = HTMLMediaElement.prototype.play;
    HTMLMediaElement.prototype.play = function() {
        const src = this.currentSrc || this.src;
        if (src && src !== lastPlayingUrl) {
            lastPlayingUrl = src;
            console.log("☄️ GravityDrop Helper captured audio:", lastPlayingUrl);
            injectStyles();
            showAudioToast(lastPlayingUrl);
        } else {
            const self = this;
            const captureSrc = () => {
                const s = self.currentSrc || self.src;
                if (s && s !== lastPlayingUrl) {
                    lastPlayingUrl = s;
                    console.log("☄️ GravityDrop Helper captured audio via event:", lastPlayingUrl);
                    injectStyles();
                    showAudioToast(lastPlayingUrl);
                }
            };
            this.addEventListener('loadstart', captureSrc, { once: true });
            this.addEventListener('play', captureSrc, { once: true });
        }
        return origPlay.apply(this, arguments);
    };

    function showAudioToast(audioUrl) {
        document.querySelectorAll('.gd-toast').forEach(t=>t.remove());
        const toast = document.createElement('div');
        toast.className = 'gd-toast';
        const fname = decodeURIComponent(audioUrl.split('/').pop().split('?')[0])||'voice_sample.mp3';

        toast.innerHTML = `
            <span style="font-size:14px;">🎵</span>
            <div style="flex:1;min-width:0;">
                <div style="font-size:10px;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">Captured Audio</div>
                <div style="font-size:9px;color:rgba(255,255,255,.35);white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${fname}</div>
            </div>
            <button class="gd-toast-btn" id="gd-toast-primary">Save to Storys</button>
            <span id="gd-toast-close" style="cursor:pointer;color:rgba(255,255,255,.25);font-size:16px;transition:color .2s;margin-left:4px;">&times;</span>
        `;
        document.body.appendChild(toast);

        const dismiss = () => { toast.style.opacity='0'; toast.style.transform='translateY(10px)'; toast.style.transition='all .3s'; setTimeout(()=>toast.remove(),300); };

        toast.querySelector('#gd-toast-primary').onclick = () => { sendDownload(audioUrl, fname, 'tooown', toast.querySelector('#gd-toast-primary')); setTimeout(dismiss, 1500); };
        toast.querySelector('#gd-toast-close').onclick = dismiss;
        toast.querySelector('#gd-toast-close').onmouseenter = function(){this.style.color='#fff';};

        setTimeout(()=>{ if(toast.parentNode) dismiss(); }, 8000);
    }

    // Inject download buttons next to matches
    const injectButtons = () => {
        injectStyles();

        // 1. Model Files & Download Links
        const links = document.querySelectorAll('a[href*="/download"], a[href*="api/download"], a[href$=".pth"], a[href$=".index"], a[href$=".zip"], a[href*="huggingface.co"]');

        links.forEach(link => {
            if (link.dataset.gdInjected) return;
            if (link.closest('#gd-root') || link.closest('.gd-modal') || link.className.includes('gd-link-badge')) return;
            
            link.dataset.gdInjected = 'true';

            const rawTitle = document.querySelector('h1')?.innerText || 'voice_model';
            const cleanTitle = rawTitle.trim().replace(/[^a-z0-9]/gi, '_').toLowerCase();
            
            let extension = '.pth';
            if (link.href.includes('.index')) extension = '.index';
            else if (link.href.includes('.zip')) extension = '.zip';
            const finalFilename = `${cleanTitle}${extension}`;

            const btn = document.createElement('button');
            btn.innerHTML = '☄️ GravityDrop';
            btn.style = `
                margin-left: 8px;
                background: #4f46e5;
                color: white;
                border: none;
                border-radius: 4px;
                padding: 4px 8px;
                font-size: 11px;
                font-weight: bold;
                cursor: pointer;
                display: inline-flex;
                align-items: center;
                transition: background 0.2s;
                vertical-align: middle;
            `;
            btn.onmouseover = () => btn.style.background = '#4338ca';
            btn.onmouseout = () => btn.style.background = '#4f46e5';

            btn.onclick = (e) => {
                e.preventDefault();
                e.stopPropagation();
                resolveAndDownload(link.href, finalFilename, 'rvc', btn);
            };

            link.parentNode.insertBefore(btn, link.nextSibling);
        });

        // 2. Play Buttons & Audio Samples
        const sBase = {
            female:'https://s3.us-west-000.backblazeb2.com/bbvoe3/samples2/',
            male:  'https://s3.us-west-000.backblazeb2.com/bbvoe3/samples/'
        };

        // Find all play buttons dynamically using class, attributes, title/label, or inner SVG
        const playButtons = [];
        document.querySelectorAll('button, a, span').forEach(el => {
            if (el.classList.contains('model-sample-btn') || el.dataset.sampleName || el.title?.toLowerCase().includes('play') || el.getAttribute('aria-label')?.toLowerCase().includes('play')) {
                playButtons.push(el);
            } else {
                const svg = el.querySelector('svg');
                if (svg && (svg.innerHTML.includes('M10.804') || svg.classList.contains('bi-play'))) {
                    playButtons.push(el);
                }
            }
        });

        playButtons.forEach(btn => {
            if (btn.dataset.gdSampleInjected) return;
            btn.dataset.gdSampleInjected = 'true';

            let sn = btn.dataset.sampleName;
            const row = btn.closest('tr, li, div[class*="row"], .model-card');
            
            // Fallback: Reconstruct sample name from Hugging Face model URL in the same row/card
            if (!sn && row) {
                const hfLink = row.querySelector('a[href*="huggingface.co"], button[data-clipboard-text*="huggingface.co"]');
                const url = hfLink ? (hfLink.href || hfLink.dataset.clipboardText) : null;
                if (url) {
                    sn = getSampleNameFromUrl(url);
                }
            }

            if (!sn) return;

            let vn = 'voice_preview', isMale = false;
            if (row) {
                const te = row.querySelector('h3, span, div, a, .model-title');
                if (te && te.innerText.trim().length > 2) {
                    vn = te.innerText.trim().replace(/[^a-z0-9]/gi,'_').toLowerCase();
                    const textLower = te.innerText.toLowerCase();
                    isMale = ['man','boy','hector','benson','don','stewie','roger','mr.'].some(k=>textLower.includes(k)) || (textLower.includes('male') && !textLower.includes('female'));
                }
            }

            const st = isMale ? 'male' : 'female';
            const aUrl = sBase[st] + encodeURIComponent(sn) + '.mp3';

            const dl = document.createElement('a');
            dl.href = 'javascript:void(0)';
            dl.className = 'gd-link-badge';
            dl.innerHTML = '🗣️';
            dl.title = 'Sling Audio Preview to Storys';

            dl.onclick = (e) => {
                e.preventDefault(); e.stopPropagation();
                sendDownload(aUrl, `${vn}_preview.mp3`, 'tooown', dl);
            };

            btn.parentNode.insertBefore(dl, btn.nextSibling);
        });
    };

    // Scan page initially and execute periodically
    setTimeout(injectButtons, 1500);
    setInterval(injectButtons, 3000);
})();
