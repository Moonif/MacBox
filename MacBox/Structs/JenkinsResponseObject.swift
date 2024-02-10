//
//  JenkinsResponseObject.swift
//  MacBox
//
//  Created by Moonif on 1/17/24.
//

import Cocoa

struct JenkinsResponseObject: Decodable {
    let id: String?
    let number: Int?
    let timestamp: Double?
    let url: String?
    let artifacts: [JenkinsArtifact]?
    let changeSets: [JenkinsChangeSets]?
}

struct JenkinsArtifact: Decodable {
    let fileName: String?
    let relativePath: String?
}

struct JenkinsChangeSets: Decodable {
    let items: [JenkinsChangeSetItem]?
}

struct JenkinsChangeSetItem: Decodable {
    let msg: String?
    let comment: String?
}

extension JenkinsResponseObject {
    func toGithubResponseObject() -> GithubResponseObject {
        // Convert timestamp to date
        let dateVal = TimeInterval(timestamp ?? 0) / 1000.0
        let date = Date(timeIntervalSince1970: dateVal)
        let formattedDate = date.getFormattedDate(format: "yyyy-MM-dd'T'HH:mm:ssZ")
        
        // Convert artifacts to assets
        var assets = [GithubAsset]()
        for artifact in artifacts ?? [] {
            let asset = GithubAsset(url: artifact.fileName, browser_download_url: artifact.relativePath)
            assets.append(asset)
        }
        
        let githubObject = GithubResponseObject(
            url: url,
            html_url: nil,
            tag_name: id,
            body: changeSets?.first?.items?.first?.comment,
            published_at: formattedDate,
            sha: nil,
            assets: assets,
            commit: nil
        )
        
        return githubObject
    }
}
