// public/theme.js
function getPreferredTheme() {
    if (localStorage.getItem('theme')) {
        return localStorage.getItem('theme');
    }
    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

(function() {
    const currentTheme = getPreferredTheme();
    if (currentTheme === 'light') {
        document.documentElement.classList.remove('dark');
    } else {
        document.documentElement.classList.add('dark');
    }
})();

document.addEventListener('DOMContentLoaded', () => {
    // Select by ID or class if needed across multiple pages
    const themeBtns = document.querySelectorAll('#theme-toggle-btn, .theme-toggle-btn');
    const themeIcons = document.querySelectorAll('#theme-toggle-icon, .theme-toggle-icon');
    
    const updateIcon = (isDark) => {
        themeIcons.forEach(icon => {
            icon.textContent = isDark ? 'light_mode' : 'dark_mode';
        });
    };

    // Set initial icon
    const currentTheme = getPreferredTheme();
    updateIcon(currentTheme === 'dark');

    themeBtns.forEach(themeBtn => {
        themeBtn.addEventListener('click', () => {
            const isDark = document.documentElement.classList.contains('dark');
            if (isDark) {
                document.documentElement.classList.remove('dark');
                localStorage.setItem('theme', 'light');
                updateIcon(false);
            } else {
                document.documentElement.classList.add('dark');
                localStorage.setItem('theme', 'dark');
                updateIcon(true);
            }
        });
    });

    // Listen for system theme changes if no explicit preference is set
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', e => {
        if (!localStorage.getItem('theme')) {
            const isDark = e.matches;
            if (isDark) {
                document.documentElement.classList.add('dark');
            } else {
                document.documentElement.classList.remove('dark');
            }
            updateIcon(isDark);
        }
    });
});
