# omarchy-world-clocks

Up to 5 world clocks in the Omarchy bar, with search-and-add for any IANA timezone.

## Install

```bash
omarchy plugin add https://github.com/danidanz/omarchy-world-clocks --enable
```

Or manually:

```bash
git clone https://github.com/danidanz/omarchy-world-clocks ~/.config/omarchy/plugins/danidanz.world-clocks
omarchy plugin enable danidanz.world-clocks --section right
```

## Use

- Bar shows first city as `JKT 07:00 +2` (short code + time + extra count).
- Left-click opens the popup: full list with seconds, remove with `✕`,
  search all 598 timezones to add (max 5), 24h/12h toggle.
- Right-click the bar pill toggles 24h/12h (persisted to `shell.json`).
- Settings persist per-widget in `shell.json` (`cities`, `timeFormat`, `showSeconds`).

## Files

- `manifest.json` — plugin contract (`bar-widget`)
- `BarWidget.qml` — bar pill + popup loader
- `Panel.qml` — clock list + city search + format toggle
- `Timezones.js` — generated from `timedatectl list-timezones`
- `clockdata` — Python `zoneinfo` helper (DST-correct offsets, polled per minute)

## License

MIT
