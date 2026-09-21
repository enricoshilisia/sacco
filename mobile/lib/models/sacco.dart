/// A SACCO resolved from its code via the public lookup endpoint
/// (backend: tenants.views.SaccoLookupView).
class Sacco {
  final String code;
  final String name;
  final String country;
  final String currency;
  final String defaultLanguage;
  final String? logo;
  final String domain;

  const Sacco({
    required this.code,
    required this.name,
    required this.country,
    required this.currency,
    required this.defaultLanguage,
    required this.logo,
    required this.domain,
  });

  factory Sacco.fromJson(Map<String, dynamic> json) => Sacco(
        code: json['code'] as String,
        name: json['name'] as String,
        country: json['country'] as String,
        currency: json['currency'] as String,
        defaultLanguage: (json['default_language'] as String?) ?? 'en',
        logo: json['logo'] as String?,
        domain: json['domain'] as String,
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'country': country,
        'currency': currency,
        'default_language': defaultLanguage,
        'logo': logo,
        'domain': domain,
      };
}
