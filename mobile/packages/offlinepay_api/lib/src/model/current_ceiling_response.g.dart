// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'current_ceiling_response.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$CurrentCeilingResponse extends CurrentCeilingResponse {
  @override
  final bool present;
  @override
  final String? ceilingId;
  @override
  final String? status;
  @override
  final int? ceilingKobo;
  @override
  final int? settledKobo;
  @override
  final int? remainingKobo;
  @override
  final DateTime? issuedAt;
  @override
  final DateTime? expiresAt;
  @override
  final DateTime? releaseAfter;

  factory _$CurrentCeilingResponse(
          [void Function(CurrentCeilingResponseBuilder)? updates]) =>
      (CurrentCeilingResponseBuilder()..update(updates))._build();

  _$CurrentCeilingResponse._(
      {required this.present,
      this.ceilingId,
      this.status,
      this.ceilingKobo,
      this.settledKobo,
      this.remainingKobo,
      this.issuedAt,
      this.expiresAt,
      this.releaseAfter})
      : super._();
  @override
  CurrentCeilingResponse rebuild(
          void Function(CurrentCeilingResponseBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  CurrentCeilingResponseBuilder toBuilder() =>
      CurrentCeilingResponseBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is CurrentCeilingResponse &&
        present == other.present &&
        ceilingId == other.ceilingId &&
        status == other.status &&
        ceilingKobo == other.ceilingKobo &&
        settledKobo == other.settledKobo &&
        remainingKobo == other.remainingKobo &&
        issuedAt == other.issuedAt &&
        expiresAt == other.expiresAt &&
        releaseAfter == other.releaseAfter;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, present.hashCode);
    _$hash = $jc(_$hash, ceilingId.hashCode);
    _$hash = $jc(_$hash, status.hashCode);
    _$hash = $jc(_$hash, ceilingKobo.hashCode);
    _$hash = $jc(_$hash, settledKobo.hashCode);
    _$hash = $jc(_$hash, remainingKobo.hashCode);
    _$hash = $jc(_$hash, issuedAt.hashCode);
    _$hash = $jc(_$hash, expiresAt.hashCode);
    _$hash = $jc(_$hash, releaseAfter.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'CurrentCeilingResponse')
          ..add('present', present)
          ..add('ceilingId', ceilingId)
          ..add('status', status)
          ..add('ceilingKobo', ceilingKobo)
          ..add('settledKobo', settledKobo)
          ..add('remainingKobo', remainingKobo)
          ..add('issuedAt', issuedAt)
          ..add('expiresAt', expiresAt)
          ..add('releaseAfter', releaseAfter))
        .toString();
  }
}

class CurrentCeilingResponseBuilder
    implements Builder<CurrentCeilingResponse, CurrentCeilingResponseBuilder> {
  _$CurrentCeilingResponse? _$v;

  bool? _present;
  bool? get present => _$this._present;
  set present(bool? present) => _$this._present = present;

  String? _ceilingId;
  String? get ceilingId => _$this._ceilingId;
  set ceilingId(String? ceilingId) => _$this._ceilingId = ceilingId;

  String? _status;
  String? get status => _$this._status;
  set status(String? status) => _$this._status = status;

  int? _ceilingKobo;
  int? get ceilingKobo => _$this._ceilingKobo;
  set ceilingKobo(int? ceilingKobo) => _$this._ceilingKobo = ceilingKobo;

  int? _settledKobo;
  int? get settledKobo => _$this._settledKobo;
  set settledKobo(int? settledKobo) => _$this._settledKobo = settledKobo;

  int? _remainingKobo;
  int? get remainingKobo => _$this._remainingKobo;
  set remainingKobo(int? remainingKobo) =>
      _$this._remainingKobo = remainingKobo;

  DateTime? _issuedAt;
  DateTime? get issuedAt => _$this._issuedAt;
  set issuedAt(DateTime? issuedAt) => _$this._issuedAt = issuedAt;

  DateTime? _expiresAt;
  DateTime? get expiresAt => _$this._expiresAt;
  set expiresAt(DateTime? expiresAt) => _$this._expiresAt = expiresAt;

  DateTime? _releaseAfter;
  DateTime? get releaseAfter => _$this._releaseAfter;
  set releaseAfter(DateTime? releaseAfter) =>
      _$this._releaseAfter = releaseAfter;

  CurrentCeilingResponseBuilder() {
    CurrentCeilingResponse._defaults(this);
  }

  CurrentCeilingResponseBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _present = $v.present;
      _ceilingId = $v.ceilingId;
      _status = $v.status;
      _ceilingKobo = $v.ceilingKobo;
      _settledKobo = $v.settledKobo;
      _remainingKobo = $v.remainingKobo;
      _issuedAt = $v.issuedAt;
      _expiresAt = $v.expiresAt;
      _releaseAfter = $v.releaseAfter;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(CurrentCeilingResponse other) {
    _$v = other as _$CurrentCeilingResponse;
  }

  @override
  void update(void Function(CurrentCeilingResponseBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  CurrentCeilingResponse build() => _build();

  _$CurrentCeilingResponse _build() {
    final _$result = _$v ??
        _$CurrentCeilingResponse._(
          present: BuiltValueNullFieldError.checkNotNull(
              present, r'CurrentCeilingResponse', 'present'),
          ceilingId: ceilingId,
          status: status,
          ceilingKobo: ceilingKobo,
          settledKobo: settledKobo,
          remainingKobo: remainingKobo,
          issuedAt: issuedAt,
          expiresAt: expiresAt,
          releaseAfter: releaseAfter,
        );
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
