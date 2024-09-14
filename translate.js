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
      element.innerHTML = DOMPurify.sanitize(translation, {
        ALLOWED_TAGS: ['strong', 'em', 'u', 'span', 'pre'],
        ALLOWED_ATTR: ['class'] // Allow class attribute in general, restricted by the hook
      });
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
  option.addEventListener('click', function (event) {
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

// dynamically load all language options
document.addEventListener('DOMContentLoaded', function () {
  const dropdownContent = document.getElementById('dropdownContent');
  const locales = [
    { code: 'af', name: 'Afrikaans' },
    { code: 'ar', name: 'العربية' },
    { code: 'ca', name: 'Català' },
    { code: 'cs', name: 'Čeština' },
    { code: 'da', name: 'Dansk' },
    { code: 'de', name: 'Deutsch' },
    { code: 'el', name: 'Ελληνικά' },
    { code: 'en', name: 'English' },
    { code: 'es', name: 'Español' },
    { code: 'es-ES', name: 'Español (España)' },
    { code: 'fi', name: 'Suomi' },
    { code: 'fr', name: 'Français' },
    { code: 'he', name: 'עברית' },
    { code: 'hu', name: 'Magyar' },
    { code: 'it', name: 'Italiano' },
    { code: 'ja', name: '日本語' },
    { code: 'ko', name: '한국어' },
    { code: 'nl', name: 'Nederlands' },
    { code: 'no', name: 'Norsk' },
    { code: 'pl', name: 'Polski' },
    { code: 'pt', name: 'Português' },
    { code: 'pt-BR', name: 'Português (Brasil)' },
    { code: 'pt-PT', name: 'Português (Portugal)' },
    { code: 'ro', name: 'Română' },
    { code: 'ru', name: 'Русский' },
    { code: 'sr', name: 'Српски' },
    { code: 'sv', name: 'Svenska' },
    { code: 'sv-SE', name: 'Svenska (Sverige)' },
    { code: 'tr', name: 'Türkçe' },
    { code: 'uk', name: 'Українська' },
    { code: 'vi', name: 'Tiếng Việt' },
    { code: 'zh', name: '中文' },
    { code: 'zh-CN', name: '简体中文' },
    { code: 'zh-TW', name: '繁體中文' }
  ];

  // Function to create language option
  function createLanguageOption(locale) {
    const a = document.createElement('a');
    a.href = '#';
    a.className = 'lang-option';
    a.setAttribute('data-lang', locale.code);
    a.textContent = locale.name;
    if (locale.code === 'he' || locale.code === 'ar') {
      a.dir = 'rtl';
    }
    a.addEventListener('click', function (e) {
      e.preventDefault();
      loadTranslations(locale.code);
    });
    return a;
  }

  // add top contribution option
  const helpTranslate = document.createElement('a');
  helpTranslate.href = 'https://github.com/ejbills/DockDoor?tab=readme-ov-file#translating-the-website-httpsdockdoornet';
  helpTranslate.target = '_blank';
  helpTranslate.setAttribute('data-translate', 'helpTranslate');
  helpTranslate.textContent = 'Help Translate';
  dropdownContent.appendChild(helpTranslate);

  // Add language options
  locales.forEach(locale => {
    dropdownContent.appendChild(createLanguageOption(locale));
  });

});