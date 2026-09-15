import XCTest
@testable import AnalytikCore

final class DatasetSerializerTests: XCTestCase {
    func testSerializationIsDeterministicAndComplete() throws {
        let subChannel = try Fixtures.subChannelReport()
        let products = try Fixtures.productsReport()
        let first = DatasetSerializer.serialize(reports: [subChannel, products])
        let second = DatasetSerializer.serialize(reports: [products, subChannel])
        XCTAssertEqual(first, second)
        XCTAssertTrue(first.hasPrefix("Légende des données"))
        XCTAssertTrue(first.contains("## Rapport : gold-subchannel.xlsx (feuille « Sub-Channel »)"))
        XCTAssertTrue(first.contains("Product : iPhone | "))
        XCTAssertTrue(first.contains("Dimension des lignes : Sub-Channel"))
        XCTAssertTrue(first.contains("Sub-Channel;Métrique;FY26 Q3 W1;"))
        XCTAssertTrue(first.contains("\nTOTAL;NBL;360;330;"))
        XCTAssertTrue(first.contains("\nRK - RETAIL KIOSK;y/y;-;-;"))
        // Les rapports sont triés par nom de fichier : products avant subchannel.
        let productsIndex = try XCTUnwrap(first.range(of: "gold-products.xlsx")).lowerBound
        let subChannelIndex = try XCTUnwrap(first.range(of: "gold-subchannel.xlsx")).lowerBound
        XCTAssertLessThan(productsIndex, subChannelIndex)
    }
}
