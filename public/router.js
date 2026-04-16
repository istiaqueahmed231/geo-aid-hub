// router.js — Client-side SPA router using History API
(function () {
  // Pages that should NOT be intercepted (auth pages, full reloads OK)
  const EXCLUDED = ['welcome.html', 'login.html', 'signup.html'];

  function isExcluded(href) {
    return (
      EXCLUDED.some(p => href.includes(p)) ||
      href.startsWith('http') ||
      href.startsWith('#') ||
      href.startsWith('mailto')
    );
  }

  async function navigateTo(url, pushState = true) {
    try {
      const res = await fetch(url);
      if (!res.ok) { window.location.href = url; return; }
      const html = await res.text();
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, 'text/html');

      const newView = doc.getElementById('view');
      const currentView = document.getElementById('view');
      if (!newView || !currentView) { window.location.href = url; return; }

      // Swap content
      currentView.innerHTML = newView.innerHTML;

      // Update title
      document.title = doc.title;

      // Update active nav link
      document.querySelectorAll('.nav-link').forEach(a => {
        a.classList.remove('active');
        const linkPage = a.getAttribute('href');
        if (linkPage && (url.endsWith(linkPage) || url.includes(linkPage))) {
          a.classList.add('active');
        }
      });

      // Push history state
      if (pushState) history.pushState({ url }, '', url);

      // Re-execute scripts inside the new view
      const scripts = currentView.querySelectorAll('script');
      scripts.forEach(oldScript => {
        const newScript = document.createElement('script');
        // Copy all attributes
        Array.from(oldScript.attributes).forEach(attr => {
          newScript.setAttribute(attr.name, attr.value);
        });
        if (oldScript.src) {
          newScript.src = oldScript.src;
        } else {
          newScript.textContent = oldScript.textContent;
        }
        document.body.appendChild(newScript);
        // Only remove inline scripts immediately; src scripts need time to load
        if (!oldScript.src) {
          document.body.removeChild(newScript);
        }
      });

      // Scroll view to top
      currentView.scrollTop = 0;
      window.scrollTo(0, 0);

    } catch (err) {
      console.error('[Router] Navigation failed:', err);
      window.location.href = url; // fallback to normal nav
    }
  }

  // Intercept all clicks
  document.addEventListener('click', function (e) {
    const anchor = e.target.closest('a[href]');
    if (!anchor) return;
    const href = anchor.getAttribute('href');
    if (!href) return;
    if (isExcluded(href)) return;
    if (anchor.target === '_blank') return;
    e.preventDefault();
    navigateTo(href);
  });

  // Handle browser back/forward
  window.addEventListener('popstate', function (e) {
    if (e.state && e.state.url) {
      navigateTo(e.state.url, false);
    }
  });

  // Set initial history state
  history.replaceState({ url: window.location.href }, '', window.location.href);

  // Expose for manual use
  window.navigateTo = navigateTo;
})();
