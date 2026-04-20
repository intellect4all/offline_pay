// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'submit_claim_body.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

class _$SubmitClaimBody extends SubmitClaimBody {
  @override
  final String clientBatchId;
  @override
  final BuiltList<PaymentTokenInput> tokens;
  @override
  final BuiltList<CeilingTokenInput> ceilings;
  @override
  final BuiltList<PaymentRequestInput> requests;

  factory _$SubmitClaimBody([void Function(SubmitClaimBodyBuilder)? updates]) =>
      (SubmitClaimBodyBuilder()..update(updates))._build();

  _$SubmitClaimBody._(
      {required this.clientBatchId,
      required this.tokens,
      required this.ceilings,
      required this.requests})
      : super._();
  @override
  SubmitClaimBody rebuild(void Function(SubmitClaimBodyBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  SubmitClaimBodyBuilder toBuilder() => SubmitClaimBodyBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is SubmitClaimBody &&
        clientBatchId == other.clientBatchId &&
        tokens == other.tokens &&
        ceilings == other.ceilings &&
        requests == other.requests;
  }

  @override
  int get hashCode {
    var _$hash = 0;
    _$hash = $jc(_$hash, clientBatchId.hashCode);
    _$hash = $jc(_$hash, tokens.hashCode);
    _$hash = $jc(_$hash, ceilings.hashCode);
    _$hash = $jc(_$hash, requests.hashCode);
    _$hash = $jf(_$hash);
    return _$hash;
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper(r'SubmitClaimBody')
          ..add('clientBatchId', clientBatchId)
          ..add('tokens', tokens)
          ..add('ceilings', ceilings)
          ..add('requests', requests))
        .toString();
  }
}

class SubmitClaimBodyBuilder
    implements Builder<SubmitClaimBody, SubmitClaimBodyBuilder> {
  _$SubmitClaimBody? _$v;

  String? _clientBatchId;
  String? get clientBatchId => _$this._clientBatchId;
  set clientBatchId(String? clientBatchId) =>
      _$this._clientBatchId = clientBatchId;

  ListBuilder<PaymentTokenInput>? _tokens;
  ListBuilder<PaymentTokenInput> get tokens =>
      _$this._tokens ??= ListBuilder<PaymentTokenInput>();
  set tokens(ListBuilder<PaymentTokenInput>? tokens) => _$this._tokens = tokens;

  ListBuilder<CeilingTokenInput>? _ceilings;
  ListBuilder<CeilingTokenInput> get ceilings =>
      _$this._ceilings ??= ListBuilder<CeilingTokenInput>();
  set ceilings(ListBuilder<CeilingTokenInput>? ceilings) =>
      _$this._ceilings = ceilings;

  ListBuilder<PaymentRequestInput>? _requests;
  ListBuilder<PaymentRequestInput> get requests =>
      _$this._requests ??= ListBuilder<PaymentRequestInput>();
  set requests(ListBuilder<PaymentRequestInput>? requests) =>
      _$this._requests = requests;

  SubmitClaimBodyBuilder() {
    SubmitClaimBody._defaults(this);
  }

  SubmitClaimBodyBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _clientBatchId = $v.clientBatchId;
      _tokens = $v.tokens.toBuilder();
      _ceilings = $v.ceilings.toBuilder();
      _requests = $v.requests.toBuilder();
      _$v = null;
    }
    return this;
  }

  @override
  void replace(SubmitClaimBody other) {
    _$v = other as _$SubmitClaimBody;
  }

  @override
  void update(void Function(SubmitClaimBodyBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  SubmitClaimBody build() => _build();

  _$SubmitClaimBody _build() {
    _$SubmitClaimBody _$result;
    try {
      _$result = _$v ??
          _$SubmitClaimBody._(
            clientBatchId: BuiltValueNullFieldError.checkNotNull(
                clientBatchId, r'SubmitClaimBody', 'clientBatchId'),
            tokens: tokens.build(),
            ceilings: ceilings.build(),
            requests: requests.build(),
          );
    } catch (_) {
      late String _$failedField;
      try {
        _$failedField = 'tokens';
        tokens.build();
        _$failedField = 'ceilings';
        ceilings.build();
        _$failedField = 'requests';
        requests.build();
      } catch (e) {
        throw BuiltValueNestedFieldError(
            r'SubmitClaimBody', _$failedField, e.toString());
      }
      rethrow;
    }
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: deprecated_member_use_from_same_package,type=lint
