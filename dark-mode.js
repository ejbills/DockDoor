document.addEventListener('DOMContentLoaded', function() {
    const toggleButton = document.getElementById('toggleDarkMode');
    const darkModeIcon = document.getElementById('darkModeIcon');
    
    // Check for saved dark mode preference or respect OS preference
    const prefersDarkMode = window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches;
    const savedMode = localStorage.getItem('darkMode');
    
    // Set initial icon
    function updateDarkModeIcon(isDarkMode) {
        darkModeIcon.innerHTML = isDarkMode ? '☀️' : '🌙';
    }
    
    // Apply dark mode if saved or OS preference is dark
    if (savedMode === 'true' || (savedMode === null && prefersDarkMode)) {
        document.body.classList.add('dark-mode');
        updateDarkModeIcon(true);
    } else {
        updateDarkModeIcon(false);
    }
    
    // Toggle dark mode on button click
    toggleButton.addEventListener('click', function() {
        document.body.classList.toggle('dark-mode');
        const isDarkMode = document.body.classList.contains('dark-mode');
        localStorage.setItem('darkMode', isDarkMode);
        updateDarkModeIcon(isDarkMode);
    });
    
    // Listen for system preference changes
    if (window.matchMedia) {
        window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', function(e) {
            // Only apply if user hasn't manually set a preference
            if (localStorage.getItem('darkMode') === null) {
                if (e.matches) {
                    document.body.classList.add('dark-mode');
                    updateDarkModeIcon(true);
                } else {
                    document.body.classList.remove('dark-mode');
                    updateDarkModeIcon(false);
                }
            }
        });
    }
});