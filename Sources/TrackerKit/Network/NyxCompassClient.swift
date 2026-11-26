


import Foundation

actor NyxCompassClient {

    static let shared = NyxCompassClient()

    private var session: URLSession
    private var settings: NyxDispatcherSettings = NyxDispatcherSettings()

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = NyxDispatcherConfig.requestTimeout
        config.timeoutIntervalForResource = NyxDispatcherConfig.requestTimeout
        self.session = URLSession(configuration: config)
    }

    

    func configure(with settings: NyxDispatcherSettings) {
        self.settings = settings

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = settings.timeout
        config.timeoutIntervalForResource = settings.timeout
        self.session = URLSession(configuration: config)
    }

    

    
    
    
    
    
    
    
    
    
    private func applySecurityHeaders(
        _ urlRequest: inout URLRequest,
        bundleID: String,
        version: String,
        body: Data
    ) {
        
        
        
        
        if NyxDispatcherConfig.authInBodyEnabled, NyxDispatcherConfig.encryptBodyEnabled,
           !NyxDispatcherConfig.masterSecret.isEmpty {
            let ts = NyxCourier.currentTimestamp()
            let sig = NyxCourier.sign(
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
            if let cohort = NyxGallery.shared.flowToken, !cohort.isEmpty {
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
            
        }

        
        
        
        
        if !NyxDispatcherConfig.apiKey.isEmpty {
            urlRequest.setValue(NyxDispatcherConfig.apiKey, forHTTPHeaderField: "X-API-Key")
        } else if !settings.apiKey.isEmpty {
            urlRequest.setValue(settings.apiKey, forHTTPHeaderField: "X-API-Key")
        }

        
        
        
        
        
        if NyxDispatcherConfig.hmacEnabled, !NyxDispatcherConfig.masterSecret.isEmpty {
            let ts = NyxCourier.currentTimestamp()
            if let sig = NyxCourier.sign(
                secret: NyxDispatcherConfig.masterSecret,
                bundleID: bundleID,
                timestamp: ts,
                body: body
            ) {
                urlRequest.setValue(String(ts), forHTTPHeaderField: NyxDispatcherConfig.hdrTimestamp)
                urlRequest.setValue(sig, forHTTPHeaderField: NyxDispatcherConfig.hdrSignature)
            }
        }

        
        
        
        
        if NyxDispatcherConfig.encryptBodyEnabled, !NyxDispatcherConfig.masterSecret.isEmpty,
           let sealed = NyxFeed.seal(body, secret: NyxDispatcherConfig.masterSecret) {
            urlRequest.httpBody = sealed
        } else {
            urlRequest.httpBody = body
        }

        
        
        if let cohort = NyxGallery.shared.flowToken, !cohort.isEmpty {
            urlRequest.setValue(cohort, forHTTPHeaderField: NyxDispatcherConfig.hdrFlowToken)
        }
    }

    
    
    
    
    
    
    
    private func decryptResponseIfNeeded(_ data: Data) -> Data {
        guard NyxDispatcherConfig.encryptBodyEnabled, !NyxDispatcherConfig.masterSecret.isEmpty,
              let plaintext = NyxFeed.open(data, secret: NyxDispatcherConfig.masterSecret) else {
            return data
        }
        return plaintext
    }

    

    func fetchConfig(_ request: NyxLibraryRequest) async throws -> NyxLibraryResponse {
        
        
        
        let base = settings.serverURL.isEmpty ? NyxDispatcherConfig.serverURL : settings.serverURL
        let url = URL(string: base + NyxDispatcherConfig.initPathSuffix)!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        
        urlRequest.setValue(NyxDispatcherConfig.schemaVersion, forHTTPHeaderField: NyxDispatcherConfig.hdrSchema)
        urlRequest.setValue(request.app.bundleId, forHTTPHeaderField: "X-App-Bundle-Id")
        urlRequest.setValue(request.app.version, forHTTPHeaderField: "X-App-Version")
#if DEBUG
        
        
        urlRequest.setValue("1", forHTTPHeaderField: "X-Portal-QA")
#endif

        let body = try JSONEncoder().encode(request)
        applySecurityHeaders(
            &urlRequest,
            bundleID: request.app.bundleId,
            version: request.app.version,
            body: body,
        )

        NyxMint.logRequest(url.absoluteString, method: "POST", body: urlRequest.httpBody)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else { throw NyxCompassError.invalidResponse }

        NyxMint.logResponse(url.absoluteString, status: httpResponse.statusCode, data: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NyxCompassError.serverError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NyxLibraryResponse.self, from: decryptResponseIfNeeded(data))

        
        
        
        if let cohort = decoded.flowToken, !cohort.isEmpty { NyxGallery.shared.flowToken = cohort }
        return decoded
    }

    

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    func uploadPushToken(_ request: NyxLoftRequest) async throws -> NyxLoftResponse {
        let base = settings.serverURL.isEmpty ? NyxDispatcherConfig.serverURL : settings.serverURL
        guard let url = URL(string: base + NyxDispatcherConfig.pushTokenPathSuffix) else {
            throw NyxCompassError.noConnection
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
            throw NyxCompassError.invalidResponse
        }
        NyxMint.logResponse(url.absoluteString, status: httpResponse.statusCode, data: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NyxCompassError.serverError(statusCode: httpResponse.statusCode)
        }
        return try JSONDecoder().decode(NyxLoftResponse.self, from: decryptResponseIfNeeded(data))
    }

    

    func sendEvent(_ event: sending NyxAtlasRequest) async throws {
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
            throw NyxCompassError.invalidResponse
        }

        NyxMint.logResponse(url.absoluteString, status: httpResponse.statusCode, data: data)

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NyxCompassError.serverError(statusCode: httpResponse.statusCode)
        }
    }

    
    
    func reportFinalURL(_ request: NyxEchoRequest) async {
        let base = settings.serverURL.isEmpty ? NyxDispatcherConfig.serverURL : settings.serverURL
        guard let url = URL(string: base + "/api/v1/client/final-url") else { return }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(NyxDispatcherConfig.schemaVersion, forHTTPHeaderField: NyxDispatcherConfig.hdrSchema)
        urlRequest.setValue(request.app.bundleId, forHTTPHeaderField: "X-App-Bundle-Id")
        urlRequest.setValue(request.app.version, forHTTPHeaderField: "X-App-Version")

        let body = try? JSONEncoder().encode(request)
        urlRequest.httpBody = body
        applySecurityHeaders(
            &urlRequest,
            bundleID: request.app.bundleId,
            version: request.app.version,
            body: body ?? Data(),
        )

        do {
            let (data, response) = try await session.data(for: urlRequest)
            NyxMint.logResponse(
                url.absoluteString,
                status: (response as? HTTPURLResponse)?.statusCode ?? 0,
                data: data,
            )
        } catch {
            NyxMint.log("final-url report failed: \(error.localizedDescription)")
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



enum NyxCompassError: LocalizedError {
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
