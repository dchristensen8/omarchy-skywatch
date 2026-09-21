import QtQuick
import "../com.omastorm.radar/ui"

// Skywatch radar section.
//
// The interactive radar is Omastorm's popover UI, embedded as-is with its
// shared PluginSession singleton so the weather panel and Omastorm share one
// engine connection, config, and remembered view. See README.md for credits
// and the required Omastorm install (https://github.com/wesleygrimes/omastorm).

Item {
  id: root
  signal expandRequested()
  signal closeRequested()

  width: parent ? parent.width : 0
  implicitHeight: radar.implicitHeight

  Popover {
    id: radar
    anchors.fill: parent
    session: PluginSession
    onExpandRequested: root.expandRequested()
    onCloseRequested: root.closeRequested()
  }
}