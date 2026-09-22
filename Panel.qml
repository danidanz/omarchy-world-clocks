import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Timezones.js" as TZ

Panel {
  id: root
  moduleName: "danidanz.world-clocks"
  ipcTarget: "danidanz.world-clocks"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  readonly property var cities: {
    var v = setting("cities", ["Asia/Jakarta"]);
    if (!v || !v.length) return ["Asia/Jakarta"];
    var list = [];
    for (var i = 0; i < v.length && list.length < 5; i++)
      if (list.indexOf(v[i]) === -1) list.push(String(v[i]));
    return list.length ? list : ["Asia/Jakarta"];
  }
  readonly property string timeFormat: String(setting("timeFormat", "24h"))
  readonly property bool showSeconds: setting("showSeconds", false) === true
  readonly property bool full: cities.length >= 5
  property var offsets: ({})
  property double tick: Date.now()
  readonly property string clockPath: Qt.resolvedUrl("clockdata").toString().replace(/^file:\/\//, "")

  function fmt(zone, withSec) {
    var o = offsets[zone];
    if (!o || o.offset === undefined) return "--:--";
    var d = new Date(tick + o.offset * 1000);
    function p(n) { return (n < 10 ? "0" : "") + n; }
    var h = d.getUTCHours(), m = d.getUTCMinutes(), s = d.getUTCSeconds();
    var sec = (withSec === undefined ? showSeconds : withSec) ? ":" + p(s) : "";
    if (timeFormat === "12h") {
      var ap = h >= 12 ? "PM" : "AM", h12 = h % 12;
      if (h12 === 0) h12 = 12;
      return h12 + ":" + p(m) + sec + ap;
    }
    return p(h) + ":" + p(m) + sec;
  }

  function persistSettings(values) {
    var entry = { id: root.moduleName };
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k];
    for (var key in values) entry[key] = values[key];
    root.settings = entry;
    if (root.hostWidget && "settings" in root.hostWidget) root.hostWidget.settings = entry;
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry);
  }

  function addZone(zone) {
    zone = String(zone || "");
    if (!zone || cities.indexOf(zone) !== -1 || full) return;
    var list = cities.slice();
    list.push(zone);
    persistSettings({ cities: list });
    refreshOffsets();
  }

  function removeZone(zone) {
    var list = [];
    for (var i = 0; i < cities.length; i++)
      if (cities[i] !== zone) list.push(cities[i]);
    if (!list.length) list = ["Asia/Jakarta"];
    persistSettings({ cities: list });
    refreshOffsets();
  }

  function refreshOffsets() {
    if (clockProc.running || cities.length === 0) return;
    clockProc.command = [clockPath].concat(cities);
    clockProc.running = true;
  }
  function refresh() { refreshOffsets(); }
  onCitiesChanged: { refreshOffsets(); rebuildOptions(); }
  Component.onCompleted: { refreshOffsets(); rebuildOptions(); }

  SystemClock { precision: SystemClock.Seconds; onDateChanged: root.tick = date.getTime() }
  Timer { interval: 60000; running: true; repeat: true; onTriggered: root.refreshOffsets() }
  Process {
    id: clockProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(String(text || "{}"));
          if (data.zones) root.offsets = data.zones;
        } catch (e) {}
      }
    }
  }

  property var zoneOptions: []
  function rebuildOptions() {
    var out = [];
    for (var i = 0; i < TZ.zones.length; i++) {
      var z = TZ.zones[i].value;
      if (cities.indexOf(z) !== -1) continue;
      out.push({ value: z, label: TZ.labelOf(z), description: z });
    }
    zoneOptions = out;
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: content
        width: parent.width
        spacing: Style.space(10)

        Text {
          textFormat: Text.PlainText
          text: "WORLD CLOCKS  " + root.cities.length + " / 5"
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.space(11)
          font.bold: true
          font.letterSpacing: Style.space(2)
        }

        PanelSeparator { foreground: Color.popups.text }

        Column {
          width: parent.width
          spacing: Style.space(4)

          Repeater {
            model: root.cities
            delegate: Row {
              required property string modelData
              width: parent.width
              height: Math.max(code.implicitHeight, time.implicitHeight) + Style.space(8)
              spacing: Style.space(8)

              Text {
                id: code
                textFormat: Text.PlainText
                width: Style.space(44)
                text: TZ.shortCode(modelData)
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.space(13)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
              Column {
                width: parent.width - code.width - time.width - rm.width - parent.spacing * 3
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  text: TZ.cityOf(modelData)
                  color: Color.popups.text
                  font.family: Style.font.family
                  font.pixelSize: Style.font.body
                  elide: Text.ElideRight
                }
                Text {
                  textFormat: Text.PlainText
                  width: parent.width
                  text: modelData
                  color: Color.muted
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }
              Text {
                id: time
                textFormat: Text.PlainText
                text: root.fmt(modelData, true)
                color: Color.popups.text
                font.family: Style.font.family
                font.pixelSize: Style.space(15)
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
              Button {
                id: rm
                text: "✕"
                foreground: Color.popups.text
                background: Color.popups.background
                accent: Color.accent
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.removeZone(modelData)
              }
            }
          }
        }

        PanelSeparator { foreground: Color.popups.text }

        SearchableDropdown {
          width: parent.width
          visible: !root.full
          label: "Add city"
          placeholderText: "Search 598 timezones..."
          emptyText: "No matching timezone"
          options: root.zoneOptions
          foreground: Color.popups.text
          background: Color.popups.background
          fontFamily: Style.font.family
          onChanged: function(v) { root.addZone(v); }
        }
        Text {
          visible: root.full
          textFormat: Text.PlainText
          text: "Max 5 reached — remove one to add another."
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.body
        }

        ButtonGroup {
          options: [{ value: "24h", label: "24h" }, { value: "12h", label: "12h" }]
          value: root.timeFormat
          foreground: Color.popups.text
          background: Color.popups.background
          accent: Color.accent
          onChanged: function(v) { root.persistSettings({ timeFormat: v }); }
        }
      }
    }
  }
}
