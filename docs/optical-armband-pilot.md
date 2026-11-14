# Optical armband pilot — COOSPO HW9

## Purpose

Validate one affordable optical armband as a no-chest-strap backup sensor for PulseClass. Do not describe the HW9 as PulseClass-tested until the physical test below passes.

## Expected connection route

- The student uses the PulseClass native app on an Android or iPhone.
- The armband must expose the Bluetooth SIG Heart Rate Service (UUID `180D`) and Heart Rate Measurement characteristic (`2A37`).
- PulseClass discovers nearby Bluetooth devices, connects to the selected device, verifies those standard GATT attributes, and reads BPM notifications.
- ANT+ is not used by this phone-based test. Bluetooth 5.x branding alone does not prove that a device exposes the standard heart-rate service.

## Before testing

1. Confirm the exact model printed on the device and its firmware version.
2. Charge the armband and fit it firmly against the skin, following the manufacturer's placement guidance.
3. Check the manufacturer's instructions for any required heart-rate broadcast setting.
4. Close or disconnect other apps/receivers if the armband only permits one active Bluetooth connection.
5. Use a supported PulseClass native-app build, with Bluetooth/Nearby Devices permission granted and the app in the foreground.

## Test procedure

1. Join a disposable test lesson using a test student identity; do not use real pupil health data for initial validation.
2. Scan in PulseClass and select the armband.
3. Confirm that PulseClass reports a sensor connection only after it has found service `180D` and characteristic `2A37`.
4. Confirm a plausible BPM appears and continues updating for at least 10 minutes.
5. Compare the display with the armband's own supported reference display/app if available. Treat small differences as expected; investigate persistent gaps, freezes or implausible values.
6. Move the armband briefly out of range or switch it off. Confirm PulseClass marks the sensor disconnected and clears the previous BPM rather than presenting it as live.
7. Reconnect and confirm fresh readings resume.
8. Confirm the teacher dashboard attributes readings to the correct test student and that stale readings are visibly distinguishable from current readings.

## Acceptance criteria

- Standard Heart Rate Service and Measurement characteristic are present and readable.
- BPM notifications update continuously for 10 minutes without unexplained freezes.
- Disconnect clears the displayed BPM and last-reading timestamp; reconnect restores fresh readings.
- The teacher dashboard receives readings for the correct student.
- No paid subscription, ANT+ receiver or chest strap is required for this BLE test.
- Record phone model, OS version, app build, armband model/firmware, connection steps and any error messages.

## Test record

| Field | Result |
|---|---|
| Armband model / firmware | Pending physical device |
| Student phone / OS | Pending |
| PulseClass app build | Pending |
| Standard BLE HR service confirmed | Pending |
| 10-minute live reading test | Pending |
| Disconnect / reconnect test | Pending |
| Teacher dashboard attribution | Pending |
| Overall result | Not yet tested |

## Important limits

This checklist prepares the test; it is not evidence that a particular HW9 unit or firmware revision works. Do not add the model to the confirmed-compatible list until all acceptance criteria pass. Students without a compatible wearable must still be able to participate without one.
