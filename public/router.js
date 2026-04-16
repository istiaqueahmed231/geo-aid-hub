// router.js — Client-side SPA router using History API
(function () {
  const EXCLUDED = ["welcome.html", "login.html", "signup.html"];

  function isExcluded(href) {
    return (
      EXCLUDED.some((p) => href.includes(p)) ||
      href.startsWith("http") ||
      href.startsWith("#") ||
      href.startsWith("mailto") ||
      href === "/"
    );
  }

  // Destroy any active Leaflet map instances to prevent "map container already initialized" errors
  function destroyLeafletMaps() {
    // Leaflet stores its map instances on the container element as _leaflet_id
    // We find all initialized map containers and call .remove() on them
    if (typeof window._activeLeafletMaps === "undefined") {
      window._activeLeafletMaps = [];
    }
    window._activeLeafletMaps.forEach((m) => {
      try {
        m.remove();
      } catch (e) {
        /* already removed */
      }
    });
    window._activeLeafletMaps = [];

    // Also brute-force clean any element with _leaflet_id set
    document
      .querySelectorAll('[class*="leaflet"], [id="map"], [id="detail-map"]')
      .forEach((el) => {
        if (el._leaflet_id) {
          try {
            // Find the L.Map object associated with this container
            if (window.L && L.Map) {
              // Leaflet 1.x stores map instances internally; attempt clean removal
              const map = el._leaflet_map_instance;
              if (map) {
                map.remove();
              } else {
                // Clear the _leaflet_id so the container can be reused
                delete el._leaflet_id;
                el.innerHTML = "";
              }
            }
          } catch (e) {
            delete el._leaflet_id;
          }
        }
      });
  }

  // Ensure the #view element fills the available space in #main
  function ensureViewStyles() {
    let style = document.getElementById("__router_view_style");
    if (!style) {
      style = document.createElement("style");
      style.id = "__router_view_style";
      style.textContent = `
        #view {
          flex: 1;
          display: flex;
          flex-direction: column;
          overflow: hidden;
          min-height: 0;
        }
        #view > * {
          flex: 1;
          min-height: 0;
        }
      `;
      document.head.appendChild(style);
    }
  }

  // Re-execute all <script> tags found in the newly injected #view content
  function runViewScripts(viewEl) {
    const scripts = Array.from(viewEl.querySelectorAll("script"));
    scripts.forEach((oldScript) => {
      const newScript = document.createElement("script");

      // Copy all attributes (type, src, etc.)
      Array.from(oldScript.attributes).forEach((attr) => {
        newScript.setAttribute(attr.name, attr.value);
      });

      if (oldScript.src) {
        // External script — set src and let the browser load it
        newScript.src = oldScript.src;
        newScript.async = false;
        document.body.appendChild(newScript);
        // Do NOT remove it — external scripts need to stay to load
      } else {
        // Inline script — execute immediately
        newScript.textContent = oldScript.textContent;
        document.body.appendChild(newScript);
        document.body.removeChild(newScript);
      }

      // Remove the original dead script tag from the view to avoid duplicates
      oldScript.remove();
    });
  }

  // Show a subtle loading indicator on the view area
  function showLoadingState() {
    const view = document.getElementById("view");
    if (view) {
      view.style.opacity = "0.4";
      view.style.pointerEvents = "none";
      view.style.transition = "opacity 0.15s ease";
    }
  }

  function hideLoadingState() {
    const view = document.getElementById("view");
    if (view) {
      view.style.opacity = "1";
      view.style.pointerEvents = "";
    }
  }

  async function navigateTo(url, pushState = true) {
    // Normalize the URL — strip leading slash duplicates
    const normalizedUrl = url.replace(/^\/+/, "") || "index.html";

    showLoadingState();

    try {
      const res = await fetch(normalizedUrl);
      if (!res.ok) {
        window.location.href = normalizedUrl;
        return;
      }

      const html = await res.text();
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, "text/html");

      const newView = doc.getElementById("view");
      const currentView = document.getElementById("view");

      if (!newView || !currentView) {
        // No #view on target page — do a full navigation
        window.location.href = normalizedUrl;
        return;
      }

      // 1. Destroy any existing Leaflet map instances BEFORE swapping DOM
      destroyLeafletMaps();

      // 2. Clear any page-level globals that the old page set
      //    (prevents stale closures from the old page interfering)
      window._selectedSupplyName = null;
      window._selectedVolunteerName = null;

      // 3. Swap the view content
      currentView.innerHTML = newView.innerHTML;

      // 4. Ensure view has proper CSS to fill layout
      ensureViewStyles();

      // 5. Update document title
      document.title = doc.title;

      // 6. Update active nav link
      const allNavLinks = document.querySelectorAll(".nav-link");
      allNavLinks.forEach((a) => {
        a.classList.remove("active");
        const linkHref = a.getAttribute("href");
        if (!linkHref) return;
        // Match by filename
        const linkFile = linkHref.split("/").pop();
        const targetFile = normalizedUrl.split("/").pop().split("?")[0];
        if (linkFile && targetFile && linkFile === targetFile) {
          a.classList.add("active");
        }
      });

      // 7. Push browser history state
      if (pushState) {
        history.pushState({ url: normalizedUrl }, "", normalizedUrl);
      }

      // 8. Re-run scripts inside the new view
      runViewScripts(currentView);

      // 9. Scroll to top
      currentView.scrollTop = 0;
      window.scrollTo(0, 0);
    } catch (err) {
      console.error(
        "[Router] Navigation failed, falling back to full load:",
        err,
      );
      window.location.href = url;
    } finally {
      hideLoadingState();
    }
  }

  // Intercept ALL anchor clicks in the document
  document.addEventListener("click", function (e) {
    const anchor = e.target.closest("a[href]");
    if (!anchor) return;

    const href = anchor.getAttribute("href");
    if (!href) return;

    // Let the logout link work normally (it uses onclick, not href navigation)
    if (anchor.getAttribute("onclick")) return;

    if (isExcluded(href)) return;
    if (anchor.target === "_blank") return;
    if (e.ctrlKey || e.metaKey || e.shiftKey) return; // Allow open-in-new-tab shortcuts

    e.preventDefault();
    navigateTo(href);
  });

  // Handle browser back/forward buttons
  window.addEventListener("popstate", function (e) {
    if (e.state && e.state.url) {
      navigateTo(e.state.url, false);
    } else {
      // Fallback: reload current location
      navigateTo(
        window.location.pathname.replace(/^\//, "") || "index.html",
        false,
      );
    }
  });

  // Register a Leaflet map instance so the router can clean it up on navigation
  // Usage: window.registerLeafletMap(mapInstance)
  window.registerLeafletMap = function (mapInstance) {
    if (!window._activeLeafletMaps) window._activeLeafletMaps = [];
    window._activeLeafletMaps.push(mapInstance);
  };

  // Set initial history state so popstate works on the first page too
  history.replaceState(
    { url: window.location.pathname.replace(/^\//, "") || "index.html" },
    "",
    window.location.href,
  );

  // Apply view styles immediately on load
  ensureViewStyles();

  // Expose navigateTo globally for any code that needs programmatic navigation
  window.navigateTo = navigateTo;
})();
