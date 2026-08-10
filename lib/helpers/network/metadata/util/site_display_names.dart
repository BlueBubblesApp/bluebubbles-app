import 'package:bluebubbles/helpers/network/metadata/util/metadata_urls.dart';

/// Translates the host a link points at into the name people call that site.
///
/// The site line on a preview card is deliberately derived from the URL and
/// never from `og:site_name` — see `UrlPreviewController.siteText`. That keeps
/// a phishing page from labelling itself "Apple", but it also means the card
/// says `chat.whatsapp.com` where every other messaging app says "WhatsApp".
///
/// This layer buys the readability back without giving up the guarantee: the
/// lookup key is the *real* host, so the label can only ever be the one [names]
/// gives that exact domain. A lookalike host matches nothing and still renders
/// its raw self, which is the whole point.
///
/// Resolution is display-time, not fetch-time. Nothing here is persisted onto
/// the message row, so an entry added to [names] applies to previews that are
/// already cached, with no refetch.
abstract final class SiteDisplayNames {
  /// Host -> the name to render for it. Add entries here; this is intentionally
  /// a compile-time constant and not a user setting.
  ///
  /// Keys are hosts, already normalised the way [_normalizeHost] normalises
  /// them: lowercase, no `www.`, no trailing dot. A key matches its own host
  /// and any subdomain of it, so `youtube.com` covers `m.youtube.com` while
  /// `music.apple.com` can still say something different from `apple.com`.
  static const Map<String, String> names = {
    // Apple
    'apple.com': 'Apple',
    'music.apple.com': 'Apple Music',
    'podcasts.apple.com': 'Apple Podcasts',
    'tv.apple.com': 'Apple TV',
    'books.apple.com': 'Apple Books',
    'apps.apple.com': 'App Store',
    'itunes.apple.com': 'iTunes',
    'maps.apple.com': 'Apple Maps',
    'icloud.com': 'iCloud',
    'sharedalbums.icloud.com': 'iCloud Photos',
    // Messaging & social
    'whatsapp.com': 'WhatsApp',
    'chat.whatsapp.com': 'WhatsApp',
    'instagram.com': 'Instagram',
    'facebook.com': 'Facebook',
    'fb.com': 'Facebook',
    'fb.watch': 'Facebook',
    'messenger.com': 'Facebook Messenger',
    'x.com': 'X',
    'twitter.com': 'X',
    't.co': 'X',
    'bsky.app': 'Bluesky',
    'threads.com': 'Threads',
    'threads.net': 'Threads',
    'tiktok.com': 'TikTok',
    'snapchat.com': 'Snapchat',
    'reddit.com': 'Reddit',
    'redd.it': 'Reddit',
    'discord.com': 'Discord',
    'discord.gg': 'Discord',
    't.me': 'Telegram',
    'signal.group': 'Signal',
    'linkedin.com': 'LinkedIn',
    'pinterest.com': 'Pinterest',
    'tumblr.com': 'Tumblr',
    'nextdoor.com': 'Nextdoor',
    // Video & audio
    'youtube.com': 'YouTube',
    'youtu.be': 'YouTube',
    'twitch.tv': 'Twitch',
    'vimeo.com': 'Vimeo',
    'netflix.com': 'Netflix',
    'hulu.com': 'Hulu',
    'disneyplus.com': 'Disney+',
    'max.com': 'HBO Max',
    'primevideo.com': 'Prime Video',
    'open.spotify.com': 'Spotify',
    'spotify.com': 'Spotify',
    'soundcloud.com': 'SoundCloud',
    'bandcamp.com': 'Bandcamp',
    // Shopping
    'amazon.com': 'Amazon',
    'a.co': 'Amazon',
    'amzn.to': 'Amazon',
    'ebay.com': 'eBay',
    'etsy.com': 'Etsy',
    'target.com': 'Target',
    'walmart.com': 'Walmart',
    'bestbuy.com': 'Best Buy',
    'costco.com': 'Costco',
    // Food & travel
    'doordash.com': 'DoorDash',
    'ubereats.com': 'Uber Eats',
    'grubhub.com': 'Grubhub',
    'yelp.com': 'Yelp',
    'opentable.com': 'OpenTable',
    'airbnb.com': 'Airbnb',
    // Work & docs
    'github.com': 'GitHub',
    'gitlab.com': 'GitLab',
    'docs.google.com': 'Google Docs',
    'drive.google.com': 'Google Drive',
    'photos.google.com': 'Google Photos',
    'maps.google.com': 'Google Maps',
    'meet.google.com': 'Google Meet',
    'gemini.google.com': 'Google Gemini',
    'goo.gl': 'Google',
    'google.com': 'Google',
    'dropbox.com': 'Dropbox',
    'notion.so': 'Notion',
    'figma.com': 'Figma',
    'zoom.us': 'Zoom',
    'slack.com': 'Slack',
    'trello.com': 'Trello',
    // Reading
    'wikipedia.org': 'Wikipedia',
    'news.ycombinator.com': 'Hacker News',
    'medium.com': 'Medium',
    'substack.com': 'Substack',
    'nytimes.com': 'The New York Times',
    'washingtonpost.com': 'The Washington Post',
    'theverge.com': 'The Verge',
    'bbc.co.uk': 'BBC',
    'bbc.com': 'BBC',
    // Money
    'venmo.com': 'Venmo',
    'cash.app': 'Cash App',
    'paypal.com': 'PayPal',
    'stripe.com': 'Stripe',
    'coinbase.com': 'Coinbase',
    'binance.com': 'Binance',
    // Misc
    'imdb.com': 'IMDb',
    'rottentomatoes.com': 'Rotten Tomatoes',
    'weather.com': 'The Weather Channel',
    'accuweather.com': 'AccuWeather',
    'chatgpt.com': 'ChatGPT',
    'claude.ai': 'Claude',
    'openai.com': 'OpenAI',
    'midjourney.com': 'MidJourney',
    'dall-e.com': 'DALL·E'
  };

  /// The name mapped to [host], or `null` when there is none and the caller
  /// should show the host itself.
  ///
  /// Tries the whole host first, then drops labels from the left, so the most
  /// specific entry wins (`music.apple.com` over `apple.com`). Labels are only
  /// ever dropped at a dot, which is what keeps `evil-apple.com` and
  /// `apple.com.evil.com` from matching `apple.com`.
  ///
  /// Stops at two labels: a single label is either a bare TLD or an intranet
  /// name, and neither should inherit a mapping.
  static String? resolve(String? host) {
    final normalized = _normalizeHost(host);
    if (normalized == null) return null;

    var candidate = normalized;
    while (true) {
      final match = names[candidate];
      if (match != null) return match;

      final dot = candidate.indexOf('.');
      if (dot < 0) return null;
      final parent = candidate.substring(dot + 1);
      if (!parent.contains('.')) return null;
      candidate = parent;
    }
  }

  /// The site line for [rawUrl]: the mapped name if there is one, else the host
  /// with `www.` stripped. Returns `null` when [rawUrl] has no host.
  static String? forUrl(String? rawUrl) {
    final host = MetadataUrls.parse(rawUrl)?.host;
    if (host == null || host.isEmpty) return null;
    return forHost(host);
  }

  /// [forUrl], for a host that has already been extracted.
  static String? forHost(String? host) {
    final normalized = _normalizeHost(host);
    if (normalized == null) return null;
    return resolve(normalized) ?? normalized;
  }

  /// Lowercases and strips the leading `www.` and any trailing dot. Returns
  /// `null` for anything that does not leave a host behind.
  static String? _normalizeHost(String? raw) {
    if (raw == null) return null;
    var host = raw.trim().toLowerCase();
    if (host.isEmpty) return null;

    while (host.endsWith('.')) {
      host = host.substring(0, host.length - 1);
    }
    if (host.startsWith('www.')) host = host.substring(4);

    return host.isEmpty ? null : host;
  }
}
