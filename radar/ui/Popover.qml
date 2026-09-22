import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "Keys.js" as KeyMap

FocusScope {
    id: card
    required property var session
    property var theme: session.theme.snapshot
    property alias engine: connection
    readonly property var state: connection.state
    readonly property var scan: state ? state.frame : null
    readonly property var frames: state ? state.timeline : []
    // One tick per frame, no gap stubs, pixel-snapped: the same strip the
    // window draws, denser.
    readonly property var slots: {
        var result = [];
        for (var j = 0; j < frames.length; j++)
            result.push({id: frames[j].id, partial: frames[j].status === "partial"});
        return result;
    }
    readonly property int currentSlot: scan ? slots.findIndex(s => s.id === scan.id) : -1
    readonly property string condition: state ? state.mode === "archived" ? "archived" : state.connection.status : "offline"
    readonly property color statusColor: condition === "stale" ? theme.yellow
        : condition === "offline" || condition === "unavailable" ? theme.red : theme.accent
    readonly property string statusText: {
        if (!state) return "OFFLINE";
        if (condition === "archived") return "ARCHIVED";
        var label = condition === "ok" ? "LIVE" : condition.toUpperCase();
        var complete = frames.filter(f => f.status === "complete");
        if (!scan || !scan.scanTime || !complete.length) return label;
        var age = Math.max(0, state.connection.ageSeconds +
            Math.round((Date.parse(complete[complete.length - 1].scanTime) - Date.parse(scan.scanTime)) / 1000));
        var minutes = Math.floor(age / 60);
        return label + " · " + (minutes < 1 ? "just now" : minutes < 60 ? minutes + " min ago"
            : minutes < 1440 ? Math.floor(minutes / 60) + "h ago" : Math.floor(minutes / 1440) + "d ago");
    }
    signal expandRequested()
    signal closeRequested()
    // True briefly while applyView() moves the camera programmatically, so a
    // settle from that move is not mistaken for a user pan (same guard the
    // full window uses).
    property bool applyingView: false
    // dBZ legend data, mirrored from the scan frame (same as the full window).
    readonly property int bands: scan ? scan.palette.length : 0
    function legendLabel(index) {
        if (!scan || !scan.bounds) return "";
        var bounds = scan.bounds;
        return index === 0 ? "<" + bounds[1] : index === bands - 1 ? bounds[index] + "+" : String(bounds[index]);
    }
    implicitWidth: 308
    // Match RadarBar's fixed KeyboardPanel contentHeight (400 − 28 inset).
    // Do not track layout.implicitHeight — time labels and status text
    // settling after open made the panel shrink and grow.
    implicitHeight: 372
    Engine { id: connection }
    function step(delta) { if (state) connection.send({type: "step", delta: delta}); }
    function play() { if (state) connection.send({type: state.playing ? "pause" : "play"}); }
    // Respect the same config keys as the window; Enter always expands.
    Shortcut { id: probe; enabled: false }
    function canon(sequence) { probe.sequence = sequence; return probe.portableText; }
    property var bindings: ({})
    function applyKeys() { bindings = KeyMap.resolve(session.config.keys, canon).bindings; }
    Component.onCompleted: applyKeys()
    Connections { target: card.session.config; function onKeysChanged() { card.applyKeys(); } }
    Instantiator {
        model: ["previous_frame", "next_frame", "play", "close"]
        delegate: Shortcut {
            required property string modelData
            sequences: card.bindings[modelData] || []
            enabled: card.visible
            onActivated: {
                if (modelData === "close") card.closeRequested();
                else if (modelData === "play") card.play();
                else card.step(modelData === "previous_frame" ? -1 : 1);
            }
        }
    }
    Keys.onReturnPressed: expandRequested()
    Keys.onEnterPressed: expandRequested()
    component Label: Text {
        color: card.theme.foreground
        font.family: card.theme.font
        font.pixelSize: 12
        elide: Text.ElideRight
    }
    component Control: Button {
        id: button
        implicitHeight: 28
        implicitWidth: Math.max(28, contentItem.implicitWidth + 12)
        padding: 5
        contentItem: Label {
            text: button.text
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            opacity: button.enabled ? 1 : .35
        }
        background: Rectangle {
            color: button.hovered || button.activeFocus ? Qt.alpha(card.theme.accent, .16) : "transparent"
            border.width: 1
            border.color: button.activeFocus ? card.theme.accent : Qt.alpha(card.theme.foreground, .22)
        }
    }
    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: card.implicitHeight
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Label { text: connection.selectedSiteId || (connection.source ? connection.source.id : "—"); font.bold: true; font.pixelSize: 14 }
            Label { Layout.fillWidth: true; text: connection.site ? connection.site.name : (connection.source ? connection.source.name : ""); opacity: .65 }
            Rectangle { width: 5; height: 5; radius: 3; color: card.statusColor }
            Label { text: card.statusText; color: card.statusColor; font.pixelSize: 11 }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 280
            color: card.theme.background
            border.color: Qt.alpha(card.theme.foreground, .17)
            clip: true
            RadarMap {
                id: map
                anchors.fill: parent
                scan: card.scan
                texture: connection.texture
                azimuthLut: connection.azimuthLut
                siteId: connection.selectedSiteId
                sourceId: connection.source ? connection.source.id : ""
                sites: connection.sites
                coverage: connection.site && connection.site.coverage ? connection.site.coverage
                    : (connection.source && connection.source.coverage ? connection.source.coverage : null)
                tileRoot: "file://" + connection.runtime
                theme: card.theme
                treatment: card.session.treatment
                weakFloor: card.session.weakFloor
                labelSize: 10
                radarOpacity: card.condition === "unavailable" ? .6 : 1
                interactive: !card.session.needsLocation
                onNavigated: (lat, lon, spanKm) => card.session.userNavigated(lat, lon, spanKm)
                // A settled pan hands the centre to the engine, which switches
                // station while following and unlocked (same as the full window);
                // without this the radar stays locked on the weather location.
                onViewSettled: (lat, lon) => {
                    if (card.session.needsLocation) return;
                    // A pick or restore already set the store; a settle still
                    // queued from the previous camera must not write that centre
                    // back (radar jumps, map stays).
                    if (card.applyingView
                        && (Math.abs(lat - card.session.centerLat) > 0.05
                            || Math.abs(lon - card.session.centerLon) > 0.05))
                        return;
                    connection.send({type: "view_center", lat: lat, lon: lon});
                    card.session.rememberView(lat, lon, map.span);
                }
                onResetRequested: card.session.resetView()
                onTilesNeeded: (z, x0, y0, x1, y1) => connection.send({type: "tiles_needed", z: z, x0: x0, y0: y0, x1: x1, y1: y1})
                function applyView() {
                    if (!card.session.hasView) return;
                    card.applyingView = true;
                    holdSpan = true;
                    lookAt(card.session.centerLat, card.session.centerLon);
                    span = card.session.span;
                    Qt.callLater(() => { holdSpan = false; });
                    Qt.callLater(() => { card.applyingView = false; });
                }
                Component.onCompleted: applyView()
            }
            Connections { target: connection; function onTileReady(tile) { map.tileReady(tile); } }
            Connections {
                target: card.session
                function onViewChanged() { map.applyView(); }
            }
            // The expand affordance: click the ⤢ in the top-right to open the
            // full window. The rest of the map stays draggable/zoomable
            // (RadarMap's own MouseArea handles pan and wheel zoom).
            Rectangle {
                anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 8
                implicitWidth: expandGlyph.implicitWidth + 12
                implicitHeight: 22
                radius: 3
                color: expandArea.containsMouse ? Qt.alpha(card.theme.accent, .22) : Qt.alpha(card.theme.background, .9)
                border.width: 1
                border.color: expandArea.containsMouse ? card.theme.accent : Qt.alpha(card.theme.foreground, .22)
                Label {
                    id: expandGlyph
                    anchors.centerIn: parent
                    text: "⤢"
                    font.pixelSize: 14
                    color: expandArea.containsMouse ? card.theme.accent : card.theme.foreground
                    opacity: expandArea.containsMouse ? 1 : .7
                }
                MouseArea {
                    id: expandArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.expandRequested()
                }
            }
            RowLayout {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
                Rectangle {
                    implicitWidth: product.implicitWidth + 10; implicitHeight: 20
                    color: Qt.alpha(card.theme.background, .92)
                    Label { id: product; anchors.centerIn: parent; font.pixelSize: 10; opacity: .8
                        text: card.scan ? card.scan.productName.toUpperCase()
                            + (card.scan.kind !== "mosaic" && card.scan.scanTime ? " " + card.scan.elevationDeg.toFixed(1) + "°" : "") : "" }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    implicitWidth: time.implicitWidth + 10; implicitHeight: 20
                    color: Qt.alpha(card.theme.background, .92)
                    Label { id: time; anchors.centerIn: parent; font.pixelSize: 10; opacity: .8
                        text: {
                            if (!card.scan || !card.scan.scanTime) return "";
                            var loc = Qt.locale(), d = new Date(card.scan.scanTime);
                            var timeFmt = loc.timeFormat(Locale.ShortFormat) + " t";
                            return card.condition === "archived"
                                ? Qt.formatDateTime(d, loc.dateFormat(Locale.ShortFormat) + " " + timeFmt)
                                : Qt.formatTime(d, timeFmt);
                        }
                    }
                }
            }
            // dBZ legend chip in the map's upper-left, with a dry→wet label above.
            Rectangle {
                anchors.top: parent.top; anchors.left: parent.left
                anchors.topMargin: 8; anchors.leftMargin: 8
                visible: card.bands > 0
                implicitWidth: Math.max(legendStrip.width, dry.implicitWidth + wet.implicitWidth + 4) + 14
                implicitHeight: 32
                color: Qt.alpha(card.theme.background, .9)
                border.color: Qt.alpha(card.theme.foreground, .22)
                radius: 3
                Column {
                    anchors.centerIn: parent
                    spacing: 3
                    Row {
                        width: legendStrip.width
                        Label { id: dry; text: "dry"; font.pixelSize: 8; opacity: .7 }
                        Item { width: legendStrip.width - dry.implicitWidth - wet.implicitWidth; height: 1 }
                        Label { id: wet; text: "wet"; font.pixelSize: 8; opacity: .7 }
                    }
                    Row {
                        id: legendStrip
                        spacing: 1
                        Repeater {
                            model: card.scan ? card.scan.palette : []
                            Rectangle {
                                required property string modelData
                                required property int index
                                width: 7; height: 10
                                color: modelData
                            }
                        }
                    }
                }
            }
            // An update is on disk but this shell still runs the old plugin;
            // the click restarts the shell (PluginSession.updatePending).
            Rectangle {
                anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 8
                visible: card.session.updatePending
                implicitWidth: updated.implicitWidth + 10; implicitHeight: 20
                color: Qt.alpha(card.theme.background, .92)
                border.color: card.theme.accent
                Label { id: updated; anchors.centerIn: parent; font.pixelSize: 10; color: card.theme.accent; text: card.session.updateNotice }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: card.session.restartShell() }
            }
            Rectangle {
                anchors.centerIn: parent
                visible: card.condition === "loading" && (!card.scan || !card.scan.scanTime) && !!card.state
                implicitWidth: popLoad.implicitWidth + 20
                implicitHeight: 24
                color: Qt.alpha(card.theme.background, .88)
                border.width: 1
                border.color: Qt.alpha(card.theme.foreground, .22)
                Label {
                    id: popLoad
                    anchors.centerIn: parent
                    text: "Loading..."
                    color: card.theme.accent
                    font.pixelSize: 10
                }
            }
            Label {
                anchors.centerIn: parent; width: parent.width - 24; wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                visible: !card.state
                text: card.session.startupError || connection.error
            }
            Rectangle {
                anchors.fill: parent
                visible: card.session.needsLocation
                color: Qt.alpha(card.theme.background, .82)
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { card.session.requestLocationPicker(); card.expandRequested(); }
                    onWheel: wheel => { wheel.accepted = true }
                }
                LocationPrompt {
                    anchors.centerIn: parent
                    width: parent.width - 32
                    session: card.session
                    theme: card.theme
                    onManualChosen: { card.session.requestLocationPicker(); card.expandRequested(); }
                }
            }
        }
        Label {
            Layout.fillWidth: true
            visible: !!connection.rejection
            text: connection.rejection; color: card.theme.accent; wrapMode: Text.Wrap
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Control { text: "‹"; Accessible.name: "Previous frame"; enabled: card.frames.length > 1; onClicked: card.step(-1) }
            Control { text: card.state && card.state.playing ? "Ⅱ" : "▷"; Accessible.name: "Play or pause"; enabled: card.frames.filter(f => f.status === "complete").length > 1; onClicked: card.play() }
            Control { text: "›"; Accessible.name: "Next frame"; enabled: card.frames.length > 1; onClicked: card.step(1) }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Item {
                    id: strip
                    Layout.fillWidth: true
                    implicitHeight: 14
                    Repeater {
                        model: card.slots
                        Rectangle {
                            required property var modelData
                            required property int index
                            readonly property bool current: index === card.currentSlot
                            x: card.slots.length > 1 ? Math.round(index * (strip.width - width) / (card.slots.length - 1)) : Math.round((strip.width - width) / 2)
                            y: Math.round((strip.height - height) / 2)
                            width: current || modelData.partial ? 3 : 2
                            height: current || modelData.partial ? 14 : 10
                            color: current ? card.theme.accent : modelData.partial ? "transparent"
                                : Qt.alpha(card.theme.foreground, .40)
                            border.width: modelData.partial && !current ? 1 : 0
                            border.color: card.theme.accent
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 12
                    Label { font.pixelSize: 10; opacity: .55; text: card.frames.length ? Qt.formatTime(new Date(card.frames[0].scanTime), Qt.locale().timeFormat(Locale.ShortFormat)) : " " }
                    Item { Layout.fillWidth: true }
                    Label { font.pixelSize: 10; opacity: .55; text: card.condition === "ok" ? "now" : card.frames.length ? Qt.formatTime(new Date(card.frames[card.frames.length - 1].scanTime), Qt.locale().timeFormat(Locale.ShortFormat)) : " " }
                }
            }
        }
        Label {
            Layout.fillWidth: true
            font.pixelSize: 8
            opacity: .5
            elide: Text.ElideRight
            text: map.osmOnScreen ? (connection.source ? connection.source.attribution : "NOAA") + " · © OpenStreetMap"
                : (connection.source ? connection.source.attribution : "NOAA") + " · Natural Earth"
        }
    }
}
