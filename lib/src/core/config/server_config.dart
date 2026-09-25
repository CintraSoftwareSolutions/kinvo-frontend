import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../network/api_envelope.dart';

/// The lists and limits the server publishes at `GET /config`, so adding a
/// mode or an interest never needs an app release.
@immutable
final class ServerConfig {
  const ServerConfig({
    required this.modes,
    required this.interests,
    required this.limits,
    this.reportReasons = const [],
    this.prompts = const [],
    this.lifestyleOptions = const {},
    this.signIn = SignInMethods.emailOnly,
    this.support = SupportLinks.none,
  });

  /// Reads the `data` of `GET /config`.
  ///
  /// A malformed mode or interest is left out rather than failing the whole
  /// catalogue: one bad entry shouldn't stop anyone finishing their profile.
  factory ServerConfig.fromJson(JsonMap json) {
    if (json case {
      'modes': final List<Object?> modes,
      'interests': final List<Object?> interests,
      'limits': final JsonMap limits,
    }) {
      return ServerConfig(
        modes: _readEach(modes, ModeOption.tryFromJson, 'mode'),
        interests: _readEach(interests, InterestOption.tryFromJson, 'interest'),
        limits: ProfileLimits.fromJson(limits),
        reportReasons: switch (json['report_reasons']) {
          final List<Object?> reasons => _readEach(
            reasons,
            ReportReasonOption.tryFromJson,
            'report reason',
          ),
          _ => const [],
        },
        prompts: switch (json['prompts']) {
          final List<Object?> prompts => _readEach(
            prompts,
            PromptOption.tryFromJson,
            'prompt',
          ),
          _ => const [],
        },
        lifestyleOptions: switch (json['lifestyle_options']) {
          final JsonMap options => _readLifestyleOptions(options),
          _ => const {},
        },
        signIn: SignInMethods.fromJson(json['sign_in']),
        support: SupportLinks.fromJson(json['support']),
      );
    }
    throw const FormatException('Expected modes, interests and limits.');
  }

  /// In the order the app should offer them.
  final List<ModeOption> modes;

  /// Grouped by category, in the order the app should offer them.
  final List<InterestOption> interests;

  final ProfileLimits limits;

  /// Why someone can be reported, in the order the app should offer them.
  final List<ReportReasonOption> reportReasons;

  /// Questions a profile can answer, in the order the app should offer them.
  final List<PromptOption> prompts;

  /// The answers each profile detail such as `drinking` or `education`
  /// accepts, as API values such as `socially`, in the order to offer them.
  final Map<String, List<String>> lifestyleOptions;

  /// The ways of signing in this server can complete right now.
  final SignInMethods signIn;

  /// Where people get help and read the rules.
  final SupportLinks support;

  static Map<String, List<String>> _readLifestyleOptions(JsonMap options) {
    return {
      for (final MapEntry(:key, :value) in options.entries)
        if (value case final List<Object?> values)
          key: [
            for (final each in values)
              if (each case final String option when option.isNotEmpty) option,
          ],
    };
  }

  static List<T> _readEach<T extends Object>(
    List<Object?> items,
    T? Function(Object? json) read,
    String kind,
  ) {
    final results = [for (final item in items) ?read(item)];
    if (results.length != items.length) {
      developer.log(
        'Skipped ${items.length - results.length} malformed $kind entries.',
        name: 'kinvo.config',
      );
    }
    return results;
  }
}

/// The ways of signing in the server can complete right now, from `sign_in`
/// in `GET /config`. The app offers only these, so no button leads to a
/// method that can only fail. Email is always one of them.
@immutable
final class SignInMethods {
  const SignInMethods({
    this.phone = false,
    this.google = false,
    this.apple = false,
  });

  /// What is assumed until the server says more, or if it never does: a
  /// method is offered only once the server has confirmed it.
  static const emailOnly = SignInMethods();

  /// Reads `sign_in`. Anything but an explicit `true` is off.
  factory SignInMethods.fromJson(Object? json) {
    if (json is! JsonMap) return emailOnly;
    return SignInMethods(
      phone: json['phone'] == true,
      google: json['google'] == true,
      apple: json['apple'] == true,
    );
  }

  /// A code texted to a phone number.
  final bool phone;
  final bool google;
  final bool apple;
}

/// Where people get help and read the rules, from `support` in
/// `GET /config`. Each is null until the operator sets it, and the app shows
/// only those that are set, so no row or link leads nowhere.
@immutable
final class SupportLinks {
  const SupportLinks({
    this.email,
    this.helpCentre,
    this.guidelines,
    this.terms,
    this.privacy,
  });

  static const none = SupportLinks();

  /// Reads `support`. A value that isn't a usable address is left out.
  factory SupportLinks.fromJson(Object? json) {
    if (json is! JsonMap) return none;
    return SupportLinks(
      email: _emailAddress(json['email']),
      helpCentre: _webPage(json['help_url']),
      guidelines: _webPage(json['guidelines_url']),
      terms: _webPage(json['terms_url']),
      privacy: _webPage(json['privacy_url']),
    );
  }

  /// Where to write for help.
  final String? email;

  final Uri? helpCentre;

  /// The community guidelines: what's allowed, and what happens otherwise.
  final Uri? guidelines;

  /// The terms of service.
  final Uri? terms;

  /// The privacy policy.
  final Uri? privacy;

  /// Whether the welcome screen can say what signing up agrees to.
  bool get hasLegalPages => terms != null && privacy != null;

  static final _address = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? _emailAddress(Object? value) {
    return value is String && _address.hasMatch(value) ? value : null;
  }

  /// Only secure web pages: a link from the server never opens anything else
  /// on the phone.
  static Uri? _webPage(Object? value) {
    if (value is! String) return null;
    final uri = Uri.tryParse(value);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri
        : null;
  }
}

/// One of the modes people can use Kinvo in, such as dating or networking.
@immutable
final class ModeOption {
  const ModeOption({
    required this.value,
    required this.label,
    required this.description,
    required this.likeLabel,
    required this.superLikeLabel,
  });

  static ModeOption? tryFromJson(Object? json) {
    if (json
        case {
          'value': final String value,
          'label': final String label,
          'description': final String description,
          'primary_action_label': final String likeLabel,
          'super_action_label': final String superLikeLabel,
        }
        when value.isNotEmpty &&
            label.isNotEmpty &&
            likeLabel.isNotEmpty &&
            superLikeLabel.isNotEmpty) {
      return ModeOption(
        value: value,
        label: label,
        description: description,
        likeLabel: likeLabel,
        superLikeLabel: superLikeLabel,
      );
    }
    return null;
  }

  /// The mode's name in the API, for example `study_buddy`.
  final String value;
  final String label;
  final String description;

  /// The word on the like button in this mode. Every mode likes, passes and
  /// super likes; only what the buttons say changes.
  final String likeLabel;

  /// The word for a super like in this mode.
  final String superLikeLabel;
}

/// An interest people can add to their profile.
@immutable
final class InterestOption {
  const InterestOption({
    required this.slug,
    required this.label,
    required this.category,
  });

  static InterestOption? tryFromJson(Object? json) {
    if (json case {
      'slug': final String slug,
      'label': final String label,
      'category': final String category,
    } when slug.isNotEmpty && label.isNotEmpty) {
      return InterestOption(slug: slug, label: label, category: category);
    }
    return null;
  }

  /// The interest's name in the API, for example `street_food`.
  final String slug;
  final String label;

  /// The group it's shown in, for example `food`.
  final String category;
}

/// A question people can answer on their profile, such as "A perfect
/// weekend looks like…".
@immutable
final class PromptOption {
  const PromptOption({required this.slug, required this.question});

  static PromptOption? tryFromJson(Object? json) {
    if (json case {
      'slug': final String slug,
      'question': final String question,
    } when slug.isNotEmpty && question.isNotEmpty) {
      return PromptOption(slug: slug, question: question);
    }
    return null;
  }

  /// The question's name in the API, for example `perfect_weekend`.
  final String slug;
  final String question;
}

/// A reason for reporting someone.
@immutable
final class ReportReasonOption {
  const ReportReasonOption({required this.value, required this.label});

  static ReportReasonOption? tryFromJson(Object? json) {
    if (json case {
      'value': final String value,
      'label': final String label,
    } when value.isNotEmpty && label.isNotEmpty) {
      return ReportReasonOption(value: value, label: label);
    }
    return null;
  }

  /// The reason's name in the API, for example `spam_scam`.
  final String value;
  final String label;
}

/// Limits on what a profile can hold.
@immutable
final class ProfileLimits {
  const ProfileLimits({
    required this.maxInterests,
    required this.maxPhotos,
    required this.bioMaxLength,
    this.maxPrompts = defaultMaxPrompts,
  });

  /// What the server allows when it doesn't say.
  static const defaultMaxPrompts = 3;

  factory ProfileLimits.fromJson(JsonMap json) {
    if (json case {
      'max_interests': final int maxInterests,
      'max_photos': final int maxPhotos,
      'bio_max_length': final int bioMaxLength,
    } when maxInterests > 0 && maxPhotos > 0 && bioMaxLength > 0) {
      return ProfileLimits(
        maxInterests: maxInterests,
        maxPhotos: maxPhotos,
        bioMaxLength: bioMaxLength,
        maxPrompts: switch (json['max_prompts']) {
          final int maxPrompts when maxPrompts > 0 => maxPrompts,
          _ => defaultMaxPrompts,
        },
      );
    }
    throw const FormatException(
      'Expected positive max_interests, max_photos and bio_max_length.',
    );
  }

  final int maxInterests;
  final int maxPhotos;
  final int bioMaxLength;

  /// How many prompts a profile can answer.
  final int maxPrompts;
}
