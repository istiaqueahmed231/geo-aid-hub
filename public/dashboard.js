// dashboard.js
// This script powers the Geo-Aid Hub dashboard.
// It fetches volunteers, resources, and SOS requests, computes the nearest volunteer for each request,
// populates the "Nearest Help" section, and handles dispatch actions.

// Utility: Haversine distance (km)
function haversine(lat1, lon1, lat2, lon2) {
  const toRad = (deg) => deg * Math.PI / 180;
  const R = 6371; // Earth radius km
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) *
            Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

async function fetchJSON(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`Failed to fetch ${url}`);
  return await res.json();
}

async function initDashboard() {
  try {
    const [volunteers, resources, requests] = await Promise.all([
      fetchJSON('/api/volunteers'),
      fetchJSON('/api/resources'),
      fetchJSON('/api/requests')
    ]);
    populateResourceDropdown(resources);
    computeAndRenderNearestHelp(volunteers, requests);
    attachDispatchHandlers(volunteers, resources, requests);
  } catch (e) {
    console.error('Dashboard init error:', e);
  }
}

function populateResourceDropdown(resources) {
  const select = document.getElementById('resource-select');
  resources.forEach(r => {
    const opt = document.createElement('option');
    opt.value = r.ResourceID;
    opt.textContent = `${r.CategoryName} (${r.Quantity} left)`;
    select.appendChild(opt);
  });
}

function computeAndRenderNearestHelp(volunteers, requests) {
  const container = document.getElementById('nearest-help');
  if (!container) return;
  container.innerHTML = '';
  requests.forEach(req => {
    const { Latitude, Longitude } = req; // Assuming these fields exist now
    let nearest = null;
    let minDist = Infinity;
    volunteers.forEach(v => {
      if (!v.Location) return; // Expect Location as "lat,lon"
      const [vLat, vLon] = v.Location.split(',').map(Number);
      const dist = haversine(Latitude, Longitude, vLat, vLon);
      if (dist < minDist) { minDist = dist; nearest = v; }
    });
    const card = document.createElement('div');
    card.className = 'bg-surface-container-low p-3 rounded-lg mb-2';
    card.innerHTML = `
      <strong>${req.RequestorName}</strong> – ${req.CategoryName}<br/>
      <span class="text-xs">${minDist.toFixed(1)} km from ${nearest ? nearest.Name : 'N/A'}</span>
    `;
    container.appendChild(card);
  });
}

function attachDispatchHandlers(volunteers, resources, requests) {
  // Example: each request card could have a Dispatch button (not yet in HTML).
  // This function is a placeholder for future UI wiring.
}

// Initialize when DOM ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initDashboard);
} else {
  initDashboard();
}
