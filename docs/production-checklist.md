# Production launch checklist

- [ ] Supabase project provisioned in the appropriate region
- [ ] Schema applied and RLS tested with teacher and anonymous participant flows
- [ ] Only the owner teacher profile retained; public signup blocked
- [ ] Email confirmation, password reset, SMTP, and account recovery configured
- [ ] Class-code expiry/rotation and membership removal implemented
- [ ] Realtime publication verified for teacher dashboard reading anonymous participant data
- [ ] Retention schedule and deletion workflow implemented
- [ ] School privacy review / DPIA and consent or other lawful-basis process completed
- [ ] Student-facing notice explains what is collected and who can see it
- [ ] Device matrix tested (Android Chrome, desktop Chrome/Edge, iOS fallback)
- [ ] BLE disconnect, reconnect, timestamp gaps, and duplicate readings tested
- [ ] Duration-in-zone derived from elapsed timestamp intervals with gap caps
- [ ] CSV export reviewed for minimisation and safe handling
- [ ] Backups, monitoring, incident response and support owner assigned


## Wearable / classroom pilot
- [ ] WHOOP Heart Rate Broadcast enabled and tested over BLE on supported student browser
- [ ] Each intended Garmin watch model checked against Garmin's BLE broadcast list and tested
- [ ] Chest straps confirmed to expose standard BLE Heart Rate Service (not ANT+ only)
- [ ] Apple Watch / Fitbit clearly excluded from live browser pilot unless companion/provider integration is built
- [ ] Test 3–5 devices, then full expected class size in the actual activity space
- [ ] Verify stale-reading warning, manual reconnect, data attribution and saved report
- [ ] Confirm school device policy allows Bluetooth permissions and HTTPS site access

## Mixed-device mobile rollout (v0.4)

- [ ] Replace the archived migration 003 with a reviewed, tested incremental migration matching the live database; do not apply the archived draft directly.
- [ ] Verify the first owner account is the only teacher; subsequent signup attempts are rejected and public signup is disabled in Auth settings.
- [ ] Verify students join with name + code and no Auth user/profile is created.
- [ ] Configure `mobile/.env` with the Supabase project URL and public key.
- [ ] Set a real EAS project ID in `mobile/app.json`.
- [ ] Build and install iOS and Android internal test releases.
- [ ] Test device discovery in a room containing multiple simultaneous HR broadcasts; verify students manually select their own sensor by device name / ID.
- [ ] Test WHOOP, each actual Garmin model, and each actual strap model separately.
- [ ] Run a 20–30 phone, 20-minute Wi-Fi load test before normal lessons.
- [ ] Verify no reading is accepted after a lesson ends and the database sampling trigger rejects excessive writes.
