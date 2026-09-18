/// How long ago [at] was, in the largest unit that fits: "3 days ago".
String timeAgo(DateTime at, DateTime now) {
  final since = now.difference(at);
  if (since.inMinutes < 1) return 'just now';
  if (since.inHours < 1) {
    return since.inMinutes == 1
        ? '1 minute ago'
        : '${since.inMinutes} minutes ago';
  }
  if (since.inDays < 1) {
    return since.inHours == 1 ? '1 hour ago' : '${since.inHours} hours ago';
  }
  return since.inDays == 1 ? 'yesterday' : '${since.inDays} days ago';
}
