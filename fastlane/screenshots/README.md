# Screenshots

Empty on purpose: 3.0.0's set has not been shot yet. What was here until now
were the 2010 app's twenty PNGs — 640×960 (iPhone 4) and iPad 9.7, sizes App
Store Connect no longer accepts, of a UI that no longer exists. They are in the
history if they are ever wanted (`git log -- fastlane/screenshots`).

## Layout

| Path | Devices |
|---|---|
| `ios/<locale>/*.png` | iPhone and iPad |
| `mac/<locale>/*.png` | Mac |

Locales are `ja` and `en-US`, the two the listing is written in. `deliver`
sorts the files into App Store display types by their **pixel size, not their
name**, so an iPhone and an iPad shot sit in the same directory; the numeric
prefix that most sets use (`01_…`, `02_…`) is only what orders them within a
device.

## Uploading

```bash
bundle exec fastlane ios deliver_screenshots   # or: mac
```

`overwrite_screenshots: true`, so what is in the directory is what the store
ends up with. The Metadata workflow runs the same lanes when a push to master
touches this directory, and on a dispatch with "Also upload the screenshots"
ticked — as a separate job, because this goes through iTMSTransporter and fails
often enough that it must not be able to take the copy down with it.

There is no capture automation yet (`ngs/tides-swift` has
`Scripts/screenshots.sh`, which drives simulators from a UI test, if this ever
wants one). For now the PNGs are shot by hand and committed here.
