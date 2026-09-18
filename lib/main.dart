import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app.dart';
import 'src/core/network/api_retry_policy.dart';

void main() {
  runApp(const ProviderScope(retry: apiRetryPolicy, child: KinvoApp()));
}
