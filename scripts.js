(() => {
    const $ = (s, r = document) => r.querySelector(s);
    const $$ = (s, r = document) => Array.from(r.querySelectorAll(s));
    const clamp = (v, lo, hi) => Math.min(Math.max(v, lo), hi);
    const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;

    let toastTimer;
    function toast(text) {
        const el = $('#copy-toast');
        if (!el) return;
        el.textContent = text;
        el.classList.add('is-shown');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => el.classList.remove('is-shown'), 2200);
    }

    function initNav() {
        const btn = $('#nav-menu');
        const links = $('#nav-links');
        if (!btn || !links) return;
        const set = (open) => {
            btn.setAttribute('aria-expanded', String(open));
            btn.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
            links.classList.toggle('is-open', open);
        };
        btn.addEventListener('click', () => set(!links.classList.contains('is-open')));
        links.addEventListener('click', (e) => {
            if (e.target.closest('a')) set(false);
        });
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') set(false);
        });
        document.addEventListener('pointerdown', (e) => {
            if (!e.target.closest('.nav')) set(false);
        });
    }

    // Safari hands <video> loading to AVFoundation, which streams with Range
    // requests the CDN answers in a way Safari rejects, so clips stay black.
    // Each clip is fetched once with a plain GET and attached as a blob: URL.
    function initVideos() {
        const videos = $$('video');
        const pending = new WeakMap();
        const canUseBlob = typeof fetch === 'function' && typeof URL.createObjectURL === 'function';

        const sourceUrl = (video) => {
            const source = video.querySelector('source[src]');
            return source ? source.getAttribute('src') : video.getAttribute('src');
        };

        function ensureLoaded(video) {
            let load = pending.get(video);
            if (load) return load;
            const url = sourceUrl(video);
            if (canUseBlob && url && !video.src) {
                load = fetch(url)
                    .then((r) => {
                        if (!r.ok) throw new Error('HTTP ' + r.status);
                        return r.blob();
                    })
                    .then((blob) => {
                        video.src = URL.createObjectURL(blob);
                    })
                    .catch(() => video.load());
            } else {
                load = Promise.resolve();
            }
            pending.set(video, load);
            return load;
        }

        function play(video) {
            video.muted = true;
            ensureLoaded(video).then(() => {
                if (video.dataset.paused === 'true') return;
                const attempt = video.play();
                if (attempt && attempt.catch) {
                    attempt.catch(() => {
                        video.addEventListener('canplay', () => {
                            if (video.dataset.paused !== 'true') video.play().catch(() => {});
                        }, { once: true });
                    });
                }
            });
        }

        if (!('IntersectionObserver' in window)) {
            videos.forEach(play);
            return;
        }

        const preload = new IntersectionObserver((entries) => {
            entries.forEach((entry) => {
                if (entry.isIntersecting) {
                    ensureLoaded(entry.target);
                    preload.unobserve(entry.target);
                }
            });
        }, { rootMargin: '400px 0px' });

        const visible = new IntersectionObserver((entries) => {
            entries.forEach((entry) => {
                const video = entry.target;
                if (entry.isIntersecting) {
                    video.dataset.paused = 'false';
                    if (!reduceMotion) play(video);
                    else ensureLoaded(video);
                } else {
                    video.dataset.paused = 'true';
                    video.pause();
                }
            });
        }, { threshold: 0.35 });

        videos.forEach((video) => {
            preload.observe(video);
            visible.observe(video);
        });
    }

    function initCopy() {
        $$('.copy-cmd').forEach((btn) => {
            const icon = btn.querySelector('use');
            btn.addEventListener('click', async () => {
                const text = btn.dataset.copy;
                try {
                    await navigator.clipboard.writeText(text);
                } catch {
                    const area = document.createElement('textarea');
                    area.value = text;
                    area.style.position = 'fixed';
                    area.style.opacity = '0';
                    document.body.appendChild(area);
                    area.select();
                    document.execCommand('copy');
                    area.remove();
                }
                btn.classList.add('is-copied');
                if (icon) icon.setAttribute('href', '#i-check');
                toast('Copied. Paste it into Terminal to install.');
                setTimeout(() => {
                    btn.classList.remove('is-copied');
                    if (icon) icon.setAttribute('href', '#i-copy');
                }, 1800);
            });
        });
    }

    function initDonation() {
        const modal = $('#donation-modal');
        const proceed = $('#proceed-to-download');
        if (!modal || !proceed) return;
        let url = '';
        let opener = null;

        const close = () => {
            modal.hidden = true;
            document.documentElement.style.overflow = '';
            if (opener) opener.focus({ preventScroll: true });
        };

        $$('.donation-prompt').forEach((link) => {
            link.addEventListener('click', (e) => {
                e.preventDefault();
                url = link.href;
                opener = link;
                modal.hidden = false;
                document.documentElement.style.overflow = 'hidden';
                proceed.focus({ preventScroll: true });
            });
        });

        proceed.addEventListener('click', (e) => {
            e.preventDefault();
            close();
            if (url) window.location.href = url;
        });

        $$('[data-close]', modal).forEach((el) => el.addEventListener('click', close));
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && !modal.hidden) close();
        });
    }

    function tabs({ list, tabSel, onSelect, vertical }) {
        const items = $$(tabSel, list);
        const select = (tab, focus) => {
            items.forEach((t) => {
                const on = t === tab;
                t.setAttribute('aria-selected', String(on));
                t.tabIndex = on ? 0 : -1;
                const panel = document.getElementById(t.getAttribute('aria-controls'));
                if (panel) panel.hidden = !on;
            });
            if (focus) tab.focus();
            if (onSelect) onSelect(tab, items.indexOf(tab));
        };
        items.forEach((tab) => {
            tab.addEventListener('click', () => select(tab, false));
            tab.addEventListener('keydown', (e) => {
                const i = items.indexOf(tab);
                const back = e.key === 'ArrowLeft' || (vertical && e.key === 'ArrowUp');
                const fwd = e.key === 'ArrowRight' || (vertical && e.key === 'ArrowDown');
                if (!back && !fwd && e.key !== 'Home' && e.key !== 'End') return;
                e.preventDefault();
                let next = i;
                if (back) next = (i - 1 + items.length) % items.length;
                if (fwd) next = (i + 1) % items.length;
                if (e.key === 'Home') next = 0;
                if (e.key === 'End') next = items.length - 1;
                select(items[next], true);
            });
        });
    }

    function initExplorer() {
        const list = $('.explorer-list');
        if (!list) return;
        tabs({
            list,
            tabSel: '[role="tab"]',
            vertical: true,
            onSelect: (tab) => {
                if (list.scrollWidth > list.clientWidth) {
                    const l = tab.offsetLeft - 8;
                    list.scrollTo({ left: l, behavior: reduceMotion ? 'auto' : 'smooth' });
                }
            },
        });
    }

    function initLooks() {
        const seg = $('#looks .segmented');
        if (!seg) return;
        tabs({
            list: seg,
            tabSel: '[role="tab"]',
            onSelect: (_, i) => seg.setAttribute('data-index', String(i)),
        });
    }

    initNav();
    initVideos();
    initCopy();
    initDonation();
    initExplorer();
    initLooks();
})();
