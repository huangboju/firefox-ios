/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import Shared


public class SuggestedSite: Site {
    public let wordmark: Favicon
    public let backgroundColor: UIColor

    override public var tileURL: NSURL {
        return NSURL(string: url) ?? NSURL(string: "about:blank")!
    }

    let trackingId: Int
    init(data: SuggestedSiteData) {
        self.backgroundColor = UIColor(colorString: data.bgColor)
        self.trackingId = data.trackingId
        self.wordmark = Favicon(url: data.imageUrl, date: NSDate(), type: .Icon)
        super.init(url: data.url, title: data.title, bookmarked: nil)
        self.icon = Favicon(url: data.faviconUrl, date: NSDate(), type: .Icon)
    }

    public var faviconImagePath: String? {
        return wordmark.url.stringByReplacingOccurrencesOfString("asset://suggestedsites", withString: "as")
    }
}

public let SuggestedSites: SuggestedSitesCursor = SuggestedSitesCursor()

public class SuggestedSitesCursor: ArrayCursor<SuggestedSite> {
    private init() {
        let locale = NSLocale.currentLocale()
        let sites = DefaultSuggestedSites.sites[locale.localeIdentifier] ??
                    DefaultSuggestedSites.sites["default"]! as Array<SuggestedSiteData>
        let tiles = sites.map({ data -> SuggestedSite in
            var site = data
            if let domainMap = DefaultSuggestedSites.urlMap[data.url], let localizedURL = domainMap[locale.localeIdentifier] {
                site.url = localizedURL
            }
            return SuggestedSite(data: site)
        })
        super.init(data: tiles, status: .Success, statusMessage: "Loaded")
    }
}

public struct SuggestedSiteData {
    var url: String
    var bgColor: String
    var imageUrl: String
    var faviconUrl: String
    var trackingId: Int
    var title: String
}
