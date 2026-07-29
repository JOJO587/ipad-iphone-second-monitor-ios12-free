# Turn an iPad stuck on iOS 12 into a wired second display for your Mac (macOS 26) over Lightning — free, self-hosted

**Built and running for real** on an iPad Air (Model A1475, iOS 12.5.8) over a Lightning cable. H.264 video + touch + two-finger scroll + a real mouse cursor all work reliably.

## The idea

Skip the paid apps (Duet Display, Luna Display...). Instead:

1. **Mac side**: build and run, unmodified, the open-source
   **[OpenDisplay](https://github.com/peetzweg/opendisplay)** app (GPL-3.0, free).
   It already handles the hard part: creating a virtual display on macOS
   (`CGVirtualDisplay`), capturing it (`ScreenCaptureKit`), hardware-encoding
   H.264 (`VideoToolbox`), and talking directly to macOS's `usbmuxd` to
   transport it over Lightning/USB-C — **no extra tool like `iproxy`
   needed.**
2. **iPad side**: OpenDisplay requires iPadOS 17+, so it **can't be
   installed on an iOS 12 iPad**. That's why the `iOS/` folder in this repo
   is a **purpose-built iOS 12 client**: a clean-room reimplementation of
   OpenDisplay's network protocol (read from their public source), so it
   can talk to the unmodified Mac app above without touching it.

Since the Mac side only needs an unmodified build, the only thing you're
actually "writing" yourself is the iPad app — much lighter than
reimplementing the whole pipeline from scratch.

## Repo layout

```
ipad12-second-screen/
  README.md
  LICENSE                 <- MIT, covers iOS/ (code written for this project)
  iOS/                    <- iOS 12 client, original code, MIT
    project.yml           <- xcodegen config
    App/
      AppDelegate.swift
      ReceiverViewController.swift  <- fullscreen video view + touch/scroll capture + cursor sprite
      VideoReceiver.swift    <- core: TCP listener, frame deframing, H.264 decode, control message send/recv
      LaunchScreen.storyboard
      Assets.xcassets/
  Mac/                    <- git submodule, upstream OpenDisplay, UNMODIFIED, GPL-3.0
```

`Mac/` is a **git submodule** pointing straight at the upstream
`peetzweg/opendisplay` repo — nothing copied or edited, so it's clear this
is someone else's code (their GPL-3.0 license stays intact), and it's easy
to `git submodule update --remote` when they cut a new release.

Minimum requirement: **iOS 12.0** (`iOS/project.yml` → `deploymentTarget`),
tested for real on iOS 12.5.8.

## Step 0 — Clone with submodules

```bash
git clone --recurse-submodules https://github.com/cuongpham1/ipad-second-monitor-ios12-free.git
cd ipad-second-monitor-ios12-free
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

## Step 1 — Build the Mac app (OpenDisplay, unmodified)

```bash
brew install xcodegen
cd Mac
echo "DEVELOPMENT_TEAM=YOUR_TEAM_ID" > .env   # find your Team ID at developer.apple.com/account, Membership section
./generate.sh
open OpenSidecar.xcodeproj
```

In Xcode: select the **OpenSidecarMac** scheme → Run. On first launch,
macOS will ask for **Screen Recording** and **Accessibility** permissions
(System Settings → Privacy & Security) — grant both, **fully quit the app
(Cmd+Q) and relaunch it** (flipping the toggle isn't enough; the app needs
a restart to actually pick up the new permissions), then run it again.

(You can also grab the prebuilt `.dmg` from
[Releases](https://github.com/peetzweg/opendisplay/releases/latest)
instead of building it yourself, if you trust the author's signed/notarized
binary.)

## Step 2 — Build the iPad app (`iOS/` in this repo)

```bash
brew install xcodegen   # skip if already installed in step 1
cd iOS
xcodegen generate
open LegacyPadDisplay.xcodeproj
```

In Xcode:
1. Select target **LegacyPadDisplay** → **Signing & Capabilities** tab →
   set Team to your personal Apple ID.
2. Plug the iPad into the Mac with a Lightning cable, select it as the
   destination device in Xcode's toolbar.
3. Hit Run. On first install, go to **Settings → General → VPN & Device
   Management** on the iPad to "Trust" your developer certificate.

The app should show a fullscreen black screen with "Listening on :9000" at
the bottom — meaning it's waiting for the Mac to connect.

### Xcode says "Failed to prepare the device for development"

Recent Xcode versions don't ship **iOS DeviceSupport** for old iOS 12
builds anymore. You need to add the matching support folder to
`~/Library/Developer/Xcode/iOS DeviceSupport/`. This repo was actually
brought up using the 12.5 support bundle from
[apptim/iPhoneOSDeviceSupport](https://github.com/apptim/iPhoneOSDeviceSupport):

```bash
curl -L -o /tmp/12.5.zip https://raw.githubusercontent.com/apptim/iPhoneOSDeviceSupport/master/12.5.zip
unzip -o /tmp/12.5.zip -d /tmp/ds125
cp -R "/tmp/ds125/12.5" ~/Library/Developer/Xcode/iOS\ DeviceSupport/
```

It doesn't need to match the exact build number (e.g. 12.5.8/16H88 worked
fine with a plain "12.5" folder) — a close minor version is enough. Other
community repos like
[filsv/iOSDeviceSupport](https://github.com/filsv/iOSDeviceSupport) work
the same way if you need a different version. Copy the folder into place,
fully quit Xcode, reconnect the iPad, and reopen.

### Free Apple ID — the app expires after 7 days

This is an Apple limitation, not something this project can fix. After 7
days, plug the cable back in, open Xcode, and hit Run again to reinstall.
To avoid repeating this, you'd need a paid Apple Developer Program
membership ($99/year) — signs for a full year.

## Step 3 — Connect

1. Make sure both apps are running (Mac app has Screen Recording +
   Accessibility permissions; iPad app is open, cable plugged in).
2. In the Mac app (OpenDisplay), select the **USB** connection mode — since
   your iPad app shares the same `id` and port 9000 as the original client,
   the Mac app will recognize it through `usbmuxd` just like a normal
   OpenDisplay device.
3. Once connected, the iPad should switch from a black screen to showing
   the macOS desktop (with a real mouse cursor), and a new display should
   appear under System Settings → Displays on the Mac — drag a window over
   to it and you're set.

## If it won't connect — check these first

- **No new virtual display shows up under System Settings → Displays**:
  almost always missing Screen Recording/Accessibility permission for the
  Mac app, or granted but the app wasn't fully quit and relaunched
  afterward (see Step 1).
- Check the Mac app's console log (Xcode → View → Debug Area → Console
  while running the OpenSidecarMac scheme) to see whether it's seeing the
  device over usbmuxd at all.
- Make sure the iPad app stays in the foreground (iOS can suspend
  `NWListener` when the app goes to background — this minimal client
  doesn't yet restart the listener on foreground return like the original
  does).
- If the Mac app sends an `updateRequired`/incompatible-version message —
  a newer OpenDisplay Mac build may have changed the protocol.
  `VideoReceiver.swift` intentionally omits the `pv` (protocol version)
  field, so it's always treated as "protocol 1", which every current
  OpenDisplay Mac release documents as backward-compatible.

## What works / what's missing

Works: video, touch to click/drag, two-finger scroll, **a real mouse
cursor** (position + shape, synced over its own control message, smooth).

Missing: an external keyboard, automatic rotation to match the virtual
display, latency measurement, auto-restart when the app returns from the
background.

## License

- `iOS/` (iOS 12 client): MIT, see [LICENSE](LICENSE).
- `Mac/`: submodule pointing at `peetzweg/opendisplay`, GPL-3.0, copyright
  held by its original authors — unmodified, not vendored into this repo.
