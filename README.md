# crimeApp

crimeApp is a Flutter and Firebase-based mobile and web platform designed to help users in Ghana report crimes and emergencies quickly, safely, and reliably even in low-connectivity conditions.

## Overview

The system combines a mobile reporting app for citizens with a web admin dashboard for authorised staff. It supports offline-first report creation, GPS-based location capture, voice-note evidence, media upload, and role-based admin review workflows.

The project is intended as a practical final-year information technology solution that addresses common challenges in emergency reporting, including:

- delayed reporting
- poor or unstable internet access
- inaccurate location descriptions
- privacy concerns around evidence and sensitive data
- limited access to fast digital reporting channels

## Problem Statement

Many users face delays and confusion when trying to report crimes or emergencies. In many cases, the reporting experience is either too slow, too complex, or inaccessible during low-connectivity situations. crimeApp aims to provide a simple and structured reporting channel that helps users submit accurate information quickly while giving admins tools to review and manage reports effectively.

## Goals

- Enable fast and easy submission of crime and emergency reports
- Support offline-first reporting so users can create reports without internet access
- Allow background synchronisation when connectivity is restored
- Support evidence capture using images, videos, and voice notes
- Enable admin users to review, filter, and update reports
- Protect sensitive evidence and personal information through secure backend controls

## Key Features

### Mobile App
- User registration and login
- Home screen with two primary actions:
  - Report Incident
  - One-tap Call 112 shortcut
- Incident reporting form with category, urgency, description, and location
- GPS location capture with GhanaPostGPS digital address fallback
- Voice-note recording, playback, delete, and re-record controls
- Image, video, and voice-note evidence upload
- Offline-first local storage of reports
- Automatic background upload when connectivity returns
- Status tracking for reports such as Pending, Uploading, Submitted, and Failed

### Admin Dashboard
- Secure login for authorised admins
- Dashboard summary cards for reports, urgent cases, pending cases, and resolved cases
- Real-time visual and audible alerts for urgent incoming reports
- Report filtering by category, location, date, urgency, and status
- Report detail view with evidence and map location
- Voice-note playback for admin review
- Report status updates and notes
- Spam or false-report flagging

### Backend and Security
- Firebase Authentication
- Firestore for structured report storage
- Firebase Storage for media evidence
- Cloud Functions for server-side validation and cleanup tasks
- Firestore and Storage security rules
- Custom claims for role-based access control
- Rate limiting and abuse prevention mechanisms

## PRD Summary

This repository is based on the project PRD and is structured around the following major requirements:

- Mobile-first reporting experience suitable for emergencies
- Offline-first architecture rather than a fallback approach
- Secure handling of sensitive reports and evidence
- Role-based access to admin features
- Location support using GPS and GhanaPostGPS fallback
- Voice-note support in local dialects and emergency contexts
- Admin dashboard for case handling and escalation

## Technology Stack

- Mobile app: Flutter
- Admin dashboard: Flutter Web
- Backend: Firebase
- Database: Firestore
- Storage: Firebase Storage
- Authentication: Firebase Authentication
- Server logic: Cloud Functions
- Local persistence: Hive or SQLite-compatible storage

## Project Structure

```text
crimeApp/
├── docs/
│   └── prd.json
├── apps/
│   ├── mobile/
│   └── admin/
├── firebase/
│   ├── firestore.rules
│   ├── storage.rules
│   └── functions/
└── README.md
```

## Development Phases

The PRD recommends the following delivery phases:

1. Requirements analysis and documentation
2. UI/UX design and project scaffolding
3. Authentication and app navigation
4. Offline-first report creation flow
5. Background synchronisation and media handling
6. Admin dashboard development
7. Testing and bug fixing
8. Deployment preparation
9. Final review and presentation

## MVP Scope

The initial minimum viable product will include:

- Flutter mobile application
- User registration and login
- Incident reporting workflow
- GPS capture and GhanaPostGPS fallback
- Image upload
- Voice-note reporting and upload
- Offline-first saving and sync
- Firebase backend
- Admin dashboard for report management
- One-tap Call 112 shortcut

## Setup Roadmap

### 1. Create Firebase Project
- Create a new Firebase project in the Firebase console
- Enable Authentication, Firestore, Storage, and Cloud Functions
- Choose a suitable region such as europe-west

### 2. Set Up Flutter
- Install Flutter SDK
- Verify the installation with:

```bash
flutter doctor
```

### 3. Create the Apps
- Create the mobile app
- Create the admin web app
- Connect both to the same Firebase project

### 4. Configure Security Rules
- Set up Firestore rules
- Set up Storage rules
- Configure admin access using Firebase custom claims

### 5. Build Core MVP Features
- Authentication
- Report form flow
- GPS and GhanaPostGPS integration
- Voice-note recording and playback
- Offline-first storage and sync
- Admin dashboard views and status updates

### 6. Test and Deploy
- Unit tests
- Integration tests
- Offline mode tests
- Security tests
- Deployment and billing safeguards

## Acceptance Criteria

The project will be considered successful when:

- users can install and open the app
- users can create accounts and log in
- users can submit crime and emergency reports
- reports can be created offline and synced later
- admins can view and update reports
- unauthorised users cannot access admin data or private media
- urgent reports trigger a visible and audible admin alert

## Risks and Mitigations

- Poor connectivity → use offline-first local storage and background sync
- Unauthorised access → use Firebase security rules and custom claims
- Large media uploads → compress files and limit size where possible
- Duplicate offline submissions → use client-generated UUIDs for idempotent writes
- Limited time → focus on the MVP first

## License

This project is intended for academic and demonstration purposes unless otherwise stated.

## Contact

For project collaboration or questions, please reach out through the repository maintainer.


# MVP Scope

## Mobile App
- User registration/login
- Home screen with Report Incident and Call 112
- Offline-first report creation
- GPS and GhanaPostGPS fallback
- Image evidence
- Voice note recording/playback
- Background sync
- My Reports and status tracking

## Admin Dashboard
- Admin login
- Overview metrics
- Report list and filters
- Report details with evidence, voice note, and location
- Status updates, notes, spam flag
- Real-time urgent alert

## Backend
- Firebase Auth
- Firestore
- Firebase Storage
- Cloud Functions
- Firestore and Storage rules
- Custom claims
- Emulator workflow