/// Where the app sends a patient who wants to look something up on MedEx.
///
/// MedEx (medex.com.bd) is the Bangladeshi medicine and diagnostics index the
/// backend already reads from: `healthcare_api/config/medex.php` calls its
/// search endpoint as a doctor types a brand. This is the other half of that
/// relationship - the site itself, opened in the phone's browser, for a patient
/// who wants to read up on something rather than book it here.
///
/// Nothing is fetched through this URL and no patient detail travels with it.
/// It hands the patient over to MedEx and the app's part is finished.
///
/// Kept in `config/` rather than typed into a screen for the same reason
/// [ApiConfig] is: one line to change if MedEx ever moves.
library;

class MedexSite {
  // This class only holds constants.
  MedexSite._();

  /// The site as a patient would visit it.
  static const String homeUrl = 'https://medex.com.bd/';

  /// What it reads as on screen, when the app has to name it in a sentence.
  static const String displayName = 'medex.com.bd';

  static Uri get home => Uri.parse(homeUrl);
}
