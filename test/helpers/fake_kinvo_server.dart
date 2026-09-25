import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'fake_http_adapter.dart';
import 'fake_realtime_server.dart';

/// A backend that remembers what the app changes, for tests that walk through
/// whole flows such as onboarding.
///
/// It follows the real API's contract, including the rules the app has to
/// cope with: the modes limit, verification for Cuddle, upload checks and the
/// onboarding checklist. Each field is the server's current state and can be
/// set up front.
final class FakeKinvoServer {
  static const storageHost = 'storage.test';
  static const maxPhotos = 6;

  /// The signed-in user's id, as `GET /auth/me` gives it.
  static const userId = 'u1';

  /// The server's live connection, which delivers events to the app. Pass it
  /// to the app under test to receive them.
  final realtime = FakeRealtimeServer();

  String displayName = 'Sam Taylor';
  String? dateOfBirth = '1995-07-04';
  String? bio;
  ({double latitude, double longitude})? location;
  String? city;
  String? country;
  List<String> interests = [];
  final List<({String id, bool isPrimary})> photos = [];
  String? jobTitle;
  String? organisation;
  String? education;
  int? heightCm;

  /// Lifestyle answers, by question such as `drinking`.
  final Map<String, String> lifestyle = {};

  /// Prompt answers, in the order the profile shows them.
  List<({String slug, String answer})> prompts = [];

  String distanceUnit = 'miles';
  bool showDistance = true;
  bool showLastActive = true;

  /// Who you meet, as the server applies it: incognito, verified people only
  /// in every mode, and new matches paused.
  bool incognito = false;
  bool verifiedOnlyEverywhere = false;
  bool pauseNewMatches = false;

  /// When the user's break from Discover ends: `null` with [isSnoozed] for
  /// a break until they come back.
  bool isSnoozed = false;
  DateTime? snoozeEndsAt;

  /// Devices signed in to the account. The one whose id the request's
  /// `X-Device-Id` names is the current one.
  final List<FakeDevice> devices = [];

  /// Device ids signed out from the device list, in order.
  final List<String> devicesSignedOut = [];

  /// Modes switched on, in the order they were switched on.
  final List<String> enabledModes = [];
  String? primaryMode;
  int maxModes = 3;
  int maxInterests = 10;

  /// The ways of signing in the server says it can complete, as `sign_in`
  /// in `GET /config`.
  bool phoneSignIn = true;
  bool googleSignIn = true;

  /// What `support` in `GET /config` lists: nothing until a test sets it.
  String? supportEmail;
  String? helpUrl;
  String? guidelinesUrl;
  String? termsUrl;
  String? privacyUrl;

  /// Filters the user has changed, by mode. Anything left out is the
  /// server's default.
  final Map<String, Map<String, Object?>> modeFilters = {};

  /// Modes whose filters were saved, in order.
  final List<String> filtersSaved = [];

  /// The reset code outstanding for each address, as forgot-password left it.
  final Map<String, String> resetCodes = {};

  /// Whether a code comes back in the response, as it does from a deployment
  /// with no way to send email. A real production server never does this.
  bool returnsResetCode = false;

  /// How the app is asked to look: appearance, text size, movement and
  /// contrast, all kept on the server so they follow the account.
  String theme = 'system';
  double textScale = 1;
  bool reduceMotion = false;
  bool highContrast = false;

  /// How plans can be bought here: `test` as on staging, `none` as
  /// anywhere real users pay until RevenueCat.
  String purchaseMode = 'test';

  /// The account's latest subscription, live or not, or null when it has
  /// never had one.
  FakeSubscription? subscription;

  /// Plans bought by test purchase, by slug, in order.
  final List<String> testPurchases = [];

  /// How many times a test plan was ended.
  int testPlansEnded = 0;

  /// The password the last successful reset set.
  String? passwordAfterReset;

  int _resetCodesIssued = 0;
  bool isVerified = false;
  bool isOnboarded = false;

  /// Whether the user's plan includes rewind, boost, likes you and extending
  /// matches.
  bool isPremium = false;

  /// People in each mode's deck, in the order the deck shows them.
  final Map<String, List<FakePerson>> decks = {};

  /// Liking any of these, by user id, makes a match.
  final Set<String> likesBack = {};

  /// People who liked the user, by mode, newest first.
  final Map<String, List<FakePerson>> likesYou = {};

  /// Swipes made, by mode, oldest first.
  final Map<String, List<({String userId, String action})>> swipes = {};

  /// Likes allowed a day, or `null` for no limit.
  int? dailyLikes;
  int likesUsed = 0;

  /// Matches, newest first.
  final List<FakeMatch> matches = [];

  /// `mode:personId` for each match that has ended. The server keeps those as
  /// rows, so rewind still refuses the swipe, with no match left to offer.
  final Set<String> endedMatches = {};

  /// Calls, oldest first.
  final List<FakeCall> calls = [];

  /// Where the app would connect for picture and sound. Null by default,
  /// which is what a server with no video service answers, and what every
  /// test uses: a real address would need a real media server.
  String? videoServerUrl;

  /// In-call safety actions the app sent, in order.
  final List<({String callId, String action})> safetyActions = [];

  /// The boost running in each mode, by when it ends.
  final Map<String, DateTime> boostsEndingAt = {};

  /// People the user blocked, by id.
  final Set<String> blocked = {};

  /// Reports the user filed, as sent.
  final List<Map<String, Object?>> reports = [];

  /// Messages allowed a day, or `null` for no limit.
  int? dailyMessages;
  int messagesUsed = 0;

  /// What moderation warns about in a message, or `null` for nothing. Warns
  /// about money unless changed.
  String? Function(String content) moderate = (content) =>
      content.toLowerCase().contains('money')
      ? 'This message mentions money. Scammers often ask for it.'
      : null;

  /// Messages checked by moderation before sending, in order.
  final List<String> moderationChecks = [];

  /// The notification feed, newest first.
  final List<FakeNotification> notifications = [];

  /// Push notifications switched off, by category.
  final Set<String> pushOff = {};

  /// The push token registered for each device.
  final Map<String, String> pushTokens = {};

  /// Devices the app asked to stop pushing to, in order.
  final List<String> pushTokensRemoved = [];

  int _messageSequence = 0;

  /// The clock the server's timestamps come from.
  DateTime Function() now = () => DateTime.utc(2026, 9, 17, 10);

  /// Runs before the server's own handling. Return a response to answer the
  /// request yourself, for example to simulate a failure, or `null` to carry
  /// on as normal.
  Future<ResponseBody?> Function(RequestOptions options)? intercept;

  /// The account's identity check, or null when there has never been one.
  FakeVerification? verification;

  /// Bytes received by storage, by upload id.
  final Map<String, Uint8List> storedUploads = {};
  final Map<
    String,
    ({String purpose, String mimeType, int size, bool completed})
  >
  _uploads = {};

  /// Plans with the user's matches, in the order they were made.
  final List<FakePlan> plans = [];

  /// Kinvo's list of places, nearest first.
  final List<FakeVenue> venues = [];

  /// The places the user saved.
  final Set<String> savedVenues = {};

  /// The user's trusted contacts, oldest first.
  final List<FakeContact> contacts = [];

  /// Contacts whose email the fake pretends not to be able to send.
  final Set<String> undeliverable = {};

  /// Each emergency raised, as the app sent it.
  final List<Map<String, Object?>> emergencies = [];

  int _nextId = 1;

  static const interestCatalogue = [
    ('music', 'Music', 'general'),
    ('travel', 'Travel', 'general'),
    ('coffee', 'Coffee', 'food'),
    ('running', 'Running', 'fitness'),
    ('cozy_nights', 'Cozy nights', 'comfort'),
  ];

  static const promptCatalogue = [
    ('weekend_looks_like', 'A perfect weekend looks like…'),
    ('talk_for_hours', 'I could talk for hours about…'),
    ('go_to_order', 'My go-to order is…'),
    ('looking_for', "What I'm looking for is…"),
  ];

  static const lifestyleOptions = {
    'drinking': [
      'never',
      'rarely',
      'socially',
      'regularly',
      'prefer_not_to_say',
    ],
    'smoking': [
      'never',
      'rarely',
      'socially',
      'regularly',
      'prefer_not_to_say',
    ],
    'exercise': ['never', 'sometimes', 'often', 'daily', 'prefer_not_to_say'],
    'diet': ['omnivore', 'vegetarian', 'vegan', 'other', 'prefer_not_to_say'],
    'pets': ['none', 'dog', 'cat', 'other', 'multiple', 'prefer_not_to_say'],
    'children': [
      'none',
      'have_children',
      'want_children',
      'do_not_want_children',
      'open',
      'prefer_not_to_say',
    ],
    'education': [
      'high_school',
      'undergraduate',
      'postgraduate',
      'doctorate',
      'other',
      'prefer_not_to_say',
    ],
  };

  static const modeCatalogue = [
    ('dating', 'Dating', 'Meet someone new.'),
    ('study_buddy', 'Study Buddy', 'Find someone to study with.'),
    ('networking', 'Networking', 'Grow your professional circle.'),
    ('cuddle', 'Cuddle', 'Low-key company and comfort.'),
  ];

  /// What onboarding still needs, in the backend's order.
  List<String> get missing => [
    if (displayName.trim().isEmpty) 'display_name',
    if (dateOfBirth == null) 'date_of_birth',
    if ((bio?.trim() ?? '').isEmpty) 'bio',
    if (location == null) 'location',
    if (interests.isEmpty) 'interests',
    if (photos.isEmpty) 'photo',
    if (enabledModes.isEmpty) 'mode',
  ];

  /// Sets up everything onboarding needs except what's in [except].
  void completeProfile({Set<String> except = const {}}) {
    if (!except.contains('bio')) bio = 'I like long walks.';
    if (!except.contains('location')) {
      location = (latitude: 53.8, longitude: -1.55);
      city = 'Leeds';
      country = 'GB';
    }
    if (!except.contains('interests')) interests = ['music'];
    if (!except.contains('photo')) photos.add((id: 'photo-0', isPrimary: true));
    if (!except.contains('mode')) {
      enabledModes.add('dating');
      primaryMode = 'dating';
    }
  }

  Future<ResponseBody> respond(RequestOptions options) async {
    if (await intercept?.call(options) case final response?) return response;

    if (options.uri.host == storageHost) return _store(options);

    final path = options.uri.path.replaceFirst('/api/v1', '');
    final body = switch (options.data) {
      final Map<String, Object?> data => data,
      _ => const <String, Object?>{},
    };
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();

    return switch ((options.method, segments)) {
      ('GET', ['auth', 'me']) => _ok({
        'id': userId,
        'display_name': displayName,
        'is_onboarded': isOnboarded,
      }),
      ('POST', ['auth', 'logout']) => _ok({'signed_out': true}),
      ('POST', ['auth', 'forgot-password']) => _sendResetCode(body),
      ('POST', ['auth', 'reset-password']) => _resetPassword(body),
      ('GET', ['config']) => _ok(_config()),
      ('GET', ['onboarding']) => _ok(_status()),
      ('POST', ['onboarding', 'date-of-birth']) => _setDateOfBirth(body),
      ('POST', ['onboarding', 'complete']) => _complete(),
      ('GET', ['users', 'me']) => _ok(_profile()),
      ('DELETE', ['users', 'me']) => _ok({
        'deleted_at': '2026-09-15T10:00:00.000Z',
      }),
      ('PATCH', ['users', 'me']) => _updateProfile(body),
      ('PATCH', ['users', 'me', 'location']) => _updateLocation(body),
      ('PUT', ['users', 'me', 'interests']) => _setInterests(body),
      ('PUT', ['users', 'me', 'prompts']) => _setPrompts(body),
      ('GET', ['users', 'me', 'preview']) => _ok(_preview()),
      ('GET', ['media', 'photos']) => _ok(_album()),
      ('PATCH', ['media', 'photos', 'reorder']) => _reorderPhotos(body),
      ('PATCH', ['media', 'photos', final id, 'primary']) => _makeMainPhoto(id),
      ('GET', ['settings']) => _ok(_settings()),
      ('PATCH', ['settings']) => _updateSettings(body),
      ('POST', ['settings', 'snooze']) => _snooze(body),
      ('DELETE', ['settings', 'snooze']) => _endSnooze(),
      ('GET', ['devices']) => _devices(options),
      ('DELETE', ['devices', 'others']) => _signOutOtherDevices(options),
      ('DELETE', ['devices', final id]) => _signOutDevice(id),
      ('POST', ['media', 'uploads']) => _createUpload(body),
      ('POST', ['media', 'uploads', final id, 'complete']) => _completeUpload(
        id,
      ),
      ('POST', ['media', 'photos']) => _addPhoto(body),
      ('GET', ['subscriptions', 'products']) => _ok({
        'products': planCatalogue,
        'purchase_mode': purchaseMode,
      }),
      ('GET', ['subscriptions', 'me']) => _ok(_currentPlanView()),
      ('GET', ['entitlements']) => _ok(_entitlementsView()),
      ('POST', ['subscriptions', 'test-purchase']) => _testPurchase(body),
      ('DELETE', ['subscriptions', 'test-purchase']) => _endTestPlan(),
      ('GET', ['verification']) => _ok(_verificationView()),
      ('POST', ['verification']) => _startVerification(body),
      ('POST', ['verification', final id, 'document']) =>
        _attachVerificationDocument(id, body),
      ('POST', ['verification', final id, 'submit']) => _submitVerification(id),
      ('DELETE', ['media', 'photos', final id]) => _deletePhoto(id),
      ('GET', ['discovery', final mode, 'deck']) => _deck(mode, options),
      ('POST', ['discovery', final mode, 'swipe']) => _swipe(mode, body),
      ('POST', ['discovery', final mode, 'rewind']) => _rewind(mode),
      ('GET', ['discovery', final mode, 'stats']) => _stats(mode),
      ('POST', ['discovery', final mode, 'boost']) => _boost(mode),
      ('GET', ['discovery', final mode, 'likes-you']) => _likesYou(mode),
      ('GET', ['matches']) => _matches(options),
      ('GET', ['matches', final id]) => _match(id),
      ('GET', ['conversations', 'unread-count']) => _ok({
        'unread_count': _unreadTotal(),
      }),
      ('GET', ['conversations', final id]) => _conversation(id),
      ('PATCH', ['conversations', final id]) => _updateConversation(id, body),
      ('GET', ['conversations', final id, 'messages']) => _messages(
        id,
        options,
      ),
      ('POST', ['conversations', final id, 'messages']) => _sendMessage(
        id,
        body,
      ),
      ('POST', ['conversations', final id, 'read']) => _markRead(id),
      ('POST', ['moderation', 'check']) => _checkMessage(body),
      ('GET', ['notifications']) => _notifications(options),
      ('GET', ['notifications', 'unread-count']) => _ok({
        'unread_count': notifications
            .where((each) => each.readAt == null)
            .length,
      }),
      ('POST', ['notifications', 'read-all']) => _readAllNotifications(),
      ('GET', ['notifications', 'preferences']) => _ok(_preferences()),
      ('PATCH', ['notifications', 'preferences', final category]) =>
        _updatePreference(category, body),
      ('POST', ['notifications', 'tokens']) => _registerPushToken(body),
      ('DELETE', ['notifications', 'tokens', final deviceId]) =>
        _removePushToken(deviceId),
      ('POST', ['notifications', final id, 'read']) => _readNotification(id),
      ('GET', ['notifications', 'badges']) => _ok(_badges()),
      ('GET', ['plans']) => _plans(options),
      ('POST', ['plans']) => _createPlan(body),
      ('GET', ['plans', final id]) => _plan(id),
      ('PATCH', ['plans', final id]) => _updatePlan(id, body),
      ('DELETE', ['plans', final id]) => _deleteDraft(id),
      ('POST', ['plans', final id, 'propose']) => _proposePlan(id),
      ('POST', ['plans', final id, 'respond']) => _respondToPlan(id, body),
      ('POST', ['plans', final id, 'cancel']) => _cancelPlan(id, body),
      ('POST', ['plans', final id, 'share']) => _sharePlan(id, body),
      ('GET', ['safety', 'contacts']) => _ok({
        'contacts': [for (final contact in contacts) contact.toJson()],
      }),
      ('POST', ['safety', 'contacts']) => _addContact(body),
      ('PATCH', ['safety', 'contacts', final id]) => _updateContact(id, body),
      ('DELETE', ['safety', 'contacts', final id]) => _deleteContact(id),
      ('POST', ['safety', 'emergency']) => _raiseEmergency(body),
      ('GET', ['calls']) => _callHistory(),
      ('POST', ['calls']) => _startCall(body),
      ('POST', ['calls', final id, 'answer']) => _answerCall(id),
      ('POST', ['calls', final id, 'decline']) => _declineCall(id),
      ('POST', ['calls', final id, 'end']) => _endCall(id),
      ('GET', ['calls', final id, 'token']) => _callToken(id),
      ('POST', ['calls', final id, 'safety']) => _callSafetyAction(id, body),
      ('GET', ['venues']) => _venues(options),
      ('GET', ['venues', 'saved']) => _ok({
        'venues': [
          for (final venue in venues)
            if (savedVenues.contains(venue.id)) _venueView(venue),
        ],
      }),
      ('GET', ['venues', 'suggest', final matchId]) => _suggestVenues(matchId),
      ('POST', ['venues', final id, 'save']) => _saveVenue(id, save: true),
      ('DELETE', ['venues', final id, 'save']) => _saveVenue(id, save: false),
      ('POST', ['blocks']) => _block(body),
      ('POST', ['reports']) => _report(body),
      ('DELETE', ['matches', final id]) => _unmatch(id),
      ('POST', ['matches', final id, 'extend']) => _extend(id),
      ('GET', ['users', final id]) => _publicProfile(id),
      ('GET', ['modes']) => _ok(_modes()),
      ('PATCH', ['modes', final mode]) => _updateMode(mode, body),
      ('POST', ['modes', final mode, 'primary']) => _makePrimary(mode),
      _ => jsonResponse(404, errorEnvelope('NOT_FOUND', 'Not found.')),
    };
  }

  // --- Discovery -----------------------------------------------------------

  ResponseBody? _requireEnabled(String mode) {
    if (enabledModes.contains(mode)) return null;
    return _error(
      400,
      'BAD_REQUEST',
      'Turn this mode on before browsing it.',
      details: {'mode': mode, 'is_enabled': false},
    );
  }

  ResponseBody _premiumRequired(String feature, String message) {
    return _error(
      403,
      'PREMIUM_REQUIRED',
      message,
      details: {
        'required_feature': feature,
        'current_tier': 'free',
        'upgrade_available': true,
      },
    );
  }

  /// The mode's deck as the server builds it, with each card's place in it:
  /// everyone within the mode's filters, less anyone already swiped.
  ///
  /// Places don't move when a card is swiped, as on the server, so a cursor
  /// taken before a swipe still points at the same card after it.
  List<(int, FakePerson)> _deckFor(String mode) {
    final filters = _modeView(mode, mode);
    final swiped = {...?swipes[mode]?.map((swipe) => swipe.userId)};
    final built = [
      for (final person in decks[mode] ?? const <FakePerson>[])
        if (person.age >= (filters['min_age']! as int) &&
            person.age <= (filters['max_age']! as int) &&
            person.distanceMetres <= (filters['radius_metres']! as int) &&
            (filters['verified_only'] != true || person.isVerified))
          person,
    ];
    return [
      for (final (position, person) in built.indexed)
        if (!swiped.contains(person.id)) (position, person),
    ];
  }

  ResponseBody _deck(String mode, RequestOptions options) {
    if (_requireEnabled(mode) case final refused?) return refused;
    final limit =
        int.tryParse('${options.queryParameters['limit'] ?? ''}') ?? 20;
    final after =
        int.tryParse('${options.queryParameters['cursor'] ?? ''}') ?? -1;
    final remaining = [
      for (final card in _deckFor(mode))
        // Verified people only, everywhere: the server rebuilds the deck
        // without anyone unverified.
        if (card.$1 > after && (!verifiedOnlyEverywhere || card.$2.isVerified))
          card,
    ];
    final page = remaining.take(limit).toList();
    final hasMore = remaining.length > page.length;
    return _list(
      [
        for (final (position, person) in page)
          {
            'entry_id': 'entry-$mode-${person.id}',
            'position': position,
            'distance_metres': person.distanceMetres,
            'user': person.compact(now()),
            'photos': person.photos,
            'bio': person.bio,
            'interests': person.interests,
          },
      ],
      nextCursor: hasMore ? '${page.last.$1}' : null,
      limit: limit,
    );
  }

  ResponseBody _swipe(String mode, Map<String, Object?> body) {
    if (_requireEnabled(mode) case final refused?) return refused;
    final userId = body['target_id'] as String?;
    final action = body['action'] as String?;
    // As the server does: a like from someone who has paused new matches is
    // refused before anything else; a pass still goes through.
    if (pauseNewMatches && (action == 'like' || action == 'super_like')) {
      return _error(
        409,
        'NEW_MATCHES_PAUSED',
        'You have paused new matches. Turn that off to like people again.',
      );
    }
    final person = [
      ...?decks[mode],
      ...?likesYou[mode],
    ].where((person) => person.id == userId).firstOrNull;
    if (person == null || action == null) {
      return _error(404, 'NOT_FOUND', 'We could not find that.');
    }
    final made = swipes.putIfAbsent(mode, () => []);
    if (made.any((swipe) => swipe.userId == userId)) {
      return _error(
        409,
        'CONFLICT',
        'You have already swiped on this person in this mode.',
      );
    }

    final usesAllowance = action != 'pass';
    final limit = dailyLikes;
    if (usesAllowance && limit != null && likesUsed >= limit) {
      return _error(
        422,
        'QUOTA_EXCEEDED',
        'You have used all $limit swipes for today. Upgrade for unlimited.',
        details: {
          'quota': 'swipes',
          'limit': limit,
          'used': likesUsed,
          'remaining': 0,
          'resets_at': '2026-09-18T00:00:00.000Z',
          'upgrade_available': true,
        },
      );
    }
    if (usesAllowance) likesUsed++;
    made.add((userId: person.id, action: action));
    likesYou[mode]?.removeWhere((like) => like.id == person.id);

    FakeMatch? match;
    if (usesAllowance && likesBack.contains(person.id)) {
      match = FakeMatch(
        id: 'match-${person.id}',
        mode: mode,
        person: person,
        isSuperLike: action == 'super_like',
        matchedAt: now(),
        expiresAt: now().add(const Duration(days: 14)),
      );
      matches.insert(0, match);
    }

    return _ok({
      'action': action,
      'is_match': match != null,
      'match': match == null
          ? null
          : {
              'id': match.id,
              'mode': mode,
              'is_super_like': match.isSuperLike,
              'matched_at': match.matchedAt.toIso8601String(),
            },
      'quota': _allowance(),
    }, status: 201);
  }

  Map<String, Object?> _allowance() {
    final limit = dailyLikes;
    return limit == null
        ? {'limit': -1, 'used': 0, 'remaining': -1, 'is_unlimited': true}
        : {
            'limit': limit,
            'used': likesUsed,
            'remaining': limit - likesUsed,
            'is_unlimited': false,
          };
  }

  ResponseBody _rewind(String mode) {
    if (_requireEnabled(mode) case final refused?) return refused;
    if (!isPremium) {
      return _premiumRequired('rewind', 'Rewind is available with Premium.');
    }
    final made = swipes[mode];
    if (made == null || made.isEmpty) {
      return _error(
        404,
        'NOT_FOUND',
        'There is nothing to rewind in this mode.',
      );
    }
    final last = made.last;
    // As the server does: a swipe that became a match is never undone.
    final live = matches
        .where((match) => match.mode == mode && match.person.id == last.userId)
        .firstOrNull;
    if (live != null || endedMatches.contains('$mode:${last.userId}')) {
      return _error(
        409,
        'ALREADY_MATCHED',
        'You matched with this person, so that swipe cannot be undone.',
        details: {'match_id': live?.id},
      );
    }
    made.removeLast();
    if (last.action != 'pass' && likesUsed > 0) likesUsed--;
    return _ok({
      'restored_user_id': last.userId,
      'action': last.action,
      'match_removed': false,
    });
  }

  ResponseBody _stats(String mode) {
    if (_requireEnabled(mode) case final refused?) return refused;
    final made = swipes[mode] ?? const [];
    int count(String action) => made.where((s) => s.action == action).length;
    final boostEnds = boostsEndingAt[mode];
    return _ok({
      'mode': mode,
      'liked': count('like'),
      'passed': count('pass'),
      'super_liked': count('super_like'),
      'matches': matches.where((match) => match.mode == mode).length,
      'likes_received': likesYou[mode]?.length ?? 0,
      'cards_remaining': _deckFor(mode).length,
      'boost': boostEnds == null || !boostEnds.isAfter(now())
          ? null
          : {
              'id': 'boost-$mode',
              'mode': mode,
              'started_at': boostEnds
                  .subtract(const Duration(minutes: 30))
                  .toIso8601String(),
              'ends_at': boostEnds.toIso8601String(),
              'is_active': true,
            },
      'swipe_quota': _allowance(),
    });
  }

  ResponseBody _boost(String mode) {
    if (_requireEnabled(mode) case final refused?) return refused;
    if (!isPremium) {
      return _premiumRequired('boost', 'Boost is available with Premium.');
    }
    if (boostsEndingAt[mode] case final ends? when ends.isAfter(now())) {
      return _error(
        409,
        'CONFLICT',
        'A boost is already running in this mode.',
        details: {'ends_at': ends.toIso8601String()},
      );
    }
    final ends = boostsEndingAt[mode] = now().add(const Duration(minutes: 30));
    return _ok({
      'id': 'boost-$mode',
      'mode': mode,
      'started_at': now().toIso8601String(),
      'ends_at': ends.toIso8601String(),
      'is_active': true,
    }, status: 201);
  }

  ResponseBody _likesYou(String mode) {
    if (_requireEnabled(mode) case final refused?) return refused;
    if (!isPremium) {
      return _premiumRequired(
        'see_who_liked_you',
        'Seeing who liked you is available with Premium.',
      );
    }
    return _list([
      for (final person in likesYou[mode] ?? const <FakePerson>[])
        {
          'swipe_id': 'like-${person.id}',
          'is_super_like': false,
          'liked_at': now()
              .subtract(const Duration(hours: 3))
              .toIso8601String(),
          'user': person.compact(now()),
        },
    ]);
  }

  ResponseBody _publicProfile(String id) {
    final person = [
      for (final deck in decks.values) ...deck,
      for (final likes in likesYou.values) ...likes,
      for (final match in matches) match.person,
    ].where((person) => person.id == id).firstOrNull;
    if (person == null) {
      return _error(404, 'NOT_FOUND', 'We could not find that.');
    }
    return _ok({
      'user': person.compact(now()),
      'photos': person.photos,
      'bio': person.bio,
      'job_title': null,
      'organisation': null,
      'education': null,
      'height_cm': null,
      'city': 'Leeds',
      'distance_metres': person.distanceMetres,
      'drinking': null,
      'smoking': null,
      'exercise': null,
      'diet': null,
      'pets': null,
      'children': null,
      'interests': [
        for (final slug in person.interests)
          {
            'id': 'interest-$slug',
            'slug': slug,
            'label': _interestLabel(slug),
            'category': 'general',
          },
      ],
      'prompts': <Object?>[],
    });
  }

  // --- Matches -------------------------------------------------------------

  ResponseBody _matches(RequestOptions options) {
    final archived = options.queryParameters['archived'] == 'true';
    return _list([
      for (final match in matches)
        if (match.isArchived == archived) _matchView(match),
    ]);
  }

  ResponseBody _match(String id) {
    final match = matches.where((match) => match.id == id).firstOrNull;
    if (match == null) {
      return _error(404, 'NOT_FOUND', 'We could not find that.');
    }
    return _ok(_matchView(match));
  }

  Map<String, Object?> _matchView(FakeMatch match) {
    final expired = !match.expiresAt.isAfter(now());
    final last = match.messages.lastOrNull;
    return {
      'id': match.id,
      'mode': match.mode,
      'status': expired ? 'expired' : 'active',
      'is_super_like': match.isSuperLike,
      'matched_at': match.matchedAt.toIso8601String(),
      'expires_at': match.expiresAt.toIso8601String(),
      'is_expired': expired,
      'extension_count': match.extensionCount,
      'is_writable': _isWritable(match),
      'user': match.person.compact(now()),
      'conversation_id': match.conversationId,
      'last_message_at': last?.createdAt.toIso8601String(),
      'last_message_preview': last?.preview,
      'unread_count': match.unreadCount,
    };
  }

  ResponseBody _unmatch(String id) {
    final before = matches.length;
    for (final match in matches.where((match) => match.id == id)) {
      endedMatches.add('${match.mode}:${match.person.id}');
    }
    matches.removeWhere((match) => match.id == id);
    if (matches.length == before) {
      return _error(404, 'NOT_FOUND', 'We could not find that.');
    }
    _closePlans((plan) => plan.match.id == id);
    return _ok({'unmatched': true});
  }

  ResponseBody _extend(String id) {
    if (!isPremium) {
      return _premiumRequired(
        'extend_matches',
        'Extending a match is available with Premium.',
      );
    }
    final match = matches.where((match) => match.id == id).firstOrNull;
    if (match == null) {
      return _error(404, 'NOT_FOUND', 'We could not find that.');
    }
    final from = match.expiresAt.isAfter(now()) ? match.expiresAt : now();
    match
      ..expiresAt = from.add(const Duration(days: 7))
      ..extensionCount += 1;
    return _ok(_matchView(match));
  }

  // --- Chat ----------------------------------------------------------------

  bool _isWritable(FakeMatch match) {
    return match.expiresAt.isAfter(now()) && !blocked.contains(match.person.id);
  }

  FakeMatch? _matchFor(String conversationId) {
    return matches
        .where((match) => match.conversationId == conversationId)
        .firstOrNull;
  }

  int _unreadTotal() {
    return matches.fold(0, (total, match) => total + match.unreadCount);
  }

  DateTime _nextMessageTime() {
    return now().add(Duration(seconds: ++_messageSequence));
  }

  Map<String, Object?> _conversationView(FakeMatch match) {
    final last = match.messages.lastOrNull;
    return {
      'id': match.conversationId,
      'match_id': match.id,
      'mode': match.mode,
      'user': match.person.compact(now()),
      'last_message_at': last?.createdAt.toIso8601String(),
      'last_message_preview': last?.preview,
      'unread_count': match.unreadCount,
      'is_archived': match.isArchived,
      'is_muted': match.isMuted,
      'is_writable': _isWritable(match),
      'match_expires_at': match.expiresAt.toIso8601String(),
    };
  }

  ResponseBody _conversation(String id) {
    final match = _matchFor(id);
    if (match == null) {
      return _error(404, 'NOT_FOUND', 'We could not find that.');
    }
    return _ok(_conversationView(match));
  }

  ResponseBody _updateConversation(String id, Map<String, Object?> body) {
    final match = _matchFor(id);
    if (match == null) {
      return _error(404, 'NOT_FOUND', 'We could not find that.');
    }
    if (body['is_archived'] case final bool archived) {
      match.isArchived = archived;
    }
    if (body['is_muted'] case final bool muted) match.isMuted = muted;
    return _ok(_conversationView(match));
  }

  /// Newest first, with the cursor as a position, as the server pages them.
  ResponseBody _messages(String id, RequestOptions options) {
    final match = _matchFor(id);
    if (match == null) {
      return _error(404, 'NOT_FOUND', 'We could not find that.');
    }
    final limit = int.tryParse('${options.queryParameters['limit']}') ?? 20;
    final start =
        int.tryParse('${options.queryParameters['cursor'] ?? ''}') ?? 0;
    final newestFirst = match.messages.reversed.toList();
    final end = start + limit;
    return _list(
      [
        for (final message in newestFirst.skip(start).take(limit))
          message.toJson(match.conversationId),
      ],
      nextCursor: end < newestFirst.length ? '$end' : null,
      limit: limit,
    );
  }

  ResponseBody _sendMessage(String id, Map<String, Object?> body) {
    final match = _matchFor(id);
    if (match == null) {
      return _error(404, 'NOT_FOUND', 'We could not find that.');
    }
    if (!_isWritable(match)) {
      return _error(
        403,
        'FORBIDDEN',
        'This conversation is closed.',
        details: {'is_writable': false},
      );
    }
    if (dailyMessages case final limit? when messagesUsed >= limit) {
      return _error(
        422,
        'QUOTA_EXCEEDED',
        "You've used today's messages.",
        details: {
          'quota': 'messages',
          'limit': limit,
          'used': messagesUsed,
          'remaining': 0,
          'resets_at': '2026-09-18T00:00:00.000Z',
          'upgrade_available': true,
        },
      );
    }

    final type = body['type'] as String? ?? 'text';
    String? mediaUrl;
    if (type == 'image') {
      final uploadId = body['media_asset_id'] as String?;
      if (uploadId == null || _uploads[uploadId]?.completed != true) {
        return _error(404, 'NOT_FOUND', 'That upload does not exist.');
      }
      mediaUrl = 'https://$storageHost/$uploadId.jpg?X-Amz-Signature=read';
    } else if ((body['body'] as String? ?? '').trim().isEmpty) {
      return _validation({
        'body': ['A text message needs a body.'],
      });
    }

    messagesUsed++;
    final message = FakeMessage(
      id: 'message-${_nextId++}',
      senderId: userId,
      type: type,
      body: body['body'] as String?,
      mediaUrl: mediaUrl,
      overridden: body['moderation_overridden'] == true,
      createdAt: _nextMessageTime(),
    );
    match.messages.add(message);
    return _ok(message.toJson(match.conversationId), status: 201);
  }

  ResponseBody _markRead(String id) {
    final match = _matchFor(id);
    if (match == null) {
      return _error(404, 'NOT_FOUND', 'We could not find that.');
    }
    final at = _nextMessageTime();
    match.unreadCount = 0;
    for (final message in match.messages) {
      if (message.senderId != userId) message.readAt ??= at;
    }
    // Reading a conversation reads the notifications about it too.
    for (final notification in notifications) {
      if (notification.category == 'new_message' &&
          notification.data['conversation_id'] == id) {
        notification.readAt ??= at;
      }
    }
    match.readByUser += 1;
    return _ok({
      'conversation_id': id,
      'unread_count': 0,
      'last_read_at': at.toIso8601String(),
    });
  }

  ResponseBody _checkMessage(Map<String, Object?> body) {
    final content = body['content'] as String? ?? '';
    moderationChecks.add(content);
    final warning = moderate(content);
    return _ok({
      'check_id': 'check-${_nextId++}',
      'severity': warning == null ? 'none' : 'medium',
      'should_warn': warning != null,
      'can_send': true,
      'findings': [
        if (warning != null)
          {'category': 'scam', 'severity': 'medium', 'message': warning},
      ],
      'timed_out': false,
      'provider': 'rules',
    });
  }

  /// Blocking ends every match with the person, as on the server.
  void _blockPerson(String personId) {
    blocked.add(personId);
    for (final match in matches.where((match) => match.person.id == personId)) {
      endedMatches.add('${match.mode}:${match.person.id}');
    }
    matches.removeWhere((match) => match.person.id == personId);
    _closePlans((plan) => plan.match.person.id == personId);
  }

  ResponseBody _block(Map<String, Object?> body) {
    final personId = body['user_id']! as String;
    _blockPerson(personId);
    return _ok({
      'id': 'block-${_nextId++}',
      'blocked_at': now().toIso8601String(),
    }, status: 201);
  }

  ResponseBody _report(Map<String, Object?> body) {
    reports.add(body);
    if (body['also_block'] == true) {
      _blockPerson(body['reported_id']! as String);
    }
    return _ok({
      'id': 'report-${_nextId++}',
      'reason': body['reason'],
      'status': 'open',
      'also_blocked': body['also_block'] == true,
      'evidence_count': (body['evidence_asset_ids'] as List<Object?>?)?.length,
      'created_at': now().toIso8601String(),
    }, status: 201);
  }

  // --- Notifications ---------------------------------------------------------

  ResponseBody _notifications(RequestOptions options) {
    final limit = int.tryParse('${options.queryParameters['limit']}') ?? 20;
    final start =
        int.tryParse('${options.queryParameters['cursor'] ?? ''}') ?? 0;
    final end = start + limit;
    return _list(
      [
        for (final notification in notifications.skip(start).take(limit))
          notification.toJson(),
      ],
      nextCursor: end < notifications.length ? '$end' : null,
      limit: limit,
    );
  }

  ResponseBody _readNotification(String id) {
    final notification = notifications
        .where((each) => each.id == id)
        .firstOrNull;
    if (notification == null) {
      return _error(404, 'NOT_FOUND', 'We could not find that.');
    }
    notification.readAt ??= now();
    return _ok(notification.toJson());
  }

  ResponseBody _readAllNotifications() {
    var marked = 0;
    for (final notification in notifications) {
      if (notification.readAt == null) {
        notification.readAt = now();
        marked++;
      }
    }
    return _ok({'marked': marked});
  }

  static const _notificationCategories = [
    'new_match',
    'new_like',
    'new_message',
    'plan_update',
    'call',
    'safety',
    'moderation',
    'subscription',
    'system',
  ];

  Map<String, Object?> _preference(String category) {
    return {
      'category': category,
      'push_enabled': !pushOff.contains(category),
      'email_enabled': false,
      'in_app_enabled': true,
    };
  }

  Map<String, Object?> _preferences() {
    return {
      'preferences': [
        for (final category in _notificationCategories) _preference(category),
      ],
    };
  }

  ResponseBody _updatePreference(String category, Map<String, Object?> body) {
    if (!_notificationCategories.contains(category)) {
      return _validation({
        'category': ['Unknown category.'],
      });
    }
    final enabled = body['push_enabled'];
    if (category == 'safety' && enabled == false) {
      return _error(
        400,
        'BAD_REQUEST',
        'Safety notifications cannot be turned off.',
      );
    }
    if (enabled case final bool on) {
      on ? pushOff.remove(category) : pushOff.add(category);
    }
    return _ok(_preference(category));
  }

  ResponseBody _registerPushToken(Map<String, Object?> body) {
    final deviceId = body['device_id']! as String;
    pushTokens[deviceId] = body['fcm_token']! as String;
    return _ok({'device_id': deviceId, 'registered': true});
  }

  ResponseBody _removePushToken(String deviceId) {
    pushTokens.remove(deviceId);
    pushTokensRemoved.add(deviceId);
    return _ok({'unregistered': true});
  }

  /// Adds a notification to the feed without announcing it, as if it arrived
  /// before the test began.
  FakeNotification addNotification(
    String category,
    String title,
    String body, {
    Map<String, Object?> data = const {},
    bool read = false,
    Duration ago = const Duration(hours: 1),
  }) {
    final createdAt = now().subtract(ago);
    final notification = FakeNotification(
      id: 'notification-${_nextId++}',
      category: category,
      title: title,
      body: body,
      data: data,
      createdAt: createdAt,
    )..readAt = read ? createdAt : null;
    notifications
      ..add(notification)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notification;
  }

  /// Adds a notification and announces it over the live connection, as the
  /// server does.
  FakeNotification notifyLive(
    String category,
    String title,
    String body, {
    Map<String, Object?> data = const {},
  }) {
    final notification = addNotification(
      category,
      title,
      body,
      data: data,
      ago: Duration.zero,
    );
    realtime.push('notification:new', notification.toJson());
    return notification;
  }

  // --- Plans ---------------------------------------------------------------

  Map<String, Object?> _badges() {
    return {
      'discover': 0,
      'requests': 0,
      'matches': _unreadTotal(),
      'plans': plans
          .where((plan) => plan.toJson(now())['awaiting_my_response'] == true)
          .length,
      'notifications': notifications
          .where((each) => each.readAt == null)
          .length,
      'total': 0,
    };
  }

  /// The plans the user can see: the other person's drafts never.
  Iterable<FakePlan> get _visiblePlans {
    return plans.where((plan) => plan.createdByUser || plan.status != 'draft');
  }

  FakePlan? _findPlan(String id) {
    return _visiblePlans.where((plan) => plan.id == id).firstOrNull;
  }

  ResponseBody _plans(RequestOptions options) {
    final query = options.uri.queryParameters;
    final at = now();
    bool started(FakePlan plan) {
      final scheduledAt = plan.scheduledAt;
      return scheduledAt != null && !scheduledAt.isAfter(at);
    }

    final shown = [
      for (final plan in _visiblePlans.toList().reversed)
        if (switch ((query['drafts'], query['tab'])) {
          ('true', _) => plan.status == 'draft',
          (_, 'upcoming') => plan.status == 'confirmed' && !started(plan),
          (_, 'pending') => plan.status == 'proposed' && !started(plan),
          (_, 'history') =>
            const {
                  'completed',
                  'cancelled',
                  'declined',
                }.contains(plan.status) ||
                ((plan.status == 'confirmed' || plan.status == 'proposed') &&
                    started(plan)),
          _ => plan.status != 'draft',
        })
          plan.toJson(at),
    ];
    return _list(shown);
  }

  ResponseBody _plan(String id) {
    final plan = _findPlan(id);
    if (plan == null) return _missing();
    return _ok(plan.toJson(now()));
  }

  /// Why a plan's time can't be used, or `null` when it can.
  ResponseBody? _checkTime(DateTime? at, {required bool sending}) {
    if (at == null) {
      if (!sending) return null;
      return _validation({
        'scheduled_at': ['Set a time before proposing a plan.'],
      });
    }
    if (at.isAfter(now())) return null;
    return _validation({
      'scheduled_at': ['Pick a time in the future.'],
    });
  }

  ResponseBody _createPlan(Map<String, Object?> body) {
    final match = matches
        .where((match) => match.id == body['match_id'])
        .firstOrNull;
    if (match == null) return _missing();

    final venueId = body['venue_id'] as String?;
    final venue = venues.where((venue) => venue.id == venueId).firstOrNull;
    if (venueId != null && venue == null) {
      return _error(404, 'NOT_FOUND', 'That venue is not available.');
    }
    final customLocation = body['custom_location'] as String?;
    if (venue == null && (customLocation == null || customLocation.isEmpty)) {
      return _validation({
        'venue_id': ['Choose a venue or give a location.'],
      });
    }

    final send = body['propose'] == true;
    final at = switch (body['scheduled_at']) {
      final String value => DateTime.parse(value),
      _ => null,
    };
    if (_checkTime(at, sending: send) case final refused?) return refused;

    final plan =
        FakePlan(
            id: 'plan-${_nextId++}',
            match: match,
            createdByUser: true,
            status: send ? 'proposed' : 'draft',
            createdAt: now(),
          )
          ..venue = venue
          ..customLocation = venue == null ? customLocation : null
          ..customAddress = body['custom_address'] as String?
          ..scheduledAt = at
          ..durationMinutes = body['duration_minutes'] as int?
          ..notes = body['notes'] as String?;
    plans.add(plan);
    return _ok(plan.toJson(now()), status: 201);
  }

  ResponseBody _updatePlan(String id, Map<String, Object?> body) {
    final plan = _findPlan(id);
    if (plan == null || !plan.createdByUser) {
      return _error(404, 'NOT_FOUND', 'We could not find that.');
    }
    if (plan.status != 'draft' && plan.status != 'proposed') {
      return _error(400, 'BAD_REQUEST', 'This plan can no longer be changed.');
    }

    var venue = plan.venue;
    if (body.containsKey('venue_id')) {
      final venueId = body['venue_id'] as String?;
      venue = venues.where((venue) => venue.id == venueId).firstOrNull;
      if (venueId != null && venue == null) {
        return _error(404, 'NOT_FOUND', 'That venue is not available.');
      }
    }
    final customLocation = body.containsKey('custom_location')
        ? body['custom_location'] as String?
        : plan.customLocation;
    if (venue == null && (customLocation == null || customLocation.isEmpty)) {
      return _validation({
        'venue_id': ['Choose a venue or give a location.'],
      });
    }
    final at = switch (body['scheduled_at']) {
      final String value => DateTime.parse(value),
      _ => plan.scheduledAt,
    };
    if (_checkTime(at, sending: false) case final refused?) return refused;

    String? cleared(String? value) {
      return value == null || value.isEmpty ? null : value;
    }

    plan
      ..venue = venue
      ..customLocation = customLocation
      ..scheduledAt = at;
    if (body.containsKey('custom_address')) {
      plan.customAddress = cleared(body['custom_address'] as String?);
    }
    if (body['duration_minutes'] case final int minutes) {
      plan.durationMinutes = minutes;
    }
    if (body.containsKey('notes')) {
      plan.notes = cleared(body['notes'] as String?);
    }
    plan.edits++;
    return _ok(plan.toJson(now()));
  }

  ResponseBody _proposePlan(String id) {
    final plan = _findPlan(id);
    if (plan == null || !plan.createdByUser) {
      return _error(404, 'NOT_FOUND', 'We could not find that.');
    }
    if (plan.status != 'draft') {
      return _error(400, 'BAD_REQUEST', 'That plan has already been sent.');
    }
    if (_checkTime(plan.scheduledAt, sending: true) case final refused?) {
      return refused;
    }
    plan.status = 'proposed';
    return _ok(plan.toJson(now()));
  }

  ResponseBody _respondToPlan(String id, Map<String, Object?> body) {
    final plan = _findPlan(id);
    if (plan == null) return _missing();
    if (plan.status != 'proposed') {
      return _error(
        400,
        'BAD_REQUEST',
        'That plan is not awaiting a response.',
      );
    }
    if (plan.createdByUser) {
      return _error(400, 'BAD_REQUEST', 'You cannot respond to your own plan.');
    }
    final accept = body['accept'] == true;
    if (accept && !(plan.scheduledAt?.isAfter(now()) ?? true)) {
      return _error(400, 'BAD_REQUEST', 'The time for that plan has passed.');
    }
    plan.status = accept ? 'confirmed' : 'declined';
    return _ok(plan.toJson(now()));
  }

  ResponseBody _cancelPlan(String id, Map<String, Object?> body) {
    final plan = _findPlan(id);
    if (plan == null) return _missing();
    if (plan.status == 'draft') {
      return _error(
        400,
        'BAD_REQUEST',
        'That plan was never sent. Delete the draft instead.',
      );
    }
    if (plan.status != 'proposed' && plan.status != 'confirmed') {
      return _error(400, 'BAD_REQUEST', 'That plan is already finished.');
    }
    plan
      ..status = 'cancelled'
      ..cancellationReason = body['reason'] as String?;
    return _ok(plan.toJson(now()));
  }

  ResponseBody _deleteDraft(String id) {
    final plan = _findPlan(id);
    if (plan == null) return _missing();
    if (plan.status != 'draft') {
      return _error(
        400,
        'BAD_REQUEST',
        'Only a draft can be deleted. Cancel a plan that was sent.',
      );
    }
    plans.remove(plan);
    return _ok({'deleted': true});
  }

  /// As ending a match does on the server: drafts go, and what was still
  /// ahead is cancelled.
  void _closePlans(bool Function(FakePlan plan) onEndedMatch) {
    final at = now();
    plans.removeWhere((plan) => onEndedMatch(plan) && plan.status == 'draft');
    for (final plan in plans.where(onEndedMatch)) {
      final ahead = plan.scheduledAt?.isAfter(at) ?? false;
      if (plan.status == 'proposed' || (plan.status == 'confirmed' && ahead)) {
        plan.status = 'cancelled';
      }
    }
  }

  /// A plan [match]'s person suggests, announced as the server does.
  FakePlan planFromPerson(
    FakeMatch match, {
    required String place,
    required DateTime at,
    String status = 'proposed',
    bool announce = true,
  }) {
    final plan =
        FakePlan(
            id: 'plan-${_nextId++}',
            match: match,
            createdByUser: false,
            status: status,
            createdAt: now(),
          )
          ..customLocation = place
          ..scheduledAt = at;
    plans.add(plan);
    if (announce) {
      notifyLive(
        'plan_update',
        'New plan suggested',
        '$place — tap to accept or decline.',
        data: {'plan_id': plan.id, 'match_id': match.id},
      );
    }
    return plan;
  }

  /// [match]'s person answers the user's [plan], as the server announces it.
  void answerPlanAsPerson(FakePlan plan, {required bool accept}) {
    plan.status = accept ? 'confirmed' : 'declined';
    notifyLive(
      'plan_update',
      accept ? 'Plan confirmed' : 'Plan declined',
      accept ? '${plan.place} is on.' : 'Your plan was declined.',
      data: {'plan_id': plan.id, 'match_id': plan.match.id},
    );
  }

  ResponseBody _missing() {
    return _error(404, 'NOT_FOUND', 'We could not find that.');
  }

  // --- Trusted contacts and emergencies -------------------------------------

  ResponseBody _addContact(Map<String, Object?> body) {
    if (contacts.length >= 5) {
      return _error(
        400,
        'BAD_REQUEST',
        'You can have at most 5 trusted contacts.',
      );
    }
    final phone = body['phone'] as String?;
    final email = body['email'] as String?;
    if (phone == null && email == null) {
      return _validation({
        'phone': [
          'Give a phone number or an email so this contact can be reached.',
        ],
      });
    }
    final contact = FakeContact(
      id: 'contact-${_nextId++}',
      name: body['name']! as String,
      phone: phone,
      email: email,
      relationship: body['relationship'] as String?,
    );
    contacts.add(contact);
    return _ok(contact.toJson(), status: 201);
  }

  ResponseBody _updateContact(String id, Map<String, Object?> body) {
    final contact = contacts.where((each) => each.id == id).firstOrNull;
    if (contact == null) return _missing();

    String? cleared(String key, String? current) {
      if (!body.containsKey(key)) return current;
      final value = body[key] as String?;
      return value == null || value.isEmpty ? null : value;
    }

    final phone = cleared('phone', contact.phone);
    final email = cleared('email', contact.email);
    if (phone == null && email == null) {
      return _validation({
        'phone': ['A trusted contact needs a phone number or an email.'],
      });
    }
    contact
      ..name = (body['name'] as String?) ?? contact.name
      ..phone = phone
      ..email = email
      ..relationship = cleared('relationship', contact.relationship);
    return _ok(contact.toJson());
  }

  ResponseBody _deleteContact(String id) {
    final before = contacts.length;
    contacts.removeWhere((each) => each.id == id);
    if (contacts.length == before) return _missing();
    return _ok({'deleted': true});
  }

  /// What happened to [contact] when the fake emailed them.
  Map<String, Object?> _delivery(FakeContact contact) {
    return {
      'id': contact.id,
      'name': contact.name,
      'delivery': contact.email == null
          ? 'no_email'
          : undeliverable.contains(contact.id)
          ? 'failed'
          : 'emailed',
    };
  }

  ResponseBody _raiseEmergency(Map<String, Object?> body) {
    emergencies.add(body);
    final alerts = [for (final contact in contacts) _delivery(contact)];
    final emailed = alerts.where((each) => each['delivery'] == 'emailed');
    final summary = switch ((alerts.length, emailed.length)) {
      (0, _) =>
        'You have no trusted contacts yet. Call someone you trust, or your '
            'local emergency number.',
      (_, 0) =>
        "We couldn't email your trusted contacts. Call someone you trust, or "
            'your local emergency number.',
      (final all, final sent) when all == sent =>
        sent == 1
            ? 'We emailed your trusted contact.'
            : 'We emailed your $sent trusted contacts.',
      (final all, final sent) =>
        'We emailed $sent of your $all trusted contacts. Call the others '
            'yourself.',
    };
    return _ok({
      'id': 'emergency-${_nextId++}',
      'type': 'help_requested',
      'note': body['note'],
      'location': body['latitude'] == null
          ? null
          : {'latitude': body['latitude'], 'longitude': body['longitude']},
      'contacts_notified': emailed.length,
      'contacts': alerts,
      'summary': summary,
      'created_at': now().toUtc().toIso8601String(),
    }, status: 201);
  }

  ResponseBody _sharePlan(String id, Map<String, Object?> body) {
    final plan = _findPlan(id);
    if (plan == null) return _missing();
    if (plan.status != 'confirmed') {
      return _error(400, 'BAD_REQUEST', 'Only a confirmed plan can be shared.');
    }
    final results = <Map<String, Object?>>[];
    for (final contactId
        in (body['contact_ids']! as List<Object?>).cast<String>()) {
      final contact = contacts
          .where((each) => each.id == contactId)
          .firstOrNull;
      if (contact == null) {
        return _error(
          404,
          'NOT_FOUND',
          'One of those contacts does not exist.',
        );
      }
      if (plan.sharedWith.contains(contact.id)) {
        results.add({
          'id': contact.id,
          'name': contact.name,
          'delivery': 'already_told',
        });
        continue;
      }
      final result = _delivery(contact);
      if (result['delivery'] == 'emailed') plan.sharedWith.add(contact.id);
      results.add(result);
    }
    return _ok({'shared': plan.sharedWith.length, 'contacts': results});
  }

  // --- Calls ---------------------------------------------------------------

  ResponseBody _startCall(Map<String, Object?> body) {
    final match = matches
        .where((match) => match.id == body['match_id'])
        .firstOrNull;

    if (match == null || !_isWritable(match)) {
      // The same 404 for every reason, as the real server gives: blocked,
      // unmatched and expired must not be told apart.
      return _error(404, 'NOT_FOUND', 'That match does not exist.');
    }

    final live = calls
        .where((call) => call.matchId == match.id && _isLive(call.status))
        .firstOrNull;

    // One live call per match, not two rooms.
    if (live != null) return _ok({'call': _callView(live, withToken: true)});

    final call = FakeCall(
      id: 'call-${calls.length + 1}',
      matchId: match.id,
      mode: match.mode,
      // Video unless the caller asked for a voice call, like the real server.
      kind: body['kind'] == 'audio' ? 'audio' : 'video',
      isInitiator: true,
      createdAt: now(),
    );
    calls.add(call);
    return _ok({'call': _callView(call, withToken: true)}, status: 201);
  }

  ResponseBody _answerCall(String id) {
    final call = _callById(id);
    if (call == null) return _noCall;
    if (call.status != 'ringing') return _callNotRinging;

    call
      ..status = 'active'
      ..answeredAt = now();
    return _ok({'call': _callView(call, withToken: true)});
  }

  ResponseBody _declineCall(String id) {
    final call = _callById(id);
    if (call == null) return _noCall;
    if (call.status != 'ringing') return _callNotRinging;

    call
      ..status = 'declined'
      ..endedAt = now();
    return _ok({'call': _callView(call)});
  }

  ResponseBody _endCall(String id) {
    final call = _callById(id);
    if (call == null) return _noCall;

    // Idempotent: both apps send a hang-up.
    if (_isLive(call.status)) {
      final answeredAt = call.answeredAt;
      call
        ..status = answeredAt == null ? 'missed' : 'ended'
        ..endedAt = now()
        ..durationSeconds = answeredAt == null
            ? null
            : now().difference(answeredAt).inSeconds;
    }
    return _ok({'call': _callView(call)});
  }

  ResponseBody _callToken(String id) {
    final call = _callById(id);
    if (call == null) return _noCall;
    if (!_isLive(call.status)) {
      return _error(409, 'CONFLICT', 'That call is not live.');
    }
    return _ok({'call': _callView(call, withToken: true)});
  }

  ResponseBody _callHistory() {
    final ordered = [...calls]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return _list([for (final call in ordered) _callView(call)]);
  }

  ResponseBody _callSafetyAction(String id, Map<String, Object?> body) {
    final call = _callById(id);
    if (call == null) return _noCall;

    final action = body['action'];
    safetyActions.add((callId: id, action: '$action'));

    if (action == 'end_and_report') _endCall(id);

    return _ok({
      'call_id': id,
      'action': action,
      'call_status': call.status,
      'report_id': action == 'end_and_report' ? 'report-1' : null,
    });
  }

  FakeCall? _callById(String id) {
    return calls.where((call) => call.id == id).firstOrNull;
  }

  static bool _isLive(String status) =>
      status == 'ringing' || status == 'active';

  Map<String, Object?> _callView(FakeCall call, {bool withToken = false}) {
    // A call always belongs to a match; the fallback only keeps the view total
    // for a test that unmatched in the middle of one.
    final person =
        matches
            .where((match) => match.id == call.matchId)
            .firstOrNull
            ?.person ??
        const FakePerson(id: 'unknown', name: 'Someone');
    return {
      'id': call.id,
      'match_id': call.matchId,
      'mode': call.mode,
      'kind': call.kind,
      'status': call.status,
      'is_initiator': call.isInitiator,
      'other_user': person.compact(now()),
      'started_at': call.createdAt.toIso8601String(),
      'answered_at': call.answeredAt?.toIso8601String(),
      'ended_at': call.endedAt?.toIso8601String(),
      'duration_seconds': call.durationSeconds,
      'created_at': call.createdAt.toIso8601String(),
      if (withToken)
        'video': {
          'room_name': 'kinvo-call-${call.id}',
          'token': 'test-token-not-a-jwt',
          // Null unless a test sets one, which is what a server with no video
          // service answers. Tests that set it would need a real media server.
          'server_url': videoServerUrl,
          'expires_at': now().add(const Duration(hours: 1)).toIso8601String(),
        },
    };
  }

  static ResponseBody get _noCall =>
      _error(404, 'NOT_FOUND', 'That call does not exist.');

  static ResponseBody get _callNotRinging =>
      _error(409, 'CONFLICT', 'That call is no longer ringing.');

  // --- Venues --------------------------------------------------------------

  Map<String, Object?> _venueView(FakeVenue venue) {
    return venue.toJson(saved: savedVenues.contains(venue.id));
  }

  ResponseBody _venues(RequestOptions options) {
    final category = options.uri.queryParameters['category'];
    return _ok({
      'venues': [
        for (final venue in venues)
          if (category == null || venue.category == category) _venueView(venue),
      ],
    });
  }

  ResponseBody _suggestVenues(String matchId) {
    final match = matches.where((match) => match.id == matchId).firstOrNull;
    if (match == null) return _missing();
    return _ok({
      'venues': [
        for (final venue in venues)
          if (venue.modes.contains(match.mode)) _venueView(venue),
      ],
    });
  }

  ResponseBody _saveVenue(String id, {required bool save}) {
    if (!venues.any((venue) => venue.id == id)) {
      return _error(404, 'NOT_FOUND', 'That venue is not available.');
    }
    if (save) {
      savedVenues.add(id);
    } else {
      savedVenues.remove(id);
    }
    return _ok({'saved': save}, status: save ? 201 : 200);
  }

  // --- The other person, live ----------------------------------------------

  /// Adds a message to [match]'s history without delivering it live, as if
  /// it was sent before the test began.
  FakeMessage addHistory(
    FakeMatch match,
    String body, {
    required bool fromUser,
    bool read = true,
  }) {
    final createdAt = _nextMessageTime();
    final message = FakeMessage(
      id: 'message-${_nextId++}',
      senderId: fromUser ? userId : match.person.id,
      type: 'text',
      body: body,
      createdAt: createdAt,
    )..readAt = read ? createdAt : null;
    match.messages.add(message);
    if (!fromUser && !read) match.unreadCount++;
    return message;
  }

  /// [match]'s person sends [body], delivered live as the server does.
  FakeMessage receiveMessage(FakeMatch match, String body) {
    final message = FakeMessage(
      id: 'message-${_nextId++}',
      senderId: match.person.id,
      type: 'text',
      body: body,
      createdAt: _nextMessageTime(),
    );
    match
      ..messages.add(message)
      ..unreadCount += 1
      ..isArchived = false;
    realtime
      ..push('message:new', message.toJson(match.conversationId))
      ..push('typing', {
        'conversation_id': match.conversationId,
        'user_id': match.person.id,
        'is_typing': false,
      })
      ..push('conversation:updated', {
        'conversation_id': match.conversationId,
        'unread_count': match.unreadCount,
        'last_message_at': message.createdAt.toIso8601String(),
        'last_message_preview': message.preview,
      });
    return message;
  }

  /// [match]'s person reads everything the user sent.
  void readByPerson(FakeMatch match) {
    final at = _nextMessageTime();
    for (final message in match.messages) {
      if (message.senderId == userId) message.readAt ??= at;
    }
    realtime.push('message:read', {
      'conversation_id': match.conversationId,
      'reader_id': match.person.id,
      'read_at': at.toIso8601String(),
    });
  }

  /// [match]'s person starts or stops typing.
  void typingBy(FakeMatch match, {required bool isTyping}) {
    realtime.push('typing', {
      'conversation_id': match.conversationId,
      'user_id': match.person.id,
      'is_typing': isTyping,
    });
  }

  /// [person] likes the user back, making a match announced live.
  FakeMatch matchLive(FakePerson person, {String mode = 'dating'}) {
    final match = FakeMatch(
      id: 'match-${person.id}',
      mode: mode,
      person: person,
      isSuperLike: false,
      matchedAt: now(),
      expiresAt: now().add(const Duration(days: 14)),
    );
    matches.insert(0, match);
    realtime.push('match:new', {
      'match_id': match.id,
      'conversation_id': match.conversationId,
      'mode': mode,
      'is_super_like': false,
      'matched_at': match.matchedAt.toIso8601String(),
      'expires_at': match.expiresAt.toIso8601String(),
      'user': person.compact(now()),
    });
    return match;
  }

  static ResponseBody _list(
    List<Object?> items, {
    String? nextCursor,
    int limit = 20,
  }) {
    return jsonResponse(
      200,
      successEnvelope(
        items,
        meta: {
          'pagination': {
            'next_cursor': nextCursor,
            'has_more': nextCursor != null,
            'limit': limit,
          },
        },
      ),
    );
  }

  // --- Password reset ------------------------------------------------------

  ResponseBody _sendResetCode(Map<String, Object?> body) {
    final email = _address(body);
    final code = (100000 + _resetCodesIssued++).toString();
    // A new code retires the last one, as the real server's does.
    resetCodes[email] = code;

    // The answer is the same whether or not the address has an account, and
    // carries the code only where there is nowhere to send it.
    return _ok({
      'message': 'If that address has an account, a reset code is on its way.',
      if (returnsResetCode) 'reset_code': code,
    });
  }

  ResponseBody _resetPassword(Map<String, Object?> body) {
    final email = _address(body);
    if (resetCodes[email] != body['code']) {
      return _error(
        401,
        'AUTH_TOKEN_INVALID',
        'That code is wrong or has expired. Please request a new one.',
      );
    }

    resetCodes.remove(email);
    passwordAfterReset = body['password'] as String?;
    return _ok({'password_reset': true});
  }

  String _address(Map<String, Object?> body) {
    return (body['email'] as String? ?? '').trim().toLowerCase();
  }

  // --- Onboarding ----------------------------------------------------------

  Map<String, Object?> _status() {
    return {
      'is_complete': isOnboarded,
      'can_complete': missing.isEmpty,
      'status': isOnboarded ? 'active' : 'pending',
      'completed_at': isOnboarded ? '2026-09-15T10:00:00.000Z' : null,
      'steps': <Object?>[],
      'missing': missing,
    };
  }

  ResponseBody _setDateOfBirth(Map<String, Object?> body) {
    if (dateOfBirth != null) {
      return _error(409, 'CONFLICT', 'Your date of birth is already set.');
    }
    dateOfBirth = body['date_of_birth'] as String?;
    return _ok(_status());
  }

  ResponseBody _complete() {
    if (missing.isNotEmpty) {
      return _error(
        403,
        'ONBOARDING_INCOMPLETE',
        'Finish setting up your profile to continue.',
        details: {'missing': missing},
      );
    }
    isOnboarded = true;
    return _ok(_status());
  }

  // --- Profile -------------------------------------------------------------

  Map<String, Object?> _profile() {
    final location = this.location;
    return {
      'id': 'profile-1',
      'user_id': 'u1',
      'display_name': displayName,
      'date_of_birth': dateOfBirth,
      'bio': bio,
      'city': city,
      'country': country,
      'location': location == null
          ? null
          : {'latitude': location.latitude, 'longitude': location.longitude},
      'interests': [
        for (final slug in interests)
          {
            'id': 'interest-$slug',
            'slug': slug,
            'label': _interestLabel(slug),
            'category': 'general',
          },
      ],
      'prompts': _promptViews(),
      'job_title': jobTitle,
      'organisation': organisation,
      'education': education,
      'height_cm': heightCm,
      for (final question in lifestyleQuestions) question: lifestyle[question],
      'age': _age(),
      'completion_percentage': _completion().percentage,
      'completion_missing': _completion().missing,
      'is_verified': isVerified,
      'is_onboarded': isOnboarded,
    };
  }

  static const lifestyleQuestions = [
    'drinking',
    'smoking',
    'exercise',
    'diet',
    'pets',
    'children',
  ];

  int? _age() {
    final born = dateOfBirth == null ? null : DateTime.tryParse(dateOfBirth!);
    if (born == null) return null;
    final today = now();
    final hadBirthday =
        today.month > born.month ||
        (today.month == born.month && today.day >= born.day);
    return today.year - born.year - (hadBirthday ? 0 : 1);
  }

  List<Map<String, Object?>> _promptViews() {
    return [
      for (final (index, prompt) in prompts.indexed)
        {
          'question_id': 'question-${prompt.slug}',
          'slug': prompt.slug,
          'question': _promptQuestion(prompt.slug),
          'answer': prompt.answer,
          'position': index,
        },
    ];
  }

  static String _promptQuestion(String slug) {
    for (final (known, question) in promptCatalogue) {
      if (known == slug) return question;
    }
    return slug;
  }

  /// The backend's checklist, with its weights.
  ({int percentage, List<Map<String, Object?>> missing}) _completion() {
    final steps = [
      ('photos', 'Add a photo', 25, photos.isNotEmpty),
      (
        'bio',
        'Write a bio of at least 20 characters',
        20,
        (bio?.length ?? 0) >= 20,
      ),
      ('interests', 'Add at least three interests', 20, interests.length >= 3),
      ('prompts', 'Answer at least one prompt', 20, prompts.isNotEmpty),
      ('location', 'Set your location', 15, location != null),
      (
        'work',
        'Add your job or organisation',
        10,
        jobTitle != null || organisation != null,
      ),
      ('education', 'Add your education', 5, education != null),
      ('lifestyle', 'Fill in your lifestyle', 10, lifestyle.length >= 3),
    ];
    final total = steps.fold(0, (sum, step) => sum + step.$3);
    final earned = steps.fold(0, (sum, step) => sum + (step.$4 ? step.$3 : 0));
    final missing = [
      for (final step in steps)
        if (!step.$4) step,
    ]..sort((a, b) => b.$3.compareTo(a.$3));
    return (
      percentage: (earned / total * 100).round(),
      missing: [
        for (final (key, label, _, _) in missing) {'key': key, 'label': label},
      ],
    );
  }

  ResponseBody _updateProfile(Map<String, Object?> body) {
    if (body['bio'] case final String newBio when newBio.length > 500) {
      return _validation({
        'bio': ['Bios can be at most 500 characters.'],
      });
    }
    if (body['display_name'] case final String name when name.trim().isEmpty) {
      return _validation({
        'display_name': ['Enter your name.'],
      });
    }
    if (body['height_cm'] case final int height
        when height < 120 || height > 250) {
      return _validation({
        'height_cm': ['Enter a height between 120cm and 250cm.'],
      });
    }
    for (final question in [...lifestyleQuestions, 'education']) {
      if (body[question] case final String answer
          when !lifestyleOptions[question]!.contains(answer)) {
        return _validation({
          question: ['Invalid enum value.'],
        });
      }
    }

    String? text(String key) => (body[key] as String?)?.trim();
    if (body['display_name'] case final String name) displayName = name.trim();
    if (body.containsKey('bio')) bio = text('bio');
    if (body.containsKey('job_title')) jobTitle = text('job_title');
    if (body.containsKey('organisation')) organisation = text('organisation');
    if (body.containsKey('education')) education = text('education');
    if (body.containsKey('city')) city = text('city');
    if (body.containsKey('height_cm')) heightCm = body['height_cm'] as int?;
    for (final question in lifestyleQuestions) {
      if (!body.containsKey(question)) continue;
      if (text(question) case final answer?) {
        lifestyle[question] = answer;
      } else {
        lifestyle.remove(question);
      }
    }
    return _ok(_profile());
  }

  ResponseBody _setPrompts(Map<String, Object?> body) {
    final given = [
      for (final prompt
          in (body['prompts']! as List<Object?>).cast<Map<String, Object?>>())
        (
          slug: prompt['slug']! as String,
          answer: (prompt['answer']! as String).trim(),
        ),
    ];
    if (given.length > 3) {
      return _validation({
        'prompts': ['Answer at most 3 prompts.'],
      });
    }
    final known = {for (final (slug, _) in promptCatalogue) slug};
    final unknown = [
      for (final prompt in given)
        if (!known.contains(prompt.slug)) prompt.slug,
    ];
    if (unknown.isNotEmpty) {
      return _validation({
        'prompts': ['Unknown prompts: ${unknown.join(', ')}.'],
      });
    }
    if (given.map((prompt) => prompt.slug).toSet().length != given.length) {
      return _validation({
        'prompts': ['Each prompt can only be answered once.'],
      });
    }
    prompts = given;
    return _ok(_profile());
  }

  /// The profile as a stranger sees it, as `GET /users/me/preview` gives it.
  Map<String, Object?> _preview() {
    return {
      'user': {
        'id': userId,
        'display_name': displayName,
        'age': _age(),
        'primary_photo_url': null,
        'is_verified': isVerified,
        'is_premium': isPremium,
        'is_online': showLastActive,
        'last_active_at': showLastActive ? now().toIso8601String() : null,
      },
      'bio': bio,
      'job_title': jobTitle,
      'organisation': organisation,
      'education': education,
      'height_cm': heightCm,
      'city': city,
      'distance_metres': null,
      for (final question in lifestyleQuestions) question: lifestyle[question],
      'interests': [
        for (final slug in interests)
          {
            'id': 'interest-$slug',
            'slug': slug,
            'label': _interestLabel(slug),
            'category': 'general',
          },
      ],
      'prompts': _promptViews(),
    };
  }

  ResponseBody _updateLocation(Map<String, Object?> body) {
    location = (
      latitude: (body['latitude']! as num).toDouble(),
      longitude: (body['longitude']! as num).toDouble(),
    );
    if (body['city'] case final String newCity) city = newCity;
    if (body['country'] case final String newCountry) country = newCountry;
    return _ok(_profile());
  }

  ResponseBody _setInterests(Map<String, Object?> body) {
    final slugs = (body['interests']! as List<Object?>).cast<String>();
    final known = {for (final (slug, _, _) in interestCatalogue) slug};
    final unknown = slugs.where((slug) => !known.contains(slug));
    if (unknown.isNotEmpty) {
      return _validation({
        'interests': ['Unknown interests: ${unknown.join(', ')}.'],
      });
    }
    if (slugs.length > maxInterests) {
      return _validation({
        'interests': ['Choose at most $maxInterests interests.'],
      });
    }
    interests = [...slugs];
    return _ok(_profile());
  }

  // --- Photos --------------------------------------------------------------

  Map<String, Object?> _album() {
    return {
      'photos': [for (final photo in photos) _photo(photo)],
      'max_photos': maxPhotos,
    };
  }

  Map<String, Object?> _photo(({String id, bool isPrimary}) photo) {
    return {
      'id': photo.id,
      'url': 'https://$storageHost/${photo.id}.jpg?X-Amz-Signature=read',
      'position': photos.indexOf(photo),
      'is_primary': photo.isPrimary,
      'moderation_status': 'approved',
      'width': 1200,
      'height': 1600,
      'created_at': '2026-09-15T10:00:00.000Z',
    };
  }

  ResponseBody _createUpload(Map<String, Object?> body) {
    final mimeType = body['mime_type']! as String;
    final size = body['size_bytes']! as int;
    if (!const ['image/jpeg', 'image/png', 'image/webp'].contains(mimeType)) {
      return _error(
        415,
        'UNSUPPORTED_MEDIA_TYPE',
        'That file type is not supported.',
      );
    }
    if (size > 10 * 1024 * 1024) {
      return _error(
        413,
        'FILE_TOO_LARGE',
        'That file is too large. The limit is 10MB.',
      );
    }
    final id = 'upload-${_nextId++}';
    _uploads[id] = (
      purpose: body['purpose']! as String,
      mimeType: mimeType,
      size: size,
      completed: false,
    );
    return _ok({
      'upload_id': id,
      'purpose': body['purpose'],
      'url': 'https://$storageHost/$id?X-Amz-Signature=write',
      'headers': {'Content-Type': mimeType, 'Content-Length': '$size'},
      'expires_at': '2026-09-15T10:15:00.000Z',
    }, status: 201);
  }

  /// Storage refuses bytes that don't match what the URL was issued for.
  ResponseBody _store(RequestOptions options) {
    final id = options.uri.pathSegments.single;
    final upload = _uploads[id];
    final bytes = options.data;
    if (options.method != 'PUT' ||
        upload == null ||
        bytes is! Uint8List ||
        bytes.length != upload.size ||
        options.headers['content-type'] != upload.mimeType) {
      return textResponse(403, '<Error><Code>SignatureDoesNotMatch</Code>');
    }
    storedUploads[id] = bytes;
    return ResponseBody.fromString('', 200);
  }

  ResponseBody _completeUpload(String id) {
    final upload = _uploads[id];
    if (upload == null) {
      return _error(404, 'NOT_FOUND', 'That upload does not exist.');
    }
    if (!storedUploads.containsKey(id)) {
      return _error(
        400,
        'BAD_REQUEST',
        'We could not find that file. Upload it before completing.',
      );
    }
    _uploads[id] = (
      purpose: upload.purpose,
      mimeType: upload.mimeType,
      size: upload.size,
      completed: true,
    );
    return _ok({'id': id, 'is_uploaded': true});
  }

  ResponseBody _addPhoto(Map<String, Object?> body) {
    final uploadId = body['upload_id']! as String;
    if (_uploads[uploadId]?.completed != true) {
      return _error(
        400,
        'BAD_REQUEST',
        'That upload has not finished. Complete it before using it.',
      );
    }
    if (photos.length >= maxPhotos) {
      return _error(409, 'CONFLICT', 'You can have at most 6 photos.');
    }
    final photo = (id: 'photo-${_nextId++}', isPrimary: photos.isEmpty);
    photos.add(photo);
    return _ok(_photo(photo), status: 201);
  }

  ResponseBody _deletePhoto(String id) {
    final index = photos.indexWhere((photo) => photo.id == id);
    if (index < 0) {
      return _error(404, 'NOT_FOUND', 'That photo does not exist.');
    }
    if (photos.length == 1 && isOnboarded) {
      return _error(
        409,
        'CONFLICT',
        'Your profile needs at least one photo. Add another one, then remove '
            'this one.',
        details: {'min_photos': 1},
      );
    }
    final removed = photos.removeAt(index);
    if (removed.isPrimary && photos.isNotEmpty) {
      photos[0] = (id: photos[0].id, isPrimary: true);
    }
    return _ok({'deleted': true});
  }

  ResponseBody _reorderPhotos(Map<String, Object?> body) {
    final ids = (body['photo_ids']! as List<Object?>).cast<String>();
    final live = {for (final photo in photos) photo.id};
    if (ids.length != photos.length ||
        ids.toSet().length != ids.length ||
        !ids.every(live.contains)) {
      return _validation({
        'photo_ids': ['List every photo exactly once, in the order you want.'],
      });
    }
    _arrangePhotos(ids);
    return _ok({
      'photos': [for (final photo in photos) _photo(photo)],
    });
  }

  ResponseBody _makeMainPhoto(String id) {
    if (!photos.any((photo) => photo.id == id)) {
      return _error(404, 'NOT_FOUND', 'That photo does not exist.');
    }
    _arrangePhotos([
      id,
      for (final photo in photos)
        if (photo.id != id) photo.id,
    ]);
    return _ok({
      'photos': [for (final photo in photos) _photo(photo)],
    });
  }

  /// Puts the photos in the order of [ids]; the first becomes the main one.
  void _arrangePhotos(List<String> ids) {
    photos
      ..clear()
      ..addAll([
        for (final (index, id) in ids.indexed) (id: id, isPrimary: index == 0),
      ]);
  }

  // --- Settings and devices --------------------------------------------------

  Map<String, Object?> _settings() {
    return {
      'theme': theme,
      'text_scale': textScale,
      'reduce_motion': reduceMotion,
      'high_contrast': highContrast,
      'distance_unit': distanceUnit,
      'show_distance': showDistance,
      'show_last_active': showLastActive,
      'incognito': incognito,
      'global_verified_only': verifiedOnlyEverywhere,
      'pause_new_matches': pauseNewMatches,
      'language': 'en',
      'snooze': {
        'is_snoozed': isSnoozed,
        'ends_at': snoozeEndsAt?.toUtc().toIso8601String(),
      },
      'updated_at': '2026-09-15T10:00:00.000Z',
    };
  }

  ResponseBody _updateSettings(Map<String, Object?> body) {
    if (body['distance_unit'] case final Object unit
        when unit != 'miles' && unit != 'kilometres') {
      return _validation({
        'distance_unit': ['Invalid enum value.'],
      });
    }
    if (body['text_scale'] case final num scale
        when scale < 0.8 || scale > 2.0) {
      return _validation({
        'text_scale': ['Text scale must be between 0.8 and 2.0.'],
      });
    }
    if (body['distance_unit'] case final String unit) distanceUnit = unit;
    if (body['show_distance'] case final bool show) showDistance = show;
    if (body['show_last_active'] case final bool show) showLastActive = show;
    if (body['theme'] case final String value) theme = value;
    if (body['text_scale'] case final num value) textScale = value.toDouble();
    if (body['reduce_motion'] case final bool value) reduceMotion = value;
    if (body['high_contrast'] case final bool value) highContrast = value;
    if (body['incognito'] case final bool value) incognito = value;
    if (body['global_verified_only'] case final bool value) {
      verifiedOnlyEverywhere = value;
    }
    if (body['pause_new_matches'] case final bool value) {
      pauseNewMatches = value;
    }
    return _ok(_settings());
  }

  ResponseBody _snooze(Map<String, Object?> body) {
    final endsAt = switch (body['ends_at']) {
      final String value => DateTime.parse(value),
      _ => null,
    };
    if (endsAt != null && !endsAt.isAfter(now())) {
      return _validation({
        'ends_at': ['Choose a time in the future.'],
      });
    }
    isSnoozed = true;
    snoozeEndsAt = endsAt;
    return _ok(_settings());
  }

  ResponseBody _endSnooze() {
    isSnoozed = false;
    snoozeEndsAt = null;
    return _ok(_settings());
  }

  ResponseBody _devices(RequestOptions options) {
    final current = options.headers['x-device-id'];
    final ordered = [...devices]
      ..sort((a, b) => b.lastSeenAt.compareTo(a.lastSeenAt));
    return _ok({
      'devices': [
        for (final device in ordered)
          device.toJson(isCurrent: device.deviceId == current),
      ],
    });
  }

  ResponseBody _signOutDevice(String id) {
    final index = devices.indexWhere((device) => device.id == id);
    if (index < 0) {
      return _error(404, 'NOT_FOUND', 'That device is not signed in.');
    }
    devicesSignedOut.add(devices.removeAt(index).deviceId);
    return _ok({'revoked': true});
  }

  ResponseBody _signOutOtherDevices(RequestOptions options) {
    final current = options.headers['x-device-id'];
    final others = [
      for (final device in devices)
        if (device.deviceId != current) device,
    ];
    for (final device in others) {
      devices.remove(device);
      devicesSignedOut.add(device.deviceId);
    }
    return _ok({'revoked_count': others.length});
  }

  // --- Modes ---------------------------------------------------------------

  Map<String, Object?> _modes() {
    return {
      'modes': [
        for (final (mode, label, _) in modeCatalogue) _modeView(mode, label),
      ],
      'enabled_count': enabledModes.length,
      'max_simultaneous_modes': maxModes,
      'primary_mode': primaryMode,
    };
  }

  Map<String, Object?> _modeView(String mode, String label) {
    return {
      'mode': mode,
      'label': label,
      'primary_action_label': 'Like',
      'is_enabled': enabledModes.contains(mode),
      'is_primary': primaryMode == mode,
      'requires_verification': mode == 'cuddle',
      'can_enable': mode != 'cuddle' || isVerified,
      // The server's defaults, until the user changes them.
      'min_age': 18,
      'max_age': 99,
      'radius_metres': 48280,
      'verified_only': false,
      ...?modeFilters[mode],
      'preferences': <String, Object?>{},
      'updated_at': null,
    };
  }

  ResponseBody _updateMode(String mode, Map<String, Object?> body) {
    final label = [
      for (final (value, label, _) in modeCatalogue)
        if (value == mode) label,
    ].firstOrNull;
    if (label == null) return _error(404, 'NOT_FOUND', 'Not found.');

    if (body['is_enabled'] case final bool enable) {
      if (enable && !enabledModes.contains(mode)) {
        if (mode == 'cuddle' && !isVerified) {
          return _error(
            403,
            'FORBIDDEN',
            'Verify your identity to use this mode.',
          );
        }
        if (enabledModes.length >= maxModes) {
          return _error(
            403,
            'PREMIUM_REQUIRED',
            'Your plan includes $maxModes modes at a time. Upgrade for more.',
          );
        }
        enabledModes.add(mode);
        primaryMode ??= mode;
      } else if (!enable) {
        enabledModes.remove(mode);
        if (primaryMode == mode) primaryMode = enabledModes.firstOrNull;
      }
    }

    const filterKeys = ['min_age', 'max_age', 'radius_metres', 'verified_only'];
    final filters = {
      for (final key in filterKeys)
        if (body.containsKey(key)) key: body[key],
    };
    if (filters.isNotEmpty) {
      modeFilters[mode] = {...?modeFilters[mode], ...filters};
      filtersSaved.add(mode);
    }

    return _ok(_modeView(mode, label));
  }

  ResponseBody _makePrimary(String mode) {
    if (!enabledModes.contains(mode)) {
      return _validation({
        'mode': ['Enable this mode before making it your primary.'],
      });
    }
    primaryMode = mode;
    return _ok(_modes());
  }

  // --- Catalogue -----------------------------------------------------------

  Map<String, Object?> _config() {
    return {
      'modes': [
        for (final (value, label, description) in modeCatalogue)
          {
            'value': value,
            'label': label,
            'primary_action_label': 'Like',
            'super_action_label': 'Super Like',
            'description': description,
          },
      ],
      'deck_actions': ['pass', 'like', 'super_like'],
      'report_reasons': [
        {'value': 'harassment', 'label': 'Harassment or abuse'},
        {'value': 'fake_profile', 'label': 'Fake profile'},
        {'value': 'spam_scam', 'label': 'Spam or scam'},
        {'value': 'safety_concern', 'label': 'Safety concern'},
      ],
      'interests': [
        for (final (slug, label, category) in interestCatalogue)
          {
            'id': 'interest-$slug',
            'slug': slug,
            'label': label,
            'category': category,
            'modes': <Object?>[],
          },
      ],
      'prompts': [
        for (final (slug, question) in promptCatalogue)
          {
            'id': 'question-$slug',
            'slug': slug,
            'question': question,
            'modes': <Object?>[],
          },
      ],
      'lifestyle_options': lifestyleOptions,
      'limits': {
        'max_interests': maxInterests,
        'max_prompts': 3,
        'max_photos': maxPhotos,
        'bio_max_length': 500,
        'default_page_size': 20,
        'max_page_size': 100,
      },
      'sign_in': {
        'email': true,
        'phone': phoneSignIn,
        'google': googleSignIn,
        'apple': false,
      },
      'support': {
        'email': supportEmail,
        'help_url': helpUrl,
        'guidelines_url': guidelinesUrl,
        'terms_url': termsUrl,
        'privacy_url': privacyUrl,
      },
    };
  }

  /// An interest retired from the catalogue can still be on a profile.
  static String _interestLabel(String slug) {
    for (final (known, label, _) in interestCatalogue) {
      if (known == slug) return label;
    }
    return slug;
  }

  // --- Verification --------------------------------------------------------

  ResponseBody _startVerification(Map<String, Object?> body) {
    final method = body['method'];
    if (method is! String ||
        !const ['photo', 'government_id', 'social'].contains(method)) {
      return _validation({
        'method': ['Choose a supported verification method.'],
      });
    }
    if (isVerified) {
      return _error(409, 'CONFLICT', 'Your account is already verified.');
    }
    if (verification?.status == 'pending') {
      return _error(
        409,
        'CONFLICT',
        'You already have a verification in progress.',
      );
    }

    verification = FakeVerification(
      id: 'verification-${_nextId++}',
      method: method,
    );
    // 201, as the real server answers a started attempt.
    return _ok(_verificationView(), status: 201);
  }

  ResponseBody _attachVerificationDocument(
    String id,
    Map<String, Object?> body,
  ) {
    final record = verification;
    if (record == null || record.id != id) {
      return _error(404, 'NOT_FOUND', 'That verification does not exist.');
    }
    if (record.status != 'pending') {
      return _error(
        409,
        'CONFLICT',
        'That verification has already been reviewed.',
      );
    }

    // The same check as the server's `claimAsset`, and the same answer: an
    // upload of the wrong kind is one this user does not have, so a profile
    // photo can never be submitted as an ID. (Verified against staging.)
    final upload = _uploads[body['upload_id']];
    if (upload == null || upload.purpose != 'verification_document') {
      return _error(404, 'NOT_FOUND', 'That upload does not exist.');
    }
    if (!upload.completed) {
      return _error(
        400,
        'BAD_REQUEST',
        'That upload has not finished. Complete it before using it.',
      );
    }

    record
      ..documentUploadId = body['upload_id']! as String
      ..currentStep = 2;
    return _ok(_verificationView());
  }

  ResponseBody _submitVerification(String id) {
    final record = verification;
    if (record == null || record.id != id) {
      return _error(404, 'NOT_FOUND', 'That verification does not exist.');
    }
    if (record.status != 'pending') {
      return _error(
        409,
        'CONFLICT',
        'That verification has already been reviewed.',
      );
    }
    if (record.method != 'social' && record.documentUploadId == null) {
      return _error(
        400,
        'BAD_REQUEST',
        'Upload your document before submitting.',
      );
    }

    record
      ..currentStep = 3
      ..submittedAt = now();
    return _ok(_verificationView());
  }

  /// Stands in for a moderator, so a test can see what an outcome looks like.
  void reviewVerification({required bool approve, String? reason}) {
    final record = verification;
    if (record == null) return;
    record
      ..status = approve ? 'approved' : 'rejected'
      ..reviewedAt = now()
      ..rejectionReason = approve ? null : reason;
    isVerified = isVerified || approve;
  }

  Map<String, Object?> _verificationView() {
    final record = verification;
    if (record == null) {
      return {
        'id': null,
        'method': null,
        'status': 'not_started',
        'current_step': 0,
        'total_steps': 3,
        'submitted_at': null,
        'reviewed_at': null,
        'rejection_reason': null,
        'is_verified': isVerified,
      };
    }
    return {
      'id': record.id,
      'method': record.method,
      'status': record.status,
      'current_step': record.currentStep,
      'total_steps': 3,
      'submitted_at': record.submittedAt?.toIso8601String(),
      'reviewed_at': record.reviewedAt?.toIso8601String(),
      'rejection_reason': record.rejectionReason,
      'is_verified': isVerified,
    };
  }

  /// The plans on sale, word for word as staging's catalogue lists them.
  static const planCatalogue = [
    {
      'slug': 'basic_monthly',
      'name': 'Kinvo Basic — Monthly',
      'tier': 'basic',
      'billing_cycle': 'monthly',
      'price': {'amount_minor': 999, 'currency': 'USD'},
      'features': basicFeatures,
    },
    {
      'slug': 'basic_yearly',
      'name': 'Kinvo Basic — Yearly',
      'tier': 'basic',
      'billing_cycle': 'yearly',
      'price': {'amount_minor': 7999, 'currency': 'USD'},
      'features': basicFeatures,
    },
    {
      'slug': 'advanced_monthly',
      'name': 'Kinvo Premium — Monthly',
      'tier': 'advanced',
      'billing_cycle': 'monthly',
      'price': {'amount_minor': 1999, 'currency': 'USD'},
      'features': premiumFeatures,
    },
    {
      'slug': 'advanced_yearly',
      'name': 'Kinvo Premium — Yearly',
      'tier': 'advanced',
      'billing_cycle': 'yearly',
      'price': {'amount_minor': 15999, 'currency': 'USD'},
      'features': premiumFeatures,
    },
  ];

  static const basicFeatures = [
    'Unlimited likes',
    'Unlimited messages',
    'Filter by interests and goals',
    'Undo your last swipe',
    'Up to 5 modes at once',
    'No ads',
  ];

  static const premiumFeatures = [
    'Unlimited likes',
    'Unlimited messages',
    'See who liked you',
    'Filter by interests and goals',
    'Undo your last swipe',
    'Boost your profile',
    'Extend a match before it expires',
    'Every mode at once',
    'No ads',
  ];

  Map<String, Object?> _currentPlanView() {
    final current = subscription;
    return {
      'tier': current != null && current.isActive ? current.tier : 'free',
      'subscription': current == null
          ? null
          : {
              'id': 'subscription-1',
              'tier': current.tier,
              'billing_cycle': current.cycle,
              'product_slug': current.productSlug,
              'status': current.isActive ? 'active' : 'expired',
              'source': current.source,
              'current_period_start': current.periodStart.toIso8601String(),
              'current_period_end': current.periodEnd.toIso8601String(),
              'auto_renew': current.source != 'test',
              'is_active': current.isActive,
              'cancelled_at': null,
              'created_at': current.periodStart.toIso8601String(),
            },
    };
  }

  /// What the plan unlocks, as the server's matrix has it: ads for the free
  /// plan only, and seeing who liked you on Premium.
  Map<String, Object?> _entitlementsView() {
    final current = subscription;
    final tier = current != null && current.isActive ? current.tier : 'free';
    return {
      'tier': tier,
      'flags': {
        'show_ads': tier == 'free',
        'see_who_liked_you': tier == 'advanced',
        'rewind': tier != 'free',
      },
      'quotas': const <String, Object?>{},
      'upgrade_available': tier != 'advanced',
    };
  }

  /// Grants the plan named in [body] at once, as staging's test purchase
  /// does — and answers as a path that does not exist where it is off.
  ResponseBody _testPurchase(Map<String, Object?> body) {
    if (purchaseMode != 'test') {
      return _error(404, 'NOT_FOUND', 'That endpoint does not exist.');
    }

    final product = planCatalogue
        .where((plan) => plan['slug'] == body['product'])
        .firstOrNull;
    if (product == null) {
      return _validation({
        'product': ['That plan is not on sale.'],
      });
    }

    final start = now().toUtc();
    final months = product['billing_cycle'] == 'yearly' ? 12 : 1;
    subscription = FakeSubscription(
      productSlug: product['slug']! as String,
      tier: product['tier']! as String,
      cycle: product['billing_cycle']! as String,
      source: 'test',
      periodStart: start,
      periodEnd: DateTime.utc(
        start.year,
        start.month + months,
        start.day,
        start.hour,
        start.minute,
      ),
    );
    testPurchases.add(product['slug']! as String);
    return _ok(_currentPlanView(), status: 201);
  }

  ResponseBody _endTestPlan() {
    if (purchaseMode != 'test') {
      return _error(404, 'NOT_FOUND', 'That endpoint does not exist.');
    }

    final current = subscription;
    if (current != null && current.source == 'test' && current.isActive) {
      current.isActive = false;
      testPlansEnded++;
    }
    return _ok(_currentPlanView());
  }

  static ResponseBody _ok(Object? data, {int status = 200}) {
    return jsonResponse(status, successEnvelope(data));
  }

  static ResponseBody _error(
    int status,
    String code,
    String message, {
    Map<String, Object?>? details,
  }) {
    return jsonResponse(status, errorEnvelope(code, message, details: details));
  }

  static ResponseBody _validation(Map<String, Object?> details) {
    return _error(
      400,
      'VALIDATION_FAILED',
      'Some fields need attention.',
      details: details,
    );
  }
}

/// A subscription, as the server keeps one.
final class FakeSubscription {
  FakeSubscription({
    required this.productSlug,
    required this.tier,
    required this.cycle,
    required this.source,
    required this.periodStart,
    required this.periodEnd,
  });

  final String productSlug;

  /// The server's name for it: `basic` or `advanced`.
  final String tier;

  final String cycle;

  /// `test` for a test purchase; `apple` or `google` for a store's.
  final String source;

  final DateTime periodStart;
  final DateTime periodEnd;
  bool isActive = true;
}

/// An identity check in progress, as the server keeps one.
final class FakeVerification {
  FakeVerification({required this.id, required this.method});

  final String id;
  final String method;

  String status = 'pending';
  int currentStep = 1;
  String? documentUploadId;
  DateTime? submittedAt;
  DateTime? reviewedAt;
  String? rejectionReason;
}

/// A device signed in to the account on the fake server.
final class FakeDevice {
  const FakeDevice({
    required this.id,
    required this.deviceId,
    required this.lastSeenAt,
    this.platform = 'android',
    this.model,
    this.osVersion,
    this.appVersion = '1.0.0+1',
  });

  /// The entry's id in the list.
  final String id;

  /// The id the app sends as `X-Device-Id`.
  final String deviceId;
  final DateTime lastSeenAt;
  final String platform;
  final String? model;
  final String? osVersion;
  final String? appVersion;

  Map<String, Object?> toJson({required bool isCurrent}) {
    return {
      'id': id,
      'device_id': deviceId,
      'platform': platform,
      'app_version': appVersion,
      'os_version': osVersion,
      'model': model,
      'is_current': isCurrent,
      'last_seen_at': lastSeenAt.toUtc().toIso8601String(),
      'created_at': '2026-09-01T10:00:00.000Z',
    };
  }
}

/// Someone the fake server can put in a deck.
final class FakePerson {
  const FakePerson({
    required this.id,
    required this.name,
    this.age = 29,
    this.distanceMetres = 3200,
    this.bio = 'Here for good company.',
    this.interests = const ['music', 'coffee'],
    this.isVerified = false,
    this.isPremium = false,
    this.photoCount = 0,
  });

  final String id;
  final String name;
  final int age;
  final int distanceMetres;
  final String? bio;
  final List<String> interests;
  final bool isVerified;
  final bool isPremium;

  /// How many approved photos they have. Zero by default, so a test that is
  /// not about photos never waits on one loading.
  final int photoCount;

  /// Their album, as the API gives it: ordered, approved, first one primary.
  List<Map<String, Object?>> get photos => [
    for (var index = 0; index < photoCount; index++)
      {
        'id': '$id-photo-$index',
        'url': 'https://photos.example.com/$id/$index.jpg',
        'width': 1200,
        'height': 1600,
      },
  ];

  /// The compact user every list in the API returns.
  Map<String, Object?> compact(DateTime now) {
    return {
      'id': id,
      'display_name': name,
      'age': age,
      // The first of the album, exactly as the server takes it.
      'primary_photo_url': photos.firstOrNull?['url'],
      'is_verified': isVerified,
      'is_premium': isPremium,
      'is_online': false,
      'last_active_at': now
          .subtract(const Duration(hours: 2))
          .toIso8601String(),
    };
  }
}

/// A match on the fake server.
/// One call on the fake server. Mutable, because a call changes as it is
/// answered and ended.
final class FakeCall {
  FakeCall({
    required this.id,
    required this.matchId,
    required this.mode,
    required this.isInitiator,
    required this.createdAt,
    this.kind = 'video',
    this.status = 'ringing',
  });

  final String id;
  final String matchId;
  final String mode;
  final String kind;
  final bool isInitiator;
  final DateTime createdAt;

  String status;
  DateTime? answeredAt;
  DateTime? endedAt;
  int? durationSeconds;
}

final class FakeMatch {
  FakeMatch({
    required this.id,
    required this.mode,
    required this.person,
    required this.isSuperLike,
    required this.matchedAt,
    required this.expiresAt,
  });

  final String id;
  final String mode;
  final FakePerson person;
  final bool isSuperLike;
  final DateTime matchedAt;
  DateTime expiresAt;
  int extensionCount = 0;

  String get conversationId => 'conversation-$id';

  /// The conversation's messages, oldest first.
  final List<FakeMessage> messages = [];

  /// Messages from the person the user hasn't read.
  int unreadCount = 0;

  bool isArchived = false;
  bool isMuted = false;

  /// How many times the user marked the conversation read.
  int readByUser = 0;
}

/// A notification in the fake server's feed.
final class FakeNotification {
  FakeNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
  });

  final String id;
  final String category;
  final String title;
  final String body;
  final Map<String, Object?> data;
  final DateTime createdAt;
  DateTime? readAt;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'category': category,
      'title': title,
      'body': body,
      'data': data,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// A message on the fake server.
final class FakeMessage {
  FakeMessage({
    required this.id,
    required this.senderId,
    required this.type,
    required this.createdAt,
    this.body,
    this.mediaUrl,
    this.overridden = false,
  });

  final String id;
  final String senderId;
  final String type;
  final String? body;
  final String? mediaUrl;
  final DateTime createdAt;

  /// Whether it was sent after a moderation warning.
  final bool overridden;

  bool flagged = false;
  DateTime? readAt;

  String get preview => type == 'image' ? 'Photo' : body ?? '';

  Map<String, Object?> toJson(String conversationId) {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'type': type,
      'body': body,
      'media_url': mediaUrl,
      'venue_id': null,
      'duration_ms': null,
      'moderation_flagged': flagged,
      'moderation_overridden': overridden,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// A plan on the fake server.
final class FakePlan {
  FakePlan({
    required this.id,
    required this.match,
    required this.createdByUser,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final FakeMatch match;

  /// Whether the signed-in user made it, rather than the match's person.
  final bool createdByUser;

  String status;
  final DateTime createdAt;
  FakeVenue? venue;
  String? customLocation;
  String? customAddress;
  DateTime? scheduledAt;
  int? durationMinutes;
  String? notes;
  String? cancellationReason;

  /// How many times the user changed it.
  int edits = 0;

  /// The trusted contacts who were emailed about it.
  final Set<String> sharedWith = {};

  /// Where it is, in a few words.
  String get place => venue?.name ?? customLocation ?? 'somewhere';

  Map<String, Object?> toJson(DateTime now) {
    final venue = this.venue;
    final scheduledAt = this.scheduledAt;
    return {
      'id': id,
      'match_id': match.id,
      'mode': match.mode,
      'user': match.person.compact(now),
      'status': status,
      'scheduled_at': scheduledAt?.toUtc().toIso8601String(),
      'duration_minutes': durationMinutes,
      'notes': notes,
      'venue': venue == null
          ? null
          : {
              'id': venue.id,
              'name': venue.name,
              'category': venue.category,
              'address': venue.address,
            },
      'custom_location': customLocation,
      'custom_address': customAddress,
      'is_mine': createdByUser,
      'awaiting_my_response':
          status == 'proposed' &&
          !createdByUser &&
          (scheduledAt == null || scheduledAt.isAfter(now)),
      'shared_with_contacts': sharedWith.length,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

/// A place in the fake server's list.
final class FakeVenue {
  const FakeVenue({
    required this.id,
    required this.name,
    this.category = 'cafe',
    this.address,
    this.distanceMetres = 1200,
    this.modes = const ['dating'],
  });

  final String id;
  final String name;
  final String category;
  final String? address;
  final int distanceMetres;
  final List<String> modes;

  Map<String, Object?> toJson({required bool saved}) {
    return {
      'id': id,
      'name': name,
      'category': category,
      'description': null,
      'address': address,
      'city': 'London',
      'rating': 4.5,
      'price_level': 2,
      'photo_url': null,
      'website_url': null,
      'modes': modes,
      'distance_metres': distanceMetres,
      'is_saved': saved,
    };
  }
}

/// A trusted contact on the fake server.
final class FakeContact {
  FakeContact({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.relationship,
  });

  final String id;
  String name;
  String? phone;
  String? email;
  String? relationship;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'relationship': relationship,
      'created_at': '2026-09-17T10:00:00.000Z',
    };
  }
}
