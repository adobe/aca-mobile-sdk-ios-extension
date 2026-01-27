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
import XCTest

/// Tests for ConfigurationValidationRules
/// Validates all configuration validation logic including:
/// - Batch size validation
/// - Org ID format validation
/// - Regex pattern validation
/// - Full configuration validation
class ContentAnalyticsConfigurationValidationTests: XCTestCase {

    var validator: ConfigurationValidationRules!

    override func setUp() {
        super.setUp()
        validator = ConfigurationValidationRules()
    }

    override func tearDown() {
        validator = nil
        super.tearDown()
    }

    // MARK: - Batch Size Validation Tests

    func testBatchSizeValidation_Valid_NoErrors() {
        // Given - Valid batch sizes
        let validSizes = [1, 5, 10, 50, 100]

        for size in validSizes {
            // When
            var config = ContentAnalyticsConfiguration()
            config.maxBatchSize = size

            let errors = validator.validate(config)

            // Then
            XCTAssertTrue(errors.isEmpty, "Batch size \(size) should be valid")
        }
    }

    func testBatchSizeValidation_TooSmall_ReturnsError() {
        // Given - Batch size < 1
        var config = ContentAnalyticsConfiguration()
        config.maxBatchSize = 0

        // When
        let errors = validator.validate(config)

        // Then
        XCTAssertEqual(errors.count, 1, "Should have 1 error")

        if case .invalidBatchSize(let size) = errors.first {
            XCTAssertEqual(size, 0, "Error should contain invalid size")
        } else {
            XCTFail("Expected invalidBatchSize error")
        }
    }

    func testBatchSizeValidation_TooLarge_ReturnsError() {
        // Given - Batch size > 100
        var config = ContentAnalyticsConfiguration()
        config.maxBatchSize = 101

        // When
        let errors = validator.validate(config)

        // Then
        XCTAssertEqual(errors.count, 1, "Should have 1 error")

        if case .invalidBatchSize(let size) = errors.first {
            XCTAssertEqual(size, 101, "Error should contain invalid size")
        } else {
            XCTFail("Expected invalidBatchSize error")
        }
    }

    func testBatchSizeValidation_BoundaryValues_Handled() {
        // Given - Boundary values (1 and 100)
        let boundaryCases = [
            (size: 1, shouldBeValid: true),
            (size: 100, shouldBeValid: true),
            (size: 0, shouldBeValid: false),
            (size: 101, shouldBeValid: false),
            (size: -1, shouldBeValid: false),
            (size: 1000, shouldBeValid: false)
        ]

        for testCase in boundaryCases {
            // When
            var config = ContentAnalyticsConfiguration()
            config.maxBatchSize = testCase.size

            let errors = validator.validate(config)

            // Then
            if testCase.shouldBeValid {
                XCTAssertTrue(errors.filter {
                    if case .invalidBatchSize = $0 { return true }
                    return false
                }.isEmpty, "Batch size \(testCase.size) should be valid")
            } else {
                XCTAssertTrue(errors.contains {
                    if case .invalidBatchSize = $0 { return true }
                    return false
                }, "Batch size \(testCase.size) should be invalid")
            }
        }
    }

    // MARK: - Org ID Validation Tests

    func testOrgIdValidation_ValidFormat_NoErrors() {
        // Given - Valid Org ID format
        var config = ContentAnalyticsConfiguration()
        config.experienceCloudOrgId = "0123456789ABCDEF01234567@AdobeOrg"

        // When
        let errors = validator.validate(config)

        // Then
        let orgIdErrors = errors.filter {
            if case .invalidOrgId = $0 { return true }
            return false
        }
        XCTAssertTrue(orgIdErrors.isEmpty, "Valid Org ID should not produce errors")
    }

    func testOrgIdValidation_InvalidFormat_ReturnsError() {
        // Given - Invalid Org ID formats
        let invalidOrgIds = [
            "InvalidOrgId",                    // Wrong format
            "12345@AdobeOrg",                  // Too short
            "0123456789ABCDEF01234567",        // Missing @AdobeOrg
            "0123456789abcdef01234567@AdobeOrg", // Lowercase not allowed
            "@AdobeOrg",                       // Empty ID
            "0123456789ABCDEF01234567@AdobeOrg123" // Extra chars after @AdobeOrg
        ]

        for invalidOrgId in invalidOrgIds {
            // When
            var config = ContentAnalyticsConfiguration()
            config.experienceCloudOrgId = invalidOrgId

            let errors = validator.validate(config)

            // Then
            let hasOrgIdError = errors.contains {
                if case .invalidOrgId = $0 { return true }
                return false
            }
            XCTAssertTrue(hasOrgIdError, "Invalid Org ID '\(invalidOrgId)' should produce error")
        }
    }

    func testOrgIdValidation_MissingAtAdobeOrg_ReturnsError() {
        // Given - Org ID without @AdobeOrg suffix
        var config = ContentAnalyticsConfiguration()
        config.experienceCloudOrgId = "0123456789ABCDEF01234567"

        // When
        let errors = validator.validate(config)

        // Then
        XCTAssertTrue(errors.contains {
            if case .invalidOrgId = $0 { return true }
            return false
        }, "Org ID without @AdobeOrg should be invalid")
    }

    func testOrgIdValidation_WrongLength_ReturnsError() {
        // Given - Org ID with wrong length (should be 24 chars before @AdobeOrg)
        let wrongLengthOrgIds = [
            "SHORT@AdobeOrg",                     // Too short
            "0123456789ABCDEF012345678@AdobeOrg", // Too long (25 chars)
            "01234567@AdobeOrg"                   // Way too short
        ]

        for orgId in wrongLengthOrgIds {
            // When
            var config = ContentAnalyticsConfiguration()
            config.experienceCloudOrgId = orgId

            let errors = validator.validate(config)

            // Then
            XCTAssertTrue(errors.contains {
                if case .invalidOrgId = $0 { return true }
                return false
            }, "Org ID '\(orgId)' with wrong length should be invalid")
        }
    }

    func testOrgIdValidation_Nil_NoError() {
        // Given - Nil Org ID (optional field)
        var config = ContentAnalyticsConfiguration()
        config.experienceCloudOrgId = nil

        // When
        let errors = validator.validate(config)

        // Then
        let orgIdErrors = errors.filter {
            if case .invalidOrgId = $0 { return true }
            return false
        }
        XCTAssertTrue(orgIdErrors.isEmpty, "Nil Org ID should not produce error (optional field)")
    }

    // MARK: - Regex Pattern Validation Tests

    func testRegexPatternValidation_ValidPattern_NoErrors() {
        // Given - Valid regex patterns
        let validPatterns = [
            "^https://example\\.com/.*",
            ".*\\.jpg$",
            "[a-z]+",
            "test",
            "(home|product)\\.hero"
        ]

        for pattern in validPatterns {
            // When
            var config = ContentAnalyticsConfiguration()
            config.excludedAssetUrlsRegexp = pattern

            let errors = validator.validate(config)

            // Then
            let patternErrors = errors.filter {
                if case .invalidUrlPattern = $0 { return true }
                return false
            }
            XCTAssertTrue(patternErrors.isEmpty, "Valid pattern '\(pattern)' should not produce errors")
        }
    }

    func testRegexPatternValidation_InvalidPattern_ReturnsError() {
        // Given - Invalid regex patterns
        let invalidPatterns = [
            "[invalid(regex",     // Unclosed bracket
            "(?P<invalid",        // Unclosed group
            "*invalid",           // Invalid quantifier
            "(?!",                // Incomplete lookahead
            "[z-a]"               // Invalid range
        ]

        for pattern in invalidPatterns {
            // When
            var config = ContentAnalyticsConfiguration()
            config.excludedAssetUrlsRegexp = pattern

            let errors = validator.validate(config)

            // Then
            let hasPatternError = errors.contains {
                if case .invalidUrlPattern = $0 { return true }
                return false
            }
            XCTAssertTrue(hasPatternError, "Invalid pattern '\(pattern)' should produce error")
        }
    }

    func testRegexPatternValidation_EmptyPattern_Valid() {
        // Given - Empty string pattern
        var config = ContentAnalyticsConfiguration()
        config.excludedAssetUrlsRegexp = ""

        // When
        let errors = validator.validate(config)

        // Then - Empty patterns are technically valid regex but meaningless
        // NSRegularExpression accepts empty strings without throwing
        let patternErrors = errors.filter {
            if case .invalidUrlPattern = $0 { return true }
            return false
        }
        XCTAssertTrue(patternErrors.isEmpty, "Empty pattern compiles as valid regex (even if meaningless)")
    }

    func testRegexPatternValidation_MultiplePatterns_ValidatesAll() {
        // Given - Invalid pattern
        var config = ContentAnalyticsConfiguration()
        config.excludedAssetUrlsRegexp = "[invalid("  // Invalid regex

        // When
        let errors = validator.validate(config)

        // Then
        let patternErrors = errors.filter {
            if case .invalidUrlPattern = $0 { return true }
            return false
        }
        XCTAssertEqual(patternErrors.count, 1, "Should report 1 invalid pattern")
    }

    // MARK: - Full Configuration Validation Tests

    func testValidateConfiguration_AllValid_NoErrors() {
        // Given - Fully valid configuration
        var config = ContentAnalyticsConfiguration()
        config.maxBatchSize = 50
        config.experienceCloudOrgId = "0123456789ABCDEF01234567@AdobeOrg"
        config.excludedAssetUrlsRegexp = "^https://example\\.com/.*"
        config.excludedExperienceLocationsRegexp = "^test\\..*"

        // When
        let errors = validator.validate(config)

        // Then
        XCTAssertTrue(errors.isEmpty, "Fully valid configuration should have no errors")
    }

    func testValidateConfiguration_MultipleErrors_ReturnsAll() {
        // Given - Configuration with multiple errors
        var config = ContentAnalyticsConfiguration()
        config.maxBatchSize = 0                          // Invalid: too small
        config.experienceCloudOrgId = "InvalidOrgId"     // Invalid: wrong format
        config.excludedAssetUrlsRegexp = "[invalid("       // Invalid: bad regex

        // When
        let errors = validator.validate(config)

        // Then
        XCTAssertEqual(errors.count, 3, "Should report all 3 errors")

        // Verify each error type is present
        let hasBatchSizeError = errors.contains {
            if case .invalidBatchSize = $0 { return true }
            return false
        }
        let hasOrgIdError = errors.contains {
            if case .invalidOrgId = $0 { return true }
            return false
        }
        let hasPatternError = errors.contains {
            if case .invalidUrlPattern = $0 { return true }
            return false
        }

        XCTAssertTrue(hasBatchSizeError, "Should report batch size error")
        XCTAssertTrue(hasOrgIdError, "Should report org ID error")
        XCTAssertTrue(hasPatternError, "Should report pattern error")
    }

    func testValidateConfiguration_DefaultConfig_Valid() {
        // Given - Default configuration
        let config = ContentAnalyticsConfiguration()

        // When
        let errors = validator.validate(config)

        // Then
        XCTAssertTrue(errors.isEmpty, "Default configuration should be valid")
    }

    // MARK: - Error Description Tests

    func testConfigurationValidationError_Descriptions_AreInformative() {
        // Given - Various errors
        let errors: [ConfigurationValidationError] = [
            .invalidBatchSize(0),
            .invalidOrgId("BadOrgId"),
            .invalidUrlPattern("[invalid("),
            .invalidRequestsPerSecond(-1.0)
        ]

        // When/Then - All errors should have meaningful descriptions
        for error in errors {
            let description = error.description
            XCTAssertFalse(description.isEmpty, "Error description should not be empty")
            XCTAssertTrue(description.count > 20, "Error description should be informative")
        }
    }
}
