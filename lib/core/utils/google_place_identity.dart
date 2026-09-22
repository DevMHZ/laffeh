/// Identity carried by a Google Maps place link. A camera position or a
/// text query cannot substitute for this identity when importing a stop.
class GooglePlaceIdentity {
  final String value;
  final _IdentityKind _kind;
  const GooglePlaceIdentity._(this.value, this._kind);

  static GooglePlaceIdentity? fromUri(Uri uri, {bool includeEmbedded = true}) {
    final query = uri.queryParameters;
    for (final key in const [
      'query_place_id',
      'destination_place_id',
      'place_id',
    ]) {
      final value = query[key]?.trim();
      if (value != null && value.isNotEmpty) {
        return GooglePlaceIdentity._(value, _IdentityKind.place);
      }
    }
    for (final key in const ['q', 'query']) {
      final value = query[key]?.trim();
      if (value != null && value.startsWith('place_id:')) {
        final id = value.substring('place_id:'.length).trim();
        if (id.isNotEmpty) {
          return GooglePlaceIdentity._(id, _IdentityKind.place);
        }
      }
    }
    final cid = query['cid']?.trim();
    if (cid != null && RegExp(r'^\d+$').hasMatch(cid)) {
      return GooglePlaceIdentity._(cid, _IdentityKind.cid);
    }
    final feature = query['ftid'];
    if (feature != null && _featurePattern.hasMatch(feature)) {
      return GooglePlaceIdentity._(
        feature.toLowerCase(),
        _IdentityKind.feature,
      );
    }
    if (!includeEmbedded) return null;
    // The full place URL and its place-detail preload both encode !1s<ID>.
    final data = Uri.decodeFull(uri.toString());
    final id = RegExp(r'!1s([^!&/?]+)').firstMatch(data)?.group(1);
    if (id != null && _featurePattern.hasMatch(id)) {
      return GooglePlaceIdentity._(id.toLowerCase(), _IdentityKind.feature);
    }
    if (id != null && id.startsWith('ChI')) {
      return GooglePlaceIdentity._(id, _IdentityKind.place);
    }
    return null;
  }

  static final _featurePattern = RegExp(r'^0x[0-9a-fA-F]+:0x[0-9a-fA-F]+$');

  bool matches({required String featureId, required String placeId}) {
    if (!_featurePattern.hasMatch(featureId) || placeId.isEmpty) return false;
    switch (_kind) {
      case _IdentityKind.place:
        return value == placeId;
      case _IdentityKind.feature:
        // CID-only Maps pages use 0x0 as the unknown first half.
        if (value.startsWith('0x0:')) {
          return value.split(':').last ==
              featureId.toLowerCase().split(':').last;
        }
        return value == featureId.toLowerCase();
      case _IdentityKind.cid:
        final hex = featureId.split(':').last.substring(2);
        return BigInt.tryParse(value) == BigInt.tryParse(hex, radix: 16);
    }
  }
}

enum _IdentityKind { place, cid, feature }
