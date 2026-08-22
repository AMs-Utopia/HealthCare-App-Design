import 'package:flutter/material.dart';
///Central colour palette for the Health Care app.
///The green and blue values are taken from the app logo so for every
///screen color stays visually consistent.
class AppColors {
  //This class only holds constants!
  AppColors._();
  ///Neon green
  static const Color neonGreen = Color(0xFF39FF14);
  ///Green
  static const Color logoGreen = Color(0xFF3FA34D);
  ///Blue
  static const Color logoBlue = Color(0xFF2E75B6);
  ///Light background
  static const Color background = Color(0xFFF2F4F3);
  ///Border colour
  static const Color fieldBorder = Color(0xFF9E9E9E);
  ///Default text colour.
  static const Color textDark = Color(0xFF1F2933);
  ///Muted text colour
  static const Color textMuted = Color(0xFF5C6B7A);

  // ---- Appointment history -------------------------------------------------
  // The stripe down the side of a row on the patient's history list. One
  // colour per action, so the trail can be read at a glance without reading
  // the words. Deliberately not pure red/yellow/green: a pure yellow is
  // unreadable on the light background, and these three still keep their
  // meaning for the most common kinds of colour blindness because they differ
  // in lightness as well as hue.
  ///A new booking.
  static const Color historyBooked = Color(0xFF2E9E4F);
  ///An appointment moved to another date.
  static const Color historyRescheduled = Color(0xFFE0A200);
  ///An appointment called off.
  static const Color historyCancelled = Color(0xFFD32F2F);

  // ---- Health metric status (reserved) -------------------------------------
  // The four states a reading can be in on the Health Dashboard. These are a
  // RESERVED set: they mean good/warning/serious/critical and are never used
  // as ordinary decoration or as "another green", because a colour that
  // sometimes means "your blood sugar is fine" and sometimes means "this row is
  // selected" means nothing at all.
  //
  // They are deliberately NOT [logoGreen] and [historyCancelled]. Those belong
  // to the app's own identity and to appointment history; borrowing them here
  // would tie a clinical judgement to an unrelated screen's palette, so a
  // restyle of one would silently restyle the other.
  //
  // Measured against the white metric cards: statusGood 3.35:1 and
  // statusCritical 4.80:1 clear 3:1, but statusWarning is 1.83:1 and
  // statusSerious 2.64:1 - both below it, and no rearranging of the palette
  // fixes that while keeping amber recognisably amber. So the rule this screen
  // follows without exception is that **a status is never colour alone**: every
  // one is drawn with an icon and a word beside it ("Above normal", "High"),
  // and the colour only reinforces what is already written. Anything that shows
  // a status must keep that pairing.
  ///In the normal range.
  static const Color statusGood = Color(0xFF0CA30C);
  ///Outside the normal range, but not alarming - "Elevated", "Overweight".
  static const Color statusWarning = Color(0xFFFAB219);
  ///Well outside the normal range.
  static const Color statusSerious = Color(0xFFEC835A);
  ///Far outside, or dangerous in itself - a low blood sugar, a stage 2 pressure.
  static const Color statusCritical = Color(0xFFD03B3B);
  ///Nothing has been recorded, so there is nothing to judge.
  static const Color statusUnknown = Color(0xFF9AA5B1);
}
