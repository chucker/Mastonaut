//
//  URLSanitizerTests.swift
//  MastonautTests
//
//  Created by Sören Kuklau on 15.10.23.
//

import Foundation
import XCTest

class URLSanitizerTests: XCTestCase {
    let data = [
        ("https://www.apple.com", nil),
        ("https://whatever/article/this-is-not-so-cöl", "https://whatever/article/this-is-not-so-c%C3%B6l"),
        ("https://www.dw.com/en/germany-settle-for-a-draw-despite-second-half-leroy-sané-show/a-47993172?maca=en-rss-en-all-1573-rdf", "https://www.dw.com/en/germany-settle-for-a-draw-despite-second-half-leroy-san%C3%A9-show/a-47993172?maca=en-rss-en-all-1573-rdf"),
        ("https://www.apple.com:443", nil),
        ("https://web.archive.org/web/20190213201804/http://shirky.com/writings/situated_software.html", nil),
        ("https://mjtsai.com/blog/2023/06/06/xcode-15-announced/#xcode-15-announced-update-2023-08-23", nil),
        ("https://example.com/wiki/2.0.8+73", nil),
        ("http://myUser@example.com/hello", nil),
        ("http://myUser:securePassword@example.com/hello", nil),
    ]

    func testInputDoesNotGetMangled() {
        data.forEach {
            input, expectedOutput in

            // if expectedOutput is set, we expect a changed output (e.g. URL-encoding);
            // if `nil`, treat it as same as input

            XCTAssertEqual(expectedOutput ?? input, NSURL(bySanitizingAddress: input)?.absoluteString)
        }
    }
}
