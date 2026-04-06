// public/theme.js
(function() {
    // Check local storage for theme preference, default to dark
    const currentTheme = localStorage.getItem('theme') || 'dark';
    if (currentTheme === 'light') {
        document.documentElement.classList.remove('dark');
    } else {
        document.documentElement.classList.add('dark');
    }
})();

document.addEventListener('DOMContentLoaded', () => {
    const themeBtns = document.querySelectorAll('#theme-toggle-btn');
    const themeIcons = document.querySelectorAll('#theme-toggle-icon');
    
    const updateIcon = (isDark) => {
        themeIcons.forEach(icon => {
            icon.textContent = isDark ? 'light_mode' : 'dark_mode';
        });
    };

    // Set initial icon
    const currentTheme = localStorage.getItem('theme') || 'dark';
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
});
