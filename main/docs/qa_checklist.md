# QA Checklist – Frontend Readiness

Use this lightweight checklist before every release to ensure the most fragile
flows remain healthy after recent optimizations.

## Authentication & Onboarding
- Verify login succeeds for existing user (cold start & warm start).
- Confirm background tasks (contact sync, pagos) show the new progress banner.
- Validate new users still reach the security questions / onboarding flow.

## Realtime & Messaging
- Send rapid-fire messages between two devices; ensure no duplicates appear.
- Scroll through a long conversation and confirm skeleton loader disappears and
  pagination loads older messages without stutter.
- Attach images/videos/audio and confirm thumbnails + heroes render correctly.
- Swipe-to-reply and forwarding should work while recorder lifecycle remains
  stable (no stuck microphone sessions).

## Notifications & Calls
- Receive foreground/background message notifications; tapping should deep-link
  back into the chat that generated the message.
- Trigger a missed call push and confirm the full-screen notification shows
  with action buttons and no missing avatar asset warnings.
- Accept/decline from notification banner and verify the call state updates.

## Home & Contacts
- Open Home after force-closing the app; skeleton list should show briefly
  instead of a blocking spinner.
- Trigger manual refresh (pull/refresh button) while socket is reconnecting and
  ensure the banner indicates syncing instead of freezing UI.

## Observability
- Review `TelemetryService.dump()` output in a debug session to verify major
  events (connect/disconnect, sync start/finish, notification taps) are logged.
- Capture `debuglog.txt` after a smoke pass to ensure no regressions or new
  stack traces were introduced.

