// public/theme.js
function getPreferredTheme() {
    if (localStorage.getItem('theme')) {
        return localStorage.getItem('theme');
    }
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

// Apply theme immediately on script load to prevent flash of wrong theme
(function() {
    const currentTheme = getPreferredTheme();
    if (currentTheme === 'light') {
        document.documentElement.classList.remove('dark');
    } else {
        document.documentElement.classList.add('dark');
    }
})();

function updateThemeIcons(isDark) {
    if (typeof isDark === 'undefined') {
        isDark = document.documentElement.classList.contains('dark');
    }
    const themeIcons = document.querySelectorAll('#theme-toggle-icon, #theme-icon, .theme-toggle-icon, .theme-icon');
    themeIcons.forEach(icon => {
        icon.textContent = isDark ? 'light_mode' : 'dark_mode';
    });
}

function toggleTheme() {
    const isDark = document.documentElement.classList.contains('dark');
    if (isDark) {
        document.documentElement.classList.remove('dark');
        localStorage.setItem('theme', 'light');
        updateThemeIcons(false);
    } else {
        document.documentElement.classList.add('dark');
        localStorage.setItem('theme', 'dark');
        updateThemeIcons(true);
    }
}

// Event delegation for theme toggle buttons across full page & SPA view changes
document.addEventListener('click', (e) => {
    const btn = e.target.closest('#theme-toggle-btn, .theme-toggle-btn');
    if (btn) {
        e.preventDefault();
        toggleTheme();
    }
});

// Update icons when DOM is interactive/ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => updateThemeIcons());
} else {
    updateThemeIcons();
}

// Listen for system theme changes if no explicit preference is set
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => {
    if (!localStorage.getItem('theme')) {
        const isDark = e.matches;
        if (isDark) {
            document.documentElement.classList.add('dark');
        } else {
            document.documentElement.classList.remove('dark');
        }
        updateThemeIcons(isDark);
    }
});

// Expose functions globally for SPA or programmatic use
window.updateThemeIcons = updateThemeIcons;
window.toggleTheme = toggleTheme;

