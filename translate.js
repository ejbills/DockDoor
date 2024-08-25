// Importation des modules nécessaires (si tu utilises des modules ES6)
// Assure-toi que les scripts i18next et i18next-xhr-backend sont inclus dans ton HTML si tu ne fais pas d'importation
// <script src="https://cdn.jsdelivr.net/npm/i18next@latest/dist/umd/i18next.min.js"></script>
// <script src="https://cdn.jsdelivr.net/npm/i18next-xhr-backend@latest/dist/umd/i18nextXHRBackend.min.js"></script>

// Initialize i18next with options
i18next
  .use(i18nextXHRBackend) // Utilise le backend pour charger les fichiers JSON
  .init({
    lng: 'en', // Langue par défaut
    fallbackLng: 'en', // Langue de secours si la traduction n'est pas trouvée
    debug: true, // Mode débogage pour le développement
    backend: {
      loadPath: '/locales/{{lng}}/translation.json' // Chemin pour charger les fichiers de traduction
    },
    react: {
      useSuspense: false // Si tu utilises React, désactive le suspense pour les traductions (optionnel)
    }
  })
  .then(() => {
    // Détecte la langue et applique les traductions lors du chargement de la page
    detectLanguageAndTranslate();
  })
  .catch(error => {
    console.error('Erreur lors de l\'initialisation de i18next:', error);
  });

// Fonction pour charger les traductions en utilisant i18next
async function loadTranslations(lang) {
  try {
    await i18next.changeLanguage(lang); // Change la langue
    document.querySelectorAll('[data-translate]').forEach(element => {
      const key = element.getAttribute('data-translate');
      element.innerHTML = i18next.t(key); // Utilise i18next pour obtenir le texte traduit
    });

    // Vérifie si la langue est RTL et applique la direction du texte
    const isRtlLang = i18next.dir() === 'rtl';
    document.documentElement.setAttribute('dir', isRtlLang ? 'rtl' : 'ltr');
  } catch (error) {
    console.error('Erreur lors du chargement des traductions:', error);
  }
}

// Fonction pour détecter la langue du navigateur et appliquer les traductions
function detectLanguageAndTranslate() {
  const userLang = navigator.language || navigator.userLanguage;
  const langCode = userLang.toLowerCase(); // Code langue complet
  const primaryLangCode = langCode.split('-')[0]; // Code langue sans indicateur régional

  // Tente de charger les traductions avec le code langue principal d'abord
  loadTranslations(primaryLangCode)
    .catch(() => {
      // Si une erreur se produit, vérifie avec le code langue complet
      return loadTranslations(langCode);
    })
    .catch(() => {
      // Si aucune traduction n'est trouvée, passe à l'anglais par défaut
      return loadTranslations('en');
    });
}

// Gère le changement de langue avec le menu déroulant
document.querySelectorAll('.lang-option').forEach(option => {
  option.addEventListener('click', function(event) {
    event.preventDefault(); // Empêche le rafraîchissement de la page
    const selectedLang = option.getAttribute('data-lang');
    loadTranslations(selectedLang);
  });
});
