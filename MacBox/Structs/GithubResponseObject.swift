//
//  GithubResponseObject.swift
//  MacBox
//
//  Created by Moonif on 1/8/24.
//

struct GithubResponseObject: Decodable {
    let url: String?
    let html_url: String?
    let tag_name: String?
    let body: String?
    let published_at: String?
    let sha: String?
    let assets: [GithubAsset]?
    let commit: GithubCommit?
}

struct GithubAsset: Decodable {
    let url: String?
    let browser_download_url: String?
}

struct GithubCommit: Decodable {
    let author: GithubCommitAuthor?
}

struct GithubCommitAuthor: Decodable {
    let name: String?
    let date: String?
}
