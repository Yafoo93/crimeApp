# crimeApp MVP Design Reference

This file captures the visual direction from the supplied SafeAlert screenshots so future app and dashboard screens stay consistent.

## Visual Direction

- Product feel: dark, urgent, secure, operational.
- Primary background: near-black navy.
- Surface color: dark blue-gray cards and inputs.
- Primary action: red gradient or strong red fill.
- Secondary text: muted blue.
- Accent colors:
  - Red for primary actions, danger, urgent, selected tabs.
  - Cyan for evidence/location/admin metrics.
  - Green for resolved/active/success.
  - Amber/orange for warnings, area alerts, pending states.
  - Purple for dispatched/secondary status.
- Typography: bold, condensed-feeling headings with high contrast; compact labels in uppercase with muted blue.
- Corners: rounded cards and controls, usually large pill buttons and 16-22px card radius.
- Layout: mobile-first, dense vertical spacing, card-based lists, fixed bottom navigation for user app.

## Shared Components

- Auth logo block:
  - Red rounded-square shield icon.
  - App name centered below, letter-spaced uppercase.
  - Dark red/navy header gradient.
- Segmented tabs:
  - Rounded container.
  - Active segment uses red fill.
  - Inactive segment uses dark surface and muted blue text.
- Form fields:
  - Dark rounded input.
  - Leading icon.
  - Muted blue placeholder/value text.
  - Password field has trailing visibility icon.
- Primary button:
  - Full-width red rounded rectangle.
  - Bold uppercase label.
  - Subtle red glow/shadow.
- Cards:
  - Dark surface with subtle border.
  - Rounded corners.
  - Status pill on the right.
  - Small colored severity dot/icon on the left.
- Status pills:
  - `Investigating`: cyan text on dark teal.
  - `Resolved` / `active`: green text on dark green.
  - `Closed`: muted blue-gray.
  - `New`: amber/orange.
  - `Dispatched`: purple.
  - `suspended`: red.
- Bottom navigation:
  - Dark raised bar.
  - Three tabs: Home, Reports, Profile.
  - Active icon/text red.
  - Inactive icon/text muted blue.

## Mobile App Screens From Screenshots

### Sign In

- Header with logo and app name.
- Sign In / Register segmented control.
- Email and password fields.
- Forgot password link aligned right.
- Full-width Sign In button.
- Divider with `OR`.
- Phone OTP secondary button.
- Admin Portal link in amber.

### Register

- Same header and segmented control.
- Fields: full name, email, phone number, password.
- Full-width Create Account button.
- Divider with `OR` continues below visible area.

### User Home

- Top greeting: `WELCOME BACK`, user name.
- Notification icon with red unread dot.
- Large red CTA card: `Tap to Report Incident`, subtitle `Anonymous • Secure • Fast`.
- Quick actions row:
  - Voice Note
  - Evidence
  - Location
  - My Reports
- Area alert warning card.
- Recent reports list.
- Bottom navigation with Home active.

### My Reports

- Title and count.
- Filter chips: All, Active, Resolved, Closed.
- Report cards with category, location, report ID, age, status, Details action.
- Bottom navigation with Reports active.

## Admin Dashboard Screens From Screenshots

### Admin Overview

- Header: shield icon, `Admin Dashboard`, officer name.
- Notification and logout icons.
- Tabs: Overview, Reports, Users.
- Metric cards:
  - Total reports
  - Active cases
  - Resolved
  - Response time
- Incident breakdown card with horizontal progress bars.

### Admin Reports

- Same admin header and tabs.
- Search input and filter button.
- Report cards with title, reporter/time, location, status, and actions:
  - Assign
  - View
  - Dispatch

### Admin Users

- Same admin header and tabs.
- Search input.
- User list cards with avatar, name, report count, user type, status pill, overflow menu.

## Screens Not Yet Shown

Build these using the same visual language:

- Splash screen.
- Forgot password.
- Phone OTP.
- Report category selection.
- Incident description form.
- Location confirmation with GPS and GhanaPostGPS field.
- Evidence upload.
- Voice-note recording/playback.
- Report preview.
- Submission confirmation.
- Report details for users.
- Admin report detail with map, evidence, voice note, notes, spam flag, and status update.
- Admin settings and category management.

## Implementation Notes

- Keep emergency reporting and `Call 112` highly visible on the home/report flow.
- Use this style for both mobile and admin, but admin screens can be denser and more operational.
- Prefer reusable Flutter widgets for tabs, cards, status pills, form fields, and action buttons.
- Avoid light backgrounds unless a specific design screen requires it.
