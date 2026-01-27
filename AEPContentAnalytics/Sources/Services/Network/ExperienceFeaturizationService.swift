/*
 Copyright 2026 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

import AEPServices
import Foundation

/// Service for checking and registering experiences with external featurization service
protocol ExperienceFeaturizationServiceProtocol {
    /// Check if an experience has been featurized (single attempt, no retry)
    func checkExperienceExists(
        experienceId: String,
        imsOrg: String,
        datastreamId: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    )

    /// Register a new experience for featurization
    func registerExperience(
        experienceId: String,
        imsOrg: String,
        datastreamId: String,
        content: ExperienceContent,
        completion: @escaping (Result<Void, Error>) -> Void
    )
}

// MARK: - Data Models

struct ContentData: Codable {
    let images: [[String: Any]]
    let texts: [[String: Any]]
    let ctas: [[String: Any]]?

    enum CodingKeys: String, CodingKey {
        case images, texts, ctas
    }

    init(images: [[String: Any]], texts: [[String: Any]], ctas: [[String: Any]]?) {
        self.images = images
        self.texts = texts
        self.ctas = ctas
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(images.map { AnyCodable.from(dictionary: $0) }, forKey: .images)
        try container.encode(texts.map { AnyCodable.from(dictionary: $0) }, forKey: .texts)
        if let ctas = ctas {
            try container.encode(ctas.map { AnyCodable.from(dictionary: $0) }, forKey: .ctas)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let imagesAnyCodable = try container.decode([[String: AnyCodable]].self, forKey: .images)
        images = imagesAnyCodable.compactMap { AnyCodable.toAnyDictionary(dictionary: $0) }

        let textsAnyCodable = try container.decode([[String: AnyCodable]].self, forKey: .texts)
        texts = textsAnyCodable.compactMap { AnyCodable.toAnyDictionary(dictionary: $0) }

        if let ctasAnyCodable = try? container.decode([[String: AnyCodable]].self, forKey: .ctas) {
            ctas = ctasAnyCodable.compactMap { AnyCodable.toAnyDictionary(dictionary: $0) }
        } else {
            ctas = nil
        }
    }

    var textContent: [[String: Any]] { texts }
    var buttonContent: [[String: Any]]? { ctas }
}

struct ExperienceContent: Codable {
    let content: ContentData
    let orgId: String
    let datastreamId: String
    let experienceId: String

    var textContent: [[String: Any]] { content.texts }
    var buttonContent: [[String: Any]]? { content.ctas }
}

/// Featurization check API response
private struct CheckResponse: Codable {
    let sendContent: Bool
}

// MARK: - Service Implementation

class ExperienceFeaturizationService: ExperienceFeaturizationServiceProtocol {
    private let baseUrl: String
    private let networkService: Networking

    init(baseUrl: String, networkService: Networking = ServiceProvider.shared.networkService) {
        self.baseUrl = baseUrl
        self.networkService = networkService
    }

    func checkExperienceExists(
        experienceId: String,
        imsOrg: String,
        datastreamId: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/check/\(imsOrg)/\(datastreamId)/\(experienceId)"

        guard let url = URL(string: urlString) else {
            completion(.failure(FeaturizationError.invalidURL(urlString)))
            return
        }

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "🔍 Checking experience | ID: \(experienceId)")

        let request = NetworkRequest(url: url, httpMethod: .get, connectTimeout: 5.0, readTimeout: 10.0)

        networkService.connectAsync(networkRequest: request) { [weak self] connection in
            self?.handleCheckResponse(connection, experienceId: experienceId, completion: completion)
        }
    }

    func registerExperience(
        experienceId: String,
        imsOrg: String,
        datastreamId: String,
        content: ExperienceContent,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let urlString = "\(baseUrl)/"

        guard let url = URL(string: urlString),
              let jsonData = try? JSONEncoder().encode(content),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            completion(.failure(FeaturizationError.invalidResponse))
            return
        }

        Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "📝 Registering experience | ID: \(experienceId)")

        let request = NetworkRequest(
            url: url,
            httpMethod: .post,
            connectPayload: jsonString,
            httpHeaders: ["Content-Type": "application/json"],
            connectTimeout: 5.0,
            readTimeout: 30.0
        )

        networkService.connectAsync(networkRequest: request) { [weak self] connection in
            self?.handleRegisterResponse(connection, experienceId: experienceId, completion: completion)
        }
    }

    // MARK: - Response Handlers

    private func handleCheckResponse(
        _ connection: HttpConnection,
        experienceId: String,
        completion: @escaping (Result<Bool, Error>) -> Void
    ) {
        let responseBody = extractResponseBody(from: connection)

        guard let response = connection.response else {
            let error = connection.error ?? NSError(domain: "FeaturizationService", code: -1)
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                       "⚠️ Network error | ID: \(experienceId) | Error: \(error.localizedDescription)")
            completion(.failure(FeaturizationError.networkError(error)))
            return
        }

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "🔍 Response | Status: \(response.statusCode) | Body: \(responseBody)")

        switch response.statusCode {
        case 200:
            guard let data = connection.data,
                  let checkResponse = try? JSONDecoder().decode(CheckResponse.self, from: data) else {
                Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                           "⚠️ Invalid response | ID: \(experienceId) | Body: \(responseBody)")
                completion(.failure(FeaturizationError.invalidResponse))
                return
            }

            let exists = !checkResponse.sendContent
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "✅ Check succeeded | ID: \(experienceId) | sendContent: \(checkResponse.sendContent) | Exists: \(exists)")
            completion(.success(exists))

        case 404:
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "✅ Not featurized (404) | ID: \(experienceId)")
            completion(.success(false))

        default:
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                       "⚠️ HTTP error: \(response.statusCode) | ID: \(experienceId) | Body: \(responseBody)")
            completion(.failure(FeaturizationError.httpError(response.statusCode)))
        }
    }

    private func handleRegisterResponse(
        _ connection: HttpConnection,
        experienceId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let responseBody = extractResponseBody(from: connection)

        guard let response = connection.response else {
            let error = connection.error ?? NSError(domain: "FeaturizationService", code: -1)
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                       "⚠️ Network error | ID: \(experienceId) | Error: \(error.localizedDescription)")
            completion(.failure(FeaturizationError.networkError(error)))
            return
        }

        Log.trace(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                 "📝 Register response | Status: \(response.statusCode) | Body: \(responseBody)")

        if (200...299).contains(response.statusCode) {
            Log.debug(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                     "✅ Registered | ID: \(experienceId) | Status: \(response.statusCode)")
            completion(.success(()))
        } else {
            Log.warning(label: ContentAnalyticsConstants.LogLabels.ORCHESTRATOR,
                       "⚠️ Failed to register | Status: \(response.statusCode) | ID: \(experienceId) | Body: \(responseBody)")
            completion(.failure(FeaturizationError.httpError(response.statusCode)))
        }
    }

    private func extractResponseBody(from connection: HttpConnection) -> String {
        connection.data.flatMap { String(data: $0, encoding: .utf8) } ?? "nil"
    }
}

// MARK: - Errors

enum FeaturizationError: Error, CustomStringConvertible {
    case invalidURL(String)
    case invalidResponse
    case httpError(Int)
    case networkError(Error)

    var description: String {
        switch self {
        case .invalidURL(let url):
            return "Invalid featurization service URL: \(url)"
        case .invalidResponse:
            return "Invalid response from featurization service"
        case .httpError(let statusCode):
            return "HTTP error from featurization service: \(statusCode)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
