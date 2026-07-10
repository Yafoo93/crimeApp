# Domain Model

This is the MVP data contract for the mobile app, admin dashboard, Firestore, Storage, and Cloud Functions.

## `reports/{reportId}`

- `id`: string
- `reporterId`: string | null
- `reporterDisplayName`: string | null
- `anonymous`: boolean
- `categoryId`: string
- `categoryLabel`: string
- `urgency`: `normal` | `urgent` | `critical`
- `description`: string
- `status`: `draft` | `pendingUpload` | `uploading` | `submitted` | `received` | `underReview` | `investigating` | `resolved` | `rejected` | `closed` | `failed`
- `syncStatus`: `draft` | `pendingUpload` | `uploading` | `submitted` | `failed`
- `location.latitude`: number | null
- `location.longitude`: number | null
- `location.accuracyMeters`: number | null
- `location.ghanaPostGps`: string | null
- `location.addressText`: string | null
- `media.images`: ReportMedia[]
- `media.videos`: ReportMedia[]
- `media.voiceNotes`: ReportMedia[]
- `spamFlagged`: boolean
- `createdAt`: timestamp
- `updatedAt`: timestamp
- `submittedAt`: timestamp | null
- `assignedTo`: string | null
- `adminNotesCount`: number

## `users/{uid}`

- `uid`: string
- `displayName`: string
- `email`: string | null
- `phoneNumber`: string | null
- `role`: `user` | `admin` | `superAdmin`
- `status`: `active` | `suspended`
- `verifiedReporter`: boolean
- `reportCount`: number
- `createdAt`: timestamp
- `updatedAt`: timestamp

Role fields in Firestore are informational for the interface. Authorization is enforced with Firebase Auth custom claims, especially `role`, `admin`, and `superAdmin`.

## `report_media/{mediaId}`

- `id`: string
- `reportId`: string
- `ownerId`: string | null
- `type`: `image` | `video` | `voice`
- `storagePath`: string
- `contentType`: string
- `sizeBytes`: number
- `durationSeconds`: number | null
- `uploadedAt`: timestamp
- `status`: `pending` | `uploaded` | `orphaned` | `deleted`

## `report_categories/{categoryId}`

- `id`: string
- `label`: string
- `icon`: string
- `defaultUrgency`: `normal` | `urgent` | `critical`
- `active`: boolean
- `sortOrder`: number

## `admin_logs/{logId}`

- `id`: string
- `adminId`: string
- `action`: string
- `reportId`: string | null
- `targetUserId`: string | null
- `before`: map | null
- `after`: map | null
- `createdAt`: timestamp

Admin logs are append-only. They should be written by Cloud Functions for privileged actions and may also be created by claim-authorized admin clients for UI actions such as status updates.

## Storage Paths

Evidence files use this private path convention:

- `evidence/{ownerId}/{reportId}/{fileName}`

Owners can upload and read their own evidence. Admins can read evidence for review. Server-side cleanup uses the Admin SDK and bypasses client Storage rules.
