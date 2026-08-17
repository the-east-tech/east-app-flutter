import 'organisation_models.dart';
import 'people_models.dart';

class EastAppSession {
  final String token;
  final EastAppTenant tenant;
  final EastAppUser user;

  const EastAppSession({
    required this.token,
    required this.tenant,
    required this.user,
  });

  EastAppSession copyWith({
    String? token,
    EastAppTenant? tenant,
    EastAppUser? user,
  }) {
    return EastAppSession(
      token: token ?? this.token,
      tenant: tenant ?? this.tenant,
      user: user ?? this.user,
    );
  }
}
