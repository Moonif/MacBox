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
    @IBOutlet weak var vmNameTextField: NSTextField!
    @IBOutlet var vmDescriptionTextView: NSTextView!
    
    @IBOutlet weak var vmSpecMachine: NSTextField!
    @IBOutlet weak var vmSpecCPU: NSTextField!
    @IBOutlet weak var vmSpecRAM: NSTextField!
    @IBOutlet weak var vmSpecHDD: NSTextField!
    @IBOutlet weak var vmSpecMachineLogo: NSImageView!
    
    // Variables
    private let userDefaults = UserDefaults.standard
    private let homeDirURL = URL(fileURLWithPath: "MacBox", isDirectory: true, relativeTo: FileManager.default.homeDirectoryForCurrentUser)
    private var emulatorUrl : URL?
    var vmList: [VM] = []
    private var currentSelectedVM: Int?
    private var currentRunningVM: [RunningVMProcess] = []
    private var currentVMPrinterPath: String?
    private var currentVMScreenShotsPath: String?
    private var currentVMConfigPath: String?
    private let nameTextFieldMaxLimit: Int = 32
    private var dragDropType = NSPasteboard.PasteboardType(rawValue: "private.table-row")
    
    // View did load
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set delegates
        vmsTableView.delegate = self
        vmsTableView.dataSource = self
        vmNameTextField.delegate = self
        vmDescriptionTextView.delegate = self
        // Register table view for drag and drop
        vmsTableView.registerForDraggedTypes(([dragDropType]))
        
        // Config views
        configView()
        // Initialize MacBox files
        initFiles()
        // Check for 86Box version
        checkFor86Box()
    }
    
    // View will appear
    override func viewWillAppear() {
        // Remove fullscreen window button
        self.view.window?.styleMask.remove(.fullScreen)
        self.view.window?.styleMask.remove(.resizable)
    }
    
    // Config views initial properties
    private func configView() {
        startVMButton.isEnabled = false
        vmSettingsButton.isEnabled = false
        deleteVMButton.isEnabled = false
        spinningProgressIndicator.startAnimation(self)
        statusLabel.stringValue = ""
        
        // Specs text
        vmSpecMachine.stringValue = "-"
        vmSpecCPU.stringValue = "-"
        vmSpecRAM.stringValue = "-"
        vmSpecHDD.stringValue = "-"
        vmSpecMachineLogo.image = nil
        
        // Add show in finder for table view cells
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show in Finder", action: #selector(tableViewFindInFinderAction(_:)), keyEquivalent: ""))
        vmsTableView.menu = menu
        
        // Add double click for table view cells
        vmsTableView.doubleAction = #selector(tableViewDoubleClickAction(_:))
    }
    
    // Initialize MacBox directory and config files
    private func initFiles() {
        // Create the MacBox directory at the User's Home directory
        do{
            try FileManager.default.createDirectory(atPath: homeDirURL.path, withIntermediateDirectories: true)
        } catch {
            print("Error: \(error.localizedDescription)")
        }
        
        // Initialize the config file
        initConfigFile()
    }
    
    // Initialize MacBox config file
    private func initConfigFile() {
        if #available(macOS 13.0, *) {
            let configFileURL = homeDirURL.appending(component: "Config")
            if !FileManager.default.fileExists(atPath: configFileURL.path) {
                writeConfigFile()
            }
            else {
                readConfigFile()
            }
        } else {
            // Fallback on earlier versions
            let configFileURL = homeDirURL.appendingPathComponent("Config")
            if !FileManager.default.fileExists(atPath: configFileURL.path) {
                writeConfigFile()
            }
            else {
                readConfigFile()
            }
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
    
    // Check if 86Box is installed, and check for updated version
    private func checkFor86Box() {
        // Check if 86Box app is installed
        var buildVer = "0"
        if let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "net.86Box.86Box") {
            // Save 86Box emulator URL
            emulatorUrl = bundleURL
            // Get 86Box info.plist
            if let bundle = Bundle(url: bundleURL) {
                // Get the 86Box bundle version
                if let bundleVersion = bundle.infoDictionary?["CFBundleVersion"] as? String {
                    // Return only the build version
                    buildVer = String((bundleVersion).suffix(4))
                }
            }
        }
        
        fetch86BoxLatestBuildNumber(ver: buildVer)
    }
    
    // Fetch the latest stable 86Box build version from Jenkins
    private func fetch86BoxLatestBuildNumber (ver: String) {
        // Check for internet connection
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "InternetConnectionMonitor")
        
        monitor.pathUpdateHandler = { pathUpdateHandler in
            if pathUpdateHandler.status == .satisfied {
                // We're online, fetch build version from Jenkins
                if let url = URL(string: "https://ci.86box.net/job/86Box/lastStableBuild/buildNumber") {
                    let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
                        guard let data = data else { return }
                        // Set status label
                        if let jenkinsBuildVer = String(data: data, encoding: .utf8) {
                            self.setVersionStatusLabel(localVer: ver, onlineVer: jenkinsBuildVer)
                        }
                        else {
                            self.setVersionStatusLabel(localVer: ver, onlineVer: "0")
                        }
                    }
                    task.resume()
                }
            }
            else {
                // We're offline, set status label to local version
                self.setVersionStatusLabel(localVer: ver, onlineVer: "0")
            }
        }
        
        monitor.start(queue: queue)
    }
    
    // Set the 86Box version status label
    private func setVersionStatusLabel (localVer: String, onlineVer: String) {
        DispatchQueue.main.async {
            self.spinningProgressIndicator.stopAnimation(self)
            
            // Compare Jenkins version with local version
            if onlineVer != localVer {
                // Version mismatch
                self.statusLabel.stringValue = localVer != "0" ? onlineVer != "0" ?
                "🟠 86Box (build \(localVer)) is installed. New update is available (build \(onlineVer))." :
                "🟢 86Box (build \(localVer)) is installed." :
                "🔴 86Box is not installed."
            }
            else {
                // Version match
                self.statusLabel.stringValue = localVer != "0" ? onlineVer != "0" ?
                "🟢 86Box (build \(localVer)) is installed and up-to-date." :
                "🟢 86Box (build \(localVer)) is installed." :
                "🔴 86Box is not installed."
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
            fixedVM.path = defaultPath.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)
        }
        
        // Create all VM paths
        setAllVMPaths(vmPath: fixedVM.path ?? "")
        
        // Copy template config file
        if vmTemplate != nil {
            if let templateConfigPath = vmTemplate?.configPath {
                let ini = IniParser()
                
                // Copy config file
                let vmConfigPath = fixedVM.path?.appending("/86box.cfg") ?? ""
                do{
                    try FileManager.default.copyItem(atPath: templateConfigPath, toPath: vmConfigPath)
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
                                    try FileManager.default.copyItem(atPath: vmTemplateBundleShaderPath, toPath: vmShaderPath)
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
                    FileManager.default.createFile(atPath: fixedVM.path?.appending("/disks/hdd.IMG") ?? "", contents: rawData, attributes: nil)
                }
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
            
            alert.messageText = "Do you want to delete the selected VM?"
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Delete").bezelColor = .controlAccentColor
            alert.addButton(withTitle: "Cancel")
            
            let alertResult = alert.runModal()
            if alertResult == .alertFirstButtonReturn {
                // User pressed the Delete button
                vmList.remove(at: currentSelectedVM!)
                vmsTableView.reloadData()
                writeConfigFile()
                
                if vmList.count > 0 {
                    currentSelectedVM = vmsTableView.selectedRow
                }
                else {
                    currentSelectedVM = nil
                    startVMButton.isEnabled = false
                    vmSettingsButton.isEnabled = false
                    deleteVMButton.isEnabled = false
                }
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
            if let customAppPath = vmList[currentSelectedVM ?? 0].appPath {
                vmAppVersion = customAppPath
                vmAppArg = "-a"
            }
            
            // Set process arguments
            let args:[String] = launchSettings ?
            ["-W", vmAppArg,vmAppVersion,"--args","-P","\(vmPath)","-S"] :
            ["-n", "-W", vmAppArg,vmAppVersion,"--args","-P","\(vmPath)","-V",vmName]
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
        if !FileManager.default.fileExists(atPath: printerPath) {
            do {
                try FileManager.default.createDirectory(atPath: printerPath, withIntermediateDirectories: true)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
        
        // Create screenshots folder if it doesn't already exist
        if !FileManager.default.fileExists(atPath: screenshotsPath) {
            do {
                try FileManager.default.createDirectory(atPath: screenshotsPath, withIntermediateDirectories: true)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
        
        // Create disk folder if it doesn't already exist
        if !FileManager.default.fileExists(atPath: diskPath) {
            do {
                try FileManager.default.createDirectory(atPath: diskPath, withIntermediateDirectories: true)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
        
        // Create shader folder if it doesn't already exist
        if !FileManager.default.fileExists(atPath: shaderPath) {
            do {
                try FileManager.default.createDirectory(atPath: shaderPath, withIntermediateDirectories: true)
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
    }
    
    // Set current VM specs
    private func setVMSpecs() {
        if currentVMConfigPath != nil {
            if FileManager.default.fileExists(atPath: currentVMConfigPath ?? "") {
                // Parse config file and return string values
                let specsParser = SpecsParser()
                let parsedSpecs = specsParser.ParseVMConfigFile(vmConfigPath: currentVMConfigPath ?? "")
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
                    vmSpecMachineLogo.image = nil
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
            for tabViewVC in addVMTabViewVC.tabViewItems {
                if let addVMVC = tabViewVC.viewController as? AddVMViewController {
                    addVMVC.mainVC = self
                }
                else if let importVMVC = tabViewVC.viewController as? ImportVMViewController {
                    importVMVC.mainVC = self
                }
            }
            self.presentAsModalWindow(addVMTabViewVC)
        }
    }
    
    // Print tray toolbar button action
    @IBAction func printTrayButtonAction(_ sender: Any) {
        if currentVMPrinterPath != nil {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: String(currentVMPrinterPath ?? ""))
        }
    }
    
    @IBAction func screenshotsButtonAction(_ sender: Any) {
        if currentVMScreenShotsPath != nil {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: String(currentVMScreenShotsPath ?? ""))
        }
    }
    
    // Open the Jenkins url
    @IBAction func versionStatusButtonAction(_ sender: NSButton) {
        if let url = URL(string: "https://ci.86box.net/job/86Box/") {
            NSWorkspace.shared.open(url)
        }
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
        else {
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
                oldIndexOffset -= 1
            }
            else {
                // Re-arrange vmList
                let vm = vmList.remove(at: oldIndex)
                vmList.insert(vm, at: row + newIndexOffset)
                // Move and animate table view cell
                tableView.moveRow(at: oldIndex, to: row + newIndexOffset)
                newIndexOffset += 1
            }
        }
        tableView.endUpdates()
        
        // Update config file
        writeConfigFile()
        
        return true
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
