# Device compatibility and student setup

PulseClass uses native Bluetooth LE on the student's phone and the Bluetooth SIG standard Heart Rate Service where a device exposes it. The student app now scans nearby named Bluetooth devices (rather than only devices that advertise the Heart Rate Service) and verifies the service after connection. This widens discovery, but it does not bypass a watch manufacturer's restrictions or make ANT+ devices visible to a phone without ANT+ radio support.

## Compatibility principles

- Prefer a direct, local Bluetooth connection for live lesson readings: it avoids vendor cloud delays and does not require a separate account.
- Accept the standard Heart Rate Service (UUID `180D`) and Heart Rate Measurement characteristic (`2A37`).
- Test exact watch/firmware/phone combinations; a brand name alone is not a compatibility guarantee.
- Do not require students to purchase receivers, subscriptions or new watches. Provide a non-wearable participation option.
- Keep live readings distinct from historical/synced health records.

## Integration routes and their limits

| Route | What it can add | Limitation |
|---|---|---|
| Standard Bluetooth LE | Broad range of chest straps and watches that expose the standard HR service | The device must make live HR available over BLE and allow the phone to connect |
| Manufacturer broadcast mode | Some watches/bands can expose a standard BLE heart-rate stream when broadcast is enabled | Support varies by exact model; ANT+-only broadcast is not enough |
| Android Health Connect | Potential later import of heart-rate records written by compatible apps | This is a permissioned health-data store, not a guaranteed continuous live sensor stream; it cannot be treated as live lesson telemetry |
| Manufacturer cloud/API integration | May add selected brands or retrospective workout data | Requires vendor approval, user consent/OAuth, internet access and vendor-specific implementation; APIs may not provide continuous live HR |
| ANT+ | Could support ANT+ sensors on devices with compatible radio hardware | No extra ANT+ receiver will be required for the core PulseClass experience; phones without ANT+ cannot receive ANT+ directly |

WHOOP's developer documentation states that continuous heart-rate data is not available through its API; WHOOP devices instead support BLE heart-rate broadcast. Android Health Connect provides access to heart-rate records with user permission, but records may be synced or historical and should not be presented as a continuous live feed. See the official documentation linked from the project research notes in the repository issue tracker before implementing a vendor-specific integration.

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

Some Garmin watches support Bluetooth heart-rate broadcasting, but support is model-specific. Check the exact model's official manual. ANT+-only broadcasting (including the vívoactive 4 broadcast mode) is not enough for direct phone BLE connection.

## Bluetooth chest strap

1. Fit the strap snugly; moisten the electrode pads if the manufacturer recommends it.
2. Wake the strap (some turn on only when worn).
3. If it is already connected to a watch or training app, disconnect that receiver if the strap does not permit another connection.
4. Scan in PulseClass Student and confirm a stable BPM display.

The sensor must expose the Bluetooth SIG Heart Rate Service (UUID `180D`) and Heart Rate Measurement characteristic (`2A37`). PulseClass now scans more broadly and checks these services after connection, but a proprietary sensor with no standard HR service, or a device advertised as ANT+ only, will not work through the direct BLE route.

## Mixed / unknown models

Do not assume a brand name guarantees compatibility. Record make, model, phone model, OS version, firmware and whether the device is configured for broadcast. A successful scan plus a stable 10-minute live test is the acceptance criterion.

## Phone requirements

- iOS: install the native PulseClass Student app build. Safari Web Bluetooth is not supported.
- Android: install the native PulseClass Student app build and allow Nearby Devices / Bluetooth permissions. Older Android versions may also request location permission for BLE scanning.
- Both: keep the app in the foreground during the lesson and keep an active internet connection. This release is not a background data logger.
