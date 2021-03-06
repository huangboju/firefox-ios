/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Shared
import WebKit
import UIKit
import GCDWebServers

class ClearPrivateDataTests: KIFTestCase, UITextFieldDelegate {
    private var webRoot: String!

    override func setUp() {
        super.setUp()
        webRoot = SimplePageServer.start()        //If it is a first run, first run window should be gone
        BrowserUtils.dismissFirstRunUI(tester())
        tester().tapViewWithAccessibilityLabel("Menu")
        tester().tapViewWithAccessibilityLabel("New Tab")

    }

    override func tearDown() {
        BrowserUtils.resetToAboutHome(tester())
    }

    func visitSites(noOfSites noOfSites: Int) -> [(title: String, domain: String, dispDomain: String, url: String)] {
        var urls: [(title: String, domain: String, dispDomain: String, url: String)] = []
        for pageNo in 1...noOfSites {
            tester().tapViewWithAccessibilityIdentifier("url")
            let url = "\(webRoot)/numberedPage.html?page=\(pageNo)"
            tester().clearTextFromAndThenEnterTextIntoCurrentFirstResponder("\(url)\n")
            tester().waitForWebViewElementWithAccessibilityLabel("Page \(pageNo)")
            let dom = NSURL(string: url)!.normalizedHost()!
            let index = dom.startIndex.advancedBy(7)
            let dispDom = dom.substringToIndex(index)
            let tuple: (title: String, domain: String, dispDomain: String, url: String) = ("Page \(pageNo)", dom, dispDom, url)
            urls.append(tuple)
        }
        BrowserUtils.resetToAboutHome(tester())
        return urls
    }

    func anyDomainsExistOnTopSites(domains: Set<String>) {
        for domain in domains {
            if self.tester().viewExistsWithLabel(domain) {
                return
            }
        }
        XCTFail("Couldn't find any domains in top sites.")
    }

    func testRemembersToggles(swipe: Bool) {
        BrowserUtils.clearPrivateData([BrowserUtils.Clearable.History], swipe:swipe, tester: tester())

        BrowserUtils.openClearPrivateDataDialog(swipe,tester: tester())

        // Ensure the toggles match our settings.
        [
            (BrowserUtils.Clearable.Cache, "0"),
            (BrowserUtils.Clearable.Cookies, "0"),
            (BrowserUtils.Clearable.OfflineData, "0"),
            (BrowserUtils.Clearable.History, "1")
        ].forEach { clearable, switchValue in
            XCTAssertNotNil(tester().waitForViewWithAccessibilityLabel(clearable.rawValue, value: switchValue, traits: UIAccessibilityTraitNone))
        }


        BrowserUtils.closeClearPrivateDataDialog(tester())
    }

    func testClearsTopSitesPanel() {
        let urls = visitSites(noOfSites: 2)
        let dispDomains = Set<String>(urls.map { $0.dispDomain })

        //tester().tapViewWithAccessibilityLabel("Top sites")

        // Only one will be found -- we collapse by domain.
        anyDomainsExistOnTopSites(dispDomains)

        BrowserUtils.clearPrivateData([BrowserUtils.Clearable.History], swipe: false, tester: tester())
        XCTAssertFalse(tester().viewExistsWithLabel(urls[0].title), "Expected to have removed top site panel \(urls[0])")
        XCTAssertFalse(tester().viewExistsWithLabel(urls[1].title), "We shouldn't find the other URL, either.")
    }

    func testDisabledHistoryDoesNotClearTopSitesPanel() {
        let urls = visitSites(noOfSites: 2)
        let dispDomains = Set<String>(urls.map { $0.dispDomain })

        anyDomainsExistOnTopSites(dispDomains)
        BrowserUtils.clearPrivateData(BrowserUtils.AllClearables.subtract([BrowserUtils.Clearable.History]), swipe: false, tester: tester())
        anyDomainsExistOnTopSites(dispDomains)
    }

    func testClearsHistoryPanel() {
        let urls = visitSites(noOfSites: 2)

        tester().tapViewWithAccessibilityLabel("History")
        let url1 = "\(urls[0].title), \(urls[0].url)"
        let url2 = "\(urls[1].title), \(urls[1].url)"
        XCTAssertTrue(tester().viewExistsWithLabel(url1), "Expected to have history row \(url1)")
        XCTAssertTrue(tester().viewExistsWithLabel(url2), "Expected to have history row \(url2)")

        BrowserUtils.clearPrivateData([BrowserUtils.Clearable.History], swipe: false, tester: tester())

        tester().tapViewWithAccessibilityLabel("History")
        XCTAssertFalse(tester().viewExistsWithLabel(url1), "Expected to have removed history row \(url1)")
        XCTAssertFalse(tester().viewExistsWithLabel(url2), "Expected to have removed history row \(url2)")
    }

    func testDisabledHistoryDoesNotClearHistoryPanel() {
        let urls = visitSites(noOfSites: 2)

        tester().tapViewWithAccessibilityLabel("History")
        let url1 = "\(urls[0].title), \(urls[0].url)"
        let url2 = "\(urls[1].title), \(urls[1].url)"
        XCTAssertTrue(tester().viewExistsWithLabel(url1), "Expected to have history row \(url1)")
        XCTAssertTrue(tester().viewExistsWithLabel(url2), "Expected to have history row \(url2)")

        BrowserUtils.clearPrivateData(BrowserUtils.AllClearables.subtract([BrowserUtils.Clearable.History]), swipe: false, tester: tester())

        XCTAssertTrue(tester().viewExistsWithLabel(url1), "Expected to not have removed history row \(url1)")
        XCTAssertTrue(tester().viewExistsWithLabel(url2), "Expected to not have removed history row \(url2)")
    }

    func testClearsCookies() {
        tester().tapViewWithAccessibilityIdentifier("url")
        let url = "\(webRoot)/numberedPage.html?page=1"
        tester().clearTextFromAndThenEnterTextIntoCurrentFirstResponder("\(url)\n")
        tester().waitForWebViewElementWithAccessibilityLabel("Page 1")

        let webView = tester().waitForViewWithAccessibilityLabel("Web content") as! WKWebView

        // Set and verify a dummy cookie value.
        setCookies(webView, cookie: "foo=bar")
        var cookies = getCookies(webView)
        XCTAssertEqual(cookies.cookie, "foo=bar")
        XCTAssertEqual(cookies.localStorage, "foo=bar")
        XCTAssertEqual(cookies.sessionStorage, "foo=bar")

        // Verify that cookies are not cleared when Cookies is deselected.
        BrowserUtils.clearPrivateData(BrowserUtils.AllClearables.subtract([BrowserUtils.Clearable.Cookies]), swipe: true, tester: tester())
        cookies = getCookies(webView)
        XCTAssertEqual(cookies.cookie, "foo=bar")
        XCTAssertEqual(cookies.localStorage, "foo=bar")
        XCTAssertEqual(cookies.sessionStorage, "foo=bar")

        // Verify that cookies are cleared when Cookies is selected.
        BrowserUtils.clearPrivateData([BrowserUtils.Clearable.Cookies], swipe: true, tester: tester())
        cookies = getCookies(webView)
        XCTAssertEqual(cookies.cookie, "")
        XCTAssertNil(cookies.localStorage)
        XCTAssertNil(cookies.sessionStorage)
    }

    func testClearsCache() {
        let cachedServer = CachedPageServer()
        let cacheRoot = cachedServer.start()
        let url = "\(cacheRoot)/cachedPage.html"
        tester().tapViewWithAccessibilityIdentifier("url")
        tester().clearTextFromAndThenEnterTextIntoCurrentFirstResponder("\(url)\n")
        tester().waitForWebViewElementWithAccessibilityLabel("Cache test")

        let webView = tester().waitForViewWithAccessibilityLabel("Web content") as! WKWebView
        let requests = cachedServer.requests

        // Verify that clearing non-cache items will keep the page in the cache.
        BrowserUtils.clearPrivateData(BrowserUtils.AllClearables.subtract([BrowserUtils.Clearable.Cache]), swipe: true, tester: tester())
        webView.reload()
        XCTAssertEqual(cachedServer.requests, requests)

        // Verify that clearing the cache will fire a new request.
        BrowserUtils.clearPrivateData([BrowserUtils.Clearable.Cache], swipe: true, tester: tester())
        webView.reload()
        XCTAssertEqual(cachedServer.requests, requests + 1)
    }

    private func setCookies(webView: WKWebView, cookie: String) {
        let expectation = expectationWithDescription("Set cookie")
        webView.evaluateJavaScript("document.cookie = \"\(cookie)\"; localStorage.cookie = \"\(cookie)\"; sessionStorage.cookie = \"\(cookie)\";") { result, _ in
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(10, handler: nil)
    }

    private func getCookies(webView: WKWebView) -> (cookie: String, localStorage: String?, sessionStorage: String?) {
        var cookie: (String, String?, String?)!
        let expectation = expectationWithDescription("Got cookie")
        webView.evaluateJavaScript("JSON.stringify([document.cookie, localStorage.cookie, sessionStorage.cookie])") { result, _ in
            let cookies = JSON.parse(result as! String).asArray!
            cookie = (cookies[0].asString!, cookies[1].asString, cookies[2].asString)
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(10, handler: nil)
        return cookie
    }
}

/// Server that keeps track of requests.
private class CachedPageServer {
    var requests = 0

    func start() -> String {
        let webServer = GCDWebServer()
        webServer.addHandlerForMethod("GET", path: "/cachedPage.html", requestClass: GCDWebServerRequest.self) { (request) -> GCDWebServerResponse! in
            self.requests += 1
            return GCDWebServerDataResponse(HTML: "<html><head><title>Cached page</title></head><body>Cache test</body></html>")
        }

        webServer.startWithPort(0, bonjourName: nil)

        // We use 127.0.0.1 explicitly here, rather than localhost, in order to avoid our
        // history exclusion code (Bug 1188626).
        let webRoot = "http://127.0.0.1:\(webServer.port)"
        return webRoot
    }
}
