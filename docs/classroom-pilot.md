# PulseClass 20–30 student classroom pilot

## Pilot before rollout

Start with 4–6 volunteer users and a 10-minute session. Include both iOS and Android phones and at least one example of each wearable type available.

## Acceptance checklist

- [ ] Teacher signs in and creates a class.
- [ ] Teacher opens a named lesson and shares the join code.
- [ ] Students join using a display name and class code without creating Auth accounts; unrelated students cannot see each other's data.
- [ ] WHOOP Heart Rate Broadcast is detected and gives stable readings.
- [ ] Each Garmin model is checked against Garmin's supported broadcast list and tested individually.
- [ ] Each chest strap is tested for standard BLE Heart Rate Service support.
- [ ] iOS and Android native apps request permissions clearly and can pair.
- [ ] Teacher dashboard receives new readings within a few seconds.
- [ ] A disconnected sensor becomes stale / visibly disconnected rather than showing a misleading current value.
- [ ] Reconnecting restores readings without creating duplicate student entries.
- [ ] Average, peak and zone distribution update during the lesson.
- [ ] Ending a lesson stops further accepted readings.
- [ ] Session report and CSV export work.
- [ ] Two unrelated student tokens cannot see or alter each other's data; a second teacher cannot see the class.
- [ ] The school's data-protection lead signs off on purpose, access, retention, deletion and consent / notice.

## Scale-up test

Run a 20–30 phone session for at least 20 minutes on the actual school Wi-Fi. Track:

- percentage of students with a fresh reading in the last 15 seconds;
- time from a sensor reading to display on teacher dashboard;
- sensor disconnect / reconnect count;
- database insert failures and Realtime errors;
- phone battery and overheating;
- whether school network filtering blocks WebSocket or Supabase traffic.

Suggested pilot targets (operational targets, not guarantees):

- At least 95% of connected devices show fresh readings during stable periods.
- Most readings appear on the teacher dashboard within 3–5 seconds.
- No cross-class or cross-student data visibility.
- Teacher can identify a stale or disconnected device immediately.

Do not use the app for formal assessment until the school has approved the data processing and the device matrix has passed its acceptance tests.
