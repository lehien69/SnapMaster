import XCTest
import AppKit
import Foundation
@testable import SnapMaster

final class SnapMasterTests: XCTestCase {
    func testURLExtraction() {
        let url1 = BarcodeManager.extractURL(from: "https://example.com/test?q=1")
        XCTAssertNotNil(url1)
        XCTAssertEqual(url1?.host, "example.com")
        
        let url2 = BarcodeManager.extractURL(from: "http://my-service.local:8080/api")
        XCTAssertNotNil(url2)
        
        let nonUrl = BarcodeManager.extractURL(from: "phone-0339145720")
        XCTAssertNil(nonUrl)
        
        let plainText = BarcodeManager.extractURL(from: "Chào bạn đây là văn bản thường")
        XCTAssertNil(plainText)
    }

    func testBarcodeScanningOnSampleImage() {
        let sampleURL = URL(fileURLWithPath: "/Users/lehien/Library/Application Support/com.valerijs.boguckis.TextSniper/screen_latest.png")
        guard FileManager.default.fileExists(atPath: sampleURL.path),
              let image = NSImage(contentsOf: sampleURL) else {
            return
        }
        
        let expectation = expectation(description: "Scan barcode")
        BarcodeManager.shared.scanFirstBarcodeAndCopy(from: image) { result in
            XCTAssertNotNil(result)
            XCTAssertEqual(result?.payload, "phone-0339145720")
            XCTAssertTrue(result?.symbology.contains("QR") == true)
            
            // Kiểm tra clipboard
            let pbString = NSPasteboard.general.string(forType: .string)
            XCTAssertEqual(pbString, "phone-0339145720")
            
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
    }

    func testHistoryManagerOperations() {
        let history = HistoryManager.shared
        history.clearHistory()
        XCTAssertTrue(history.items.isEmpty)
        
        history.addBarcodeScan(payload: "https://github.com", symbology: "Mã QR")
        XCTAssertEqual(history.items.count, 1)
        XCTAssertEqual(history.items.first?.type, .qrBarcode)
        XCTAssertEqual(history.items.first?.content, "https://github.com")
        XCTAssertTrue(history.items.first?.isURL == true)
        
        history.addTextCapture("Dòng chữ mẫu trích xuất từ màn hình")
        XCTAssertEqual(history.items.count, 2)
        XCTAssertEqual(history.items.first?.type, .text)
        
        history.clearHistory()
        XCTAssertTrue(history.items.isEmpty)
    }
}

