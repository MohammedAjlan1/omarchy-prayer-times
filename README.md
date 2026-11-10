# Prayer times (Omarchy plugin)

Shows the next prayer and a countdown in the Omarchy bar. Clicking it opens a
themed popup with the day's prayer times, the Hijri date and a Jumu'ah reminder.

- Plugin id: `moha.prayer`
- Kind: bar widget (default section `centerEnd`)
- Language: QML + a bash helper (`prayer-times`)

## Install

```bash
omarchy plugin add https://github.com/MohammedAjlan1/omarchy-prayer-times --enable --yes
```

Or place it by hand in `~/.config/omarchy/plugins/moha.prayer/`, then
`omarchy plugin enable moha.prayer --section centerEnd`.

## Remove

```bash
omarchy plugin remove moha.prayer --yes
rm -rf ~/.cache/omarchy-prayer        # cached times (optional)
rm -f ~/.config/omarchy/prayer.conf   # your settings, if you created one (optional)
```

## Dependencies

`bash`, `curl`, `jq`, `notify-send` (libnotify). No other setup.

## Network use and privacy

- Prayer times come from the [Aladhan API](https://aladhan.com/prayer-times-api),
  cached per day (about two requests a day).
- With no coordinates configured, your approximate location is detected from
  `https://geo.omarchy.org/`. Set `LATITUDE` and `LONGITUDE` to avoid that lookup.
- Nothing else is sent anywhere. The plugin never writes to your config.

## Configuration (optional)

Create `~/.config/omarchy/prayer.conf`. All keys are optional:

```
LATITUDE=21.42
LONGITUDE=39.82
CITY="Makkah"          # label only
METHOD=4               # Aladhan calculation method id
SCHOOL=0               # 0 Shafi/Maliki/Hanbali, 1 Hanafi
ALERT_MINUTES=15
TIME_FORMAT=24         # 12 or 24
HIJRI_CALENDAR=UAQ     # UAQ, HJCoSA, DIYANET, MATHEMATICAL
JUMUAH_REMINDER=30
```

## Helper commands

```
prayer-times --table     timetable in the terminal
prayer-times --notify    timetable as a desktop notification
prayer-times --refresh   drop cache and refetch
```

## Tests

```bash
node --test tests
```

## License

MIT, see `LICENSE`.
