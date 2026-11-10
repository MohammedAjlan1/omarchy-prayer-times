// Pure helpers for the prayer-times widget, kept out of QML so they can be
// tested with node (see tests/model.test.js).

function isInt(v) {
  return typeof v === "number" && isFinite(v) && Math.floor(v) === v
}

// The script's hijri object ({day, month, year}) when every part is in range,
// otherwise null (the widget then simply hides the date).
function validHijri(h) {
  if (!h || typeof h !== "object") return null
  if (!isInt(h.day) || h.day < 1 || h.day > 30) return null
  if (!isInt(h.month) || h.month < 1 || h.month > 12) return null
  if (!isInt(h.year) || h.year < 1300 || h.year > 1700) return null
  return { day: h.day, month: h.month, year: h.year }
}

// "30 Jumada al-Awwal 1448 AH". `fmt` writes numbers in the user's digits.
function hijriText(h, monthName, fmt, suffix) {
  var v = validHijri(h)
  if (!v) return ""
  return fmt(v.day) + " " + monthName + " " + fmt(v.year) + " " + suffix
}

// On Fridays the Dhuhr slot is the Jumu'ah prayer.
function isJumuah(report, name) {
  return !!report && report.friday === true && name === "Dhuhr"
}

// True when the Jumu'ah reminder window has opened for the report's day (it
// runs from `leadMinutes` before Dhuhr until Dhuhr) and the reminder has not
// already been asked for that day. The script only offers a jumuah entry on a
// Friday, for today's own times.
function jumuahDue(report, nowMs, askedFor) {
  var j = report ? report.jumuah : null
  if (!j || !isInt(j.epoch) || !isInt(j.leadMinutes)) return false
  if (typeof report.date !== "string" || report.date === askedFor) return false
  return nowMs >= (j.epoch - j.leadMinutes * 60) * 1000 && nowMs < j.epoch * 1000
}

if (typeof module !== "undefined") {
  module.exports = { validHijri: validHijri, hijriText: hijriText, isJumuah: isJumuah, jumuahDue: jumuahDue }
}
