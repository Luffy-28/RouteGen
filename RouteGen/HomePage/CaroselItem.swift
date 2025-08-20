//
//  CaroselItem.swift
//  RouteGen
//
//  Created by 10167 on 1/8/2025.
//

import Foundation

public struct CaroselItem {
    public let title: String
    public let imageURL: URL
    public let linkURL: URL
    
    public init(title: String, imageURL: URL, linkURL: URL) {
        self.title = title
        self.imageURL = imageURL
        self.linkURL = linkURL
    }
}
