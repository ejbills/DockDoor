// Initialize i18next with options
i18next
  .use(i18nextXHRBackend) // Uses backend to load JSON files
  .init({
    lng: 'en', // Default language
    fallbackLng: 'en', // Fallback language if requested language is not found
    debug: true, // Mode débogage pour le développement
    backend: {
      loadPath: '/locales/{{lng}}/translation.json' // Path to translation files
    }
  })
  .then(() => {
    // Detects language and translates web page
    detectLanguageAndTranslate();
  })
  .catch(error => {
    console.error('Error while loading i18next:', error);
  });

// Function to load translations using i18next
async function loadTranslations(lang) {
  try {
      await i18next.changeLanguage(lang); // Change language
      document.querySelectorAll('[data-translate]').forEach(element => {
          const key = element.getAttribute('data-translate');
          let translation = i18next.t(key); // Use i18next to get translated text
          
          // Purify the translation before injecting it into the DOM
          element.innerHTML = DOMPurify.sanitize(translation);
      });

      // Verifies whether language is RTL and applies fix
      const isRtlLang = i18next.dir().toLowerCase() === 'rtl';
      document.documentElement.setAttribute('dir', isRtlLang ? 'rtl' : 'ltr');
  } catch (error) {
      console.error(error);
  }
}

// Function to detect browser language and apply it
function detectLanguageAndTranslate() {
    // Gets URL parameters
    const urlParams = new URLSearchParams(window.location.search);
    const urlLang = urlParams.get('lang');

    // Detects browser language if no URL parameter is specified
    const userLang = urlLang || navigator.language || navigator.userLanguage;
    const langCode = userLang.toLowerCase(); // Complete language code
    const primaryLangCode = langCode.split('-')[0]; // Language code without regional indicator

    // Tries loading translations with partial language code
    loadTranslations(primaryLangCode)
        .catch(() => {
            // If no language is detected, try loading with the complete language code
            return loadTranslations(langCode);
        })
        .catch(() => {
            // If no translation is found, switch to default (English)
            return loadTranslations('en');
        });
}

// Manages language switching with dropdown menu
document.querySelectorAll('.lang-option').forEach(option => {
    option.addEventListener('click', function(event) {
        event.preventDefault(); // Prevents page from reloading
        const selectedLang = option.getAttribute('data-lang');

        // Updates URL with new language
        const newUrl = new URL(window.location.href);
        newUrl.searchParams.set('lang', selectedLang);
        window.history.pushState({ path: newUrl.href }, '', newUrl.href);

        loadTranslations(selectedLang);
        document.getElementById('dropdownContent').style.display = 'none';
    });
})