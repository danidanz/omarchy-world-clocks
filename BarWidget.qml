import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Timezones.js" as TZ

BarWidget {
  id: root
  moduleName: "danidanz.world-clocks"

  readonly property var cities: boundedCities()
  readonly property string timeFormat: String(setting("timeFormat", "24h"))
  readonly property bool showSeconds: setting("showSeconds", false) === true
  readonly property int rotateIntervalSec: intSetting("rotateIntervalSec", 5)
  property var offsets: ({})
  property double tick: Date.now()
  property int currentIndex: 0
  readonly property string clockPath: Qt.resolvedUrl("clockdata").toString().replace(/^file:\/\//, "")

  function intSetting(name, dflt) {
    var n = parseInt(String(setting(name, dflt)), 10);
    return isFinite(n) ? n : dflt;
  }

  function boundedCities() {
    var v = setting("cities", ["Asia/Jakarta"]);
    if (!v || !v.length) return ["Asia/Jakarta"];
    var list = [];
    for (var i = 0; i < v.length && list.length < 5; i++)
      if (list.indexOf(v[i]) === -1) list.push(String(v[i]));
    return list.length ? list : ["Asia/Jakarta"];
  }

  function fmt(zone) {
    var o = offsets[zone];
    if (!o || o.offset === undefined) return "--:--";
    var d = new Date(tick + o.offset * 1000);
    function p(n) { return (n < 10 ? "0" : "") + n; }
    var h = d.getUTCHours(), m = d.getUTCMinutes(), s = d.getUTCSeconds();
    if (timeFormat === "12h") {
      var ap = h >= 12 ? "PM" : "AM", h12 = h % 12;
      if (h12 === 0) h12 = 12;
      return h12 + ":" + p(m) + (showSeconds ? ":" + p(s) : "") + ap;
    }
    return p(h) + ":" + p(m) + (showSeconds ? ":" + p(s) : "");
  }

  readonly property bool rotationActive: cities.length > 1 && rotateIntervalSec > 0 && !vertical && !opened
  readonly property string currentZone: cities.length ? cities[currentIndex % cities.length] : "Asia/Jakarta"
  readonly property string pillText: TZ.shortCode(currentZone) + " " + fmt(currentZone)
  readonly property string tipText: {
    var lines = [];
    for (var i = 0; i < cities.length; i++)
      lines.push(TZ.shortCode(cities[i]) + " " + fmt(cities[i]) + "  " + TZ.cityOf(cities[i]));
    return lines.join("\n");
  }

  function advanceIndex() {
    if (cities.length < 2) return;
    currentIndex = (currentIndex + 1) % cities.length;
  }

  function refreshOffsets() {
    if (clockProc.running || cities.length === 0) return;
    clockProc.command = [clockPath].concat(cities);
    clockProc.running = true;
  }
  function refresh() { refreshOffsets(); }
  onCitiesChanged: {
    if (currentIndex >= cities.length) currentIndex = 0;
    refreshOffsets();
  }
  Component.onCompleted: refreshOffsets()
  SystemClock { precision: SystemClock.Seconds; onDateChanged: root.tick = date.getTime() }
  Timer { interval: 60000; running: true; repeat: true; onTriggered: root.refreshOffsets() }
  Timer {
    id: rotateTimer
    interval: Math.max(1, root.rotateIntervalSec) * 1000
    running: root.rotationActive
    repeat: true
    onTriggered: {
      if (!root.rotationActive || slideAnim.running) return;
      slideAnim.restart();
    }
  }
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

  function injectPanel() {
    var t = panelLoader.item;
    if (!t) return;
    if ("bar" in t) t.bar = root.bar;
    if ("settings" in t) t.settings = root.settings;
    if ("anchorItem" in t) t.anchorItem = button;
    if ("hostWidget" in t) t.hostWidget = root;
  }
  function togglePanel() { if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle(); }
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  function open() { if (panelLoader.item && panelLoader.item.open) panelLoader.item.open(); }
  function close() { if (panelLoader.item && panelLoader.item.close) panelLoader.item.close(); }
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch(); }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: { root.injectPanel(); Qt.callLater(root.injectPanel); }
  }

  TextMetrics {
    id: pillMetrics
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.bar.iconFont
    text: root.vertical ? "" : root.pillText
  }

  SequentialAnimation {
    id: slideAnim
    ParallelAnimation {
      NumberAnimation { target: slideTrans; property: "y"; to: -14; duration: 150; easing.type: Easing.InCubic }
      NumberAnimation { target: slideText; property: "opacity"; to: 0; duration: 150 }
    }
    ScriptAction { script: root.advanceIndex(); }
    PropertyAction { target: slideTrans; property: "y"; value: 14 }
    ParallelAnimation {
      NumberAnimation { target: slideTrans; property: "y"; to: 0; duration: 200; easing.type: Easing.OutCubic }
      NumberAnimation { target: slideText; property: "opacity"; to: 1; duration: 200 }
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: " "
    labelVisible: false
    slotSize: root.vertical ? Style.bar.iconSlot
      : Math.max(Style.bar.statusSlot, Math.ceil(pillMetrics.width) + Style.space(9))
    opticalSize: slotSize
    tooltipText: root.tipText
    onPressed: function(b) {
      if (!root.bar) return;
      if (b === Qt.RightButton) cycleFormat();
      else root.togglePanel();
    }

    Item {
      anchors.fill: parent
      clip: true
      Text {
        id: slideText
        textFormat: Text.PlainText
        anchors.centerIn: parent
        transform: Translate { id: slideTrans; y: 0 }
        text: root.vertical ? "" : root.pillText
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.bar.iconFont
      }
    }
  }

  function cycleFormat() {
    var entry = { id: root.moduleName };
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k];
    entry.timeFormat = timeFormat === "24h" ? "12h" : "24h";
    root.settings = entry;
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry);
  }
}
