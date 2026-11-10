// Run with: node tests/model.test.js
const assert = require("node:assert/strict")
const M = require("../Model.js")

const plain = (n) => String(n)
const arabicDigits = (n) => String(n).replace(/[0-9]/g, (d) => String.fromCharCode(0x660 + Number(d)))

// validHijri
assert.deepEqual(M.validHijri({ day: 30, month: 5, year: 1448 }), { day: 30, month: 5, year: 1448 })
for (const bad of [null, undefined, "x", {}, { day: 0, month: 1, year: 1448 }, { day: 31, month: 1, year: 1448 },
  { day: 1, month: 13, year: 1448 }, { day: 1, month: 1, year: 1299 }, { day: 1, month: 1, year: 1701 },
  { day: "1", month: 1, year: 1448 }, { day: 1.5, month: 1, year: 1448 }]) {
  assert.equal(M.validHijri(bad), null, JSON.stringify(bad))
}

// hijriText
assert.equal(M.hijriText({ day: 30, month: 5, year: 1448 }, "Jumada al-Awwal", plain, "AH"), "30 Jumada al-Awwal 1448 AH")
assert.equal(M.hijriText({ day: 3, month: 6, year: 1448 }, "X", arabicDigits, "هـ"), "٣ X ١٤٤٨ هـ")
assert.equal(M.hijriText(null, "X", plain, "AH"), "")
assert.equal(M.hijriText({ day: 99, month: 6, year: 1448 }, "X", plain, "AH"), "")

// isJumuah
assert.equal(M.isJumuah({ friday: true }, "Dhuhr"), true)
assert.equal(M.isJumuah({ friday: true }, "Asr"), false)
assert.equal(M.isJumuah({ friday: false }, "Dhuhr"), false)
assert.equal(M.isJumuah(null, "Dhuhr"), false)

// jumuahDue: Dhuhr at epoch 10000s, 30 minute lead => window [8200s, 10000s)
const report = { date: "2026-11-13", jumuah: { epoch: 10000, leadMinutes: 30 } }
const at = (s) => s * 1000
assert.equal(M.jumuahDue(report, at(8199), ""), false, "before window")
assert.equal(M.jumuahDue(report, at(8200), ""), true, "window opens")
assert.equal(M.jumuahDue(report, at(9999), ""), true, "last second")
assert.equal(M.jumuahDue(report, at(10000), ""), false, "Dhuhr itself is too late")
assert.equal(M.jumuahDue(report, at(9000), "2026-11-13"), false, "already asked today")
assert.equal(M.jumuahDue(report, at(9000), "2026-11-06"), true, "asked last week only")
assert.equal(M.jumuahDue({ date: "2026-11-12", jumuah: null }, at(9000), ""), false, "not a Friday")
assert.equal(M.jumuahDue(null, at(9000), ""), false)
assert.equal(M.jumuahDue({ date: "d", jumuah: { epoch: "x", leadMinutes: 30 } }, at(9000), ""), false, "malformed")
assert.equal(M.jumuahDue({ jumuah: { epoch: 10000, leadMinutes: 30 } }, at(9000), ""), false, "missing date")

console.log("model tests passed")
