enum AppLanguage { english, filipino }

abstract final class AppStrings {
  static String langCode(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'fil' : 'en';

  static String welcomeSub(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Pumili ng kategorya at pindutin ang parirala para marinig ito.'
      : 'Select a category and tap a phrase to hear it spoken aloud.';

  static String categories(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mga Kategorya' : 'Categories';

  static String addCategory(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Magdagdag ng kategorya' : 'Add category';

  static String enterText(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Maglagay ng teksto' : 'Enter text';

  static String attachImage(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mag-attach ng larawan' : 'Attach image';

  static String play(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'I-play' : 'Play';

  static String pause(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'I-pause' : 'Pause';

  static String speed(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Bilis' : 'Speed';

  static String speechSpeed(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Bilis ng Pagsasalita' : 'Speech Speed';

  static String languageDisplay(AppLanguage selected, AppLanguage uiLang) {
    if (selected == AppLanguage.english) {
      return uiLang == AppLanguage.filipino ? '🇺🇸 Ingles' : '🇺🇸 English';
    }
    return uiLang == AppLanguage.filipino ? '🇵🇭 Filipino' : '🇵🇭 Filipino';
  }

  static String home(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Pangunahin' : 'Home';

  static String appName(AppLanguage lang) => 'TapTalk';

  static String email(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Email' : 'Email';

  static String password(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Password' : 'Password';

  static String currentPassword(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Kasalukuyang password'
      : 'Current password';

  static String newPassword(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Bagong password'
      : 'New password';

  static String confirmPassword(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Kumpirmahin ang password'
      : 'Confirm password';

  static String fullName(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Buong pangalan'
      : 'Full name';

  static String fillAllFields(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Pakipunan ang lahat ng patlang.'
      : 'Please fill in all fields.';

  static String passwordsDoNotMatch(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi magkatugma ang mga password.'
      : 'Passwords do not match.';

  static String whatAreYou(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Sino ka?'
      : 'What are you?';

  static String learner(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mag-aaral' : 'Learner';

  static String parent(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Magulang' : 'Parent';

  static String teacher(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Guro' : 'Teacher';

  static String confirm(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Kumpirmahin' : 'Confirm';

  static String createAccount(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Gumawa ng account'
      : 'Create account';

  static String chooseCategoryTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mga Kategorya' : 'Categories';

  static String hiUser(String name, AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Kumusta, $name!' : 'Hi, $name!';

  static String chooseCategorySub(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Pumili ng kategorya para makita ang mga parirala.'
      : 'Choose a category to see phrases.';

  static String addCategoryShort(AppLanguage lang) =>
      lang == AppLanguage.filipino ? '+ Idagdag' : '+ Add';

  static String favoritePhrases(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Mga paboritong parirala'
      : 'Favorite phrases';

  static String favoritesHint(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Pindutin ang parirala para marinig • ⭐ para alisin'
      : 'Tap a phrase to hear it • ⭐ to remove';

  static String emptyFavoritesDesign(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang paborito pa. Pindutin ang ⭐ sa anumang parirala para i-save dito.'
      : 'No favorites yet. Tap ⭐ on any phrase to save it here.';

  static String delete(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Burahin' : 'Delete';

  static String imageAttached(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'May naka-attach na larawan'
      : 'Image attached';

  static String customCategory(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Pasadyang' : 'Custom';

  static String defaultLearnerName(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mag-aaral' : 'Learner';

  static String ttsNotAvailable(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi magsalita ang phone. I-check ang Text-to-speech sa Settings at i-download ang wika (offline).'
      : 'Speech failed. Check Text-to-speech in device Settings and download the language for offline use.';

  static String speechNeedsInternet(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Ang voice input ay kailangan ng internet sa ilang phone. Ang Speak button ay gumagana offline.'
      : 'Voice input may need internet on some phones. The Speak button works offline.';

  static String speechNotAvailable(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi available ang speech recognition.'
      : 'Speech recognition is not available.';

  static String settingsSubtitle(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Pamahalaan ang iyong mga kagustuhan at humingi ng suporta.'
      : 'Manage your preferences and seek support.';

  static String helpSupport(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Tulong at Suporta'
      : 'Help & Support';

  static String contactSupport(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Makipag-ugnayan sa support@taptalk.app o bisitahin ang aming Help Center para sa FAQs at gabay sa troubleshooting.'
      : 'Contact us at support@taptalk.app or visit our Help Center for FAQs and troubleshooting guides.';

  static String aboutUs(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Tungkol sa Amin' : 'About Us';

  static String aboutBody(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'TapTalk v2.1.0 — Mabilis at accessible na communication app para sa lahat. © 2026 TapTalk Inc.'
      : 'TapTalk v2.1.0 — A fast, accessible communication app built for everyone. © 2026 TapTalk Inc.';

  static String backToHome(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Bumalik sa Home'
      : 'Back to Home';

  static String englishLabel(AppLanguage lang) => 'English';

  static String filipinoLabel(AppLanguage lang) => 'Filipino';

  static String invalidEmailPassword(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Maling email o password.'
      : 'Invalid email or password.';

  static String loginFailed(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi matagumpay ang pag-login.'
      : 'Login failed.';

  static String emailInUse(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Ginagamit na ang email na ito.'
      : 'Email is already in use.';

  static String parentTeacherComingSoon(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Malapit na ang para sa magulang at guro. Gumamit ng learner account.'
      : 'Parent and teacher flows are coming soon. Use a learner account.';

  static String notSignedIn(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi naka-sign in'
      : 'Not signed in';

  static String unableAddCategory(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi maidagdag ang kategorya.'
      : 'Unable to add category.';

  static String favorites(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mga Paborito' : 'Favorites';

  static String history(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Kasaysayan' : 'History';

  static String settings(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mga Setting' : 'Settings';

  static String sources(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Pinanggalingan' : 'Sources';

  static String classes(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mga Klase' : 'Classes';

  static String parents(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mga Magulang' : 'Parents';

  static String forMe(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Para sa akin' : 'For me';

  static String logout(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mag-logout' : 'Logout';

  static String speak(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Magsalita' : 'Speak';

  static String phrasesLabel(String categoryName, AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Mga Parirala — $categoryName'
          : '$categoryName Phrases';

  static String welcomeUser(String name, AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Maligayang pagdating, $name' : 'Welcome, $name';

  static String loginTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mag-login' : 'Log in';

  static String signUp(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mag-sign up' : 'Sign up';

  static String noAccount(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Wala pang account?'
      : "Don't have an account?";

  static String hasAccount(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'May account na?'
      : 'Already have an account?';

  static String chooseThemeTitle(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Pumili ng Tema 🌸'
      : 'Choose Your Theme 🌸';

  static String chooseThemeSub(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Pumili ng kulay na komportable para sa iyo'
      : 'Pick a color that feels comfortable for you';

  static String chooseThemeFooter(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Ang napiling tema ay gagamitin sa lahat ng learner pages mo.'
      : 'Your selected theme will be used across your learner pages.';

  static String continueLabel(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Magpatuloy →' : 'Continue →';

  static String hereWeGo(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Tara na!' : 'Here we go!';

  static String profile(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Profile' : 'Profile';

  static String preferences(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mga Kagustuhan' : 'Preferences';

  static String language(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Wika' : 'Language';

  static String theme(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Tema' : 'Theme';

  static String emptyFavorites(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang paborito pa. Pindutin ang ☆ sa isang parirala.'
      : 'No favorites yet. Tap ☆ on a phrase card.';

  static String historySubtitle(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Narito ang mga pariralang sinabi mo kamakailan.'
      : 'Here are the phrases you\'ve spoken recently.';

  static String emptyHistory(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang kasaysayan pa.'
      : 'No history yet.';

  static String clearAll(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Burahin lahat' : 'Clear All';

  static String clearAllHistoryConfirm(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Burahin ang buong kasaysayan?'
          : 'Clear all history?';

  static String deletePhrase(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Burahin ang pariralang ito?'
      : 'Delete this phrase?';

  static String newCategory(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Bagong kategorya' : 'New category';

  static String categoryNameHint(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Pangalan ng kategorya'
      : 'Category name';

  static String add(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Idagdag' : 'Add';

  static String cancel(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Kanselahin' : 'Cancel';

  static String myProfile(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Aking Profile' : 'My Profile';

  static String profileSubtitle(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Tingnan at i-update ang iyong personal na detalye.'
      : 'View and update your personal details.';

  static String personalDetails(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Personal na Detalye'
      : 'Personal Details';

  static String emailAddress(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Email Address'
      : 'Email Address';

  static String profileCode(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'PROFILE CODE' : 'PROFILE CODE';

  static String profileCodeHint(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Ibahagi ang code na ito sa iyong guro para ma-link ang account mo sa kanilang class roster.'
      : 'Share this code with your teacher to link your account to their class roster.';

  static String saveChanges(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'I-save ang mga Pagbabago'
      : 'Save Changes';

  static String copy(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Kopyahin' : 'Copy';

  static String copied(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Nakopya na' : 'Copied';

  static String editPassword(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'I-edit ang password'
      : 'Edit password';

  static String profileUpdated(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Na-update ang profile.'
      : 'Profile updated.';

  static String passwordUpdated(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Na-update ang password.'
      : 'Password updated.';

  static String wrongCurrentPassword(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Maling kasalukuyang password.'
      : 'Current password is incorrect.';
}
