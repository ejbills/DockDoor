document.addEventListener('DOMContentLoaded', function () {
    const toggleDarkModeButton = document.getElementById('toggleDarkMode');
    const darkModeIcon = document.getElementById('darkModeIcon');
    const prefersDarkMode = window.matchMedia('(prefers-color-scheme: dark)').matches;
    const savedTheme = localStorage.getItem('theme');

    // If user already has saved setting
    if (savedTheme) {
        document.body.classList.toggle('dark-mode', savedTheme === 'dark');
        darkModeIcon.textContent = savedTheme === 'dark' ? '☀️' : '🌙';
    } else if (prefersDarkMode) {
        // Else, use system setting
        document.body.classList.add('dark-mode');
        darkModeIcon.textContent = '☀️';
    } else {
        darkModeIcon.textContent = '🌙';
    }

    toggleDarkModeButton.addEventListener('click', function () {
        document.body.classList.toggle('dark-mode');
        const theme = document.body.classList.contains('dark-mode') ? 'dark' : 'light';
        localStorage.setItem('theme', theme);
    
        // Change icon according to current theme
        darkModeIcon.textContent = theme === 'dark' ? '☀️' : '🌙';
    });
});
