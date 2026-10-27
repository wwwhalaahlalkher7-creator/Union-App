/* Leo UI Pro — lightweight interaction layer. Visual/accessibility only; backend/API contract untouched. */
(function () {
  'use strict';
  const body = document.body;
  const reduce = window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  // One small ambient layer: transform/opacity animation only; no canvas and no pointer tracking.
  if (!reduce && !document.querySelector('.ui-ambient')) {
    const ambient = document.createElement('div');
    ambient.className = 'ui-ambient';
    ambient.setAttribute('aria-hidden', 'true');
    ambient.innerHTML = '<span class="ambient-core"></span><span class="ambient-node"></span>';
    body.appendChild(ambient);
  }

  // Scroll progress uses one passive listener and a tiny transform-only update.
  const progress = document.createElement('div');
  progress.className = 'ui-scroll-progress';
  progress.setAttribute('aria-hidden', 'true');
  body.appendChild(progress);

  let progressTick = false;
  function updateProgress() {
    if (progressTick) return;
    progressTick = true;
    requestAnimationFrame(function () {
      progressTick = false;
      const doc = document.documentElement;
      const max = doc.scrollHeight - doc.clientHeight;
      progress.style.transform = 'scaleX(' + (max > 0 ? Math.min(1, window.scrollY / max) : 0) + ')';
    });
  }
  window.addEventListener('scroll', updateProgress, { passive: true });
  window.addEventListener('resize', updateProgress, { passive: true });

  // Reveal only meaningful page-level blocks. Cards remain immediately available for faster scrolling.
  if (!reduce && 'IntersectionObserver' in window) {
    const selector = '.page-title-section, .page-header, .hero-content, section > h2, .notice-board > h2, .statistics-section > h2, .news-toolbar, .search-bar';
    const observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: .06, rootMargin: '0px 0px -20px' });
    document.querySelectorAll(selector).forEach(function (el) {
      el.classList.add('ui-reveal');
      observer.observe(el);
    });
  }

  const current = (location.pathname.split('/').pop() || 'index.html').toLowerCase();
  document.querySelectorAll('#navMenu a[href]').forEach(function (a) {
    const href = (a.getAttribute('href') || '').split('#')[0].split('?')[0].split('/').pop().toLowerCase();
    if (href && href === current) {
      a.classList.add('active');
      a.setAttribute('aria-current', 'page');
    }
  });

  document.addEventListener('click', function (e) {
    const a = e.target.closest && e.target.closest('a[target="_blank"]');
    if (a) {
      const rel = new Set((a.getAttribute('rel') || '').split(/\s+/).filter(Boolean));
      rel.add('noopener');
      rel.add('noreferrer');
      a.setAttribute('rel', Array.from(rel).join(' '));
    }
  });

  const menuToggle = document.getElementById('menuToggle');
  const navMenu = document.getElementById('navMenu');
  if (menuToggle && navMenu) {
    const closeMenu = function () {
      navMenu.classList.remove('active');
      menuToggle.setAttribute('aria-expanded', 'false');
    };
    document.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') closeMenu();
    });
    navMenu.addEventListener('click', function (e) {
      if (e.target.closest('a')) closeMenu();
    });
  }

  requestAnimationFrame(updateProgress);
})();
