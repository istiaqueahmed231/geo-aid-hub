// public/mobile-menu.js
document.addEventListener('DOMContentLoaded', () => {
    const sidebar = document.getElementById('sidebar');
    const toggleBtn = document.getElementById('mobile-menu-toggle');

    if (!sidebar || !toggleBtn) return;

    // Create overlay
    const overlay = document.createElement('div');
    overlay.className = 'fixed inset-0 bg-black/50 z-[90] hidden transition-opacity duration-300';
    document.body.appendChild(overlay);

    const openSidebar = () => {
        sidebar.style.transform = 'translateX(0)';
        overlay.classList.remove('hidden');
        document.body.style.overflow = 'hidden';
    };

    const closeSidebar = () => {
        sidebar.style.transform = 'translateX(-256px)';
        overlay.classList.add('hidden');
        document.body.style.overflow = '';
    };

    toggleBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        const isOpen = sidebar.style.transform === 'translateX(0px)';
        isOpen ? closeSidebar() : openSidebar();
    });

    overlay.addEventListener('click', closeSidebar);

    // Close sidebar on link click (mobile)
    const navLinks = sidebar.querySelectorAll('nav a');
    navLinks.forEach(link => {
        link.addEventListener('click', () => {
            if (window.innerWidth < 900) {
                closeSidebar();
            }
        });
    });
});
