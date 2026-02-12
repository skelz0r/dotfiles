---
name: dev-ios
description: iOS development workflow for building, signing, and deploying to physical devices. Covers remote builds on ch405, provisioning profiles, keychain, and srun tooling. Use when dealing with iOS builds, device deployment, code signing, or provisioning issues.
---

# iOS Development Workflow

## Architecture

Build happens on **ch405** (remote Mac), install/run happens on **local machine** (where device is plugged in). Communication via reverse SSH tunnel set up by `sproject`.

## Key Tools (`~/.bin/`)

| Command | Description |
|---------|-------------|
| `sproject <project>` | SSH to ch405, sets up reverse tunnel, opens tmux |
| `srun-local phy <project>` | From ch405 SSH: build remote, install on local physical device |
| `srun-local sim <project>` | From ch405 SSH: build remote, run on local simulator |
| `srun-phy <project>` | Build + install + launch on physical device (local only) |
| `srun-sim <project>` | Build + install + launch on simulator (local only) |
| `_srun-build <project> <type>` | Internal: builds on ch405, copies .app to local /tmp |

## Typical Workflow

```bash
# From local machine:
sproject local_events        # SSH to ch405 with reverse tunnel

# From ch405 SSH session:
srun-local phy local_events  # Build on ch405, install on local device
srun-local sim local_events  # Build on ch405, run on local simulator
```

## Device UUID Configuration

Device UUID is configured in **3 places** (all must match):

1. `~/.bin/srun-phy` - default in `DEVICE_UUID="${IOS_DEVICE_UUID:-<uuid>}"`
2. `<project>/.ios-device-uuid` - read by `bin/install-ios-device`
3. `<project>/bin/run-ios-device` - default fallback

To find device UUID: `xcrun devicectl list devices` (on machine where device is plugged in).

The UDID (different from CoreDevice UUID) is visible in Xcode > Window > Devices and Simulators. Both are needed:
- **CoreDevice Identifier** (format `XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`): used by `xcrun devicectl`
- **UDID** (format `00008140-XXXXXXXXXXXXXXXX`): must be registered on developer.apple.com

## Code Signing & Keychain

ch405 uses a dedicated CI keychain:
```bash
security unlock-keychain -p ci ~/Library/Keychains/ci.keychain-db
```

`_srun-build` handles this automatically. For manual builds via SSH:
```bash
security list-keychains -d user -s ~/Library/Keychains/ci.keychain-db ~/Library/Keychains/login.keychain-db
security unlock-keychain -p ci ~/Library/Keychains/ci.keychain-db
```

Without unlocking the keychain, codesign fails with `errSecInternalComponent`.

## Provisioning Profiles

Profiles are cached in `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`.

### Adding a New Device

1. Get UDID from Xcode (Window > Devices and Simulators) on the machine where device is connected
2. Add UDID on [developer.apple.com/account/resources/devices/list](https://developer.apple.com/account/resources/devices/list)
3. On ch405, delete cached profiles:
   ```bash
   rm ~/Library/Developer/Xcode/UserData/Provisioning\ Profiles/*.mobileprovision
   ```
4. In Xcode on ch405, open project, toggle "Automatically manage signing" off/on for **each target** (Morris, MorrisShareExtension) to force profile regeneration
5. Clean and rebuild:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/Morris-*
   security unlock-keychain -p ci ~/Library/Keychains/ci.keychain-db
   xcodebuild -project ios/Morris.xcodeproj -scheme Morris -allowProvisioningUpdates \
     -destination "generic/platform=iOS" -configuration Debug CODE_SIGN_STYLE=Automatic build
   ```
6. Update device UUID in the 3 config locations (see above)

### Verifying Profiles

Check which devices are in a profile:
```bash
security cms -D -i "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles/<uuid>.mobileprovision" | grep -A 10 "ProvisionedDevices"
```

### Common Error

`This provisioning profile cannot be installed on this device` = device UDID not in the embedded profile. Follow "Adding a New Device" steps above.

## Build Commands (on ch405 directly)

```bash
./bin/build-ios              # Build for simulator
./bin/build-ios device       # Build for physical device
./bin/run-ios-device         # Build + install + run on device (device must be local)
```
