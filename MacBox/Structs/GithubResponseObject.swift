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
}
