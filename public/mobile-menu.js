// public/mobile-menu.js
document.addEventListener('DOMContentLoaded', () => {
    const sidebar = document.querySelector('aside');
    const toggleBtn = document.getElementById('mobile-menu-toggle');
    const mainContent = document.querySelector('main');

    if (!sidebar || !toggleBtn) return;

    // Create overlay
    const overlay = document.createElement('div');
    overlay.className = 'fixed inset-0 bg-black/50 z-30 hidden lg:hidden transition-opacity duration-300 opacity-0';
    document.body.appendChild(overlay);

    const toggleSidebar = () => {
        const isOpen = !sidebar.classList.contains('-translate-x-full');
        
        if (isOpen) {
            // Close
            sidebar.classList.add('-translate-x-full');
            overlay.classList.add('hidden', 'opacity-0');
            overlay.classList.remove('block', 'opacity-100');
            document.body.classList.remove('overflow-hidden');
        } else {
            // Open
            sidebar.classList.remove('-translate-x-full');
            overlay.classList.remove('hidden', 'opacity-0');
            overlay.classList.add('block', 'opacity-100');
            document.body.classList.add('overflow-hidden');
        }
    };

    toggleBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        toggleSidebar();
    });

    overlay.addEventListener('click', toggleSidebar);

    // Close sidebar on link click (mobile)
    const navLinks = sidebar.querySelectorAll('nav a');
    navLinks.forEach(link => {
        link.addEventListener('click', () => {
            if (window.innerWidth < 1024) { // lg breakpoint
                toggleSidebar();
            }
        });
    });
});
