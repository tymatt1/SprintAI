# Data handling

This document describes the code in this repository. It is not a replacement for the owner-reviewed privacy policy and App Store disclosures required for a distributed release.

## On-device features

Motion samples are held in a short in-memory window for inference. Completed sprint records (identifier, date, duration, and display color) are stored in the app's UserDefaults domain. The app does not upload motion samples or history.

The system Photos picker grants access to a selected video. The app copies that selection into its temporary directory, processes pose landmarks locally, and creates an annotated temporary export. Clearing a video removes the app-owned import and completed export; cancellation/failure removes partial output. iOS may also purge temporary files. Saving an export requests add-only Photos permission and preserves the saved Photos copy.

The app contains no analytics SDK or tracking identifiers. Its manifest declares UserDefaults for app-owned preferences (`CA92.1`) and system uptime for elapsed-time display (`35F9.1`), based on [Apple's approved API reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons?language=objc). Third-party framework manifests and release disclosures still need review before App Store submission.

## Optional feedback

After the user chooses to send frames, up to 14 JPEG frames and a summary of measured angles are sent to the configured feedback server. The reference gateway forwards them to OpenAI, requests `store: false`, and does not write frames, responses, access tokens, or provider error bodies to disk or request logs. Provider-side retention and deployment-platform logging are governed by the owner's configuration and provider terms; this repository does not assert zero retention.

The backend access token is stored in the device Keychain with `WhenUnlockedThisDeviceOnly` accessibility. The endpoint URL is stored in UserDefaults. OpenAI API keys belong exclusively on the server, consistent with [OpenAI's authentication guidance](https://developers.openai.com/api/reference/overview).

The gateway's development token and in-memory rate limits are not a production authentication/abuse-control system. Before deploying, configure per-user authentication, HTTPS, quotas, request limits, retention, and operational logging deliberately.

## Before a release

- Revoke the API credential that existed in the original private app source; deleting it from source does not revoke it.
- Review the complete app and third-party SDK privacy manifests.
- Publish an accurate privacy policy and complete App Store data disclosures for the actual hosted deployment.
- Review consent, retention, deletion, and access behavior for any real athlete footage used in demos.
