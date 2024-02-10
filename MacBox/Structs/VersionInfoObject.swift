//
//  VersionInfoObject.swift
//  MacBox
//
//  Created by Moonif on 1/22/24.
//

import Cocoa

struct VersionInfoObject {
    // 86Box emulator info
    var emulatorUpdateChannel: String?
    var emulatorAutoUrl: URL?
    var emulatorCustomUrl: URL?
    // 86Box ROMs info
    var romsUrls: [URL] = []
    // Update objects
    var emulatorUpdateObject: GithubResponseObject?
    var romsUpdateObject: GithubResponseObject?
    var macboxUpdateObject: GithubResponseObject?
}
