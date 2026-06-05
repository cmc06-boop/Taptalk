import '../../data/models/parent_notification.dart';

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

  static String editPhrase(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'I-edit ang parirala' : 'Edit phrase';

  static String attachImage(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mag-attach ng larawan' : 'Attach image';

  static String remove(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Alisin' : 'Remove';

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
      ? 'Dapat ay hindi bababa sa 8 na character ang password at may malaki/maliit na titik, numero, at simbolo.'
      : 'Password must be at least 8 characters with upper, lower, number, and symbol.';

  static String passwordRequirements(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi bababa sa 8 character, may malaki/maliit na titik, numero, at simbolo.'
      : 'At least 8 characters with upper, lower, number, and symbol.';

  static String strongPassword(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Malakas na password'
      : 'Strong password';

  static String weakPassword(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Mahinang password'
      : 'Weak password';

  static String wrongPassword(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Maling password.'
      : 'Incorrect password.';

  static String invalidFullName(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Maglagay ng buong pangalan (hindi bababa sa 2 character).'
      : 'Enter your full name (at least 2 characters).';

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

  static String myClasses(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mga Klase Ko' : 'My Classes';

  static String editClass(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'I-edit ang klase' : 'Edit class';

  static String dashboard(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Dashboard' : 'Dashboard';

  static String monitoring(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Monitoring' : 'Monitoring';

  static String teacherDashboardSubtitle(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Mabilis na buod ng iyong mga klase at mag-aaral.'
          : 'A quick overview of your classes and students.';

  static String teacherMyClassesSubtitle(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Pamahalaan ang class codes at ibahagi sa mga mag-aaral.'
          : 'Manage class codes and share them with learners.';

  static String teacherMonitoringSubtitle(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Pindutin ang pangalan ng mag-aaral para makita ang paggamit ng parirala.'
          : "Tap a student's name to view their phrase usage.";

  static String totalStudents(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mag-aaral' : 'Students';

  static String totalClasses(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Klase' : 'Classes';

  static String noTeacherStudents(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang naka-enroll na mag-aaral. Ibahagi ang class code sa mga bata.'
      : 'No enrolled students yet. Share your class code with learners.';

  static String noTeacherClasses(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Wala pang klase. Pindutin ang + para gumawa ng bago.'
      : 'No classes yet. Tap + to create one.';

  static String createClass(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Gumawa ng klase'
      : 'Create class';

  static String create(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Gumawa' : 'Create';

  static String createClassHint(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Ilagay ang pangalan ng subject at section, hal. English 1 - Sampaguita.'
      : 'Enter subject and section name, e.g. English 1 - Sampaguita.';

  static String classNameExample(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'hal. English 1-Sampaguita'
      : 'e.g. English 1-Sampaguita';

  static String enterClassName(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Maglagay ng pangalan ng klase.'
      : 'Please enter a class name.';

  static String deleteClass(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Burahin ang klase'
      : 'Delete class';

  static String deleteClassConfirm(AppLanguage lang, String className) =>
      lang == AppLanguage.filipino
          ? 'Burahin ang "$className"? Maaalis din ang mga naka-enroll na mag-aaral sa klaseng ito.'
          : 'Delete "$className"? Enrolled students will be removed from this class.';

  static String classCreated(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Nalikha ang klase.'
      : 'Class created.';

  static String classUpdated(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Na-update ang klase.'
      : 'Class updated.';

  static String classDeleted(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Nabura ang klase.'
      : 'Class deleted.';

  static String lessons(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mga Aralin' : 'Lessons';

  static String createLesson(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Gumawa ng aralin'
      : 'Create lesson';

  static String createLessonHint(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hal. Unit 1 - Mga Pakiramdam'
      : 'e.g. Unit 1 - Feelings';

  static String enterLessonTitle(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Maglagay ng pamagat ng aralin.'
      : 'Please enter a lesson title.';

  static String lessonCreated(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Nalikha ang aralin.'
      : 'Lesson created.';

  static String noLessons(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Wala pang aralin. Pindutin ang + para gumawa.'
      : 'No lessons yet. Tap + to create one.';

  static String noLessonsLearner(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Wala pang aralin sa klaseng ito.'
      : 'No lessons in this class yet.';

  static String noPhrasesInLesson(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Wala pang salita o phrase sa araling ito.'
      : 'No words or phrases in this lesson yet.';

  static String classLessonsSubtitle(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Pindutin ang aralin para makita ang mga salita at phrase.'
      : 'Tap a lesson to see its words and phrases.';

  static String phrasesInLesson(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Mga parirala sa aralin'
      : 'Phrases in this lesson';

  static String lessonPhrasesSubtitle(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Magdagdag ng parirala at larawan — tulad ng home screen.'
          : 'Add phrases and images — just like the home screen.';

  static String phrasesCount(int count, AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? '$count parirala'
          : '$count phrases';

  static String editLesson(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'I-edit ang aralin'
      : 'Edit lesson';

  static String lessonUpdated(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Na-update ang aralin.'
      : 'Lesson updated.';

  static String deleteLesson(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Burahin ang aralin'
      : 'Delete lesson';

  static String deleteLessonConfirm(AppLanguage lang, String title) =>
      lang == AppLanguage.filipino
          ? 'Burahin ang "$title"? Mabubura rin ang lahat ng parirala dito.'
          : 'Delete "$title"? All phrases in this lesson will be removed.';

  static String unableAddPhrase(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi maidagdag ang parirala.'
      : 'Could not add phrase.';

  static String openClass(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Buksan ang klase'
      : 'Open class';

  static String studentsInClass(int count, AppLanguage lang) {
    if (lang == AppLanguage.filipino) {
      return count == 1 ? '1 mag-aaral' : '$count mag-aaral';
    }
    return count == 1 ? '1 student' : '$count students';
  }

  static String alertStudent(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Alert' : 'Alert';

  static String alertStudentConfirm(AppLanguage lang, String studentName) =>
      lang == AppLanguage.filipino
          ? 'Magpadala ng urgent alert sa mga magulang ni $studentName?'
          : 'Send an urgent alert to $studentName\'s linked parents?';

  static String alertSent(AppLanguage lang, String studentName) =>
      lang == AppLanguage.filipino
          ? 'Naipadala ang alert sa mga magulang ni $studentName.'
          : 'Alert sent to $studentName\'s linked parents.';

  static String alertNoLinkedParents(AppLanguage lang, String studentName) =>
      lang == AppLanguage.filipino
          ? 'Walang naka-link na magulang si $studentName.'
          : 'No linked parents found for $studentName.';

  static String alertNotAuthorized(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Hindi mo maaaring mag-alert sa mag-aaral na ito.'
          : 'You cannot alert this student.';

  static String loginNeedsInternet(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Kailangan ng internet para mag-log in sa online account na ito.'
      : 'Internet is required to sign in to this online account.';

  static String loginFailedTryAgain(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi makapag-log in. Subukan muli o mag-sign up gamit ang bagong email.'
      : 'Could not sign in. Try again or sign up with a new email on this phone.';

  static String signUpFailedTryAgain(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi makapag-sign up. Subukan muli o gumamit ng ibang email.'
      : 'Could not sign up. Try again or use a different email.';

  static String accountNotOnThisDevice(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'May Firebase account ang email na ito pero wala pa sa teleponong ito. Mag-sign up dito gamit ang parehong email at password.'
      : 'This email has a cloud account but is not set up on this phone yet. Sign up here with the same email and password.';

  static String smsSignInRequired(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Mag-log out at mag-log in muli para makapagpadala ng SMS alert.'
      : 'Sign out and sign in again to send SMS alerts.';

  static String smsEnrollmentSyncRequired(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Hindi naka-sync ang enrollment sa cloud. Mag-log in ang learner gamit internet, tapos i-enroll ulit sa class.'
          : 'Enrollment is not synced to cloud. Learner must log in online and enroll in the class again.';

  static String smsNoEmergencyContacts(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang emergency contact ang learner. Idagdag sa profile ng learner.'
      : 'Learner has no emergency contacts. Add them in the learner profile.';

  static String smsPermissionDenied(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Payagan ang SMS permission sa settings ng phone para maipadala ang alert.'
      : 'Allow SMS permission in phone settings to send the alert.';

  static String smsSendFailed(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi naipadala ang SMS. Suriin ang SIM, load, at emergency contacts.'
      : 'SMS could not be sent. Check SIM, load, and emergency contacts.';

  static String smsNoSignal(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang cellular signal. Hindi maipadala ang SMS.'
      : 'No cellular signal. SMS could not be sent.';

  static String inAppNeedsInternet(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Kailangan ng internet ang in-app alert sa magulang. Naipadala ang SMS sa emergency contacts.'
      : 'In-app parent alerts need internet. SMS was sent to emergency contacts.';

  static String smsSentViaPhone(AppLanguage lang, int sent, int attempted) =>
      lang == AppLanguage.filipino
          ? 'Naipadala ang SMS sa $sent/$attempted contact(s).'
          : 'SMS sent to $sent/$attempted contact(s).';

  static String smsTapSendToDeliver(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi ma-send ng automatic ang SMS sa phone na ito. Binuksan ang Messages — i-tap ang Send.'
      : 'Automatic SMS is blocked on this phone. Messages app opened — tap Send.';

  static String chooseAlertType(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Piliin ang uri ng alert'
      : 'Choose alert type';

  static String alertTypeLabel(AppLanguage lang, ParentAlertType type) =>
      switch (type) {
        ParentAlertType.needsAttention =>
          lang == AppLanguage.filipino ? 'Needs attention' : 'Needs attention',
        ParentAlertType.distress =>
          lang == AppLanguage.filipino ? 'Behavior / Tantrums' : 'Behavior / Tantrums',
        ParentAlertType.schoolNeeded => lang == AppLanguage.filipino
            ? 'Need parent at school'
            : 'Need parent at school',
        ParentAlertType.teacherAlert =>
          lang == AppLanguage.filipino ? 'General classroom concern' : 'General classroom concern',
      };

  static String teacherAlertTitle(
    AppLanguage lang,
    String teacherName,
    String childName,
    ParentAlertType type,
  ) =>
      switch (type) {
        ParentAlertType.needsAttention => lang == AppLanguage.filipino
            ? 'Kailangan ng atensyon si $childName'
            : '$childName needs attention',
        ParentAlertType.distress => lang == AppLanguage.filipino
            ? 'Behavior concern para kay $childName'
            : 'Behavior concern for $childName',
        ParentAlertType.schoolNeeded => lang == AppLanguage.filipino
            ? 'Kailangan sa paaralan si $childName'
            : '$childName needs parent presence at school',
        ParentAlertType.teacherAlert => lang == AppLanguage.filipino
            ? 'Alert mula kay $teacherName — $childName'
            : 'Alert from $teacherName — $childName',
      };

  static String teacherAlertBody(
    AppLanguage lang,
    String teacherName,
    String className,
    String childName,
    ParentAlertType type,
  ) =>
      switch (type) {
        ParentAlertType.needsAttention => lang == AppLanguage.filipino
            ? '$teacherName reports na kailangan ng agarang atensyon si $childName sa $className. Pakicheck in agad.'
            : '$teacherName reports that $childName needs immediate attention in $className. Please check in soon.',
        ParentAlertType.distress => lang == AppLanguage.filipino
            ? '$teacherName reports behavior/tantrum concerns for $childName sa $className. Kailangan ng support ninyo.'
            : '$teacherName reports behavior/tantrum concerns for $childName in $className and needs your support.',
        ParentAlertType.schoolNeeded => lang == AppLanguage.filipino
            ? '$teacherName requests parent presence for $childName sa $className. Pakiusap na pumunta o tumawag agad.'
            : '$teacherName requests parent presence for $childName in $className. Please come to school or call as soon as possible.',
        ParentAlertType.teacherAlert => lang == AppLanguage.filipino
            ? 'Nagpadala si $teacherName ng urgent alert para kay $childName sa $className. Pakitingnan agad.'
            : '$teacherName sent an urgent alert for $childName in $className. Please check in as soon as you can.',
      };

  static String alertStudentSoon(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Paparating na ang alert sa magulang.'
      : 'Parent alert coming soon.';

  static String viewMonitoring(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Tingnan'
      : 'View';

  static String enrolledIn(AppLanguage lang, String className) =>
      lang == AppLanguage.filipino
          ? 'Naka-enroll sa $className'
          : 'Enrolled in $className';

  static String myChild(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Aking Anak' : 'My child';

  static String parentDashboard(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Dashboard' : 'Dashboard';

  static String parentDashboardSubtitle(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Subaybayan ang alerts, aralin, at progress ng anak.'
          : 'Track alerts, lessons, and your child\'s progress.';

  static String recentAlerts(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Kamakailang Alerts' : 'Recent Alerts';

  static String recentLessons(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Kamakailang Aralin' : 'Recent Lessons';

  static String viewAll(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Tingnan lahat' : 'View all';

  static String alertHistory(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Kasaysayan ng Alerts' : 'Alert History';

  static String alertHistorySubtitle(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Lahat ng alert na ipinadala mo sa mga magulang.'
          : 'All alerts you sent to parents.';

  static String noRecentAlerts(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang alert pa. Lalabas dito ang mga alert na ipinadala mo sa magulang.'
      : 'No alerts yet. Alerts you send to parents will appear here.';

  static String noRecentLessons(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang bagong aralin pa. Gumawa ng lesson sa My Classes.'
      : 'No lessons yet. Create one from My Classes.';

  static String linkedChildren(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Mga Naka-link na Anak'
      : 'Linked Children';

  static String timeAgo(DateTime date, AppLanguage lang) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) {
      return lang == AppLanguage.filipino ? 'Ngayon lang' : 'Just now';
    }
    if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes;
      return lang == AppLanguage.filipino
          ? '$minutes min ang nakalipas'
          : '$minutes mins ago';
    }
    if (diff.inHours < 24) {
      final hours = diff.inHours;
      if (lang == AppLanguage.filipino) {
        return hours == 1 ? '1 oras ang nakalipas' : '$hours oras ang nakalipas';
      }
      return hours == 1 ? '1 hour ago' : '$hours hours ago';
    }
    if (diff.inDays < 7) {
      final days = diff.inDays;
      if (lang == AppLanguage.filipino) {
        return days == 1 ? '1 araw ang nakalipas' : '$days araw ang nakalipas';
      }
      return days == 1 ? '1 day ago' : '$days days ago';
    }
    return lang == AppLanguage.filipino
        ? '${date.day}/${date.month}/${date.year}'
        : '${date.month}/${date.day}/${date.year}';
  }

  static String shortChildName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return fullName;
    if (parts.length == 1) return parts.first;
    return '${parts.first} ${parts.last[0]}.';
  }

  static String notifications(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mga Abiso' : 'Notifications';

  static String noNotifications(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang abiso sa ngayon.'
      : 'No notifications yet.';

  static String notificationsSubtitle(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Mahahalagang alert mula sa paaralan at paggamit ng anak.'
          : 'Urgent alerts from school and your child\'s app use.';

  static String todayLabel(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Ngayon' : 'Today';

  static String yesterdayLabel(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Kahapon' : 'Yesterday';

  static String markAllRead(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Markahan lahat na nabasa'
      : 'Mark all as read';

  static String newAlertBadge(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Bago' : 'New';

  static String urgentLabel(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Apurahan' : 'Urgent';

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

  static String forgotPassword(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Nakalimutan ang password?'
      : 'Forgot password?';

  static String forgotPasswordTitle(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'I-reset ang Password'
      : 'Reset Password';

  static String forgotPasswordHint(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Ilagay ang email na ginamit mo sa sign up. Magpapadala kami ng reset link sa inbox mo.'
      : 'Enter the email you used to sign up. We\'ll send a reset link to that inbox.';

  static String sendResetLink(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Ipadala ang reset link'
      : 'Send reset link';

  static String backToLogin(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Bumalik sa login'
      : 'Back to login';

  static String passwordResetEmailSent(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Naipadala na ang reset link sa email mo. Suriin ang inbox (at spam folder).'
      : 'Reset link sent to your email. Check your inbox (and spam folder).';

  static String emailNotRegistered(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang account na nakarehistro sa email na ito.'
      : 'No account is registered with this email.';

  static String setNewPasswordHint(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Maglagay ng bagong password para sa account mo.'
      : 'Enter a new password for your account.';

  static String saveNewPassword(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'I-save ang bagong password'
      : 'Save new password';

  static String passwordResetSuccess(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Na-update na ang password. Puwede ka nang mag-login.'
      : 'Password updated. You can log in now.';

  static String localPasswordResetUnavailable(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Kailangan ng internet para magpadala ng reset link sa email.'
          : 'Internet is required to send a reset link to your email.';

  static String passwordResetEmailFailed(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Hindi maipadala ang reset link. Suriin ang email at subukan muli.'
          : 'Could not send reset link. Check the email and try again.';

  static String passwordResetTooManyRequests(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Masyadong maraming request. Subukan muli pagkalipas ng ilang minuto.'
          : 'Too many requests. Try again in a few minutes.';

  static String signUpRequiresInternet(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Kailangan ng internet para mag-sign up. Gamitin ang valid na email (Gmail o iba pa).'
      : 'Internet is required to sign up. Use a valid email address (Gmail or any inbox).';

  static String signUpOnlineAccountFailed(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Hindi makagawa ng online account. Suriin ang internet at subukan muli.'
      : 'Could not create your online account. Check your internet and try again.';

  static String ok(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'OK' : 'OK';

  static String successTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Tagumpay' : 'Success';

  static String somethingWentWrong(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'May nangyaring mali'
          : 'Something went wrong';

  static String profileUpdatedTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Na-update ang profile' : 'Profile updated';

  static String passwordUpdatedTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Na-update ang password'
          : 'Password updated';

  static String classEnrolledTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Naka-enroll na' : 'Enrolled';

  static String leftClassTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Umalis sa class' : 'Left class';

  static String classCreatedTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Nagawa ang class' : 'Class created';

  static String classUpdatedTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Na-update ang class' : 'Class updated';

  static String classDeletedTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Natanggal ang class' : 'Class deleted';

  static String childLinkedTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Naka-link na' : 'Child linked';

  static String childUnlinkedTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Na-unlink na' : 'Child unlinked';

  static String lessonCreatedTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Nagawa ang lesson' : 'Lesson created';

  static String lessonUpdatedTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Na-update ang aralin' : 'Lesson updated';

  static String copiedTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Nakopya' : 'Copied';

  static String alertSentTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Naipadala ang alert' : 'Alert sent';

  static String alertFailedTitle(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Hindi maipadala'
          : 'Unable to send';

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

  static String welcomeHeadline(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Maligayang pagdating'
      : 'Welcome';

  static String welcomeTagline(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Ang iyong boses — isang tap lang.'
      : 'Your voice — just one tap away.';

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

  static String join(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Sumali' : 'Join';

  static String joinClass(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Sumali sa klase'
      : 'Join class';

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
      ? 'Pindutin ang pangalan ng anak para makita ang paggamit ng parirala.'
      : "Tap your child's name to view their phrase usage.";

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

  static String selectMonthPeriod(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Pumili ng buwan'
      : 'Select month';

  static String vocabularyGrowth(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Paglago ng bokabularyo'
      : 'Vocabulary growth';

  static String vocabularyGrowthSubtitle(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Mga bagong salita at kategoryang ginagamit ng anak mo.'
          : 'New words and categories your child is building.';

  static String totalVocabulary(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Kabuuang salita'
      : 'Total words';

  static String newWordsThisWeek(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Bago ngayong linggo'
      : 'New this week';

  static String newWordsThisMonth(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Bago ngayong buwan'
      : 'New this month';

  static String newWordsTrend(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Bagong salita sa paglipas ng panahon'
      : 'New words over time';

  static String categoriesUsed(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Mga kategorya'
      : 'Categories used';

  static String trendByWeek(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Linggo' : 'Weeks';

  static String trendByMonth(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Buwan' : 'Months';

  static String noVocabularyData(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Wala pang naitalang salita. Gagamit ang anak ng app para makita ang paglago dito.'
      : 'No words recorded yet. Usage will appear here as your child taps phrases.';

  static String vocabularyWords(int count, AppLanguage lang) =>
      lang == AppLanguage.filipino ? '$count salita' : '$count words';

  static String lessonProgress(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Pag-unlad sa aralin'
      : 'Lesson progress';

  static String lessonProgressSubtitle(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Mga klase at aralin na binuksan ng bata sa panahong ito.'
          : 'Classes and lessons your child opened in this period.';

  static String noLessonProgress(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang aralin na ginamit sa panahong ito.'
      : 'No lessons used in this period.';

  static String lessonPhrasesPracticed(
    int practiced,
    int total,
    AppLanguage lang,
  ) =>
      lang == AppLanguage.filipino
          ? '$practiced / $total parirala'
          : '$practiced / $total phrases';

  static String lastUsedAt(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Huling ginamit'
      : 'Last used';

  static String frequentlyUsed(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Madalas gamitin'
      : 'Frequently used';

  static String sessionActivity(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Oras ng paggamit'
      : 'Session activity';

  static String sessionActivitySubtitle(AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? 'Tinatantya mula sa mga pagkakataong ginamit ang app.'
          : 'Estimated from app usage patterns.';

  static String totalSessionTime(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Kabuuan'
      : 'Total';

  static String sessionsCount(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Sesyon'
      : 'Sessions';

  static String avgSession(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Avg/sesyon'
      : 'Avg/session';

  static String noSessionData(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Walang naitalang sesyon sa panahong ito.'
      : 'No sessions recorded for this period.';

  static String sessionInProgress(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'May aktibong sesyon'
      : 'Session in progress';

  static String sessionInProgressDetail(double minutes, AppLanguage lang) =>
      lang == AppLanguage.filipino
          ? '${formatDurationMinutes(minutes, lang)} at tumataas pa'
          : '${formatDurationMinutes(minutes, lang)} and counting';

  static String liveUpdating(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Live · ina-update bawat 30s'
      : 'Live · updates every 30s';

  static String formatDurationMinutes(double minutes, AppLanguage lang) {
    final total = minutes.round();
    if (total < 1) {
      return lang == AppLanguage.filipino ? '<1 min' : '<1 min';
    }
    if (total < 60) return '${total}m';
    final hours = total ~/ 60;
    final mins = total % 60;
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins}m';
  }

  static String timesUsed(int count, AppLanguage lang) {
    if (lang == AppLanguage.filipino) {
      return count == 1 ? '1 beses' : '$count beses';
    }
    return count == 1 ? '1 time' : '$count times';
  }

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

  static String childUnlinked(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Naalis na ang link sa anak.'
      : 'Child unlinked.';

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
      ? 'Wala ka pang naka-enroll na klase. Pindutin ang + para sumali gamit ang class code.'
      : 'No classes enrolled yet. Tap + to join with a class code.';

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

  static String leftClass(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Umalis ka na sa klase.'
      : 'You left the class.';

  static String leaveClass(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Umalis sa klase' : 'Leave class';

  static String leaveClassConfirm(AppLanguage lang, String className) =>
      lang == AppLanguage.filipino
          ? 'Umalis sa $className?'
          : 'Leave $className?';

  static String unenroll(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Mag-unenroll' : 'Unenroll';

  static String unenrollConfirm(AppLanguage lang, String className) =>
      lang == AppLanguage.filipino
          ? 'Mag-unenroll sa $className?'
          : 'Unenroll from $className?';

  static String gradeAndSection(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Baitang at section' : 'Grade and section';

  static String teacherLabel(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'Guro' : 'Teacher';

  static String classCode(AppLanguage lang) =>
      lang == AppLanguage.filipino ? 'CLASS CODE' : 'CLASS CODE';

  static String classCodeHint(AppLanguage lang) => lang == AppLanguage.filipino
      ? 'Ibahagi ang code na ito sa mga mag-aaral para makapag-enroll sila sa iyong klase.'
      : 'Share this code with learners so they can enroll in your class.';
}
