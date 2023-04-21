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
    @IBOutlet weak var deleteVMButton: NSButton!
    @IBOutlet weak var spinningProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var vmNameTextField: NSTextField!
    @IBOutlet var vmDescriptionTextView: NSTextView!
    
    @IBOutlet weak var vmSpecMachine: NSTextField!
    @IBOutlet weak var vmSpecCPU: NSTextField!
    @IBOutlet weak var vmSpecRAM: NSTextField!
    @IBOutlet weak var vmSpecHDD: NSTextField!
    
    // Variables
    private let userDefaults = UserDefaults.standard
    private let homeDirURL = URL(fileURLWithPath: "MacBox", isDirectory: true, relativeTo: FileManager.default.homeDirectoryForCurrentUser)
    private var emulatorUrl : URL?
    var vmList: [VM] = []
    private var currentSelectedVM: Int?
    private var currentRunningVM: Int?
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
        
        // Add show in finder for table view cells
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show in Finder", action: #selector(tableViewFindInFinderAction(_:)), keyEquivalent: ""))
        vmsTableView.menu = menu
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
        if lastSelectedVM > 0 && lastSelectedVM < vmList.count {
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
    func addVM(vm: VM, vmTemplateConfigPath: String? = nil) {
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
        
        // Copy template config file
        if vmTemplateConfigPath != nil {
            do{
                try FileManager.default.copyItem(atPath: vmTemplateConfigPath ?? "", toPath: fixedVM.path?.appending("/86box.cfg") ?? "")
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
        
        vmList.append(fixedVM)
        vmsTableView.reloadData()
        writeConfigFile()
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
            // Set process arguments
            let args:[String] = launchSettings ?
            ["-W", "-b","net.86Box.86Box","--args","-P","\(vmPath)","-S"] :
            ["-W", "-b","net.86Box.86Box","--args","-P","\(vmPath)","-V",vmName]
            process.arguments = args
            
            process.executableURL = URL(fileURLWithPath:"/usr/bin/open")

            // Run the process
            do{
                try process.run()
                // Process is running
                currentRunningVM = launchSettings ? nil : currentSelectedVM
                let lastSelectedRow = currentSelectedVM
                vmsTableView.reloadData()
                
                // Re-select previously selected row
                reselectTableRow(row: lastSelectedRow)
                
                // Wait for process to end
                process.waitUntilExit()
                
                // Process is terminated
                currentRunningVM = nil
                vmsTableView.reloadData()
                
                // Re-select previously selected row
                reselectTableRow(row: lastSelectedRow)
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
        
        // Set VM name and description text
        vmNameTextField.stringValue = vmList[row].name ?? "86Box - MacBoxVM"
        vmDescriptionTextView.string = vmList[row].description ?? ""
        // Set all VM paths
        var defaultPath = homeDirURL
        if #available(macOS 13.0, *) {
            defaultPath = homeDirURL.appending(component: "\(vmList[row].name ?? "")")
        } else {
            // Fallback on earlier versions
            defaultPath = homeDirURL.appendingPathComponent("\(vmList[row].name ?? "")")
        }
        let vmPath = (vmList[row].path != nil ? vmList[row].path : defaultPath.path) ?? ""
        setAllVMPaths(vmPath: vmPath)
        
        // Set VM specs
        setVMSpecs()
        
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
    
    // Table View Cell Show in Finder Action
    @objc private func tableViewFindInFinderAction(_ sender: AnyObject) {
        if vmsTableView.clickedRow >= 0 {
            let vmPathURL = URL(fileURLWithPath: vmList[vmsTableView.clickedRow].path ?? "")
            NSWorkspace.shared.open(vmPathURL)
        }
    }
    
    // Set all VM paths
    private func setAllVMPaths(vmPath: String) {
        currentVMPrinterPath = vmPath.appending("/printer")
        currentVMScreenShotsPath = vmPath.appending("/screenshots")
        currentVMConfigPath = vmPath.appending("/86box.cfg")
        
        // Create printer folder if it doesn't already exist
        if let printerPath = currentVMPrinterPath {
            if !FileManager.default.fileExists(atPath: printerPath) {
                do {
                    try FileManager.default.createDirectory(atPath: printerPath, withIntermediateDirectories: true)
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
        
        // Create screenshots folder if it doesn't already exist
        if let screenshotsPath = currentVMScreenShotsPath {
            if !FileManager.default.fileExists(atPath: screenshotsPath) {
                do {
                    try FileManager.default.createDirectory(atPath: screenshotsPath, withIntermediateDirectories: true)
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Set current VM specs
    private func setVMSpecs() {
        if currentVMConfigPath != nil {
            if FileManager.default.fileExists(atPath: currentVMConfigPath ?? "") {
                let ini = IniParser()
                // Parse machine type
                let machineType = ini.parseConfig(currentVMConfigPath ?? "")["Machine"]?["machine"] ?? ""
                // Parse cpu family
                let cpuFamily = ini.parseConfig(currentVMConfigPath ?? "")["Machine"]?["cpu_family"] ?? ""
                // Parse cpu speed
                let cpuSpeed = ini.parseConfig(currentVMConfigPath ?? "")["Machine"]?["cpu_speed"] ?? ""
                // Parse ram size
                let ramSize = ini.parseConfig(currentVMConfigPath ?? "")["Machine"]?["mem_size"] ?? ""
                // Parse ram size
                let hddPath = ini.parseConfig(currentVMConfigPath ?? "")["Hard disks"]?["hdd_01_fn"] ?? nil

                // Parse and define devices name
                let nameDefs = Bundle.main.path(forResource: "namedefs.inf", ofType: nil)
                
                // Define machine type name
                if let machinesDef = (ini.parseConfig(nameDefs ?? "")["machine"]) {
                    if machinesDef[machineType] != nil {
                        vmSpecMachine.stringValue = machinesDef[machineType] ?? ""
                    }
                    else {
                        vmSpecMachine.stringValue = machineType
                    }
                }
                
                // Define cpu family name
                var cpuFamilyName = ""
                if let cpuDef = (ini.parseConfig(nameDefs ?? "")["cpu_family"]) {
                    if cpuDef[cpuFamily] != nil {
                        cpuFamilyName = cpuDef[cpuFamily] ?? ""
                    }
                    else {
                        cpuFamilyName = cpuFamily
                    }
                }
                
                // Define cpu speed
                let cpuSpeedConverted = (Float(cpuSpeed) ?? 0.0) / 1000000
                let cpuSpeedRounded = String(format: "%.2f", cpuSpeedConverted)
                vmSpecCPU.stringValue = "\(cpuFamilyName) \(cpuSpeedRounded) MHz"
                
                // Define and format ram size
                let ramBCF = ByteCountFormatter()
                ramBCF.allowedUnits = [.useAll]
                ramBCF.countStyle = .memory
                let ramSizeConverted = ramBCF.string(fromByteCount: (Int64(ramSize) ?? 0) * 1024)
                vmSpecRAM.stringValue = "RAM \(ramSizeConverted)"

                // Define hdd size
                if hddPath != nil {
                    let hddSize = FileManager.default.sizeOfFile(atPath: hddPath ?? "") ?? 0
                    // Format hdd size
                    let hddBCF = ByteCountFormatter()
                    hddBCF.allowedUnits = [.useAll]
                    hddBCF.countStyle = .binary
                    let hddSizeConverted = hddBCF.string(fromByteCount: hddSize)
                    vmSpecHDD.stringValue = "HDD \(hddSizeConverted)"
                }
                else {
                    vmSpecHDD.stringValue = "No HDD Found"
                }
            }
            else {
                vmSpecMachine.stringValue = "-"
                vmSpecCPU.stringValue = "-"
                vmSpecRAM.stringValue = "-"
                vmSpecHDD.stringValue = "-"
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
            if currentRunningVM != nil && currentRunningVM == row {
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
