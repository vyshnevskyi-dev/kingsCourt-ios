// NyxGalleryClient.swift
// HTTP client for backend communication

import Foundation

actor NyxGalleryClient {

    static let shared = NyxGalleryClient()

    private var session: URLSession
    private var settings: NyxDispatcherSettings = NyxDispatcherSettings()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = NyxDispatcherConfig.requestTimeout
        config.timeoutIntervalForResource = NyxDispatcherConfig.requestTimeout
        self.session = URLSession(configuration: config)
    }

    // MARK: - Configuration

    func configure(with settings: NyxDispatcherSettings) {
        self.settings = settings

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = settings.timeout
        config.timeoutIntervalForResource = settings.timeout
        self.session = URLSession(configuration: config)
    }

    // MARK: - Security headers

    /// Attach ``X-API-Key`` + (if HMAC enabled) ``X-Signature`` /
    /// ``X-Timestamp`` + (if set) ``X-Cohort-Token``. Writes the body
    /// before signing so the signature covers the exact bytes the
    /// server receives.
    ///
    /// The function mutates ``urlRequest`` in place and returns the
    /// body bytes for logging. When none of the security features are
    /// enabled / filled this is effectively a no-op beyond setting the
    /// body — so legacy builds behave exactly as before.
    private func applySecurityHeaders(
        _ urlRequest: inout URLRequest,
        bundleID: String,
        version: String,
        body: Data
    ) {
        // #13 auth-in-body: ship {"b": bundleId, "d": <encrypted auth+payload>}
        // with NO custom X-* headers. Requires encryption + a secret. Built
        // first; on success we strip the cleartext headers the caller pre-set
        // and return. Any failure falls through to the normal header path.
        if NyxDispatcherConfig.authInBodyEnabled, NyxDispatcherConfig.encryptBodyEnabled,
           !NyxDispatcherConfig.masterSecret.isEmpty {
            let ts = NyxPlanner.currentTimestamp()
            let sig = NyxPlanner.sign(
                secret: NyxDispatcherConfig.masterSecret,
                bundleID: bundleID, timestamp: ts, body: body
            ) ?? ""
            var inner: [String: Any] = [
                "p": String(decoding: body, as: UTF8.self),
                "t": ts, "s": sig, "v": version, "sc": NyxDispatcherConfig.schemaVersion,
            ]
            if !NyxDispatcherConfig.apiKey.isEmpty {
                inner["k"] = NyxDispatcherConfig.apiKey
            } else if !settings.apiKey.isEmpty {
                inner["k"] = settings.apiKey
            }
            if let cohort = NyxProfile.shared.flowToken, !cohort.isEmpty {
                inner["c"] = cohort
            }
            if let innerData = try? JSONSerialization.data(withJSONObject: inner),
               let sealed = NyxFeed.seal(innerData, secret: NyxDispatcherConfig.masterSecret),
               let sealedObj = try? JSONSerialization.jsonObject(with: sealed) as? [String: Any],
               let d = sealedObj["d"],
               let wire = try? JSONSerialization.data(
                   withJSONObject: ["b": bundleID, "d": d]) {
                urlRequest.setValue(nil, forHTTPHeaderField: "X-App-Bundle-Id")
                urlRequest.setValue(nil, forHTTPHeaderField: "X-App-Version")
                urlRequest.setValue(nil, forHTTPHeaderField: NyxDispatcherConfig.hdrSchema)
                urlRequest.httpBody = wire
                return
            }
            // else: fall through to the normal header-based path below.
        }

        // X-API-Key — prefer the compile-time constant (set by the
        // AppFactory pipeline when security is enabled). Fall back to
        // any runtime override carried on NyxDispatcherSettings so existing
        // Builder.apiKey() callers still work.
        if !NyxDispatcherConfig.apiKey.isEmpty {
            urlRequest.setValue(NyxDispatcherConfig.apiKey, forHTTPHeaderField: "X-API-Key")
        } else if !settings.apiKey.isEmpty {
            urlRequest.setValue(settings.apiKey, forHTTPHeaderField: "X-API-Key")
        }

        // HMAC signs the *plaintext* body — unchanged semantics whether
        // or not encryption is on. The server decrypts the envelope back
        // to this same plaintext (in BodyCipherMiddleware, before the
        // HMAC dependency runs), so the signature it verifies matches.
        // Only when the pipeline opted in AND a secret is present.
        if NyxDispatcherConfig.hmacEnabled, !NyxDispatcherConfig.masterSecret.isEmpty {
            let ts = NyxPlanner.currentTimestamp()
            if let sig = NyxPlanner.sign(
                secret: NyxDispatcherConfig.masterSecret,
                bundleID: bundleID,
                timestamp: ts,
                body: body
            ) {
                urlRequest.setValue(String(ts), forHTTPHeaderField: NyxDispatcherConfig.hdrTimestamp)
                urlRequest.setValue(sig, forHTTPHeaderField: NyxDispatcherConfig.hdrSignature)
            }
        }

        // Body encryption (opt-in). Sealing happens LAST so the HMAC
        // above covers the plaintext; the bytes on the wire are the
        // opaque ``{"d":"…"}`` envelope. Fall back to plaintext if
        // sealing fails rather than dropping the request.
        if NyxDispatcherConfig.encryptBodyEnabled, !NyxDispatcherConfig.masterSecret.isEmpty,
           let sealed = NyxFeed.seal(body, secret: NyxDispatcherConfig.masterSecret) {
            urlRequest.httpBody = sealed
        } else {
            urlRequest.httpBody = body
        }

        // Cohort token — sticky per-device mode assignment. The first
        // /init has nothing to echo; every subsequent request does.
        if let cohort = NyxProfile.shared.flowToken, !cohort.isEmpty {
            urlRequest.setValue(cohort, forHTTPHeaderField: NyxDispatcherConfig.hdrFlowToken)
        }
    }

    /// Unwrap an encrypted response body. When body encryption is on the
    /// server seals its JSON into the same ``{"d":"…"}`` AES-GCM envelope
    /// the client uses; here we open it back to plaintext before the
    /// JSON decoder runs. If the data isn't an envelope (encryption off,
    /// or an error response that the server didn't seal) ``NyxFeed``
    /// returns nil and we pass the bytes through untouched — so legacy
    /// builds and non-enrolled apps decode exactly as before.
    private func decryptResponseIfNeeded(_ data: Data) -> Data {
        guard NyxDispatcherConfig.encryptBodyEnabled, !NyxDispatcherConfig.masterSecret.isEmpty,
              let plaintext = NyxFeed.open(data, secret: NyxDispatcherConfig.masterSecret) else {
            return data
        }
        return plaintext
    }

    // MARK: - Init Request

    func fetchConfig(_ request: NyxLibraryRequest) async throws -> NyxLibraryResponse {
        // Honour the masked-alias path for cherry_flow builds. For base
        // apps ``initPathSuffix`` is ``/api/v1/client/init`` → URL is
        // byte-for-byte what it was before.
        let base = settings.serverURL.isEmpty ? NyxDispatcherConfig.serverURL : settings.serverURL
        let url = URL(string: base + NyxDispatcherConfig.initPathSuffix)!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Standard API headers
        urlRequest.setValue(NyxDispatcherConfig.schemaVersion, forHTTPHeaderField: NyxDispatcherConfig.hdrSchema)
        urlRequest.setValue(request.app.bundleId, forHTTPHeaderField: "X-App-Bundle-Id")
        urlRequest.setValue(request.app.version, forHTTPHeaderField: "X-App-Version")

        let body = try JSONEncoder().encode(request)
        applySecurityHeaders(
            &urlRequest,
            bundleID: request.app.bundleId,
            version: request.app.version,
            body: body,
        )

        NyxMint.logRequest(url.absoluteString, method: "POST", body: urlRequest.httpBody)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NyxGalleryError.invalidResponse
        }

        NyxMint.logResponse(url.absoluteString, status: httpResponse.statusCode, data: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NyxGalleryError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NyxLibraryResponse.self, from: decryptResponseIfNeeded(data))

        // Persist the cohort token on first receipt. NyxProfile
        // enforces write-once semantics so repeat runs never overwrite
        // an existing sticky assignment.
        if let cohort = decoded.flowToken, !cohort.isEmpty {
            NyxProfile.shared.flowToken = cohort
        }

        return decoded
    }

    // MARK: - Push Token Upload

    /// Upload / refresh the APNs push token via the dedicated
    /// ``/client/push-token`` endpoint.
    ///
    /// Called from ``NyxDispatcherRouter.updatePushToken`` whenever iOS hands
    /// us a new token (first permission grant, reinstall, token
    /// rotation). Uses the same header stack as ``fetchConfig`` —
    /// X-Schema / bundle / version / API key / HMAC when enrolled —
    /// so the server applies identical auth rules without a parallel
    /// code path.
    ///
    /// The server returns ``{ok, push_enabled}`` echoing the derived
    /// deliverability state; we propagate it so the caller can
    /// update any UI state without re-reading
    /// ``UNUserNotificationCenter``.
    func uploadPushToken(_ request: NyxKernelRequest) async throws -> NyxKernelResponse {
        let base = settings.serverURL.isEmpty ? NyxDispatcherConfig.serverURL : settings.serverURL
        guard let url = URL(string: base + NyxDispatcherConfig.pushTokenPathSuffix) else {
            throw NyxGalleryError.noConnection
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        urlRequest.setValue(NyxDispatcherConfig.schemaVersion, forHTTPHeaderField: NyxDispatcherConfig.hdrSchema)
        urlRequest.setValue(request.app.bundleId, forHTTPHeaderField: "X-App-Bundle-Id")
        urlRequest.setValue(request.app.version, forHTTPHeaderField: "X-App-Version")

        let body = try JSONEncoder().encode(request)
        applySecurityHeaders(
            &urlRequest,
            bundleID: request.app.bundleId,
            version: request.app.version,
            body: body,
        )

        NyxMint.logRequest(url.absoluteString, method: "POST", body: urlRequest.httpBody)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NyxGalleryError.invalidResponse
        }
        NyxMint.logResponse(url.absoluteString, status: httpResponse.statusCode, data: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NyxGalleryError.serverError(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(NyxKernelResponse.self, from: decryptResponseIfNeeded(data))
    }

    // MARK: - Event Tracking

    func sendEvent(_ event: NyxAtlasRequest) async throws {
        let base = settings.serverURL.isEmpty ? NyxDispatcherConfig.serverURL : settings.serverURL
        let url = URL(string: base + NyxDispatcherConfig.eventPathSuffix)!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        urlRequest.setValue(NyxDispatcherConfig.schemaVersion, forHTTPHeaderField: NyxDispatcherConfig.hdrSchema)
        urlRequest.setValue(event.app.bundleId, forHTTPHeaderField: "X-App-Bundle-Id")
        urlRequest.setValue(event.app.version, forHTTPHeaderField: "X-App-Version")

        let body = try JSONEncoder().encode(event)
        applySecurityHeaders(
            &urlRequest,
            bundleID: event.app.bundleId,
            version: event.app.version,
            body: body,
        )

        NyxMint.logRequest(url.absoluteString, method: "POST", body: urlRequest.httpBody)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NyxGalleryError.invalidResponse
        }

        NyxMint.logResponse(url.absoluteString, status: httpResponse.statusCode, data: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NyxGalleryError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    @MainActor
    func trackEvent(name: String, uniqueId: String, properties: [String: Any]? = nil) async {
        let event = NyxAtlasRequest.create(
            name: name,
            uniqueId: uniqueId,
            properties: properties
        )
        try? await sendEvent(event)
    }
}

// MARK: - Errors

enum NyxGalleryError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int)
    case decodingError
    case noConnection

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Invalid server response"
        case .serverError(let code): return "Server error: \(code)"
        case .decodingError: return "Failed to decode response"
        case .noConnection: return "No internet connection"
        }
    }
}
