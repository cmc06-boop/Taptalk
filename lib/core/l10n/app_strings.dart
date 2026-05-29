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

  static String invalidEmail(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Maglagay ng wastong email address.'
      : 'Enter a valid email address.';

  static String passwordTooShort(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Dapat ay hindi bababa sa 6 na character ang password.'
      : 'Password must be at least 6 characters.';

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

  static String myChild(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Aking Anak' : 'My child';

  static String notifications(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mga Abiso' : 'Notifications';

  static String noNotifications(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang bagong abiso.'
      : 'No new notifications.';

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
      ? 'Awtomatikong ginawa ng sistema ang code na ito. Ibahagi ito sa iyong magulang para ma-link ang account mo.'
      : 'This code was automatically generated by the system. Share it with your parent to link your account.';

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

  static String emergencyContacts(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Mga Contact sa Emerhensiya'
      : 'Emergency Contact';

  static String emergencyContactHint(AppLanguage lang, int index) {
    if (lang == AppLanguage.filipino) {
      return index == 1
          ? 'Contact 1 (hal. 09xx xxx xxxx)'
          : 'Contact 2 (Opsyonal)';
    }
    return index == 1
        ? 'Contact 1 (e.g. 09xx xxx xxxx)'
        : 'Contact 2 (Optional)';
  }

  static String edit(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'I-edit' : 'Edit';

  static String addAnotherContact(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Magdagdag pa ng contact'
      : 'Add another contact';

  static String emergencyContactHelp(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Para ito sa emergency alerts ng learner. Hindi ipinapakita sa teacher ang buong number.'
      : 'Used for learner emergency alerts. The teacher does not see the full number.';

  static String emergencyContactRequired(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Maglagay ng kahit isang emergency contact.'
      : 'Please add at least one emergency contact.';

  static String myChildSubtitle(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Subaybayan ang mga madalas gamiting parirala ng iyong anak.'
      : "Track your child's frequently used phrases.";

  static String linkChildCode(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'I-link ang code ng anak'
      : "Link child's code";

  static String enterChildCodeHint(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Ilagay ang profile code (hal. TT-AB12CD34)'
      : 'Enter profile code (e.g. TT-AB12CD34)';

  static String noLinkedChild(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Wala pang naka-link na anak. Pindutin ang + para maglagay ng code.'
      : 'No child linked yet. Tap + to enter their code.';

  static String noPhraseUsage(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang pariralang nagamit sa panahong ito.'
      : 'No phrases used in this period.';

  static String today(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Ngayon' : 'Today';

  static String thisWeek(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Linggong ito' : 'This week';

  static String month(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Buwan' : 'Month';

  static String frequentlyUsed(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Madalas gamitin'
      : 'Frequently used';

  static String timesUsed(int count) => '${count}x';

  static String invalidProfileCode(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi wasto ang profile code.'
      : 'Invalid profile code.';

  static String childNotFound(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang learner na may ganitong code.'
      : 'No learner found with this code.';

  static String childAlreadyLinked(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Naka-link na ang anak na ito.'
      : 'This child is already linked.';

  static String cannotLinkSelf(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi mo maililink ang sarili mong account.'
      : 'You cannot link your own account.';

  static String childLinked(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Matagumpay na na-link ang anak.'
      : 'Child linked successfully.';

  static String unlinkChild(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Alisin ang link'
      : 'Unlink';

  static String unlinkChildConfirm(AppLanguage lang, String name) =>
      lang == AppLanguage.filipino
          ? 'Alisin ang link kay $name?'
          : 'Unlink $name?';

  static String selectChild(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Pumili ng anak' : 'Select child';

  static String classesSubtitle(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Mga klase at subject na naka-enroll ka.'
      : 'Classes and subjects you are enrolled in.';

  static String enrollClassCode(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Mag-enroll gamit ang class code'
      : 'Enroll with class code';

  static String enterClassCodeHint(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Ilagay ang class code (hal. CLS-AB12CD34)'
      : 'Enter class code (e.g. CLS-AB12CD34)';

  static String noEnrolledClasses(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Wala ka pang naka-enroll na klase. Pindutin ang + para maglagay ng code.'
      : 'No classes enrolled yet. Tap + to enter a class code.';

  static String invalidClassCode(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi wasto ang class code.'
      : 'Invalid class code.';

  static String classNotFound(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang klase na may ganitong code.'
      : 'No class found with this code.';

  static String classAlreadyEnrolled(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Naka-enroll ka na sa klaseng ito.'
      : 'You are already enrolled in this class.';

  static String classEnrolled(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Matagumpay na na-enroll sa klase.'
      : 'Successfully enrolled in class.';

  static String leaveClass(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Umalis sa klase' : 'Leave class';

  static String leaveClassConfirm(AppLanguage lang, String className) =>
      lang == AppLanguage.filipino
          ? 'Umalis sa $className?'
          : 'Leave $className?';

  static String teacherLabel(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Guro' : 'Teacher';

  static String classCode(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'CLASS CODE' : 'CLASS CODE';

  static String classCodeHint(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Ibahagi ang code na ito sa mga mag-aaral para makapag-enroll sila sa iyong klase.'
      : 'Share this code with learners so they can enroll in your class.';
}
