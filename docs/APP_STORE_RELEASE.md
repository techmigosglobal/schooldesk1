# Arish Ville iOS App Store release

This checklist complements Apple's current App Review Guidelines. It reduces
avoidable submission failures, but Apple makes the final review decision.

## 1. Prepare the local archive

1. Update `version` in `pubspec.yaml`. Every upload needs a new build number.
2. Confirm `env.supabase.json` contains the production Supabase and Firebase
   values and remains untracked.
3. Run `scripts/prepare-ios-release.sh`.
4. Open `ios/Runner.xcworkspace`, not the `.xcodeproj` file.
5. Select the `Runner` scheme and `Any iOS Device (arm64)`.
6. Select Product > Archive.
7. In Organizer, run Validate App before uploading.

The preparation script writes the production values into Flutter's generated
Xcode configuration. `EnvConfig.validate()` also prevents a Release build with
missing Supabase/Firebase configuration from launching silently.

## 2. Xcode Cloud

Create the App Store Connect app record manually before onboarding Xcode Cloud.
Use bundle ID `com.techmigos.arishville` and an available App Store name. Add
the following Xcode Cloud environment variables before starting a workflow:

- `API_BASE_URL`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `FIREBASE_API_KEY`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_IOS_APP_ID`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_STORAGE_BUCKET`

Mark values secret where appropriate. `ci_scripts/ci_post_clone.sh` installs
the pinned Flutter version and generates the Release configuration.

## 3. App Store Connect metadata

- Name: use the exact available brand name, at most 30 characters.
- Subtitle draft: `School ERP for Every Role`
- Primary category: Education.
- Secondary category: Productivity.
- Keyword draft: `school,ERP,parent,teacher,attendance,homework,fees,timetable,notices,student`
- Provide a public Support URL and Privacy Policy URL.
- Upload accurate iPhone and iPad screenshots showing real app screens.
- Complete age-rating, content-rights, export-compliance, and App Privacy forms.
- Supply working principal, teacher, and parent demo accounts in Review Notes.
- Keep the production Supabase backend available throughout review.

## 4. Privacy answers to verify with the school

The App Privacy form must reflect the actual production data and retention
policy. Review at least these likely categories before answering:

- Contact information: names, email addresses, phone numbers.
- User content: messages, documents, homework, photos, and uploaded proof.
- Identifiers: account IDs and push-notification device tokens.
- Health information: health reminders or student health records, if enabled.
- Financial information: school fee balances and payment records, if enabled.
- Diagnostics: crash or error information, if production reporting is enabled.

Do not declare tracking unless data is actually linked across third-party apps
or websites for advertising or measurement. Firebase Analytics is disabled in
the bundled Firebase configuration, but Firebase Messaging device-token data
still needs to be considered in the privacy answers.

## 5. Review notes draft

`Arish Ville is a role-based school operations app for authorized school staff
and parents. Accounts are provisioned by the school; public self-registration
is not offered. No digital content is sold in the app. The Fees area records
offline school-fee payments and uploaded proof. Push notifications are used for
school notices and reminders. Demo credentials for each role are provided
below. The Supabase production backend will remain available during review.`

Add demo usernames/passwords and any sample QR code required to exercise the
attendance flow. Never place production administrator credentials in notes.
