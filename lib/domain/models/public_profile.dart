/// Perfil visible en Comunidad (`public_profiles/{uid}`), generado por el
/// servidor. Nunca contiene fecha de nacimiento ni datos de autenticación.
class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.displayName,
    required this.initials,
    this.cellName,
    this.nationality,
    this.stampCount = 0,
    this.stampIds = const [],
    this.communityVisible = true,
  });

  final String uid;
  final String displayName;
  final String initials;
  final String? cellName;
  final String? nationality;
  final int stampCount;
  final List<String> stampIds;
  final bool communityVisible;
}
