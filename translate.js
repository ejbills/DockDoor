
function loadTranslations(lang) {
    fetch('/translations/translations.json')
        .then(response => response.json())
        .then(translations => {
            const selectedLangTranslations = translations[lang] || translations['en']; // 'en' is default language
            if (selectedLangTranslations) {
                document.querySelectorAll('[data-translate]').forEach(element => {
                    const key = element.getAttribute('data-translate');
                    if (selectedLangTranslations[key]) {
                        element.innerHTML = selectedLangTranslations[key]; // Using innerHTML
                    }
                });
            } else {
                console.error('Langue non trouvée et langue par défaut manquante:', lang);
            }
        })
        .catch(error => console.error('Erreur lors du chargement des traductions:', error));
}

// Detect browser language
function detectLanguageAndTranslate() {
    const userLang = navigator.language || navigator.userLanguage;
    const langCode = userLang.split('-')[0];
    loadTranslations(langCode);
}

// Call function
detectLanguageAndTranslate();

// Manages languages with dropdown menu
document.querySelectorAll('.lang-option').forEach(option => {
    option.addEventListener('click', function(event) {
        event.preventDefault(); // Prevents page reloading
        const selectedLang = option.getAttribute('data-lang');
        loadTranslations(selectedLang);
    });
});
