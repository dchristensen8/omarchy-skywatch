# Skywatch

Weather forecast and live interactive radar, combined into a single Omarchy Quattro bar widget.

One pill in the bar: click it to open a single panel with the **current conditions and 3-day forecast on top**, and the **interactive Omastorm radar below** — scan timeline, playback, and expand to the full radar window.

![Skywatch panel](preview.png)

## Install

Requires **Omastorm** (live radar engine + UI). Install it first:

```sh
omarchy plugin add https://github.com/wesleygrimes/omastorm.git --enable
```

Then install Skywatch:

```sh
omarchy plugin add https://github.com/dchristensen8/omarchy-skywatch.git --enable
```

The Omastorm engine binary downloads itself on first radar open (see the
[Omastorm README](https://github.com/wesleygrimes/omastorm)).

## Usage

- **Left-click** the Skywatch pill to open the combined panel: current
  conditions + 3-day forecast on top, interactive radar below.
- **Right-click** the pill to send the current conditions as a notification.
- **Middle-click** the pill to refresh the forecast immediately.
- Click the radar's **⤢** to expand into the full Omastorm window.
- Click the location label in the panel to search for a different city
  (coordinates are shared with Omastorm via `weather.json`).

### Weather

- Current temperature, condition icon, feels-like, wind, and humidity
- 3-day forecast (icon, day name, hi/lo)
- Location auto-detected by IP, or configured via the click-to-search label
- Refresh interval configurable (default 15 min) via the weather widget
  settings; middle-click refreshes now

### Location sync

The weather panel and the radar share one location (`weather.json`), so
changing it in either surface updates both:

- **Weather → radar** — search a new city in the weather panel and the radar
  re-centers on it.
- **Radar → weather** — pick a place on the radar (search, site picker, or
  "my location") and the forecast follows.

Panning the radar is navigation, not a location change, so it never rewrites
your weather location.

### Radar

- Live interactive radar (drag to pan, scroll to zoom) rendered by Omastorm
- Timeline scrubber with play/step controls over recent scans
- Status line: LIVE / ARCHIVED and how long ago the sweep was taken
- **⤢** opens the full standalone Omastorm window

## Configure

Weather unit (metric/imperial) follows your locale and country, or can be
overridden in the widget settings. Radar site, location, and playback are
managed inside the radar itself and by Omastorm's config
(`~/.config/omastorm/config.toml`).

## Remove

```sh
omarchy plugin remove dchristensen8.skywatch
```

## Dependencies

- **Omastorm** (`com.omastorm.radar`) — required. Live NEXRAD / OPERA radar
  engine and map UI.
- `curl` — weather and geocoding API requests (open-meteo, wttr.in)
- Internet connection for live weather and radar data

## Credits

Skywatch is a combined, user-customizable build of two plugins:

- **Weather** — derived from the Omarchy first-party `omarchy.weather`
  widget (part of [Omarchy](https://github.com/omacom/omarchy), MIT).
  Forecast data from [open-meteo.com](https://open-meteo.com) and
  [wttr.in](https://wttr.in).
- **Radar** — embeds [Omastorm](https://github.com/wesleygrimes/omastorm)
  (`com.omastorm.radar`) by **Wes Grimes** (MIT), including its interactive
  radar map, engine bootstrap, and full-window mode. NOAA NEXRAD (US) and
  EUMETNET OPERA (Europe) reflectivity data; basemaps © OpenStreetMap /
  Natural Earth.

The panel layout that joins the forecast and the radar is original to
Skywatch. Both source projects remain MIT-licensed; this project is MIT.

## License

MIT — see [LICENSE](LICENSE).