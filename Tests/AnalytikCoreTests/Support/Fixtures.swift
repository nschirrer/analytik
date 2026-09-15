import Foundation
import XCTest
@testable import AnalytikCore

enum Fixtures {
    static func url(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: "xlsx", subdirectory: "Fixtures") else {
            XCTFail("Fixture introuvable : \(name).xlsx", file: file, line: line)
            throw NSError(domain: "Fixtures", code: 1)
        }
        return url
    }

    static func subChannelReport() throws -> Report {
        try GoldReportParser.parse(fileURL: try url("gold-subchannel"))
    }

    static func productsReport() throws -> Report {
        try GoldReportParser.parse(fileURL: try url("gold-products"))
    }

    static func week(_ w: Int, fy: Int = 2026, q: Int = 3) -> Period {
        .week(fiscalYear: fy, quarter: q, week: w)
    }
}
