//
//  VersionManagerViewController.swift
//  MacBox
//
//  Created by Moonif on 1/15/24.
//

import Cocoa
import ZIPFoundation

class VersionManagerViewController: NSViewController {
    
    // IBOutlets
    @IBOutlet weak var tagsStackView: NSStackView!
    
    @IBOutlet weak var versionTagTextField: NSTextField!
    @IBOutlet weak var experimentalTagTextField: NSTextField!
    @IBOutlet weak var stableTagTextField: NSTextField!
    
    @IBOutlet weak var emulatorUpdateDateTextField: NSTextField!
    @IBOutlet weak var romsUpdateDateTextField: NSTextField!
    @IBOutlet weak var macboxUpdateDateTextField: NSTextField!
    
    @IBOutlet var emulatorReleaseNoteTextView: NSTextView!
    
    @IBOutlet var macboxReleaseNoteTextView: NSTextView!
    
    @IBOutlet weak var emulatorUpdateButton: NSButton!
    @IBOutlet weak var emulatorUpdateCheckImageView: NSImageView!
    @IBOutlet weak var emulatorUpdateProgressIndicator: NSProgressIndicator!
    
    @IBOutlet weak var romsUpdateButton: NSButton!
    @IBOutlet weak var romsUpdateCheckImageView: NSImageView!
    @IBOutlet weak var romsUpdateProgressIndicator: NSProgressIndicator!
    
    @IBOutlet weak var macboxUpdateButton: NSButton!
    @IBOutlet weak var macboxUpdateCheckImageView: NSImageView!
    @IBOutlet weak var macboxUpdateProgressIndicator: NSProgressIndicator!
    
    // Variables
    let dateFormatter = DateFormatter()
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let homeDirURL = URL(fileURLWithPath: "MacBox", isDirectory: true, relativeTo: FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!)
    private let dateInputFormatString = "yyyy-MM-dd'T'HH:mm:ssZ"
    private let dateOutputFormatString = "MMM dd, yyyy"
    var isStableChannel: Bool = false
    var emulatorAppVer: String = "0"
    var emulatorBuildVer: String = "0"
    private var emulatorUpdatedURL: URL?
    private var emulatorUpdatedAppVer: String?
    private var emulatorUpdatedBuildVer: String?
    
    var downloadTasks: [DownloadInfo] = []

    struct DownloadInfo {
        var type: updateType
        var downloadTask: URLSessionDownloadTask
        var updateButton: NSButton
        var progressIndicator: NSProgressIndicator
        var updateCheck: NSImageView
    }
    
    enum updateType {
        case emulator
        case roms
        case macbox
    }
    
    // View did load
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Config views
        configView()
    }
    
    // View will appear
    override func viewWillAppear() {
        // Remove fullscreen window button
        self.view.window?.styleMask.remove(.fullScreen)
        self.view.window?.styleMask.remove(.resizable)
    }
    
    // View did layout
    override func viewDidLayout() {
        // Adjust tags appearance
        for view in tagsStackView.views {
            view.layer?.masksToBounds = true
            view.layer?.cornerRadius = 4
        }
    }
    
    // View will disappear
    override func viewWillDisappear() {
        // Cancel all download tasks
        for downloadTask in downloadTasks {
            downloadTask.downloadTask.cancel()
        }
    }
    
    // Config views initial properties
    private func configView() {
        // Populate update info
        populateEmulatorUpdateInfo()
        populateRomsUpdateInfo()
        populateMacBoxUpdateInfo()
        // Set update buttons visibility
        setUpdateButtons()
    }
    
    // Populate 86Box update info
    private func populateEmulatorUpdateInfo() {
        let versionInfoObject = MainViewController.instance.versionInfoObject
        
        dateFormatter.dateFormat = dateInputFormatString
        let date: Date? = dateFormatter.date(from: versionInfoObject.emulatorUpdateObject?.published_at ?? "")
        let formattedDate = date?.getFormattedDate(format: dateOutputFormatString)
        
        var relativeDate = ""
        if #available(macOS 10.15, *) {
            let relativeDateFormatter = RelativeDateTimeFormatter()
            relativeDateFormatter.unitsStyle = .full
            
            relativeDate = relativeDateFormatter.localizedString(for: date ?? Date(), relativeTo: Date())
        } else {
            // Fallback on earlier versions
            relativeDate = formattedDate ?? "-"
        }
        
        emulatorUpdateDateTextField.stringValue = relativeDate
        emulatorUpdateDateTextField.toolTip = formattedDate
        
        emulatorReleaseNoteTextView.string = isStableChannel ? versionInfoObject.emulatorUpdateObject?.body ?? "-" : "What's New:\n" + (versionInfoObject.emulatorUpdateObject?.body ?? "-")
        
        // Tags
        versionTagTextField.stringValue = isStableChannel ? versionInfoObject.emulatorUpdateObject?.tag_name ?? "-" : "Build #" + (versionInfoObject.emulatorUpdateObject?.tag_name ?? "-")
        stableTagTextField.isHidden = !isStableChannel
        experimentalTagTextField.isHidden = isStableChannel
    }
    
    // Populate 86Box ROMs update info
    private func populateRomsUpdateInfo() {
        let versionInfoObject = MainViewController.instance.versionInfoObject
        
        dateFormatter.dateFormat = dateInputFormatString
        let date: Date? = dateFormatter.date(from: versionInfoObject.romsUpdateObject?.commit?.author?.date ?? "")
        let formattedDate = date?.getFormattedDate(format: dateOutputFormatString)
        
        var relativeDate = ""
        if #available(macOS 10.15, *) {
            let relativeDateFormatter = RelativeDateTimeFormatter()
            relativeDateFormatter.unitsStyle = .full
            
            relativeDate = relativeDateFormatter.localizedString(for: date ?? Date(), relativeTo: Date())
        } else {
            // Fallback on earlier versions
            relativeDate = formattedDate ?? "-"
        }
        
        romsUpdateDateTextField.stringValue = relativeDate
        romsUpdateDateTextField.toolTip = formattedDate
    }
    
    // Populate MacBox update info
    private func populateMacBoxUpdateInfo() {
        let versionInfoObject = MainViewController.instance.versionInfoObject
        
        dateFormatter.dateFormat = dateInputFormatString
        let date: Date? = dateFormatter.date(from: versionInfoObject.macboxUpdateObject?.published_at ?? "")
        let formattedDate = date?.getFormattedDate(format: dateOutputFormatString)
        
        var relativeDate = ""
        if #available(macOS 10.15, *) {
            let relativeDateFormatter = RelativeDateTimeFormatter()
            relativeDateFormatter.unitsStyle = .full
            
            relativeDate = relativeDateFormatter.localizedString(for: date ?? Date(), relativeTo: Date())
        } else {
            // Fallback on earlier versions
            relativeDate = formattedDate ?? "-"
        }
        
        macboxUpdateDateTextField.stringValue = relativeDate
        macboxUpdateDateTextField.toolTip = formattedDate
        
        macboxReleaseNoteTextView.string = versionInfoObject.macboxUpdateObject?.body ?? "-"
    }
    
    // Set update buttons visibility
    private func setUpdateButtons() {
        let versionInfoObject = MainViewController.instance.versionInfoObject
        
        emulatorUpdateButton.isHidden = false
        emulatorUpdateCheckImageView.isHidden = true
        emulatorUpdateProgressIndicator.isHidden = true
        
        romsUpdateButton.isHidden = false
        romsUpdateCheckImageView.isHidden = true
        romsUpdateProgressIndicator.isHidden = true
        
        macboxUpdateButton.isHidden = false
        macboxUpdateCheckImageView.isHidden = true
        macboxUpdateProgressIndicator.isHidden = true
        
        // Compare 86Box version
        if let emulatorOnlineVersion = versionInfoObject.emulatorUpdateObject?.tag_name {
            if isStableChannel {
                // Stable: compare app version
                if emulatorOnlineVersion.dropFirst() == emulatorAppVer {
                    emulatorUpdateButton.isHidden = true
                    emulatorUpdateCheckImageView.isHidden = false
                }
            }
            else {
                // Experimental: compare build version
                if emulatorOnlineVersion == emulatorBuildVer {
                    emulatorUpdateButton.isHidden = true
                    emulatorUpdateCheckImageView.isHidden = false
                }
            }
        }
        
        // Set button label if 86Box is not installed
        if versionInfoObject.emulatorAutoUrl == nil && versionInfoObject.emulatorCustomUrl == nil {
            emulatorUpdateButton.title = NSLocalizedString("Install", comment: "")
        }
        else {
            emulatorUpdateButton.title = NSLocalizedString("Update", comment: "")
        }
        
        // Compare 86Box ROMs version
        if let romsShaVersion = versionInfoObject.romsUpdateObject?.sha {
            if let localShaVersion = userDefaults.string(forKey: "romsShaVersion") {
                if localShaVersion == String(romsShaVersion) && !versionInfoObject.romsUrls.isEmpty {
                    romsUpdateButton.isHidden = true
                    romsUpdateCheckImageView.isHidden = false
                }
            }
        }
        
        // Set button label if 86Box ROMs are not installed
        if versionInfoObject.romsUrls.isEmpty {
            romsUpdateButton.title = NSLocalizedString("Install", comment: "")
        }
        else {
            romsUpdateButton.title = NSLocalizedString("Update", comment: "")
        }
        
        // Compare MacBox version
        if let macboxOnlineVersion = versionInfoObject.macboxUpdateObject?.tag_name {
            let localBuildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? String(macboxOnlineVersion)
            
            if localBuildVersion == String(macboxOnlineVersion) {
                macboxUpdateButton.isHidden = true
                macboxUpdateCheckImageView.isHidden = false
            }
        }
    }
    
    // Fetch 86Box updated macOS binary
    private func fetchEmulatorUpdateBinary() {
        let versionInfoObject = MainViewController.instance.versionInfoObject
        
        for asset in versionInfoObject.emulatorUpdateObject?.assets ?? [] {
            if let downloadURL = asset.browser_download_url {
                if isStableChannel {
                    // Stable
                    if downloadURL.lowercased().contains("macos") {
                        if let url = URL(string: downloadURL) {
                            downloadEmulatorBinary(url: url)
                        }
                    }
                }
                else {
                    // Experimental
                    if downloadURL.lowercased().contains("recommended") && downloadURL.lowercased().contains("macos") {
                        if let url = URL(string: "https://ci.86box.net/job/86Box/lastSuccessfulBuild/artifact/" + downloadURL) {
                            downloadEmulatorBinary(url: url)
                        }
                    }
                }
            }
        }
    }
    
    // Download 86Box binary
    private func downloadEmulatorBinary(url: URL) {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue.main)
        
        let downloadTask = session.downloadTask(with: url)
        
        let downloadInfo = DownloadInfo(
            type: .emulator,
            downloadTask: downloadTask,
            updateButton: emulatorUpdateButton,
            progressIndicator: emulatorUpdateProgressIndicator,
            updateCheck: emulatorUpdateCheckImageView
        )
        
        downloadTasks.append(downloadInfo)
        
        downloadTask.resume()
    }
    
    // Update 86Box binary with the new version
    private func updateEmulatorBinary(location: URL) {
        let versionInfoObject = MainViewController.instance.versionInfoObject
        
        var tempURL = homeDirURL
        tempURL.appendPathComponent("tmp")
        
        var fileURL = tempURL
        fileURL.appendPathComponent(location.lastPathComponent + ".zip")
        
        var emulatorDefaultInstallationURL = homeDirURL
        emulatorDefaultInstallationURL.appendPathComponent("86Box.app")
        
        var unzippedEmulatorFileURL = tempURL
        unzippedEmulatorFileURL.appendPathComponent("86Box.app")
        
        do {
            // Create the tmp directory
            try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
            // Move the downloaded file into the tmp directory
            try fileManager.moveItem(at: location, to: URL(fileURLWithPath: fileURL.path))
            // Unzip the file
            try fileManager.unzipItem(at: fileURL, to: tempURL)
            
            var emulatorPath: URL?
            if let emulatorCustomPath = versionInfoObject.emulatorCustomUrl?.path {
                if #available(macOS 13.0, *) {
                    emulatorPath = URL(filePath: emulatorCustomPath)
                } else {
                    // Fallback on earlier versions
                    emulatorPath = URL(fileURLWithPath: emulatorCustomPath)
                }
            }
            else if let emulatorAutoPath = versionInfoObject.emulatorAutoUrl?.path {
                if #available(macOS 13.0, *) {
                    emulatorPath = URL(filePath: emulatorAutoPath)
                } else {
                    // Fallback on earlier versions
                    emulatorPath = URL(fileURLWithPath: emulatorAutoPath)
                }
            }
            
            // Get 86Box info.plist
            var binaryAppVer: String?
            var binaryBuildVer: String?
            
            if let bundle = Bundle(url: unzippedEmulatorFileURL) {
                // Get the 86Box short version
                if let shortVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String {
                    binaryAppVer = shortVersion
                }
                // Get the 86Box bundle version
                if let bundleVersion = bundle.infoDictionary?["CFBundleVersion"] as? String {
                    binaryBuildVer = String((bundleVersion).suffix(4))
                }
            }
            
            // Set variables
            emulatorUpdatedAppVer = binaryAppVer
            emulatorUpdatedBuildVer = binaryBuildVer
            
            if let path = emulatorPath {
                // 86Box is installed; replace old binary with the updated one
                let _ = try fileManager.replaceItemAt(path, withItemAt: unzippedEmulatorFileURL)
                // Set variables
                emulatorUpdatedURL = path
                // Update version info
                MainViewController.instance.checkFor86Box(url: path, appVer: binaryAppVer, buildVer: binaryBuildVer)
            }
            else {
                // 86Box is not installed; install it in the MacBox folder
                try fileManager.moveItem(at: unzippedEmulatorFileURL, to: emulatorDefaultInstallationURL)
                // Set variables
                emulatorUpdatedURL = emulatorDefaultInstallationURL
                // Update version info
                MainViewController.instance.checkFor86Box(url: emulatorDefaultInstallationURL, appVer: binaryAppVer, buildVer: binaryBuildVer)
            }
            
            // Delete temporary file
            deleteTmpFile(url: fileURL)
            
            // Update buttons status
            emulatorUpdateProgressIndicator.isHidden = true
            emulatorUpdateButton.isHidden = true
            emulatorUpdateCheckImageView.isHidden = false
        } catch {
            print("Error: \(error.localizedDescription)")
            
            emulatorUpdateProgressIndicator.isHidden = true
            emulatorUpdateButton.isHidden = false
        }
    }
    
    // Fetch 86Box ROMs file
    private func fetchRomsUpdateFile() {
        if let url = URL(string: "https://api.github.com/repos/86Box/roms/zipball/master") {
            downloadRomsFile(url: url)
        }
    }
    
    // Download 86Box ROMs file
    private func downloadRomsFile(url: URL) {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue.main)
        
        let downloadTask = session.downloadTask(with: url)
        
        let downloadInfo = DownloadInfo(
            type: .roms,
            downloadTask: downloadTask,
            updateButton: romsUpdateButton,
            progressIndicator: romsUpdateProgressIndicator,
            updateCheck: romsUpdateCheckImageView
        )
        
        downloadTasks.append(downloadInfo)
        
        downloadTask.resume()
    }
    
    // Update 86Box ROMs with the new version
    private func updateRomsFile(location: URL) {
        var versionInfoObject = MainViewController.instance.versionInfoObject
        
        var tempURL = homeDirURL
        tempURL.appendPathComponent("tmp")
        
        var fileURL = tempURL
        fileURL.appendPathComponent(location.lastPathComponent + ".zip")
        
        var unzippedRomsFileURL = tempURL
        unzippedRomsFileURL.appendPathComponent("roms")
        
        do {
            // Create the tmp directory
            try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
            // Move the downloaded file into the tmp directory
            try fileManager.moveItem(at: location, to: URL(fileURLWithPath: fileURL.path))
            // Unzip the file
            try fileManager.unzipItem(at: fileURL, to: unzippedRomsFileURL)
            // Get the unzipped folder
            let unzippedItems = try fileManager.contentsOfDirectory(atPath: unzippedRomsFileURL.path)
            for item in unzippedItems {
                if item.hasPrefix("86Box-roms") {
                    var unzippedRomsFolderURL = unzippedRomsFileURL
                    unzippedRomsFolderURL.appendPathComponent(item)
                    
                    if versionInfoObject.romsUrls.isEmpty {
                        // 86Box ROMs are not installed; install them in the user application support directory
                        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: [.userDomainMask])
                        if var romsDirPath = appSupportDir.first {
                            romsDirPath.appendPathComponent("net.86box.86Box/roms")
                            // Create the 86Box ROMs directory
                            try fileManager.createDirectory(at: romsDirPath, withIntermediateDirectories: true, attributes: nil)
                            // Move the updated ROMs directory to the user's application support
                            let _ = try fileManager.replaceItemAt(romsDirPath, withItemAt: unzippedRomsFolderURL)
                            // Set user defaults
                            if let romsSha = versionInfoObject.romsUpdateObject?.sha {
                                userDefaults.set(romsSha, forKey: "romsShaVersion")
                            }
                            // Update version info
                            versionInfoObject.romsUrls.append(romsDirPath)
                        }
                    }
                    else {
                        // Replace the ROMs directory with the updated one
                        for romsURL in versionInfoObject.romsUrls {
                            let _ = try fileManager.replaceItemAt(romsURL, withItemAt: unzippedRomsFolderURL)
                            // Set user defaults
                            if let romsSha = versionInfoObject.romsUpdateObject?.sha {
                                userDefaults.set(romsSha, forKey: "romsShaVersion")
                            }
                        }
                    }
                    
                    // Delete temporary file
                    deleteTmpFile(url: fileURL)
                    
                    // Update version info
                    MainViewController.instance.checkFor86Box(url: emulatorUpdatedURL, appVer: emulatorUpdatedAppVer, buildVer: emulatorUpdatedBuildVer)
                    
                    break
                }
            }
            
            // Update buttons status
            romsUpdateProgressIndicator.isHidden = true
            romsUpdateButton.isHidden = true
            romsUpdateCheckImageView.isHidden = false
        } catch {
            print("Error: \(error.localizedDescription)")
            
            romsUpdateProgressIndicator.isHidden = true
            romsUpdateButton.isHidden = false
        }
    }
    
    // Fetch MacBox updated macOS binary
    private func fetchMacBoxUpdateBinary() {
        let versionInfoObject = MainViewController.instance.versionInfoObject
            
        for asset in versionInfoObject.macboxUpdateObject?.assets ?? [] {
            guard let downloadURL = asset.browser_download_url,
                  let url = URL(string: downloadURL) else {
                continue
            }
            downloadMacBoxBinary(url: url)
        }
    }
    
    // Download MacBox binary
    private func downloadMacBoxBinary(url: URL) {
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig, delegate: self, delegateQueue: OperationQueue.main)
        
        let downloadTask = session.downloadTask(with: url)
        
        let downloadInfo = DownloadInfo(
            type: .macbox,
            downloadTask: downloadTask,
            updateButton: macboxUpdateButton,
            progressIndicator: macboxUpdateProgressIndicator,
            updateCheck: macboxUpdateCheckImageView
        )
        
        downloadTasks.append(downloadInfo)
        
        downloadTask.resume()
    }
    
    // Update MacBox binary with the new version
    private func updateMacBoxBinary(location: URL) {
        var tempURL = homeDirURL
        tempURL.appendPathComponent("tmp")
        
        var fileURL = tempURL
        fileURL.appendPathComponent(location.lastPathComponent + ".zip")
        
        var unzippedMacBoxFileURL = tempURL
        unzippedMacBoxFileURL.appendPathComponent("MacBox.app")
        
        do {
            // Create the tmp directory
            try fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
            // Move the downloaded file into the tmp directory
            try fileManager.moveItem(at: location, to: URL(fileURLWithPath: fileURL.path))
            // Unzip the file
            try fileManager.unzipItem(at: fileURL, to: tempURL)
            
            let macboxAppURL = Bundle.main.bundleURL
            let _ = try fileManager.replaceItemAt(macboxAppURL, withItemAt: unzippedMacBoxFileURL)
            
            // Delete temporary file
            deleteTmpFile(url: fileURL)
            
            // Update buttons status
            macboxUpdateProgressIndicator.isHidden = true
            macboxUpdateButton.isHidden = true
            macboxUpdateCheckImageView.isHidden = false
            
            // Prompt the user to restart the app
            let alert = NSAlert()
            
            alert.messageText = NSLocalizedString("MacBox will now restart in order to apply the update", comment: "")
            alert.alertStyle = .critical
            alert.addButton(withTitle: NSLocalizedString("Restart", comment: ""))
            
            // Show the alert
            let alertResult = alert.runModal()
            let taskLaunchPath = "/usr/bin/open"
            
            if alertResult == .alertFirstButtonReturn {
                let macboxAppPath = Bundle.main.bundlePath
                let task = Process()
                task.launchPath = taskLaunchPath
                task.arguments = [macboxAppPath]
                task.launch()
                exit(0)
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            
            macboxUpdateProgressIndicator.isHidden = true
            macboxUpdateButton.isHidden = false
        }
    }
    
    // Delete a temporary file
    private func deleteTmpFile(url: URL) {
        let filePath = url.path
        do {
            try fileManager.removeItem(at: URL(fileURLWithPath:filePath))
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
// ------------------------------------
// IBActions
// ------------------------------------
    
    // 86Box update button action
    @IBAction func emulatorUpdateButtonAction(_ sender: NSButton) {
        // Hide update button and show progress indicator
        emulatorUpdateButton.isHidden = true
        emulatorUpdateProgressIndicator.isHidden = false
        
        // Find the MacOS binary
        fetchEmulatorUpdateBinary()
    }
    
    // 86Box ROMs update button action
    @IBAction func romsUpdateButtonAction(_ sender: NSButton) {
        // Hide update button and show progress indicator
        romsUpdateButton.isHidden = true
        romsUpdateProgressIndicator.isHidden = false
        
        // Download the 86Box ROMs file
        fetchRomsUpdateFile()
    }
    
    // MacBox update button action
    @IBAction func macboxUpdateButtonAction(_ sender: NSButton) {
        // Hide update button and show progress indicator
        macboxUpdateButton.isHidden = true
        macboxUpdateProgressIndicator.isHidden = false
        
        // Find the MacOS binary
        fetchMacBoxUpdateBinary()
    }
    
}

// ------------------------------------
// URLSessionDownload Delegate
// ------------------------------------

extension VersionManagerViewController: URLSessionDownloadDelegate {
    
    // Handle files download
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let info = downloadTasks.first(where: { $0.downloadTask == downloadTask }) {
            if info.type == .emulator {
                updateEmulatorBinary(location: location)
            }
            else if info.type == .roms {
                updateRomsFile(location: location)
            }
            else {
                updateMacBoxBinary(location: location)
            }
        }
    }
    
    // Handle download progress
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if let info = downloadTasks.first(where: { $0.downloadTask == downloadTask }) {
            var progress: Float = 0
            if totalBytesExpectedToWrite > 0 {
                // Known file size
                progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            }
            else {
                // Unknown file size (Usually, it's the ROMs github zip file); set 50MB by default
                progress = Float(totalBytesWritten) / Float(52428800)
            }
            
            DispatchQueue.main.async {
                info.progressIndicator.doubleValue = Double(progress * 100.0)
            }
        }
    }
    
    // Handle download error
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let info = downloadTasks.first(where: { $0.downloadTask == task }),
              let error = error
        else {
            return
        }
            
        info.progressIndicator.isHidden = true
        info.updateButton.isHidden = false
            
        print("Error: \(error.localizedDescription)")
    }
}
