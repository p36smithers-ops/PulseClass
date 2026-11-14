# Device compatibility and student setup

PulseClass v0.3 uses native Bluetooth LE on the student's phone and the standard Heart Rate Service rather than vendor cloud sync.

## WHOOP

1. Open the WHOOP app and tap the device indicator / Device Settings.
2. Under Status, enable **Heart Rate Broadcast**.
3. Return to PulseClass Student and tap **Find heart-rate monitor**.
4. Select the WHOOP broadcast if prompted by the operating system.
5. Keep the band worn, the phone nearby and PulseClass in the foreground.

WHOOP support documentation describes the Heart Rate Broadcast control in Device Settings. The broadcast must be available to the student phone; if it is currently streaming to another receiver, disconnect that receiver and retry.

## Garmin watch

1. Check Garmin's official Bluetooth HR broadcast compatibility list for the exact model.
2. On the watch, enable **Broadcast Heart Rate** (menu wording varies by model).
3. Return to PulseClass Student and scan.
4. Stop the watch broadcast after the lesson if desired.

Many Garmin watches support broadcasting, but not all. Garmin says to verify the exact device and owner's manual. ANT+ broadcasting alone is not enough for this app.

## Bluetooth chest strap

1. Fit the strap snugly; moisten the electrode pads if the manufacturer recommends it.
2. Wake the strap (some turn on only when worn).
3. If it is already connected to a watch or training app, disconnect that receiver if the strap does not permit another connection.
4. Scan in PulseClass Student and confirm a stable BPM display.

The sensor must expose the Bluetooth SIG Heart Rate Service (UUID `180D`) and Heart Rate Measurement characteristic (`2A37`). A device advertised as ANT+ only, or a proprietary sensor with no standard HR service, will not work in this release.

## Mixed / unknown models

Do not assume a brand name guarantees compatibility. Record make, model, phone model, OS version, firmware and whether the device is configured for broadcast. A successful scan plus a stable 10-minute live test is the acceptance criterion.

## Phone requirements

- iOS: install the native PulseClass Student app build. Safari Web Bluetooth is not supported.
- Android: install the native PulseClass Student app build and allow Nearby Devices / Bluetooth permissions. Older Android versions may also request location permission for BLE scanning.
- Both: keep the app in the foreground during the lesson and keep an active internet connection. This release is not a background data logger.
