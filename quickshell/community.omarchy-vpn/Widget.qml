import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "community.omarchy-vpn"
  ipcTarget: "community.omarchy-vpn"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property bool connected: false
  property bool killSwitch: false
  property bool autoConnect: false
  property bool busy: false
  property string location: "Disconnected"
  property string profile: ""
  property string errorText: ""
  property string actionText: ""
  property string query: ""
  property var locations: []

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color accent: Color.accent
  readonly property color connectedColor: "#b8e36b"
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string icon: killSwitch ? "󰌾" : "󰒘"
  readonly property string tooltip: connected
    ? "VPN connected: " + location + (killSwitch ? "\nKill switch active" : "")
    : "VPN disconnected" + (killSwitch ? "\nKill switch active" : "")
  readonly property var filteredLocations: {
    var needle = query.trim().toLowerCase()
    if (!needle) return locations
    return locations.filter(function(row) {
      return (row.city + " " + row.country + " " + row.profile).toLowerCase().indexOf(needle) !== -1
    })
  }

  function refresh() {
    if (!statusProcess.running) statusProcess.running = true
    if (opened && !locationsProcess.running) locationsProcess.running = true
  }

  function runAction(args, label) {
    if (busy) return
    busy = true
    errorText = ""
    actionText = label
    actionProcess.errorOutput = ""
    actionProcess.command = ["/usr/local/lib/omarchy-vpn/vpn-client"].concat(args)
    actionProcess.running = true
  }

  onOpenedChanged: {
    if (opened) {
      query = ""
      refresh()
      Qt.callLater(function() { search.forceActiveFocus() })
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    fontSize: Math.max(10, (Style.bar.iconFont))
    foreground: root.connected ? root.connectedColor : root.urgent
    tooltipText: root.tooltip
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton)
        root.runAction([root.connected ? "disconnect" : "auto"], root.connected ? "Disconnecting…" : "Connecting…")
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: search
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(590))

    Column {
      id: content
      width: parent.width
      spacing: Style.space(12)

      PanelHero {
        id: hero
        width: parent.width
        title: root.connected ? root.location : "WireGuard VPN"
        meta: root.busy ? root.actionText : (root.connected ? "Encrypted connection active" : "VPN is disconnected")
        detail: root.connected ? root.profile.toUpperCase() : ""
        foreground: root.foreground
        fontFamily: root.fontFamily
        iconOpacity: root.connected ? 1.0 : 0.55
        iconComponent: Component {
          Text {
            text: root.icon
            color: root.connected ? root.connectedColor : root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
          }
        }
        trailingControl: Component {
          ToggleSwitch {
            checked: root.connected
            busy: root.busy
            foreground: hero.foreground
            accent: root.accent
            onToggled: root.runAction([root.connected ? "disconnect" : "auto"], root.connected ? "Disconnecting…" : "Connecting…")
          }
        }
      }

      Text {
        visible: root.errorText !== ""
        width: parent.width
        text: root.errorText
        color: root.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        wrapMode: Text.WordWrap
      }

      PanelSeparator { foreground: root.foreground }

      Column {
        width: parent.width
        spacing: Style.space(8)

        PanelSectionHeader {
          text: "CONNECTION PROTECTION"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        SettingRow {
          width: parent.width
          title: "AUTO-CONNECT"
          subtitle: "Resume the latest location on startup"
          checked: root.autoConnect
          onToggled: root.runAction(["set-autoconnect", root.autoConnect ? "off" : "on"], "Updating auto-connect…")
        }

        SettingRow {
          width: parent.width
          title: "KILL SWITCH"
          subtitle: "Block traffic outside the VPN tunnel"
          checked: root.killSwitch
          onToggled: root.runAction(["set-killswitch", root.killSwitch ? "off" : "on"], "Updating kill switch…")
        }
      }

      PanelSeparator { foreground: root.foreground }

      Column {
        width: parent.width
        spacing: Style.space(8)

        PanelSectionHeader {
          text: "VPN LOCATIONS"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        TextField {
          id: search
          width: parent.width
          foreground: root.foreground
          placeholderText: "Search city or country"
          text: root.query
          onTextChanged: root.query = text
          Keys.onEscapePressed: root.close()
        }

        Flickable {
          width: parent.width
          height: Math.min(locationColumn.implicitHeight, Style.space(300))
          contentWidth: width
          contentHeight: locationColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          flickableDirection: Flickable.VerticalFlick
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          Column {
            id: locationColumn
            width: parent.width
            spacing: Style.space(4)

            Text {
              visible: root.filteredLocations.length === 0
              width: parent.width
              text: "No matching locations"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(12)
            }

            Repeater {
              model: root.filteredLocations
              LocationRow {
                required property var modelData
                width: locationColumn.width
                row: modelData
              }
            }
          }
        }
      }
    }
  }

  Process {
    id: statusProcess
    command: ["omarchy-vpn", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var state = JSON.parse(text)
          root.connected = state.connected === true
          root.killSwitch = state.killswitch === true
          root.autoConnect = state.autoconnect === true
          root.location = state.location || "Disconnected"
          root.profile = state.profile || ""
        } catch (error) {
          root.errorText = "VPN status is unavailable"
        }
      }
    }
  }

  Process {
    id: locationsProcess
    command: ["omarchy-vpn", "locations"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { root.locations = JSON.parse(text) }
        catch (error) { root.errorText = "VPN locations are unavailable" }
      }
    }
  }

  Process {
    id: actionProcess
    property string errorOutput: ""
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: actionProcess.errorOutput = text.trim() }
    onExited: function(exitCode) {
      root.busy = false
      root.errorText = exitCode === 0 ? "" : (errorOutput || "VPN action failed")
      refreshDelay.restart()
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer { id: refreshDelay; interval: 350; onTriggered: root.refresh() }

  component SettingRow: CursorSurface {
    id: settingRow
    property string title: ""
    property string subtitle: ""
    property bool checked: false
    signal toggled()
    foreground: root.foreground
    implicitHeight: settingContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      enabled: !root.busy
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: settingRow.toggled()
      onContainsMouseChanged: settingRow.hasCursor = containsMouse
    }

    Row {
      id: settingContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(4)

      Column {
        width: parent.width - settingSwitch.implicitWidth
        spacing: Style.space(1)
        Text { width: parent.width; text: settingRow.title; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
        Text { width: parent.width; text: settingRow.subtitle; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
      }

      ToggleSwitch {
        id: settingSwitch
        checked: settingRow.checked
        busy: root.busy
        interactive: false
        foreground: root.foreground
        accent: root.accent
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }

  component LocationRow: CursorSurface {
    id: locationRow
    required property var row
    current: row.current === true
    foreground: root.foreground
    implicitHeight: locationContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      enabled: !root.busy
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: locationRow.hasCursor = containsMouse
      onClicked: root.runAction(["connect", row.profile], "Connecting to " + row.city + "…")
    }

    Row {
      id: locationContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(10)

      Text { text: locationRow.row.flag; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.heading; anchors.verticalCenter: parent.verticalCenter }

      Column {
        width: parent.width - parent.children[0].implicitWidth - stateText.implicitWidth - parent.spacing * 2
        spacing: Style.space(1)
        Text { width: parent.width; text: locationRow.row.city; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; elide: Text.ElideRight }
        Text { width: parent.width; text: locationRow.row.country; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption; elide: Text.ElideRight }
      }

      Text {
        id: stateText
        text: locationRow.row.current ? "CONNECTED" : (locationRow.row.stale ? "STALE" : (locationRow.row.recent ? "RECENT" : ""))
        color: locationRow.row.stale ? root.urgent : (locationRow.row.current ? root.connectedColor : root.dim)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
