# Kinvo

Flutter app for Kinvo, a multi-mode social connection app. It talks to the
Kinvo REST API in `kinvo-backend`.

## Requirements

- Flutter 3.44 or newer
- Android: SDK 36 and JDK 17. iOS: Xcode and CocoaPods, iOS 15 or newer
  (Firebase's minimum).

The iOS `Podfile` is checked in because it sets
`BYPASS_PERMISSION_LOCATION_ALWAYS` for the location plugin. Without it, App
Store Connect asks for a background-location purpose string the app has no
use for. Keep that block if the Podfile is regenerated.

## Running

Build-time configuration comes from a JSON file in `env/`:

```bash
flutter run --dart-define-from-file=env/staging.json
```

| Key                 | Purpose                                                                                                                     |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `API_BASE_URL`      | Root of the REST API, including `/api/v1`. Must use `https`, except for local hosts (`localhost`, `127.0.0.1`, `10.0.2.2`). |

These values are compiled into the app, so never put secrets in them. A build
without the file still starts, but its first API call fails with an
`AppConfigException` explaining what to pass. Push notifications need a few
more keys, listed under [Push notifications](#push-notifications).

## Checks

```bash
flutter analyze
flutter test
```

`analysis_options.yaml` turns on strict casts, inference and raw types. Keep
`flutter analyze` free of issues.

Tests that need the whole app use `pumpKinvoApp` from
`test/helpers/app_harness.dart`, which runs it on in-memory storage against a
fake backend. For flows that change data, such as onboarding, answer requests
with `FakeKinvoServer`, which remembers what the app saves and follows the
API's rules. The camera, photo library and location are always faked
(`test/helpers/device_fakes.dart`), because they need a real device.

Format only the files you add or rewrite: many older files predate the current
Dart style, and reformatting them belongs in a change of its own.

## Layout

```
lib/src/
  core/
    auth/        session: tokens, refresh, status; the signed-in account
    config/      build-time configuration (AppConfig) and the server's
                 catalogue of modes, interests and limits (ServerConfig)
    device/      device id, platform, app version, and the phone's model
                 and system, sent to the API
    entitlements/ paywalls: what the server says needs an upgrade
    forms/       sorting the server's validation errors onto form fields
    location/    the device's approximate location
    media/       picking photos, preparing them, and uploading files
    network/     API client, response envelope, errors, retry policy
    push/        push notifications (Firebase), this phone's registration
                 for them, and the app icon badge
    realtime/    the live connection (Socket.IO) and when it's open
    storage/     secure storage and preferences
    navigation/  routes, router and route guard
    theme/       colours and typography
    time/        clock and calendar dates
    units/       distance units (miles or kilometres) and their wording
    widgets/     shared widgets
  features/system/  splash, account suspended and not-found screens
  features/<feature>/
    data/          API calls and the services that use them
    domain/        models and rules
    presentation/  controllers (Riverpod notifiers), screens, widgets
```

## Navigation

The router is go_router, from `appRouterProvider`. Every location is in
`AppRoutes`; build links from its constants and helpers, never by hand.

- `context.go` changes place, for example after finishing a flow.
  `context.push` opens a screen the user comes back from, and `context.pop`
  can hand a result back to it.
- The five tabs are a `StatefulShellRoute`, so each keeps its own stack and
  state. Screens opened from a tab, such as a chat, cover the bottom navigation.
- `redirectFor` in `route_guard.dart` decides who can go where. The router runs
  it again whenever the session or the account changes:
  - While the saved session is read, the splash screen shows, then continues to
    the link that was opened.
  - A suspended account only reaches the suspension screen.
  - Signed out, only the welcome, sign-up and log-in screens are open.
  - Signed in, the splash screen shows while `GET /auth/me` loads and offers a
    retry if it fails. Onboarding follows until the account is onboarded, then
    the app opens.
- After anything that changes the account, such as finishing onboarding,
  invalidate `currentAccountProvider`. The router follows the new account.
- Unknown locations, and links to something that no longer exists, show
  `NotFoundScreen`.
- The log-in and sign-up screens offer phone and Google only while
  `GET /config` `sign_in` says the server can complete them
  (`signInMethodsProvider`), and Google only in builds set up for it. Apple
  isn't offered yet. Email is always there.
- Each feature reads and writes through a repository interface whose provider
  returns the API's implementation. Tests keep the real client and answer its
  requests from a fake server (`test/helpers/fake_kinvo_server.dart`).

## Calling the API

Repositories get an `ApiClient` from `apiClientProvider`.

- Paths are relative to `API_BASE_URL` and start with `/`, for example `/auth/me`.
- Responses are unwrapped from the backend's envelope. List endpoints return a
  `CursorPage<T>`; pass its `nextCursor` back unchanged to load the next page.
- Every failure is an `ApiException`, and a `switch` over it is exhaustive:
  - `ApiErrorException`: the server's error envelope. Branch on `code`, never
    on `message`, which is for display. `fieldErrors` holds validation messages
    and `details` holds paywall context.
  - `NetworkException`: offline, timed out, or no secure connection.
  - `UnexpectedResponseException`: a body that doesn't match the contract,
    such as a CDN error page.
  - `RequestCancelledException`: the caller cancelled.
- Riverpod retries a failed provider only when the failure is transient; see
  `lib/src/core/network/api_retry_policy.dart`.
- Endpoints that don't use the session, such as sign-in, use
  `publicApiClientProvider` instead.

## Sessions

`SessionManager` (`sessionManagerProvider`) owns the session. Features never
read or store tokens themselves.

- After a successful sign-in, pass the response to
  `signIn(AuthTokens.fromResponse(...))`. With `remember: false` the session
  stays in memory and ends when the app closes. `signOut()` ends the session on
  the device at once and revokes it on the server in the background.
- `sessionStatusProvider` holds `SessionRestoring`, `SignedIn`,
  `SignedOut(reason)` or `AccountSuspended(message)`. Routing can listen to
  `SessionManager.status` directly.
- Requests through `apiClientProvider` carry the access token. It's refreshed a
  minute before it expires, and a request answered `AUTH_TOKEN_EXPIRED` is
  retried once. Concurrent requests share one refresh, because the backend
  treats a reused refresh token as theft and signs the user out on every device.
- Being offline or rate limited never signs anyone out. Only the server
  rejecting the session (`AUTH_TOKEN_INVALID`) does.
- Every request sends `X-Device-Id`, `X-Platform`, `X-App-Version` and
  `Accept-Language`, and `X-Device-Model` and `X-OS-Version` when the phone
  says (from `device_info_plus`). The server labels the device list with
  them.
- The server can sign one device out from another (Settings → Privacy →
  Signed-in devices). Its next request or reconnect is refused with
  `AUTH_TOKEN_INVALID`, which ends the session there as usual.

Storage:

- Tokens are kept in the Keychain on iOS (readable after the first unlock, never
  restored onto another device) and in Keystore-backed encrypted storage on
  Android.
- The iOS Keychain survives uninstalling the app, so tokens left by a previous
  installation are discarded on first launch.
- Android backups and device-to-device transfer are turned off in
  `AndroidManifest.xml` and `res/xml/data_extraction_rules.xml`, because
  restored tokens can't be decrypted on another device. Users sign in again
  after moving to a new phone.

## Accounts

- `EmailAuthService` creates accounts (`POST /auth/register`) and signs in
  (`POST /auth/login`). Both send the device id, so the session shows up in
  the account's device list, and both start the session through
  `SessionManager`.
- Settings logs out, and deletes the account with `DELETE /users/me`. Profile
  setup offers logging out too, since a new account starts there.
- When the server ends a session, the app returns to the welcome screen and
  says why.

Signing in without a password:

- **Phone.** `PhoneAuthService` asks for a code (`POST /auth/otp/send`) and
  signs in with it (`POST /auth/otp/verify`). Twilio makes, holds and checks
  the code; nothing about it is stored here. The number is checked on the
  device first, so a typo cannot buy an SMS.
- **Google.** `SocialAuthService` carries Google's ID token to
  `POST /auth/google` and nothing else — the server verifies it against
  Google's keys and the client it was minted for. `GoogleIdentity` wraps the
  vendor package so tests never talk to Google; backing out returns null
  rather than throwing, because changing your mind is not a failure.
- Both create an account when there is none, and the router sends it to
  onboarding, because neither a phone number nor a Google account carries a
  date of birth.
- A build without `GOOGLE_SERVER_CLIENT_ID` hides the Google button instead of
  failing when it is pressed. The value is the **web** client id from the
  Google project (`client_type: 3` in `google-services.json`), and the server's
  `GOOGLE_OAUTH_CLIENT_IDS` must list the same one: the app asks Google for a
  token with it, and the server refuses a token minted for anything else.
  Android also needs the app's signing fingerprint registered in the Firebase
  console, or Google refuses the app itself.
- Logging out calls `forgetGoogle()`, so the next sign-in asks which account to
  use instead of reaching for the one that just left.

Forgotten passwords:

- "Forgot password?" on the log-in screen asks the server to email a six-digit
  code (`POST /auth/forgot-password`). The next screen takes that code and a
  new password (`POST /auth/reset-password`), then signs in with them.
- The server answers the same whether or not the address has an account, so no
  screen may suggest one exists. Wrong, expired, already used and out-of-guesses
  codes all come back as one message, shown under the code field.
- A code lasts an hour and works once, and asking for another retires it — so
  the code box empties when a new one is sent, and the app waits a minute
  between asks, because the server allows five an hour per address.
- A development server with no way to send email hands the code back in its
  response. The app never shows it: the code only ever comes by email.
- A reset ends every session the account had, so the app signs in again with
  the new password. If that sign-in fails, the password is still the new one:
  the app says so on the log-in screen rather than sending the user back for a
  code that has already been spent.

Forms:

- `AccountRules` repeats the backend's validation, messages included, so
  mistakes show before anything is sent. Keep it in step with
  `src/modules/auth/auth.schema.ts` in the backend.
- Errors show after the first attempt to submit and update as the user types.
  The server's field errors appear under the matching field (see
  `sortFieldErrors`); anything else appears above the submit button.
- Dates without a time, such as a date of birth, are `CalendarDate`s, sent as
  `YYYY-MM-DD`. Code that needs today's date reads `clockProvider`, so tests can
  fix it.

## Onboarding

A new account sets up its profile in five steps before the app opens: about
you, photos, interests, the modes it's here for, and location. Together they
meet the backend's checklist (`GET /onboarding`), and finishing calls
`POST /onboarding/complete`.

- `OnboardingController` loads everything the steps show at once, then opens
  at the first step with something missing, so leaving and coming back resumes
  where the user was.
- Each step saves when the user continues, then reports what it saved to
  `OnboardingController`. Going back shows the saved values.
- If finishing is refused because something is missing, for example a photo
  removed on another device, onboarding returns to that step and says so.
- The date of birth is asked for only when the account has none, as after a
  social or phone sign-in.
- Mode names, interests and limits come from `GET /config` (`ServerConfig`),
  so the server can add them without an app release. Modes that need a
  verified identity, such as Cuddle, are shown but can't be chosen.

## Discover

The Discover tab shows today's deck for one of the modes the user has switched
on (`GET /discovery/{mode}/deck`), starting on their main mode.

- The deck is built once a day on the server, so pages are stable. The app
  fetches 25 cards at a time and the next page before the last few run out.
- Every mode passes, likes and super likes (`POST /discovery/{mode}/swipe`);
  only the words on the buttons change, and they come from `GET /config`.
  The next card shows as soon as a button is tapped. If the swipe fails, the
  card comes back; if it was already answered elsewhere, it just goes. Swipes
  go one at a time, so the server records them in order.
- Likes and super likes use a daily allowance; passes never do. A used-up
  allowance answers `QUOTA_EXCEEDED`, and a paid feature such as rewind, boost
  or seeing who liked you answers `PREMIUM_REQUIRED`. Both become a `Paywall`
  (`Paywall.fromError`) and open `showPaywallSheet`. The app never decides
  what's paid for itself: that's server data.
- When the deck runs out, the empty state reads the day's numbers from
  `GET /discovery/{mode}/stats`.
- Filters (distance, age range, verified only) are saved per mode with
  `PATCH /modes/{mode}`, which rebuilds today's deck on the server, and the
  app reads the deck again. There's no "online now" filter because the server
  has none.
- Distances arrive in metres and show in whole miles or kilometres, as the
  user chose in Settings (`distanceUnitProvider`), never more precisely than
  "less than a mile" or "less than 1 km". Activity shows as "Online now",
  "Active today" or "Active this week", never a time. Both are coarse on
  purpose: precise distances and times can be used to find where and when
  someone is.
- People can hide both. A hidden distance arrives as `null` and isn't shown;
  hidden activity arrives as `is_online: false` and `last_active_at: null`,
  on cards, profiles, matches, chats and live presence alike.
- Tapping a card opens the full profile (`GET /users/{id}`).

## Matches

The Matches tab has three lists: matches (`GET /matches`), people who liked the
user in the mode Discover is showing (`GET /discovery/{mode}/likes-you`), and
archived matches.

- Seeing who liked you is a paid feature. Without it, the tab shows how many
  are waiting, from the deck stats, and never who.
- Liking someone back from that list is a swipe like any other, and can make a
  match.
- Tapping a match opens its conversation. Unmatching and extending are in the
  conversation's menu (`DELETE /matches/{id}`, `POST /matches/{id}/extend`).
  The server decides whether a match has expired, so the app never works it
  out from clocks that disagree.
- The lists stay current without a refresh: new messages move a row's last
  message and unread count, people come online, new matches appear at the top,
  and a conversation archived, or brought back by a new message, moves between
  Matches and Archived. The Matches tab's badge counts unread messages
  (`GET /conversations/unread-count`).
- Someone liking the user back while the app is open is announced wherever
  the user is, with a way straight into the conversation.

## Chat

A conversation belongs to one match (`GET /conversations/{id}`). Messages load
newest first, 30 at a time, and further back as the user scrolls up.

- A message shows at once as "Sending…". Messages go one at a time, so they
  arrive in the order they were written, and the conversation stays alive
  until they have, even if the user leaves it. One that fails stays in place
  with a way to try again or delete it. A photo that uploaded but didn't send
  isn't uploaded again.
- Before a text is sent, the server's moderation looks at it
  (`POST /moderation/check`). If it warns, nothing is sent and the user sees
  why: they can edit the message, or send it anyway, which the message records
  (`moderation_overridden`). The check only advises: if it can't be reached,
  the message still goes, and the server scans every message sent regardless.
- A daily message limit (`QUOTA_EXCEEDED`) leaves the message failed and opens
  the paywall.
- A conversation that can't be replied to, because the match expired or ended
  or someone blocked someone, replaces the message box with a notice. The
  server gives the same answer for every reason, so nobody can find out they
  were blocked. Only expiry, which the match itself says, offers to extend.
- Photos go through `MediaUploader` as `chat_image`. A photo the user sent
  shows from the device, not downloaded again. Voice notes and videos show as
  such; recording and playing them isn't built yet.
- Received messages the server's moderation flagged carry a warning about
  money and personal details.
- Messages are marked read (`POST /conversations/{id}/read`) while the
  conversation is open and the app is on screen, which shows the other person
  "Read". The user's latest message says "Sent" or "Read".
- The menu has: view profile, mute, archive, extend (close to expiring),
  report, unmatch and block. Reporting (`POST /reports`) takes a reason from
  `GET /config`, details, up to five screenshots (`report_evidence`) and
  blocks too unless the user says not; it names the other person's latest
  message, so moderators know where to look. Blocking (`POST /blocks`) ends the
  match. Reports are anonymous.

## Live updates

`RealtimeConnection` (`core/realtime/`) is the app's one Socket.IO connection,
at `/socket.io` on the API's host, over WebSocket.

- `realtimeKeeperProvider` opens it while it's useful: signed in to an account
  that has finished onboarding, with the app on screen.
  Signing out closes it at once. Leaving the screen closes it after 30 seconds,
  so a trip to the camera doesn't show the user going offline.
- It sends the session's access token in the handshake. An expired token is
  refreshed and the connection tried again straight away; a session the
  server rejects is ended; a suspended account shows the suspension screen.
  Anything else, such as no network, is tried again after a wait that doubles
  from a second up to 30 seconds.
- While open it tells the server the user is active once a minute
  (`presence:ping`), and sends typing as the user writes (`typing:start`,
  `typing:stop`).
- Every event describes something the server already saved, so a missed one
  costs a refresh, never data. `LiveUpdates` reads each event once into a
  `LiveUpdate` for the screens that show it, alongside changes made on the
  device, such as sending or unmatching, that other screens should reflect.
- Events sent while the connection was closed never arrive, so anything that
  shows live data reads it again whenever the connection opens.
- Tests replace the socket with `FakeRealtimeServer`, which accepts or refuses
  connections, records what the app sends, and pushes events.

## Notifications

The server keeps every notification in a list (`GET /notifications`), and
sends each one as a push notification too, unless the user switched that kind
off.

- The bell on Discover opens the list, newest first and 30 at a time. New
  notifications join it as they arrive (`notification:new`). Opening one marks
  it read and goes to what it's about: the conversation for a message or a
  match, the likes for a like, the plan for a plan update, or the safety
  centre.
  `NotificationTarget` works out where from the category and data. "Mark all
  read" does what it says.
- The bell and the More tab show the unread count
  (`GET /notifications/unread-count`). It's read again when a notification
  arrives, a conversation is read (which reads its message notifications on
  the server), the connection reopens, or the app comes back to the screen.
  On iPhone the same number is on the app icon.
- Settings → Notifications says whether this phone allows notifications, with
  a way to turn them on, or to open the phone's settings once they've been
  refused. Below that is a switch for each kind
  (`PATCH /notifications/preferences/{category}`). Safety notifications can't
  be switched off.
- Once onboarding is done, the app invites the user once to turn notifications
  on, before the system asks. The system only asks once, so that prompt isn't
  spent on someone who hasn't seen why.

### Push notifications

Push notifications come through Firebase Cloud Messaging.

- `pushRegistrationKeeperProvider` keeps this phone's token registered
  (`POST /notifications/tokens`) while the user is signed in and allows
  notifications. It registers again when Firebase replaces the token, and when
  the app comes back to the screen, since notifications may have been switched
  on in the phone's settings. It tells the server to stop
  (`DELETE /notifications/tokens/{device_id}`) when they're refused. Signing
  out throws the token away, so the next account on the phone gets its own.
- Tapping a push opens what it's about and marks it read, whether it launched
  the app or brought it back. A push that arrives while the app is open shows
  as a banner with View, unless the user is already in that conversation.
- The server sends notification messages, which the phone shows by itself
  while the app isn't open. So there's no background handler and no
  background mode.
- On Android they use the "Matches, messages and plans" channel, which
  `MainActivity` creates at high importance, with `ic_stat_kinvo` as the small
  icon. Android 13 and newer ask for permission, as iOS does.
- When Firebase can't start, the app carries on without push, logs why, and
  settings say push is unavailable.
- Tests replace Firebase with `FakePushMessaging`, which sets the permission,
  rotates tokens, and delivers or taps notifications.

A build receives push notifications only with the Firebase settings for its
apps, added to the `env/` file. They identify the apps and ship inside them;
none is secret.

| Key                            | Value, from the Firebase console                          |
| ------------------------------ | --------------------------------------------------------- |
| `FIREBASE_PROJECT_ID`          | Project settings → Project ID                             |
| `FIREBASE_MESSAGING_SENDER_ID` | Project settings → Cloud Messaging → Sender ID            |
| `FIREBASE_ANDROID_API_KEY`     | `current_key` in the Android app's `google-services.json` |
| `FIREBASE_ANDROID_APP_ID`      | The Android app's App ID                                  |
| `FIREBASE_IOS_API_KEY`         | `API_KEY` in the iOS app's `GoogleService-Info.plist`     |
| `FIREBASE_IOS_APP_ID`          | The iOS app's App ID                                      |
| `FIREBASE_IOS_BUNDLE_ID`       | The iOS app's bundle ID                                   |

A build without them runs with push off. A build with only some of them throws
an `AppConfigException` naming what's missing, rather than quietly never
receiving a notification. Set a platform's keys all together, or leave them
all out.

Beyond the keys:

- The Firebase apps must use the app's real application ID and bundle ID.
  `com.example.kinvo` is a placeholder that the stores refuse.
- iOS: upload an APNs authentication key to the Firebase project (Project
  settings → Cloud Messaging). `Runner.entitlements` turns on push
  notifications. Its `aps-environment` says `development`, and Xcode signs
  store builds for production.
- The server sends with a Firebase service account
  (`FIREBASE_SERVICE_ACCOUNT_JSON`) from the same project.

## Plans

A plan is a suggestion to meet one match: a place, a day and time, how long,
and a note. The Plans tab lists them by where they stand
(`GET /plans?tab=upcoming|pending|history`, and `?drafts=true`).

- A plan is made from the Plans tab, choosing the match, or from a
  conversation's menu ("Suggest a plan"), which chooses it already. The place
  is one from Kinvo's list (`GET /venues`, with suggestions for the match's
  mode from `GET /venues/suggest/{match_id}`) or one typed in. Kinvo's list
  only covers a few cities so far, so typing a place is the usual way
  elsewhere.
- Sending proposes the plan (`propose: true`); saving it as a draft keeps it
  where only its creator can see it. The other person accepts or declines,
  from the list or the plan's page. The creator can change a draft or a
  proposal, and the other person is told about a change to a proposal. Either
  can cancel a plan that was sent, with a reason if they like; a draft is
  deleted instead (`DELETE /plans/{id}`), because a cancelled plan is visible to
  both people.
- Times are chosen in the phone's time and sent in UTC. A proposal whose time
  passes unanswered moves to History and can no longer be accepted.
- Unmatching or blocking closes the pair's plans on the server, and a plan with
  an account that was deleted or suspended stops being listed.
- The Plans tab's badge counts plans waiting on the user's answer
  (`GET /notifications/badges`). Lists, the badge and an open plan refresh
  when a plan notification arrives (`notification:new`, category
  `plan_update`), after the user's own changes, when the live connection
  reopens, and when the app comes back to the screen. A plan notification
  opens its plan.
- A confirmed plan can be emailed to trusted contacts ("Tell a trusted
  contact", `POST /plans/{id}/share`): who the user is meeting, where and
  when, in the user's own time.

## Safety

The Safety Center (More → Safety Center) holds the emergency alert, the
trusted contacts it reaches, and reporting someone.

- Trusted contacts (`/safety/contacts`) are up to five people Kinvo emails
  when the user needs help. They need an email address to be reached; one
  with only a phone number is kept, and shown as not reachable.
- The emergency alert (`POST /safety/emergency`) emails every trusted contact
  with an address: that the user needs help, roughly where they are, their
  message, and the plan they're on if there is one. The location is sent only
  if the phone already allows it: no permission dialog stands between someone
  in trouble and the alert, and the alert waits a few seconds at most for a
  position.
- The screen then shows exactly who was emailed, and who wasn't and why. It
  never says a contact was told unless the server says an email was sent. If
  the alert doesn't reach the server, it says so and offers to try again.
- Live location sharing isn't offered: the server can't show it to anyone yet.

## Support

More → Support & guidelines. Every row leads somewhere real.

- The Safety Center, always.
- The help centre, community guidelines, terms and privacy policy, each only
  once the server lists it under `GET /config` `support`. A page Kinvo
  hasn't published isn't shown.
- **Email support** starts an email in the phone's mail app, to the address in
  `support.email`. A phone with no mail app is shown the address to copy.
- Pages and emails open through `ExternalLinks` (`core/links/`, over
  `url_launcher`), which tests replace to see what would have opened.
- The welcome screen says what continuing agrees to only once both the terms
  and the privacy policy exist, and links to both.

## Profile

The Profile tab shows the user's own profile (`GET /users/me`): main photo,
name and age, work and place, how complete it is, and the steps that would
complete it (`completion_missing`, the steps worth most first).

- **Edit profile** saves each change on its own, as it's made; there's no
  form-wide Save button. Each detail opens its own editor:
  - text (name, bio, job title, organisation, city), checked against the
    server's limits before sending; an empty value takes it off the profile
  - answers picked from the lists `GET /config` publishes (education and the
    six lifestyle questions), with "Take it off my profile"
  - height on a slider, shown in centimetres and feet
    All of them go through `PATCH /users/me` with only the changed field, and
    `null` to clear it.
- **Photos** (`/media/photos`): add from the camera or photos (uploaded as in
  [Photos and uploads](#photos-and-uploads)), hold and drag to reorder, or tap
  one for "Make it my main photo", "Move earlier", "Move later" and "Delete".
  The main photo is always the first. Changes show at once and go back if the
  server refuses them. Once onboarding is done the server keeps the last
  photo, so the app doesn't offer to delete it.
- **Interests** (`PUT /users/me/interests`) are picked from the catalogue,
  up to its limit. **Prompts** (`PUT /users/me/prompts`): choose a question,
  write an answer; tap one to change or remove it.
- **How others see me** shows `GET /users/me/preview`, the server's own
  public view of the profile, with the same widgets as someone else's full
  profile.

## Settings and privacy

Settings are kept on the server (`/settings`), so they follow the user to a
new phone. `userSettingsProvider` holds them for the session.

- **Distance units:** miles or kilometres, for every distance in the app.
- **Distance and age range** open the same filters as Discover, for a mode.
- **Privacy** (More → Privacy, or Settings → Privacy):
  - "Show my distance" and "Show when I'm active". Hiding your activity hides
    only yours; you still see other people's.
  - **Take a break** (`POST /settings/snooze`, optionally until a time):
    nobody new sees the user in Discover, while matches and chats carry on.
    The Profile tab says so while it lasts.
  - **Signed-in devices** (`/devices`): each device with its model, system,
    app version and when it was last used. Signing one out, or all but this
    one, stops it working at once.
- Switches change at once and go back, with the reason, if saving fails.
  - **Who you meet** (`incognito`, `pause_new_matches`,
    `global_verified_only` on `/settings`), applied by the server:
    incognito shows the user only to people they have liked and to their
    matches; a pause keeps them visible but refuses their likes with
    `NEW_MATCHES_PAUSED` — Discover shows a "paused" line with Resume, and a
    refused like offers the same — and makes held matches on resume;
    verified people only applies in every mode, and the deck is refetched
    after it changes.

## Ads

Spec §7.4: Google AdMob, banners and interstitials, for the free plan only.

- **Who sees them is the server's answer**: the `show_ads` flag in
  `GET /entitlements`, read again when `entitlements:updated` arrives, so an
  upgrade takes the ads away at once. The app never works it out from a plan's
  name. Anything unknown means no ads — while loading, after a failure, and
  signed out.
- **Banners** sit above the navigation bar on Matches, Plans and More, and only
  on those tabs' own screens (`HomeShell._bannerPaths`). Never on Discover,
  where the swipe buttons are — an ad a thumb lands on by accident is an
  invalid click, and AdMob penalises the account for it. A banner takes no room
  until it has loaded.
- **Interstitials** come between cards in Discover, by
  `InterstitialPolicy`: every 15 swipes at most, at least 3 minutes apart,
  never in the first minute, and never on a swipe that made a match. One is
  loaded in advance; if none is ready when one is due, none shows.
- **Consent**: Google's consent message (UMP) is shown at launch where the law
  requires it — the UK and the EEA — and only to accounts that see ads. No ad
  is requested until it allows. The message itself is set up in AdMob, under
  Privacy & messaging; until it is, nothing is shown. Where the law requires a way to change the
  answer, Settings shows "Ad privacy choices".
- **Content**: nothing rated above T (teen).

| Setting                                                   | What it is                                                                   |
| --------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `-Pkinvo.admobAppId=ca-app-pub-…~…` (Gradle)              | The AdMob Android app. Google's sample app unless given.                     |
| `GADApplicationIdentifier` in `ios/Runner/Info.plist`     | The AdMob iOS app. Google's sample app until changed.                        |
| `ADMOB_ANDROID_BANNER_ID`, `ADMOB_ANDROID_INTERSTITIAL_ID` | Android ad units, as `--dart-define`s. Google's test units unless given.     |
| `ADMOB_IOS_BANNER_ID`, `ADMOB_IOS_INTERSTITIAL_ID`         | iOS ad units, the same way.                                                  |

Real IDs belong in a production build's settings only. A debug build always
asks for Google's test units whatever it is given, and `env/staging.json`
names none — tapping a real ad from a test build is invalid traffic, and AdMob
closes accounts over it.

No test reaches Google's SDK: the app talks to `AdsPlatform`, and tests use
`FakeAdsPlatform`, which records what it was asked to do.

## Photos and uploads

`MediaUploader` uploads the way the backend requires: ask for a presigned URL
(`POST /media/uploads`), send the bytes straight to storage, then have the
server check them (`POST /media/uploads/{id}/complete`). Only then can the
upload be attached, for example with `POST /media/photos`.

- The storage request goes through `storageDioProvider`, which sends no
  session or device headers and logs nothing: the presigned URL is itself a
  credential.
- Every photo is re-encoded on the device by `preparePhoto` before upload. That
  removes the metadata cameras add, including where the photo was taken, turns
  the pixels the right way up, and caps the longest side at 1600px.
- Picking and preparing photos goes through `photoPickerProvider`, so tests use
  a fake.
- Other people's photos are shown with `PersonPhoto`, which falls back to their
  initial while a photo loads, when there is none, and when its link has
  expired. Photo links from the API are presigned and time-limited.

## Location

`locationServiceProvider` asks for location permission when needed and finds
the device's approximate position.

- Only approximate location is requested (`ACCESS_COARSE_LOCATION` on Android,
  "when in use" on iOS), and the coordinates are rounded to about a kilometre
  before they leave the device. Distances shown between people could otherwise
  be used to work out where someone lives.
- The town and country come from the device's geocoder when it can name them.
  The position is saved even when it can't.
- A refusal the system won't ask about again, or location services being off,
  is explained with a button to open the right settings.
