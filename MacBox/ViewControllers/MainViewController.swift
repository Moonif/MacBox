//
//  ViewController.swift
//  MacBox
//
//  Created by Moonif on 4/9/23.
//

import Cocoa
import Network

class MainViewController: NSViewController {

    // IBOutlets
    @IBOutlet weak var vmsTableView: NSTableView!
    @IBOutlet weak var startVMButton: NSButton!
    @IBOutlet weak var vmSettingsButton: NSButton!
    @IBOutlet weak var vmAppVersionPopUpButton: NSPopUpButton!
    @IBOutlet weak var deleteVMButton: NSButton!
    @IBOutlet weak var spinningProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var statusCheckMarkImage: NSImageView!
    @IBOutlet weak var statusXMarkImage: NSImageView!
    @IBOutlet weak var statusExclamationMarkImage: NSImageView!
    @IBOutlet weak var statusArrowImage: NSImageView!
    @IBOutlet weak var statusButton: NSButton!
    @IBOutlet weak var vmNameTextField: NSTextField!
    @IBOutlet var vmDescriptionTextView: NSTextView!
    
    @IBOutlet weak var vmSpecMachine: NSTextField!
    @IBOutlet weak var vmSpecCPU: NSTextField!
    @IBOutlet weak var vmSpecRAM: NSTextField!
    @IBOutlet weak var vmSpecHDD: NSTextField!
    @IBOutlet weak var vmSpecMachineLogo: NSImageView!
    
    // Instance
    private(set) static var instance: MainViewController!
    
    // Variables
    let screensaverManager = ScreensaverManager()
    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    var homeDirURL = URL(fileURLWithPath: "MacBox", isDirectory: true, relativeTo: FileManager.default.homeDirectoryForCurrentUser)
    var vmList: [VM] = []
    private var currentSelectedVM: Int?
    private var currentRunningVM: [RunningVMProcess] = []
    private var currentVMPrinterPath: String?
    private var currentVMScreenShotsPath: String?
    private var currentVMConfigPath: String?
    private let nameTextFieldMaxLimit: Int = 32
    private let dragDropType = NSPasteboard.PasteboardType(rawValue: "private.table-row")
    // HTTP request default values
    private let httpHeaderAcceptValue = "application/vnd.github+json"
    private let httpHeaderContentTypeValue = "application/json; charset=utf-8"
    // 86Box emulator variables
    private var emulatorAppVer: String = "0"
    private var emulatorBuildVer: String = "0"
    private var emulatorOnlineVer: String = "0"
    // Version info
    var versionInfoObject = VersionInfoObject()
    private var numberOfUpdates: Int = 0
    
    // View did load
    override func viewDidLoad() {
        super.viewDidLoad()
        MainViewController.instance = self
        
        // Set delegates
        vmsTableView.delegate = self
        vmsTableView.dataSource = self
        vmNameTextField.delegate = self
        vmDescriptionTextView.delegate = self
        // Register table view for drag and drop
        vmsTableView.registerForDraggedTypes([dragDropType])
        
        // Config views
        configView()
        // Set MacBox home directory
        setHomeDir()
        // Initialize MacBox files
        initFiles()
        // Set screensaver & screen sleep preference
        setScreenSaver()
        // Check for 86Box version
        setEmulatorDefaultPath()
        setEmulatorUpdateChannel()
        checkFor86Box()
        checkForRoms()
    }
    
    // View will appear
    override func viewWillAppear() {
        // Remove fullscreen window button
        self.view.window?.styleMask.remove(.fullScreen)
        self.view.window?.styleMask.remove(.resizable)
        // Set the Start VM button dynamic width based on localized title
        let startVMWidth = startVMButton.frame.width + 14
        startVMButton.translatesAutoresizingMaskIntoConstraints = false
        startVMButton.widthAnchor.constraint(equalToConstant: startVMWidth).isActive = true
        // Set the app's appearance
        setAppearance()
    }
    
    // Set the app's appearance
    private func setAppearance() {
        if let appAppearance = userDefaults.string(forKey: "appAppearance") {
            switch appAppearance {
            case "aqua":
                NSApp.appearance = NSAppearance(named: .aqua)
            case "darkAqua":
                NSApp.appearance = NSAppearance(named: .darkAqua)
            default:
                break
            }
        }
    }
    
    // Set screensaver & screen sleep preference
    private func setScreenSaver() {
        let disableScreensaver = userDefaults.bool(forKey: "disableScreensaver")
        
        if disableScreensaver == true {
            screensaverManager.disableScreensaver()
        }
    }
    
    // Set 86Box default path
    private func setEmulatorDefaultPath() {
        if let defaultPath = userDefaults.string(forKey: "emulatorDefaultPath") {
            if defaultPath != "auto" {
                if #available(macOS 13.0, *) {
                    versionInfoObject.emulatorCustomUrl = URL(filePath: defaultPath)
                } else {
                    // Fallback on earlier versions
                    versionInfoObject.emulatorCustomUrl = URL(fileURLWithPath: defaultPath)
                }
            }
        }
    }
    
    // Set 86Box update channel
    private func setEmulatorUpdateChannel() {
        if let updateChannel = userDefaults.string(forKey: "emulatorUpdateChannel") {
            versionInfoObject.emulatorUpdateChannel = updateChannel
        }
    }
    
    // Config views initial properties
    private func configView() {
        spinningProgressIndicator.startAnimation(self)
        statusLabel.stringValue = ""
        statusCheckMarkImage.isHidden = true
        statusXMarkImage.isHidden = true
        statusExclamationMarkImage.isHidden = true
        statusArrowImage.isHidden = true
        statusButton.isEnabled = false
        resetVmInfoView()

        // Add right-click actions for table view cells
        let menu = NSMenu()
        menu.delegate = self
        vmsTableView.menu = menu
        
        // Add double click for table view cells
        vmsTableView.doubleAction = #selector(tableViewDoubleClickAction(_:))
    }

    // Resets VMInfoView to initial values
    private func resetVmInfoView() {
        startVMButton.isEnabled = false
        vmAppVersionPopUpButton.isEnabled = false
        vmSettingsButton.isEnabled = false
        deleteVMButton.isEnabled = false
        vmNameTextField.stringValue = "-"
        vmDescriptionTextView.string = ""

        // Specs text
        vmSpecMachine.stringValue = "-"
        vmSpecCPU.stringValue = "-"
        vmSpecRAM.stringValue = "-"
        vmSpecHDD.stringValue = "-"
        vmSpecMachineLogo.image = nil
    }
    
    // Set MacBox home directory path
    private func setHomeDir() {
        if let homeDirPath = userDefaults.string(forKey: "homeDirPath") {
            if #available(macOS 13.0, *) {
                homeDirURL = URL(filePath: homeDirPath)
            } else {
                // Fallback on earlier versions
                homeDirURL = URL(fileURLWithPath: homeDirPath)
            }
        }
    }

    // Initialize MacBox directory and config files
    private func initFiles() {
        // Create the MacBox directory at the User's Home directory
        do{
            try fileManager.createDirectory(atPath: homeDirURL.path, withIntermediateDirectories: true)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
        
        // Initialize the config file
        initConfigFile()
    }
    
    // Initialize MacBox config file
    private func initConfigFile() {
        var configFileURL = homeDirURL
        if #available(macOS 13.0, *) {
            configFileURL = configFileURL.appending(component: "Config")
        } else {
            // Fallback on earlier versions
            configFileURL = configFileURL.appendingPathComponent("Config")
        }
        if !fileManager.fileExists(atPath: configFileURL.path) {
            writeConfigFile()
        }
        else {
            readConfigFile()
        }
        
        // Restore last selected vm
        let lastSelectedVM = userDefaults.integer(forKey: "lastSelectedVM")
        if lastSelectedVM >= 0 && lastSelectedVM < vmList.count {
            let indexSet = IndexSet(integer: lastSelectedVM)
            vmsTableView.selectRowIndexes(indexSet, byExtendingSelection: false)
            vmsTableView.scrollRowToVisible(lastSelectedVM)
            selectTableRow(row: lastSelectedVM)
        }
    }
    
    // Write the MacBox config file
    private func writeConfigFile() {
        var configStr = ""
        let jsonEncoder = JSONEncoder()
        
        // Encode VM list as JSON data
        do{
            let jsonResultData = try jsonEncoder.encode(vmList)
            configStr = String(data: jsonResultData, encoding: .utf8) ?? ""
        } catch {
            print("Error: \(error.localizedDescription)")
        }
        
        // Write data to the Config file
        if #available(macOS 13.0, *) {
            let configFileURL = homeDirURL.appending(component: "Config")
            do {
                try configStr.write(to: configFileURL, atomically: true, encoding: .utf8)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        } else {
            // Fallback on earlier versions
            let configFileURL = homeDirURL.appendingPathComponent("Config")
            do {
                try configStr.write(to: configFileURL, atomically: true, encoding: .utf8)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    // Read from the MacBox config file
    private func readConfigFile() {
        var configFileURL: URL?
        if #available(macOS 13.0, *) {
            configFileURL = homeDirURL.appending(component: "Config")
        } else {
            // Fallback on earlier versions
            configFileURL = homeDirURL.appendingPathComponent("Config")
        }
        
        // Decode JSON data and add it to the vmList
        do {
            let jsonData = try Data(contentsOf: configFileURL ?? URL(fileURLWithPath: ""))
            let jsonDecoder = JSONDecoder()
            let vms = try jsonDecoder.decode([VM].self, from: jsonData)
            
            for vm in vms {
                addVM(vm: vm)
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
    
    // Update the config file for custom HomeDir path
    func updateConfigFile(previousLocation: URL, newLocation: URL) {
        for vm in vmList {
            guard let isValid = vm.path?.hasPrefix(previousLocation.path) else { return }
            if isValid {
                if let index = vmList.firstIndex(where: {$0.path == vm.path}) {
                    let newVMPath = vm.path?.replacingOccurrences(of: previousLocation.path, with: newLocation.path)
                    vmList[index].path = newVMPath
                    // Update config file
                    writeConfigFile()
                    // Update HomeDir URL
                    homeDirURL = newLocation
                }
            }
        }
        // Recheck for MacBox in-case it was moved with the home directory
        checkFor86Box(url: nil, appVer: nil, buildVer: nil, ignoreVersionCheck: true)
    }
    
    // Check if 86Box is installed, and check for updated version
    func checkFor86Box(url: URL? = nil, appVer: String? = nil, buildVer: String? = nil, ignoreVersionCheck: Bool = false) {
        var localUrl: URL?
        
        if let url = url {
            // Updated 86Box app url
            localUrl = url
            versionInfoObject.emulatorAutoUrl = url
            
            if let appVer = appVer {
                emulatorAppVer = appVer
            }
            
            if let buildVer = buildVer {
                emulatorBuildVer = buildVer
            }
        }
        else {
            // Check if 86Box app is installed
            if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "net.86Box.86Box") {
                // Save 86Box emulator URL
                versionInfoObject.emulatorAutoUrl = bundleURL
                localUrl = bundleURL
            }
            
            // Check if there's a custom 86Box path set
            if versionInfoObject.emulatorCustomUrl != nil {
                localUrl = versionInfoObject.emulatorCustomUrl
            }
            
            if let localUrl = localUrl, !ignoreVersionCheck {
                // Get 86Box info.plist
                if let bundle = Bundle(url: localUrl) {
                    // Get the 86Box short version
                    if let shortVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String {
                        emulatorAppVer = shortVersion
                    }
                    // Get the 86Box bundle version
                    if let bundleVersion = bundle.infoDictionary?["CFBundleVersion"] as? String {
                        emulatorBuildVer = String((bundleVersion).suffix(4))
                    }
                }
            }
        }
        
        fetchLatestOnlineBuildNumbers()
    }
    
    // Check all possible locations for 86Box ROMs
    func checkForRoms() {
        // Check location related to VMs
        for vm in vmList {
            if let vmPath = vm.path {
                let romsDirPath = vmPath + "/roms"
                var isDirectory : ObjCBool = false
                if fileManager.fileExists(atPath: romsDirPath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        // ROMs directory exists; Check if it's not empty
                        if fileManager.sizeOfDirectory(atPath: romsDirPath) != 0 {
                            versionInfoObject.romsUrls.append(URL(fileURLWithPath: romsDirPath))
                        }
                    }
                }
            }
        }
        
        // Check location related to 86Box
        if let emulatorAutoPath = versionInfoObject.emulatorAutoUrl?.relativePath {
            let romsDirPath = emulatorAutoPath + "/roms"
            var isDirectory : ObjCBool = false
            if fileManager.fileExists(atPath: romsDirPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // ROMs directory exists; Check if it's not empty
                    if fileManager.sizeOfDirectory(atPath: romsDirPath) != 0 {
                        versionInfoObject.romsUrls.append(URL(fileURLWithPath: romsDirPath))
                    }
                }
            }
        }
        
        if let emulatorCustomPath = versionInfoObject.emulatorCustomUrl?.relativePath {
            let romsDirPath = emulatorCustomPath + "/roms"
            var isDirectory : ObjCBool = false
            if fileManager.fileExists(atPath: romsDirPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // ROMs directory exists; Check if it's not empty
                    if fileManager.sizeOfDirectory(atPath: romsDirPath) != 0 {
                        versionInfoObject.romsUrls.append(URL(fileURLWithPath: romsDirPath))
                    }
                }
            }
        }
        
        // Check location related to system library
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: [.userDomainMask, .systemDomainMask])
        for dir in appSupportDir {
            let romsDirPath = dir.relativePath + "/net.86box.86Box/roms"
            var isDirectory : ObjCBool = false
            if fileManager.fileExists(atPath: romsDirPath, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // ROMs directory exists; Check if it's not empty
                    if fileManager.sizeOfDirectory(atPath: romsDirPath) != 0 {
                        versionInfoObject.romsUrls.append(URL(fileURLWithPath: romsDirPath))
                    }
                }
            }
        }
    }
    
    // Fetch the latest 86Box build version, ROMs and MacBox version
    private func fetchLatestOnlineBuildNumbers() {
        numberOfUpdates = 0
        
        // Check for internet connection
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "InternetConnectionMonitor")
        
        monitor.pathUpdateHandler = { pathUpdateHandler in
            if pathUpdateHandler.status == .satisfied {
                // Cancel the NWPathMonitor as it's not needed any longer
                monitor.cancel()
                
                // We're online, fetch 86Box build version from update channel
                if self.versionInfoObject.emulatorUpdateChannel == "stable" {
                    // Stable: from GitHub
                    self.fetchEmulatorUpdateInfoFromGitHub()
                }
                else {
                    // Experimental: from Jenkins
                    self.fetchEmulatorUpdateInfoFromJenkins()
                }
            }
            else {
                // We're offline, set status label to local version
                self.emulatorOnlineVer = "0"
                self.updateVersionStatus()
            }
        }
        
        monitor.start(queue: queue)
    }
    
    // Fetch 86Box update info from Jenkins
    private func fetchEmulatorUpdateInfoFromJenkins() {
        if let url = URL(string: "https://ci.86box.net/job/86Box/lastStableBuild/api/json") {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
                guard let data = data else { return }
                
                do {
                    // Try getting the 86Box update info from Jenkins
                    let jenkinsJsonResponse = try JSONDecoder().decode(JenkinsResponseObject.self, from: data)
                    self.versionInfoObject.emulatorUpdateObject = jenkinsJsonResponse.toGithubResponseObject()
                    
                    // Set status label
                    if let jenkinsBuildVer = jenkinsJsonResponse.number {
                        self.emulatorOnlineVer = String(jenkinsBuildVer)
                        // Compare Jenkins version with local version
                        if self.emulatorOnlineVer != self.emulatorBuildVer {
                            self.numberOfUpdates += 1
                        }
                    }
                    else {
                        self.emulatorOnlineVer = "0"
                    }
                    
                    // Check for latest 86Box ROMs
                    self.fetchEmulatorRomsUpdateInfo()
                } catch {
                    // Jenkins Connection error
                    print("Error: \(error.localizedDescription)")
                    // Set version to local
                    self.emulatorOnlineVer = self.emulatorBuildVer
                    // Check for latest 86Box ROMs
                    self.fetchEmulatorRomsUpdateInfo()
                }
            }
            task.resume()
        }
    }
    
    // Fetch 86Box update info from GitHub
    private func fetchEmulatorUpdateInfoFromGitHub() {
        if let url = URL(string: "https://api.github.com/repos/86Box/86Box/releases/latest") {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(httpHeaderAcceptValue, forHTTPHeaderField: "Accept")
            request.setValue(httpHeaderContentTypeValue, forHTTPHeaderField: "Content-Type")
            
            let task = URLSession.shared.dataTask(with: request) {(data, response, error) in
                guard let data = data else { return }
                
                do {
                    // Try getting the MacBox repo info from GitHub
                    let githubJsonResponse = try JSONDecoder().decode(GithubResponseObject.self, from: data)
                    self.versionInfoObject.emulatorUpdateObject = githubJsonResponse
                    
                    if let githubBuildVer = githubJsonResponse.tag_name {
                        if githubBuildVer.hasPrefix("v") {
                            self.emulatorOnlineVer = String(githubBuildVer.dropFirst())
                            // Compare Github version with local version
                            if self.emulatorOnlineVer != self.emulatorAppVer {
                                self.numberOfUpdates += 1
                            }
                        }
                        else {
                            self.emulatorOnlineVer = "0"
                        }
                    }
                    else {
                        self.emulatorOnlineVer = "0"
                    }
                    
                    // Check for latest 86Box ROMs
                    self.fetchEmulatorRomsUpdateInfo()
                } catch {
                    // Connection error
                    print("Error: \(error.localizedDescription)")
                }
            }
            task.resume()
        }
    }
    
    // Fetch 86Box ROMs update info from GitHub
    private func fetchEmulatorRomsUpdateInfo() {
        if let url = URL(string: "https://api.github.com/repos/86Box/roms/commits/master") {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(httpHeaderAcceptValue, forHTTPHeaderField: "Accept")
            request.setValue(httpHeaderContentTypeValue, forHTTPHeaderField: "Content-Type")
            
            let task = URLSession.shared.dataTask(with: request) {(data, response, error) in
                guard let data = data else { return }
                
                do {
                    // Try getting the 86Box ROMs repo info from GitHub
                    let githubJsonResponse = try JSONDecoder().decode(GithubResponseObject.self, from: data)
                    self.versionInfoObject.romsUpdateObject = githubJsonResponse
                    
                    // Compare versions
                    if let latestShaVersion = githubJsonResponse.sha {
                        if let localShaVersion = self.userDefaults.string(forKey: "romsShaVersion") {
                            if localShaVersion != String(latestShaVersion) {
                                // New version found
                                self.numberOfUpdates += 1
                            }
                        }
                        else {
                            // Enforce update when ROMs were not installed via MacBox
                            self.numberOfUpdates += 1
                        }
                    }
                    
                    // Check for latest MacBox github version
                    self.fetchMacBoxUpdateInfo()
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            }
            task.resume()
        }
    }
    
    // Fetch MacBox update info from GitHub
    private func fetchMacBoxUpdateInfo() {
        if let url = URL(string: "https://api.github.com/repos/Moonif/MacBox/releases/latest") {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(httpHeaderAcceptValue, forHTTPHeaderField: "Accept")
            request.setValue(httpHeaderContentTypeValue, forHTTPHeaderField: "Content-Type")
            
            let task = URLSession.shared.dataTask(with: request) {(data, response, error) in
                guard let data = data else { return }
                
                do {
                    // Try getting the MacBox repo info from GitHub
                    let githubJsonResponse = try JSONDecoder().decode(GithubResponseObject.self, from: data)
                    self.versionInfoObject.macboxUpdateObject = githubJsonResponse
                    
                    // Compare versions
                    if let latestTagVersion = githubJsonResponse.tag_name {
                        let localBuildVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? String(latestTagVersion)
                        
                        if localBuildVersion != String(latestTagVersion) {
                            // New version found
                            self.numberOfUpdates += 1
                        }
                    }
                    
                    // Update the version status
                    self.updateVersionStatus()
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            }
            task.resume()
        }
    }
    
    // Update the version status
    private func updateVersionStatus () {
        DispatchQueue.main.async {
            self.spinningProgressIndicator.stopAnimation(self)
            self.statusCheckMarkImage.isHidden = true
            self.statusXMarkImage.isHidden = true
            self.statusExclamationMarkImage.isHidden = true
            
            // Enable version manager when online
            if self.emulatorOnlineVer != "0" {
                self.statusArrowImage.isHidden = false
                self.statusButton.isEnabled = true
            }
            
            // Check for local build
            if self.emulatorBuildVer == ".0.0" {
                self.statusLabel.stringValue = String(format: NSLocalizedString("86Box v%@ (Local Build)", comment: ""), self.emulatorAppVer)
                return
            }
            
            // Set version status
            let updateString = self.numberOfUpdates == 1 ? NSLocalizedString("update", comment: "") : NSLocalizedString("updates", comment: "")
            if self.emulatorBuildVer != "0" {
                if self.emulatorOnlineVer != "0" && self.numberOfUpdates == 0 {
                    // 86Box is installed, we're online and there's no updates available
                    self.statusLabel.stringValue = String(format: NSLocalizedString("86Box v%@ (Build %@). Version status: up-to-date.", comment: ""), self.emulatorAppVer, self.emulatorBuildVer)
                    self.statusCheckMarkImage.isHidden = false
                }
                else if self.emulatorOnlineVer != "0" && self.numberOfUpdates > 0 {
                    // 86Box is installed, we're online and there's some updates available
                    self.statusLabel.stringValue = String(format: NSLocalizedString("86Box v%@ (Build %@). Version status: %d %@ available.", comment: ""), self.emulatorAppVer, self.emulatorBuildVer, self.numberOfUpdates, updateString)
                    self.statusExclamationMarkImage.isHidden = false
                }
                else {
                    // 86Box is installed, but we're offline
                    self.statusLabel.stringValue = String(format: NSLocalizedString("86Box v%@ (Build %@).", comment: ""), self.emulatorAppVer, self.emulatorBuildVer)
                }
            }
            else {
                // 86Box is not installed
                self.statusLabel.stringValue = NSLocalizedString("86Box is not installed.", comment: "")
                self.statusXMarkImage.isHidden = false
            }
            
            // Set status color to red when 86Box is not installed
            if self.versionInfoObject.emulatorAutoUrl == nil && self.versionInfoObject.emulatorCustomUrl == nil {
                self.statusLabel.textColor = .systemRed
            }
            else {
                self.statusLabel.textColor = .secondaryLabelColor
            }
        }
    }
    
    // Add VM to the table view
    func addVM(vm: VM, vmTemplate: VMTemplate? = nil) {
        // Make sure vm has a path
        var fixedVM = vm
        
        if vm.path == nil {
            var defaultPath = homeDirURL
            if #available(macOS 13.0, *) {
                defaultPath = homeDirURL.appending(component: "\(vm.name?.replacingOccurrences(of: "/", with: "") ?? "")")
            } else {
                // Fallback on earlier versions
                defaultPath = homeDirURL.appendingPathComponent("\(vm.name?.replacingOccurrences(of: "/", with: "")  ?? "")")
            }
            
            // Check if path was used before
            if fileManager.fileExists(atPath: defaultPath.path) {
                defaultPath = homeDirURL.appendingPathComponent(UUID().uuidString)
            }
            
            fixedVM.path = defaultPath.path
        }
        
        // Create all VM paths
        setAllVMPaths(vmPath: fixedVM.path ?? "")
        
        // Copy template config file
        if vmTemplate != nil, let templateConfigPath = vmTemplate?.configPath {
            let ini = IniParser()
            
            // Copy config file
            let vmConfigPath = fixedVM.path?.appending("/86box.cfg") ?? ""
            do{
                try fileManager.copyItem(atPath: templateConfigPath, toPath: vmConfigPath)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
            
            // Copy shader file
            if vmTemplate?.useShader == true {
                // Get VM template shader path
                if let templateInfoPath = vmTemplate?.infoPath {
                    if let vmShaderFileName = ini.parseConfig(templateInfoPath)["Shader"]?["video_gl_shader"] {
                        // Get the shader file from the main bundle
                        if let vmTemplateBundleShaderPath = Bundle.main.path(forResource: vmShaderFileName, ofType: nil, inDirectory: "Shaders") {
                            // Copy shader file to VM shaders directory
                            let vmShaderPath = fixedVM.path?.appending("/shaders/\(vmShaderFileName)") ?? ""
                            do{
                                try fileManager.copyItem(atPath: vmTemplateBundleShaderPath, toPath: vmShaderPath)
                            } catch {
                                print("Error: \(error.localizedDescription)")
                            }
                            // Get shader config
                            let vmShaderRenderer = ini.parseConfig(templateInfoPath)["Shader"]?["vid_renderer"] ?? ""
                            let vmShaderOverscan = ini.parseConfig(templateInfoPath)["Shader"]?["enable_overscan"] ?? "0"
                            let vmShaderCGAContrast = ini.parseConfig(templateInfoPath)["Shader"]?["vid_cga_contrast"] ?? "0"
                            // Write shader config
                            var vmConfigURL: URL?
                            if #available(macOS 13.0, *) {
                                vmConfigURL = URL(filePath: vmConfigPath)
                            } else {
                                // Fallback on earlier versions
                                vmConfigURL = URL(fileURLWithPath: vmConfigPath)
                            }
                            if let url = vmConfigURL {
                                // Read and create VM config file
                                var shaderConfigString = ""
                                do {
                                    try shaderConfigString = String(contentsOfFile: url.path, encoding: .utf8)
                                    shaderConfigString.append("\n[General]\nvid_renderer = \(vmShaderRenderer)\nvideo_gl_shader = \(vmShaderPath)\nenable_overscan = \(vmShaderOverscan)\nvid_cga_contrast = \(vmShaderCGAContrast)\n")
                                } catch {
                                    print("Error: \(error.localizedDescription)")
                                }
                                
                                // Write VM config file
                                if shaderConfigString != "" {
                                    do {
                                        try shaderConfigString.write(to: url, atomically: true, encoding: .utf8)
                                    } catch {
                                        print("Error: \(error.localizedDescription)")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // Create disk if available
            let hddParams = ini.parseConfig(templateConfigPath)["Hard disks"]?["hdd_01_parameters"] ?? ""
            let hddParamsSplit = hddParams.split(separator: ",")
            var hddS: Int64 = 0
            var hddH: Int64 = 0
            var hddC: Int64 = 0
            if hddParamsSplit.count > 0 {
                hddS = Int64(hddParamsSplit[0].trimmingCharacters(in: .whitespaces)) ?? 0
                hddH = Int64(hddParamsSplit[1].trimmingCharacters(in: .whitespaces)) ?? 0
                hddC = Int64(hddParamsSplit[2].trimmingCharacters(in: .whitespaces)) ?? 0
            }
            // Calculate hdd size
            let vmTemplateHDDSize = hddS * hddH * hddC * 512
            if vmTemplateHDDSize > 0 {
                let rawData = Data(count: Int(vmTemplateHDDSize))
                fileManager.createFile(atPath: fixedVM.path?.appending("/disks/hdd.IMG") ?? "", contents: rawData, attributes: nil)
            }
        }
        
        vmList.append(fixedVM)
        vmsTableView.reloadData()
        writeConfigFile()
        
        // Select last added VM
        let lastIndex = vmList.count - 1
        let indexSet = IndexSet(integer: lastIndex)
        vmsTableView.selectRowIndexes(indexSet, byExtendingSelection: false)
        vmsTableView.scrollRowToVisible(lastIndex)
        selectTableRow(row: lastIndex)
    }
    
    // Delete selected VM
    func deleteVM() {
        if currentSelectedVM != nil {
            // Show confirmation alert
            let alert = NSAlert()
            
            alert.messageText = NSLocalizedString("Do you want to remove the selected VM?", comment: "")
            alert.informativeText = NSLocalizedString("This will only remove it from MacBox. If you also want to remove the VM files, check the option below.", comment: "")
            alert.alertStyle = .critical
            alert.addButton(withTitle: NSLocalizedString("Remove", comment: "")).bezelColor = .controlAccentColor
            alert.addButton(withTitle: NSLocalizedString("Cancel", comment: ""))
            
            // Add delete option accessory view
            let deleteOptionButton = NSButton(checkboxWithTitle: NSLocalizedString("Send the selected VM and all its files to trash", comment: ""), target: nil, action: nil)
            alert.accessoryView = deleteOptionButton
            
            // Show the alert
            let alertResult = alert.runModal()
            
            // User pressed the Remove button
            if alertResult == .alertFirstButtonReturn {
                // Send vm files to trash
                if deleteOptionButton.state == .on {
                    if let vmPath = vmList[currentSelectedVM ?? 0].path {
                        // Check the VM config file for HDDs that are located outside the VM path
                        if let vmConfigPath = currentVMConfigPath {
                            let ini = IniParser()
                            // Iterate through the list of HDDs and send them to trash
                            if let hddPaths = ini.parseConfig(vmConfigPath)["Hard disks"] {
                                for hddPath in hddPaths {
                                    if hddPath.key.hasSuffix("_fn") {
                                        do {
                                            try fileManager.trashItem(at: URL(fileURLWithPath:hddPath.value), resultingItemURL: nil)
                                        } catch {
                                            print("Error: \(error.localizedDescription)")
                                        }
                                    }
                                }
                            }
                        }
                        do {
                            try fileManager.trashItem(at: URL(fileURLWithPath:vmPath), resultingItemURL: nil)
                        } catch {
                            print("Error: \(error.localizedDescription)")
                        }
                    }
                }
                
                // Remove vm from list
                vmList.remove(at: currentSelectedVM!)
                vmsTableView.reloadData()
                writeConfigFile()
            }
        }
    }
    
    // Copy the selected VM
    private func copyVM(row: Int) {
        let vmPathURL = URL(fileURLWithPath: vmList[row].path ?? "")
        
        // VM copy path
        var vmCopyPathURL = URL(string: "")
        let copyString: String = "(Copy)"
        
        if #available(macOS 13.0, *) {
            vmCopyPathURL = homeDirURL.appending(component: vmPathURL.lastPathComponent + copyString)
        } else {
            // Fallback on earlier versions
            vmCopyPathURL = homeDirURL.appendingPathComponent(vmPathURL.lastPathComponent + copyString)
        }
        
        if vmCopyPathURL != nil {
            // Check if path was used before
            if fileManager.fileExists(atPath: vmCopyPathURL?.path ?? "") {
                vmCopyPathURL = homeDirURL.appendingPathComponent(UUID().uuidString)
            }
            
            // Copy the VM folder
            do{
                try fileManager.copyItem(atPath: vmPathURL.path, toPath: vmCopyPathURL?.path ?? "")
                
                // Create the VM copy
                var vm = VM()
                
                // Set VM properties
                vm.name = (vmList[row].name ?? "") + copyString
                vm.description = vmList[row].description
                vm.path = vmCopyPathURL?.path
                vm.logo = vmList[row].logo
                vm.appPath = vmList[row].appPath
                // Add the VM
                addVM(vm: vm)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    // Start VM process
    private func startVM(launchSettings: Bool = false) {
        if currentSelectedVM != nil {
            let process = Process()
            
            let vmName = (vmList[currentSelectedVM ?? 0]).name ?? "86Box - MacBoxVM"
            // Set default path for new VMs
            var defaultPath = homeDirURL
            if #available(macOS 13.0, *) {
                defaultPath = homeDirURL.appending(component: "/\(vmName)")
            } else {
                // Fallback on earlier versions
                defaultPath = homeDirURL.appendingPathComponent("/\(vmName)")
            }
            let vmPath = (vmList[currentSelectedVM ?? 0]).path ?? defaultPath.path
            
            // Selected app version
            var vmAppVersion = "net.86Box.86Box"
            var vmAppArg = "-b"
            
            // Set the emulator path if we already have it
            if let emulatorCustomPath = versionInfoObject.emulatorCustomUrl?.path {
                vmAppVersion = emulatorCustomPath
                vmAppArg = "-a"
            }
            else if let emulatorAutoPath = versionInfoObject.emulatorAutoUrl?.path {
                vmAppVersion = emulatorAutoPath
                vmAppArg = "-a"
            }
            
            if let customAppPath = vmList[currentSelectedVM ?? 0].appPath {
                if fileManager.fileExists(atPath: customAppPath) {
                    vmAppVersion = customAppPath
                    vmAppArg = "-a"
                }
                else {
                    // Custom app version was not found (Probably got moved or deleted)
                    let alert = NSAlert()
                    
                    alert.messageText = NSLocalizedString("Selected 86Box file is not found. VM will open using default version.", comment: "")
                    alert.alertStyle = .critical
                    
                    alert.runModal()
                }
            }
            
            // Check fullscreen option
            let vmFullScreen = vmList[currentSelectedVM ?? 0].fullScreen ?? false
            
            // Set process arguments
            let argsString: String = "--args"
            let args:[String] = launchSettings ?
            ["-W", vmAppArg,vmAppVersion,argsString,"-P","\(vmPath)","-S"] :
            vmFullScreen ?
            ["-n", "-W", vmAppArg,vmAppVersion,argsString,"-P","\(vmPath)","-V",vmName, "-F"] :
            ["-n", "-W", vmAppArg,vmAppVersion,argsString,"-P","\(vmPath)","-V",vmName]
            process.arguments = args
            
            process.executableURL = URL(fileURLWithPath:"/usr/bin/open")

            // Run the process
            do{
                try process.run()
                // Process is running
                if !launchSettings && currentSelectedVM != nil {
                    let vmProcess = RunningVMProcess(vmProcessID: process.processIdentifier, vmRowNumber: currentSelectedVM ?? 0)
                    currentRunningVM.append(vmProcess)
                }
                let lastSelectedRow = currentSelectedVM
                vmsTableView.reloadData()
                
                // Re-select previously selected row
                reselectTableRow(row: lastSelectedRow)
                
                // Wait for process to end
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { (timer) in
                    if !process.isRunning {
                        // Process is terminated, invalidate timer
                        timer.invalidate()
                        
                        // Clear current running vm
                        self.currentRunningVM.removeAll(where:{ $0.vmProcessID == process.processIdentifier })
                        
                        self.vmsTableView.reloadData()
                        
                        // Re-select previously selected row
                        self.reselectTableRow(row: lastSelectedRow)
                    }
                }
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    // Select table row and populate vm info
    private func selectTableRow(row: Int) {
        currentSelectedVM = row
        startVMButton.isEnabled = true
        vmAppVersionPopUpButton.isEnabled = true
        vmSettingsButton.isEnabled = true
        deleteVMButton.isEnabled = true
        
        // VM properties
        let vmName = vmList[row].name ?? "86Box - MacBoxVM"
        let vmDescription = vmList[row].description ?? ""
        let vmPath = vmList[row].path ?? ""
        currentVMPrinterPath = vmPath.appending("/printer")
        currentVMScreenShotsPath = vmPath.appending("/screenshots")
        currentVMConfigPath = vmPath.appending("/86box.cfg")
        
        // Set VM name and description text
        vmNameTextField.stringValue = vmName
        vmDescriptionTextView.string = vmDescription
        
        // Set VM specs
        setVMSpecs()
        
        // Check for custom app path
        if vmList[row].appPath != nil {
            vmAppVersionPopUpButton.selectItem(at: 1)
        }
        else {
            vmAppVersionPopUpButton.selectItem(at: 0)
        }
        setPopupOptionsMultiselection()
        
        // Set user defaults
        DispatchQueue.main.async {
            self.userDefaults.set(row, forKey: "lastSelectedVM")
        }
    }
    
    // Re-select previously selected row
    private func reselectTableRow(row: Int?) {
        let indexSet = IndexSet(integer: row ?? 0)
        
        vmsTableView.selectRowIndexes(indexSet, byExtendingSelection: false)
        vmsTableView.scrollRowToVisible(row ?? 0)
        selectTableRow(row: row ?? 0)
    }
    
    // Tableview cell 'Show in Finder' action
    @objc private func tableViewFindInFinderAction(_ sender: AnyObject) {
        if vmsTableView.clickedRow >= 0 {
            let vmPathURL = URL(fileURLWithPath: vmList[vmsTableView.clickedRow].path ?? "")
            NSWorkspace.shared.open(vmPathURL)
        }
    }
    
    // Tableview cell 'Duplicate' action
    @objc private func tableViewDuplicateAction(_ sender: AnyObject) {
        if vmsTableView.clickedRow >= 0 {
            copyVM(row: vmsTableView.clickedRow)
        }
    }
    
    // Tableview cell double click action
    @objc private func tableViewDoubleClickAction(_ sender: AnyObject) {
        if vmsTableView.clickedRow >= 0 {
            startVM()
        }
    }
    
    // Set all VM paths
    private func setAllVMPaths(vmPath: String) {
        let printerPath = vmPath.appending("/printer")
        let screenshotsPath = vmPath.appending("/screenshots")
        let diskPath = vmPath.appending("/disks")
        let shaderPath = vmPath.appending("/shaders")
        
        // Create printer folder if it doesn't already exist
        if !fileManager.fileExists(atPath: printerPath) {
            do {
                try fileManager.createDirectory(atPath: printerPath, withIntermediateDirectories: true)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
        
        // Create screenshots folder if it doesn't already exist
        if !fileManager.fileExists(atPath: screenshotsPath) {
            do {
                try fileManager.createDirectory(atPath: screenshotsPath, withIntermediateDirectories: true)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
        
        // Create disk folder if it doesn't already exist
        if !fileManager.fileExists(atPath: diskPath) {
            do {
                try fileManager.createDirectory(atPath: diskPath, withIntermediateDirectories: true)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
        
        // Create shader folder if it doesn't already exist
        if !fileManager.fileExists(atPath: shaderPath) {
            do {
                try fileManager.createDirectory(atPath: shaderPath, withIntermediateDirectories: true)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    // Set current VM specs
    private func setVMSpecs() {
        if currentVMConfigPath != nil {
            if fileManager.fileExists(atPath: currentVMConfigPath ?? "") {
                // Parse config file and return string values
                let specsParser = SpecsParser()
                let parsedSpecs = specsParser.parseVMConfigFile(vmConfigPath: currentVMConfigPath ?? "")
                // Set specs strings
                vmSpecMachine.stringValue = parsedSpecs.machine
                vmSpecCPU.stringValue = parsedSpecs.cpu
                vmSpecRAM.stringValue = parsedSpecs.ram
                vmSpecHDD.stringValue = parsedSpecs.hdd
                
                // Define machine logo
                if let machineLogo = vmList[currentSelectedVM ?? 0].logo {
                    vmSpecMachineLogo.image = NSImage(named: machineLogo)
                }
                else {
                    // Check for used machine name and set a logo by default
                    switch vmSpecMachine.stringValue {
                    case _ where vmSpecMachine.stringValue.hasPrefix("IBM"):
                        vmSpecMachineLogo.image = NSImage(named: "IBM_logo")
                    case _ where vmSpecMachine.stringValue.hasPrefix("Compaq"):
                        vmSpecMachineLogo.image = NSImage(named: "Compaq_logo")
                    case _ where vmSpecMachine.stringValue.hasPrefix("Amstrad"):
                        vmSpecMachineLogo.image = NSImage(named: "Amstrad_logo")
                    case _ where vmSpecMachine.stringValue.hasPrefix("Commodore"):
                        vmSpecMachineLogo.image = NSImage(named: "Commodore_logo")
                    case _ where vmSpecMachine.stringValue.hasPrefix("Epson"):
                        vmSpecMachineLogo.image = NSImage(named: "Epson_logo")
                    case _ where vmSpecMachine.stringValue.hasPrefix("NEC"):
                        vmSpecMachineLogo.image = NSImage(named: "NEC_logo")
                    case _ where vmSpecMachine.stringValue.hasPrefix("Packard Bell"):
                        vmSpecMachineLogo.image = NSImage(named: "Pb_logo")
                    case _ where vmSpecMachine.stringValue.hasPrefix("Tandy"):
                        vmSpecMachineLogo.image = NSImage(named: "Tandy_logo")
                    default:
                        // No machine logo
                        vmSpecMachineLogo.image = nil
                    }
                }
            }
            else {
                vmSpecMachine.stringValue = "-"
                vmSpecCPU.stringValue = "-"
                vmSpecRAM.stringValue = "-"
                vmSpecHDD.stringValue = "-"
                vmSpecMachineLogo.image = nil
            }
        }
    }
    
    // Set the Start button popup options multiselection
    private func setPopupOptionsMultiselection() {
        if let selectedVM = currentSelectedVM {
            if vmList[selectedVM].appPath == nil {
                vmAppVersionPopUpButton.selectItem(at: 0)
            }
            else {
                vmAppVersionPopUpButton.selectItem(at: 1)
            }
            
            if vmList[selectedVM].fullScreen != nil && vmList[selectedVM].fullScreen! {
                vmAppVersionPopUpButton.itemArray[3].state = .on
            }
            else {
                vmAppVersionPopUpButton.itemArray[3].state = .off
            }
        }
    }
    
// ------------------------------------
// IBActions
// ------------------------------------
    
    // Start VM button action
    @IBAction func startVMButtonAction(_ sender: NSButton) {
        startVM()
    }
    
    // VM settings button action
    @IBAction func vmSettingsButtonAction(_ sender: NSButton) {
        startVM(launchSettings: true)
    }
    
    // Delete VM button action
    @IBAction func deleteVMButtonAction(_ sender: NSButton) {
        deleteVM()
    }
    
    // Add VM toolbar button action
    @IBAction func addVMButtonAction(_ sender: Any) {
        if let addVMTabViewVC = self.storyboard?.instantiateController(withIdentifier: "AddVMVC") as? NSTabViewController {
            self.presentAsModalWindow(addVMTabViewVC)
        }
        
        // Deselect the toolbar button after action
        if let senderButton = sender as? NSToolbarItem {
            senderButton.toolbar?.selectedItemIdentifier = nil
        }
    }
    
    // Print tray toolbar button action
    @IBAction func printTrayButtonAction(_ sender: Any) {
        if currentVMPrinterPath != nil {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: String(currentVMPrinterPath ?? ""))
        }
        
        // Deselect the toolbar button after action
        if let senderButton = sender as? NSToolbarItem {
            senderButton.toolbar?.selectedItemIdentifier = nil
        }
    }
    
    // Screenshots toolbar button action
    @IBAction func screenshotsButtonAction(_ sender: Any) {
        if currentVMScreenShotsPath != nil {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: String(currentVMScreenShotsPath ?? ""))
        }
        
        // Deselect the toolbar button after action
        if let senderButton = sender as? NSToolbarItem {
            senderButton.toolbar?.selectedItemIdentifier = nil
        }
    }
    
    // Settings button action
    @IBAction func showSettingsWindow(_ sender: Any?) {
        self.performSegue(withIdentifier: "showSettingsVC", sender: sender)
    }
    
    // Open the Jenkins url
    @IBAction func versionStatusButtonAction(_ sender: NSButton) {
        self.performSegue(withIdentifier: "showVersionManagerVC", sender: sender)
    }
    
    // Select 86Box version for the selected vm
    @IBAction func vmAppVersionPopUpButtonAction(_ sender: NSPopUpButton) {
        if sender.selectedItem?.identifier == NSUserInterfaceItemIdentifier(rawValue: "defaultAppId") {
            if let selectedVM = currentSelectedVM {
                // Default is nil: uses app bundle identifier
                vmList[selectedVM].appPath = nil
                // Update config file
                writeConfigFile()
            }
        }
        else if sender.selectedItem?.identifier == NSUserInterfaceItemIdentifier(rawValue: "customAppId") {
            // Open the file picker
            let filePickerPanel = NSOpenPanel()
            
            filePickerPanel.allowsMultipleSelection = false
            filePickerPanel.canChooseDirectories = false
            filePickerPanel.canChooseFiles = true
            filePickerPanel.allowedFileTypes = ["app"]
            
            if filePickerPanel.runModal() == .OK {
                if let appURL = filePickerPanel.url {
                    if let selectedVM = currentSelectedVM {
                        // Set custom app path
                        vmList[selectedVM].appPath = appURL.path
                        // Update config file
                        writeConfigFile()
                    }
                }
            }
            else {
                // Reset selection
                if let selectedVM = currentSelectedVM {
                    if vmList[selectedVM].appPath == nil {
                        vmAppVersionPopUpButton.selectItem(at: 0)
                    }
                }
            }
        }
        else {
            // Set start in full screen option
            if let selectedVM = currentSelectedVM {
                vmList[selectedVM].fullScreen = !(vmList[selectedVM].fullScreen ?? false);
                // Update config file
                writeConfigFile()
            }
        }
        
        // Set popup options multiselection
        setPopupOptionsMultiselection()
    }
    
// ------------------------------------
// Segue handling
// ------------------------------------
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == "showVersionManagerVC" {
            // Version Manager
            if let versionManagerVC = segue.destinationController as? VersionManagerViewController {
                versionManagerVC.emulatorAppVer = emulatorAppVer
                versionManagerVC.emulatorBuildVer = emulatorBuildVer
                
                if versionInfoObject.emulatorUpdateChannel == "stable" {
                    versionManagerVC.isStableChannel = true
                }
            }
        }
    }
}

// ------------------------------------
// VM TableView Delegate and Datasource
// ------------------------------------
extension MainViewController: NSTableViewDelegate, NSTableViewDataSource {
    
    // Return number of cells for vm table view
    func numberOfRows(in tableView: NSTableView) -> Int {
        return vmList.count
    }
    
    // Populate cells based on vmList data
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let vmObject = vmList[row]
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "textCellID"), owner: self) as? NSTableCellView
        cell?.textField?.stringValue = vmObject.name ?? "No Name"
        if let imageView = cell?.subviews.first as? NSImageView {
            if currentRunningVM.contains(where: { $0.vmRowNumber == row }) {
                imageView.image = NSImage(named: "pcon")
            }
            else {
                imageView.image = NSImage(named: "pc")
            }
        }
        return cell
    }
    
    // Handle cells selection
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        selectTableRow(row: row)
        
        return true
    }
    
    // Set drag and drop for table cells
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let indexSet = IndexSet(integer: row)
        vmsTableView.selectRowIndexes(indexSet, byExtendingSelection: false)
        selectTableRow(row: row)
        
        let item = NSPasteboardItem()
        item.setString(String(row), forType: self.dragDropType)
        return item
    }
    
    // Validate drag and drop behavior
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .above {
            return .move
        }
        return []
    }
    
    // Handle post drag and drop behavior
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        var oldIndexes = [Int]()
        info.enumerateDraggingItems(options: [], for: tableView, classes: [NSPasteboardItem.self], searchOptions: [:]) { dragItem, _, _ in
            if let str = (dragItem.item as! NSPasteboardItem).string(forType: self.dragDropType), let index = Int(str) {
                oldIndexes.append(index)
            }
        }
        
        var oldIndexOffset = 0
        var newIndexOffset = 0
        
        // Update table view cells and vmlist data
        tableView.beginUpdates()
        for oldIndex in oldIndexes {
            if oldIndex < row {
                // Re-arrange vmList
                let vm = vmList.remove(at: oldIndex + oldIndexOffset)
                vmList.insert(vm, at: row - 1)
                // Move and animate table view cell
                tableView.moveRow(at: oldIndex + oldIndexOffset, to: row - 1)
                currentSelectedVM = row - 1
                oldIndexOffset -= 1
            }
            else {
                // Re-arrange vmList
                let vm = vmList.remove(at: oldIndex)
                vmList.insert(vm, at: row + newIndexOffset)
                // Move and animate table view cell
                tableView.moveRow(at: oldIndex, to: row + newIndexOffset)
                currentSelectedVM = row + newIndexOffset
                newIndexOffset += 1
            }
        }
        tableView.endUpdates()
        
        // Update config file
        writeConfigFile()
        
        return true
    }
    
    // Disable events for table view
    func tableView(_ tableView: NSTableView, shouldTypeSelectFor event: NSEvent, withCurrentSearch searchString: String?) -> Bool {
        return false
    }

    // Handle row deletions
    func tableView(_ tableView: NSTableView, didRemove rowView: NSTableRowView, forRow row: Int) {
        if tableView.numberOfRows > 0 {
            currentSelectedVM = tableView.selectedRow
        } else {
            currentSelectedVM = nil
            resetVmInfoView()
        }
    }
}

// ------------------------------------
// TextField Delegate
// ------------------------------------
extension MainViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            // Limit name text field max number of characters
            if textField.stringValue.count > nameTextFieldMaxLimit && textField.identifier == NSUserInterfaceItemIdentifier(rawValue: "vmNameID") {
                textField.stringValue = String(textField.stringValue.dropLast())
            }
        }
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            if textField.identifier == NSUserInterfaceItemIdentifier(rawValue: "vmNameID") {
                if currentSelectedVM != nil {
                    // Update VM name
                    vmList[currentSelectedVM!].name = textField.stringValue
                    writeConfigFile()
                    // Save current selected row
                    let lastSelectedRow = currentSelectedVM
                    // Reload table data
                    vmsTableView.reloadData()
                    // Re-select previously selected row
                    reselectTableRow(row: lastSelectedRow)
                }
            }
        }
    }
}

// ------------------------------------
// TextView Delegate
// ------------------------------------
extension MainViewController: NSTextViewDelegate {
    func textDidEndEditing(_ notification: Notification) {
        if let textView = notification.object as? NSTextView {
            if textView.identifier == NSUserInterfaceItemIdentifier(rawValue: "vmDescriptionID") {
                if currentSelectedVM != nil {
                    // Update VM description
                    vmList[currentSelectedVM!].description = textView.string
                    writeConfigFile()
                }
            }
        }
    }
}

// ------------------------------------
// Table Menu Delegate
// ------------------------------------
extension MainViewController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        
        if vmsTableView.clickedRow >= 0 {
            // Right-Clicked on a VM cell
            menu.addItem(NSMenuItem(title: NSLocalizedString("Show in Finder", comment: ""), action: #selector(tableViewFindInFinderAction(_:)), keyEquivalent: ""))
            menu.addItem(.separator())
            menu.addItem(NSMenuItem(title: NSLocalizedString("Duplicate", comment: ""), action: #selector(tableViewDuplicateAction(_:)), keyEquivalent: ""))
        }
        else {
            // Right-Clicked on an empty cell
            menu.addItem(NSMenuItem(title: NSLocalizedString("Add a Virtual Machine", comment: ""), action: #selector(addVMButtonAction(_:)), keyEquivalent: ""))
        }
    }
}
