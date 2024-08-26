document.addEventListener('DOMContentLoaded', function () {
    const toggleDarkModeButton = document.getElementById('toggleDarkMode');
    const prefersDarkMode = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const savedTheme = localStorage.getItem('theme');

    // If user already has saved setting
    if (savedTheme) {
        document.body.classList.toggle('dark-mode', savedTheme === 'dark');
    } else if (prefersDarkMode) {
        // Else, use system setting
        document.body.classList.add('dark-mode');
    }

    toggleDarkModeButton.addEventListener('click', function () {
        document.body.classList.toggle('dark-mode');
        const theme = document.body.classList.contains('dark-mode') ? 'dark' : 'light';
        localStorage.setItem('theme', theme);
    
        // Change icon according to current theme
        const darkModeIcon = document.getElementById('darkModeIcon');
        darkModeIcon.textContent = theme === 'dark' ? '🌙' : '☀️';
    });
})