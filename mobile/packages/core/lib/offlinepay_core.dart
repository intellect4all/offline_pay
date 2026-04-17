// Public barrel for the shared core package. Re-exports the cryptographic
// primitives, canonical encoder, QR framing, and token models consumed by
// the Flutter C2C app.

export 'src/canonical.dart' show canonicalize, CanonicalBytes, formatRfc3339Nano;
export 'src/tokens.dart'
    show
        CeilingTokenPayload,
        PaymentPayload,
        PaymentToken,
        GossipBlob,
        DisplayCardPayload,
        DisplayCard,
        PaymentRequestPayload,
        PaymentRequest,
        sessionNonceSize,
        unboundAmount;
export 'src/ed25519.dart'
    show
        Ed25519Keys,
        generateEd25519KeyPair,
        signCeiling,
        verifyCeiling,
        signPayment,
        verifyPayment,
        signDisplayCard,
        verifyDisplayCard,
        signRequest,
        verifyRequest,
        hashRequest;
export 'src/aes_gcm.dart'
    show seal, open, deriveFrameNonce, realmKeySize, aesGcmNonceSize, aesGcmTagSize;
export 'src/sealed_box.dart'
    show
        SealedBoxKeyPair,
        generateSealedBoxKeyPair,
        sealAnonymous,
        openAnonymous,
        sealedBoxOverhead,
        sealedBoxPubKeySize,
        sealedBoxPrivKeySize;
export 'src/gossip/bloom.dart' show BloomFilter;
export 'src/gossip/carry_cache.dart'
    show CarryCache, maxGossipHops, maxCarryCapacity;
export 'src/gossip/payload.dart' show CeilingTokenWire, GossipInnerPayload;
export 'src/gossip/envelope.dart' show EnvelopeCeiling, GossipEnvelope;
export 'src/gossip/encode.dart' show sealGossipBlobs;
export 'src/gossip/wire.dart'
    show
        OpenedEnvelope,
        SealedEnvelope,
        UnknownKeyVersionError,
        chunkEnvelopeFrames,
        envelopeContentType,
        openEnvelopeFromWire,
        reassembleEnvelopeWire,
        sealEnvelopeToWire;
export 'src/realm_keyring.dart' show RealmKeyring;
export 'src/request_wire.dart'
    show
        OpenedRequest,
        SealedRequest,
        UnknownRequestKeyVersionError,
        chunkRequestFrames,
        openRequestFromWire,
        reassembleRequestWire,
        requestContentType,
        sealRequestToWire;
export 'src/transport/transport.dart'
    show PaymentChannel, PaymentSendTransport, PaymentReceiveTransport;
export 'src/transport/qr_transport.dart'
    show QrSendTransport, QrReceiveTransport;
export 'src/transport/nfc_apdu.dart'
    show
        NfcApduException,
        NfcChunkApdu,
        NfcReassembler,
        chunkSealedWireToApdus,
        parseChunkApdu,
        offlinePayAid,
        nfcChunkPayloadSize,
        nfcCla,
        nfcInsGetChunk,
        nfcMaxChunks;
export 'src/transport/nfc_pull_protocol.dart'
    show
        GetChunkResponse,
        buildGetChunkCommand,
        buildGetChunkResponse,
        buildSelectAidCommand,
        buildSelectOkResponse,
        isSelectAidCommand,
        parseGetChunkResponse,
        stageChunkResponses,
        tryParseGetChunkCommand;
export 'src/qr/frames.dart'
    show
        Frame,
        Reassembler,
        QrFrameException,
        chunk,
        encodeFrame,
        decodeFrame,
        protocolVersion,
        kindHeader,
        kindPayload,
        kindTrailer,
        defaultChunkSize;
