import QtQuick
import Quickshell
import "./radar/ui"

// Skywatch radar section.
//
// The interactive radar is Omastorm's popover UI (MIT, Wes Grimes,
// https://github.com/wesleygrimes/omastorm), vendored into radar/ so Skywatch
// is self-contained: no separate Omastorm install is required, and updates to
// Skywatch carry the radar UI with them. The shared PluginSession singleton
// keeps the weather panel and radar on one engine connection, config, and
// remembered view.
//
// Location sync (two-way, weather.json is the shared source of truth):
//   - Weather -> radar: when the weather location changes, the radar moves
//     to that place (PluginSession.setPlace).
//   - Radar -> weather: when the user picks a place on the radar (search,
//     site picker, "my location"), the chosen place is written back to
//     weather.json so the forecast follows.
// A syncingFromWeather guard plus a deferred read (Qt.callLater) prevent echo
// loops and the transient where setPlace updates placeName before center.

Item {
  id: root
  signal expandRequested()
  signal closeRequested()

  width: parent ? parent.width : 0
  implicitHeight: radar.implicitHeight

  property bool syncingFromWeather: false

  // ---- weather -> radar ---------------------------------------------------
  Connections {
    target: PluginSession.config
    function onLocationChanged() {
      if (root.syncingFromWeather) return
      var loc = PluginSession.config.location
      if (!loc || !PluginSession.initialized || !PluginSession.hasView) return
      // Already centered there? Don't fight panning.
      if (Math.abs(PluginSession.centerLat - loc.lat) < 1e-6
          && Math.abs(PluginSession.centerLon - loc.lon) < 1e-6) return
      root.syncingFromWeather = true
      PluginSession.setPlace(loc.lat, loc.lon, loc.name || "")
      root.syncingFromWeather = false
    }
  }

  // ---- radar -> weather ---------------------------------------------------
  // placeName only changes on an explicit pick (search, site picker, locate);
  // panning updates center/span without touching placeName, so it stays out.
  // setPlace sets placeName before center, so read the center on the next
  // tick after the change settles.
  Connections {
    target: PluginSession
    function onPlaceNameChanged() {
      if (root.syncingFromWeather) return
      Qt.callLater(root.writeBackToWeather)
    }
  }

  function writeBackToWeather() {
    var name = PluginSession.placeName
    if (!name || !PluginSession.hasView) return
    var lat = PluginSession.centerLat
    var lon = PluginSession.centerLon
    if (!isFinite(lat) || !isFinite(lon)) return
    // Already the weather location? Nothing to write back.
    var wl = PluginSession.config.location
    if (wl && Math.abs(wl.lat - lat) < 1e-6 && Math.abs(wl.lon - lon) < 1e-6) return
    Quickshell.execDetached(["omarchy-weather-location", "--set", name, String(lat) + "," + String(lon)])
  }

  Popover {
    id: radar
    anchors.fill: parent
    session: PluginSession
    onExpandRequested: root.expandRequested()
    onCloseRequested: root.closeRequested()
  }
}