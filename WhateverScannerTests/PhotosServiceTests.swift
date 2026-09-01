import XCTest
@testable import WhateverScanner

/// Unit tests for `PhotosService`. Only the deterministic `PhotosServiceError`
/// descriptions are covered here — `requestAuthorization()`/`save(images:)` drive
/// the system photo-permission prompt and can't be exercised in a headless
/// unit test without mocking `PHPhotoLibrary`, which the service doesn't inject.
final class PhotosServiceTests: XCTestCase {

    func testAccessDeniedErrorDescription() {
        XCTAssertNotNil(PhotosServiceError.accessDenied.errorDescription)
    }

    func testSaveFailedErrorDescriptionForwardsUnderlyingMessage() {
        let underlying = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "no space"])
        XCTAssertEqual(PhotosServiceError.saveFailed(underlying).errorDescription, "no space")
    }
}
