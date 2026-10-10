---
name: ios-device-install
description: Install a development build of an iOS app on the physical iPhone, wherever it is — with devicectl when the iPhone is reachable (USB or same LAN), otherwise over the air through Tailscale (install page served on the tailnet, opened in Safari). Generic across apps; each project keeps its own build command. Use when the user asks to "installe sur mon iPhone", "mets le build sur le téléphone", "test live", "je ne suis pas à la maison", when `bin/run-ios-device` or devicectl fails with "unable to locate a device matching the requested device identifier", or when `xcrun devicectl list devices` shows the iPhone `unavailable`.
---

# Install an iOS dev build on the iPhone

`scripts/install-ios-app <App.app>` takes a device build already signed by
the project and installs it:

- iPhone reachable by CoreDevice (tunnel not `unavailable`): `devicectl`
  installs and launches it;
- otherwise: it zips the `.app` into an `.ipa`, writes the manifest and an
  install page under `~/share/ios-ota/<bundle id>/` and serves them on
  `https://<mac>.<tailnet>.ts.net/ios-ota/<bundle id>/`; it prints that URL
  on stdout.

The project-specific part (scheme, bundle id, signing, worktree, server)
stays in the project: its skill or `CLAUDE.md` says how to build, this skill
how to get the build onto the phone.

## Steps

1. Build for the device with the project's own command, Debug configuration,
   `-destination generic/platform=iOS`: the product is
   `<derived data>/Build/Products/Debug-iphoneos/<Name>.app`. A simulator
   build is refused.
2. Install:

   ```bash
   ~/.agents/skills/ios-device-install/scripts/install-ios-app [--device <id>] "<path/to/App.app>"
   ```

   The device defaults to `$IOS_DEVICE_UUID`, else the only paired iPhone;
   `--device` takes the CoreDevice identifier, the UDID or the name.
   `--ota` forces the OTA path, `--no-launch` skips the launch.
3. In OTA mode, tell the user what to do on the iPhone, in the reply:
   Tailscale connected on the iPhone, open the printed URL in Safari (not an
   in-app browser), tap Installer then confirm, wait for the icon to fill
   (it can look idle for a few seconds), open the app by hand.

## Why OTA, and why it works without archiving

- CoreDevice finds the iPhone only through Bonjour (`_remotepairing._tcp`,
  `*.coredevice.local`), with no option to target an IP; Bonjour does not
  cross Tailscale, and on cellular no iPhone port answers the `RPPairing`
  handshake through Tailscale. Away from the LAN, devicectl cannot work.
- A Debug build signed by automatic signing embeds the team development
  profile, which lists the iPhone's UDID: the `.app` zipped under
  `Payload/` is a valid `.ipa`, no archive nor export. The script checks the
  embedded profile lists the target UDID before publishing, since iOS
  otherwise fails the install without a clear message.

## Pitfalls

- **Serving a folder needs root**: `tailscale serve <path>` answers `must be
  root, or be an operator`. The script serves `~/share/ios-ota` with
  `python3 -m http.server` on `127.0.0.1:8791` (detached with `setsid`, a
  plain `&` dies with the Bash tool's process group) and `tailscale serve`
  proxies `/ios-ota` to it. The serve config persists; the local server does
  not survive a reboot, the script restarts it. If the port serves another
  folder, it stops: pick another with `IOS_OTA_PORT`.
- **Serve disabled on the tailnet**: `tailscale serve` waits forever behind
  a `https://login.tailscale.com/f/serve?...` link; the script stops after
  20 s. Give the link to the user as plain text.
- **Tailscale DNS from the shell**: `<mac>.ts.net` does not always resolve
  locally; the script checks its own URLs with `curl --resolve` on
  `tailscale ip -4`.
- **itms-services link**: the manifest URL is percent-encoded and has no
  query string; the `.ipa` gets a new name per build to dodge caching, and
  the previous one stays served for an install already started.
- **Nothing happens on the phone**: the local server does not log. Restart
  it with a log (kill the listener on 8791, rerun
  `python3 -m http.server 8791 --bind 127.0.0.1` from `~/share/ios-ota`) and
  check `GET /<bundle id>/manifest.plist` then `GET /<bundle id>/app-*.ipa`
  arrive.
- **Profile without the iPhone** (`does not list` from the script, `This
  provisioning profile cannot be installed on this device` from devicectl):
  register the UDID and regenerate the profiles, see the `dev-ios` skill.
- **iPhone locked**: devicectl installs but the launch is refused; open the
  app by hand.
- **One app per bundle id**: each install replaces the previous build with
  the same bundle id, session included.
- **Backend on the Mac**: an app talking to a local server reaches it at
  the Mac's Tailscale name; check its requests come from a `100.x` address
  in the server log.
