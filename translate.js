// List of RTL languages
const rtlLanguages = ['ar', 'he'];

// Function to load translations
async function loadTranslations(lang) {
    try {
        const response = await fetch(`/translations/${lang}/translations.json`);
        if (!response.ok) {
            throw new Error(`Translation not found for language: ${lang}`);
        }
        const translations = await response.json();
        document.querySelectorAll('[data-translate]').forEach(element => {
            const key = element.getAttribute('data-translate');
            if (translations[key]) {
                element.innerHTML = translations[key]; // Uses innerHTML to manage JSON values and HTML tags inside
            }
        });

        // Verifies whether language is RTL and applies fix
        if (rtlLanguages.includes(lang.split('-')[0])) {
            document.documentElement.setAttribute('dir', 'rtl');
        } else {
            document.documentElement.setAttribute('dir', 'ltr');
        }
    } catch (error) {
        return console.error(error.message);
    }
}

// Function to detect browser language and apply it to website
function detectLanguageAndTranslate() {
    const userLang = navigator.language || navigator.userLanguage;
    let langCode = userLang.toLowerCase(); // The whole language code
    let primaryLangCode = langCode.split('-')[0]; // Language code without regional indicator

    // Tries without regional indicator first
    loadTranslations(primaryLangCode)
        .catch(() => {
            // If error, check with the language code.
            return loadTranslations(langCode);
        })
        .catch(() => {
            // If no translation is found, switch to default English
            return loadTranslations('en');
        });
}

// Calls function when loading page
detectLanguageAndTranslate();

// Managing language switching with dropdown menu
document.querySelectorAll('.lang-option').forEach(option => {
    option.addEventListener('click', function(event) {
        event.preventDefault(); // Prevents page refreshing
        const selectedLang = option.getAttribute('data-lang');
        loadTranslations(selectedLang);
    });
});
