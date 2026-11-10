import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Prayer times: a bar label showing the next prayer and a countdown, and a
// popup with the day's timetable. Colors come from the Omarchy theme
// (Commons.Color), so the widget follows theme changes live.
//
// Data comes from the prayer-times script beside this file (`--json`), which
// fetches from the Aladhan API at most about twice a day and caches the
// result. Everything it returns is validated here and drawn as plain text.
Panel {
  id: root
  moduleName: "moha.prayer"
  ipcTarget: "moha.prayer"
  manageIpc: false

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  // nf-md-mosque_outline (U+F1827) as a UTF-16 pair.
  readonly property string iconGlyph: "\uDB86\uDC27"
  readonly property string scriptPath: String(Qt.resolvedUrl("prayer-times")).replace(/^file:\/\//, "")

  // ---- Theme. The bar's own colors for the bar label, the popup tokens for
  //      the popup, so both track whatever theme is active.
  readonly property color textColor: Commons.Color.popups.text
  readonly property color dimColor: Qt.darker(textColor, 1.5)
  readonly property color accentColor: Commons.Color.accent
  readonly property color urgentColor: Commons.Color.bar.active
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ---- Data
  property var report: null        // last good answer from the script
  property string errorText: ""
  property double nowMs: Date.now()

  readonly property var nextPrayer: report ? report.next : null
  readonly property var prayers: report ? report.prayers : []
  readonly property int remainingMinutes: nextPrayer
    ? Math.max(0, Math.ceil((nextPrayer.epoch * 1000 - nowMs) / 60000)) : 0
  readonly property bool imminent: !!report && report.alertMinutes > 0 && remainingMinutes <= report.alertMinutes

  function prayerName(name) {
    // On Fridays the Dhuhr slot is the Jumu'ah prayer.
    return strings.t(Model.isJumuah(report, name) ? "prayer.Jumuah" : "prayer." + name, name)
  }

  // Hijri date of the listed day, from the Umm al-Qura calendar by default
  // (see HIJRI_CALENDAR in prayer.conf). Hidden when the script sent none.
  readonly property var hijri: report ? Model.validHijri(report.hijri) : null
  readonly property string hijriLine: hijri
    ? Model.hijriText(hijri, strings.t("hijri.month." + hijri.month), Commons.I18n.formatNumber, strings.t("hijri.suffix"))
    : ""

  function countdownText(minutes) {
    var hours = Math.floor(minutes / 60)
    var rest = minutes % 60
    var fmt = Commons.I18n.formatNumber
    return hours > 0
      ? strings.t("countdown.hm").arg(fmt(hours)).arg(fmt(rest))
      : strings.t("countdown.m").arg(fmt(rest))
  }

  readonly property string nextTimeText: nextPrayer ? (report.approx ? "~" : "") + nextPrayer.time : ""
  readonly property string labelText: nextPrayer
    ? prayerName(nextPrayer.name) + " " + nextTimeText + " · " + countdownText(remainingMinutes)
    : ""

  function applyReport(raw) {
    var data = null
    try { data = JSON.parse(String(raw || "").trim().split("\n").pop()) } catch (e) { data = null }

    var valid = data && data.ok === true && data.next
      && typeof data.next.epoch === "number" && typeof data.next.name === "string" && typeof data.next.time === "string"
      && Array.isArray(data.prayers) && data.prayers.length > 0 && data.prayers.length <= 8
    if (valid) {
      for (var i = 0; i < data.prayers.length; i++) {
        var p = data.prayers[i]
        if (!p || typeof p.name !== "string" || typeof p.time !== "string" || typeof p.epoch !== "number") { valid = false; break }
      }
    }

    if (!valid) {
      errorText = data && typeof data.error === "string" ? data.error.slice(0, 200) : strings.t("error.generic")
      // Keep the last good answer only while it is still ahead of us.
      if (root.report && root.report.next.epoch * 1000 < Date.now()) root.report = null
      return
    }
    errorText = ""
    root.nowMs = Date.now()
    root.report = data
    root.maybeRemindJumuah()
  }

  // Friday reminder before Dhuhr. The script decides whether it is really due
  // and sends the notification at most once per day; this only asks when the
  // window has opened, once per day.
  property string jumuahAskedFor: ""

  function maybeRemindJumuah() {
    if (!Model.jumuahDue(root.report, Date.now(), root.jumuahAskedFor)) return
    root.jumuahAskedFor = root.report.date
    if (!jumuahProc.running) jumuahProc.running = true
  }

  function refresh() {
    if (!backend.running) backend.running = true
  }

  // Forget cached times and location, then read again.
  function forceRefresh() {
    if (!resetProc.running) resetProc.running = true
  }

  Process {
    id: backend
    command: ["bash", root.scriptPath, "--json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyReport(text)
    }
  }

  Process {
    id: jumuahProc
    command: ["bash", root.scriptPath, "--jumuah"]
  }

  Process {
    id: resetProc
    command: ["bash", root.scriptPath, "--refresh"]
    onExited: root.refresh()
  }

  // Keeps the countdown honest, and reads again once the next prayer arrives.
  Timer {
    interval: 20000
    running: true
    repeat: true
    onTriggered: {
      root.nowMs = Date.now()
      if (!root.report || root.nowMs >= root.nextPrayer.epoch * 1000) root.refresh()
      root.maybeRemindJumuah()
    }
  }

  Timer {
    interval: 15 * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // ---- Panel lifecycle. Written out in full rather than inherited, so every
  //      way in (click, Super+Ctrl+P, IPC) takes the same path.
  function open() {
    root.nowMs = Date.now()
    root.controller.show()
    root.refresh()
    // After showing: showing hands the popout over, and the panel it closes
    // clears the shared flag on its way out.
    Qt.callLater(function() {
      if (root.opened && root.bar) root.bar.setCenterHoverRevealSuppressed(true)
    })
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    if (root.bar) root.bar.setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  ShellIpc {
    target: root.ipcTarget

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.forceRefresh() }
  }

  // ---- Bar label
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical || root.labelText === "" ? root.iconGlyph : root.iconGlyph + "  " + root.labelText
    active: root.imminent
    horizontalMargin: 8.75
    verticalPadding: 8.75
    tooltipText: strings.t("tooltip")
    pressFeedbackButtons: Qt.NoButton

    onPressed: function(b) {
      if (b === Qt.RightButton) root.forceRefresh()
      else root.toggle()
    }
  }

  // ---- Popup: a small card. Header (next prayer, time, countdown), the day's
  //      six times as slim rows, and one footer line.
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    padding: Style.space(10)
    contentWidth: panel.fittedContentWidth(Style.space(260))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) { if (t.toLowerCase() === "r") root.forceRefresh() }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(8)

        // ---- Header
        Column {
          visible: !!root.report
          width: parent.width
          spacing: Style.space(2)

          // Prayer name on the left, place on the right.
          Item {
            width: parent.width
            height: Math.max(nameRow.height, placeText.height)

            Row {
              id: nameRow
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: root.iconGlyph
                color: root.accentColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: root.nextPrayer ? root.prayerName(root.nextPrayer.name).toUpperCase() : ""
                color: root.accentColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                font.letterSpacing: 1
              }
            }

            Text {
              id: placeText
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              width: Math.min(implicitWidth, Style.space(110))
              textFormat: Text.PlainText
              elide: Text.ElideRight
              horizontalAlignment: Text.AlignRight
              text: (root.report ? root.report.place : "").toUpperCase()
              color: root.dimColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.letterSpacing: 1
            }
          }

          // Time on the left, countdown on the right.
          Item {
            width: parent.width
            height: timeText.height

            Text {
              id: timeText
              anchors.left: parent.left
              anchors.leftMargin: Style.space(8)
              textFormat: Text.PlainText
              text: root.nextTimeText
              color: root.textColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              font.bold: true
            }
            Text {
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.baseline: timeText.baseline
              textFormat: Text.PlainText
              text: root.nextPrayer ? strings.t("countdown.in").arg(root.countdownText(root.remainingMinutes)) : ""
              color: root.imminent ? root.urgentColor : root.dimColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
          }
        }

        Rectangle {
          visible: !!root.report
          width: parent.width
          height: Style.spacing.hairline
          color: root.textColor
          opacity: 0.12
        }

        // ---- The day's times. The next prayer is picked out in the accent
        //      color, ones already past are dimmed.
        Column {
          visible: !!root.report
          width: parent.width
          spacing: 0

          Repeater {
            model: root.prayers

            Rectangle {
              required property var modelData
              required property int index
              readonly property bool isNext: !!root.nextPrayer && modelData.name === root.nextPrayer.name
              readonly property bool passed: !isNext && modelData.epoch * 1000 < root.nowMs
              readonly property color rowColor: isNext ? root.accentColor
                : (passed || modelData.prayer === false ? root.dimColor : root.textColor)

              width: parent.width
              height: Style.space(24)
              radius: Style.cornerRadius
              color: isNext ? Style.selectedAccentFill : "transparent"

              Rectangle {
                visible: parent.isNext
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(3)
                height: parent.height * 0.6
                radius: width / 2
                color: root.accentColor
              }

              Text {
                anchors.left: parent.left
                anchors.leftMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: root.prayerName(modelData.name)
                color: parent.rowColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: parent.isNext
              }

              Text {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: modelData.time
                color: parent.rowColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: parent.isNext
              }
            }
          }
        }

        // ---- Footer: Hijri date (with "Tomorrow" when the list is tomorrow's).
        Text {
          visible: !!root.report && text !== ""
          width: parent.width
          textFormat: Text.PlainText
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideRight
          text: {
            var parts = []
            if (root.report && root.report.tomorrow) parts.push(strings.t("tomorrow"))
            if (root.hijriLine !== "") parts.push(root.hijriLine)
            return parts.join(" · ")
          }
          color: root.dimColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        // ---- Loading / error
        Text {
          visible: !root.report
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
          text: root.errorText !== "" ? root.errorText : strings.t("loading")
          color: root.errorText !== "" ? root.urgentColor : root.dimColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.italic: root.errorText === ""
        }
      }
    }
  }
}
