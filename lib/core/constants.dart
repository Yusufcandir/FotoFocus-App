class AppConstants {
  static const String baseUrl =
      "https://fotofocus-app-production.up.railway.app";

  static const String auth = "/auth";
  static const String register = "/auth/register";
  static const String login = "/auth/login";
  static const String lessons = "/lessons";
  static const String challenges = "/challenges";
  static const String photos = "/photos";
  static const String comments = "/comments";
  static const String ratings = "/ratings";
  static const String posts = "/posts";

  static String resolveImageUrl(String? url) {
    if (url == null) return "";
    final u = url.trim();
    if (u.isEmpty) return "";
    if (u.startsWith("http://") || u.startsWith("https://")) return u;

    if (u.startsWith("/")) return "$baseUrl$u";
    return "$baseUrl/$u";
  }

  String normalizeImageUrl(String url) {
    if (url.isEmpty) return url;

    // If backend already sends full URL
    if (url.startsWith('http://') || url.startsWith('https://')) return url;

    final base = AppConstants.baseUrl;
    if (url.startsWith('/')) return '$base$url';
    return '$base/$url';
  }
}
