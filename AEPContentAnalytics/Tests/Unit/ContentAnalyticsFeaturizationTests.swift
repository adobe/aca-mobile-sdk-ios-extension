/*
 Copyright 2025 Adobe. All rights reserved.
 This file is licensed to you under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License. You may obtain a copy
 of the License at http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software distributed under
 the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR REPRESENTATIONS
 OF ANY KIND, either express or implied. See the License for the specific language
 governing permissions and limitations under the License.
 */

@testable import AEPContentAnalytics
import AEPCore
import AEPServices
import XCTest

/// Tests for featurization service: data structures, encoding, and error handling.
/// Network integration requires complex mocking, so we focus on testable components.
class ContentAnalyticsFeaturizationTests: XCTestCase {

    // MARK: - ContentData Tests

    func testContentData_Initialization_CreatesValidStructure() {
        // Given
        let images = [["url": "https://example.com/image.jpg"]]
        let texts = [["value": "Welcome", "role": "headline"]]
        let ctas = [["value": "Buy Now", "enabled": true]]

        // When
        let contentData = ContentData(images: images, texts: texts, ctas: ctas)

        // Then
        XCTAssertEqual(contentData.images.count, 1)
        XCTAssertEqual(contentData.texts.count, 1)
        XCTAssertEqual(contentData.ctas?.count, 1)
    }

    func testContentData_WithNilCTAs_HandlesCorrectly() {
        // Given
        let images = [["url": "https://example.com/image.jpg"]]
        let texts = [["value": "Welcome"]]

        // When
        let contentData = ContentData(images: images, texts: texts, ctas: nil)

        // Then
        XCTAssertEqual(contentData.images.count, 1)
        XCTAssertEqual(contentData.texts.count, 1)
        XCTAssertNil(contentData.ctas)
    }

    func testContentData_Encoding_ProducesValidJSON() throws {
        // Given
        let images = [["url": "https://example.com/image.jpg"]]
        let texts = [["value": "Welcome"]]
        let contentData = ContentData(images: images, texts: texts, ctas: nil)

        // When
        let jsonData = try JSONEncoder().encode(contentData)
        let jsonString = String(data: jsonData, encoding: .utf8)

        // Then
        XCTAssertNotNil(jsonString, "Should encode to valid JSON")
        XCTAssertTrue(jsonString?.contains("images") ?? false)
        XCTAssertTrue(jsonString?.contains("texts") ?? false)
    }

    // MARK: - ExperienceContent Tests

    func testExperienceContent_Initialization_CreatesValidStructure() {
        // Given
        let contentData = ContentData(
            images: [["url": "https://example.com/image.jpg"]],
            texts: [["value": "Welcome"]],
            ctas: nil
        )
        let orgId = "TEST_ORG@AdobeOrg"
        let datastreamId = "test-datastream-id"
        let experienceId = "test-experience-id"

        // When
        let experienceContent = ExperienceContent(
            content: contentData,
            orgId: orgId,
            datastreamId: datastreamId,
            experienceId: experienceId
        )

        // Then
        XCTAssertEqual(experienceContent.orgId, orgId)
        XCTAssertEqual(experienceContent.datastreamId, datastreamId)
        XCTAssertEqual(experienceContent.experienceId, experienceId)
        XCTAssertNotNil(experienceContent.content)
    }

    func testExperienceContent_WithAllRequiredFields_IncludesAll() {
        // Given
        let contentData = ContentData(
            images: [["url": "https://example.com/image.jpg"]],
            texts: [["value": "Welcome"]],
            ctas: nil
        )

        // When
        let experienceContent = ExperienceContent(
            content: contentData,
            orgId: "TEST_ORG@AdobeOrg",
            datastreamId: "test-datastream",
            experienceId: "test-experience-id"
        )

        // Then
        XCTAssertEqual(experienceContent.orgId, "TEST_ORG@AdobeOrg")
        XCTAssertEqual(experienceContent.datastreamId, "test-datastream")
        XCTAssertEqual(experienceContent.experienceId, "test-experience-id")
        XCTAssertNotNil(experienceContent.content)
    }

    func testExperienceContent_Encoding_ProducesValidJSON() throws {
        // Given
        let contentData = ContentData(
            images: [["url": "https://example.com/image.jpg"]],
            texts: [["value": "Welcome"]],
            ctas: nil
        )
        let experienceContent = ExperienceContent(
            content: contentData,
            orgId: "TEST_ORG@AdobeOrg",
            datastreamId: "test-datastream",
            experienceId: "test-experience-id"
        )

        // When
        let jsonData = try JSONEncoder().encode(experienceContent)
        let jsonString = String(data: jsonData, encoding: .utf8)

        // Then
        XCTAssertNotNil(jsonString, "Should encode to valid JSON")
        XCTAssertTrue(jsonString?.contains("content") ?? false)
        XCTAssertTrue(jsonString?.contains("orgId") ?? false)
        XCTAssertTrue(jsonString?.contains("datastreamId") ?? false)
        XCTAssertTrue(jsonString?.contains("experienceId") ?? false)
    }

    // MARK: - FeaturizationError Tests

    func testFeaturizationError_InvalidURL_HasCorrectDescription() {
        // Given
        let error = FeaturizationError.invalidURL("https://invalid url")

        // When
        let description = error.description

        // Then
        XCTAssertTrue(description.contains("Invalid featurization service URL"))
        XCTAssertTrue(description.contains("https://invalid url"))
    }

    func testFeaturizationError_HTTPError_HasCorrectDescription() {
        // Given
        let error = FeaturizationError.httpError(404)

        // When
        let description = error.description

        // Then
        XCTAssertTrue(description.contains("HTTP error"))
        XCTAssertTrue(description.contains("404"))
    }

    func testFeaturizationError_NetworkError_HasCorrectDescription() {
        // Given
        let underlyingError = NSError(domain: "Test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Connection failed"])
        let error = FeaturizationError.networkError(underlyingError)

        // When
        let description = error.description

        // Then
        XCTAssertTrue(description.contains("Network error"))
        XCTAssertTrue(description.contains("Connection failed"))
    }

    func testFeaturizationError_InvalidResponse_HasCorrectDescription() {
        // Given
        let error = FeaturizationError.invalidResponse

        // When
        let description = error.description

        // Then
        XCTAssertTrue(description.contains("Invalid response"))
    }
}
