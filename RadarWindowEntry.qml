import QtQuick
import "./radar/ui"

// Skywatch full radar window, summoned from the ⤢ expand button in the panel
// (and scriptable via `omarchy shell shell toggle dchristensen8.skywatch`).
RadarWindow {
    session: PluginSession
}