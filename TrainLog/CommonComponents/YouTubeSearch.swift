import Foundation
import SwiftUI
import UIKit

enum YouTubeSearch {
    static func open(query: String, openURL: OpenURLAction) {
        guard let vndURL = vndSearchURL(query: query),
              let appURL = appSearchURL(query: query),
              let webURL = webSearchURL(query: query) else { return }

        if UIApplication.shared.canOpenURL(appURL) {
            openURL(appURL)
        } else if UIApplication.shared.canOpenURL(vndURL) {
            openURL(vndURL)
        } else {
            openURL(webURL)
        }
    }

    private static func appSearchURL(query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "youtube"
        components.host = "search"
        components.queryItems = [
            URLQueryItem(name: "query", value: query)
        ]
        return components.url
    }

    private static func vndSearchURL(query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "vnd.youtube"
        components.host = "search"
        components.queryItems = [
            URLQueryItem(name: "query", value: query)
        ]
        return components.url
    }

    private static func webSearchURL(query: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.youtube.com"
        components.path = "/results"
        components.queryItems = [
            URLQueryItem(name: "search_query", value: query)
        ]
        return components.url
    }
}
