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
    @IBOutlet weak var deleteVMButton: NSButton!
    @IBOutlet weak var spinningProgressIndicator: NSProgressIndicator!
    @IBOutlet weak var statusLabel: NSTextField!
    @IBOutlet weak var vmNameTextField: NSTextField!
    @IBOutlet weak var vmDescriptionTextField: NSTextField!
    
    // Variables
    private let homeDirURL = URL(fileURLWithPath: "MacBox", isDirectory: true, relativeTo: FileManager.default.homeDirectoryForCurrentUser)
    var vmList: [VM] = []
    private var currentSelectedVM: Int?
    
    let nameTextFieldMaxLimit: Int = 32
    
    // View did load
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set delegates
        vmsTableView.delegate = self
        vmsTableView.dataSource = self
        vmNameTextField.delegate = self
        
        // Config views
        configView()
        // Initialize MacBox files
        initFiles()
        // Check for 86Box version
        checkFor86Box()
    }
    
    // Config views initial properties
    private func configView() {
        startVMButton.isEnabled = false
        deleteVMButton.isEnabled = false
        spinningProgressIndicator.startAnimation(self)
        statusLabel.stringValue = ""
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
    func addVM(vm: VM) {
        vmList.append(vm)
        vmsTableView.reloadData()
        writeConfigFile()
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
            ["-n", "-b","net.86Box.86Box","--args","-P","\(vmPath)","-S"] :
            ["-n", "-b","net.86Box.86Box","--args","-P","\(vmPath)","-V",vmName]
            process.arguments = args
            
            process.executableURL = URL(fileURLWithPath:"/usr/bin/open")

            // Run the process
            do{
                try process.run()
            } catch {
                print("Error: \(error.localizedDescription)")
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
                    deleteVMButton.isEnabled = false
                }
            }
        }
    }
    
    // Add VM toolbar button action
    @IBAction func addVMButtonAction(_ sender: Any) {
        if let addVMVC = self.storyboard?.instantiateController(withIdentifier: "AddVMVC") as? AddVMViewController {
            addVMVC.mainVC = self
            self.presentAsModalWindow(addVMVC)
        }
    }
    
}

// ------------------------------------
// VM TableView Delegate and Datasource
// ------------------------------------
extension MainViewController: NSTableViewDelegate, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return vmList.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let vmObject = vmList[row]
        let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "textCellID"), owner: self) as? NSTableCellView
        cell?.textField?.stringValue = vmObject.name ?? "No Name"
        return cell
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        currentSelectedVM = row
        startVMButton.isEnabled = true
        deleteVMButton.isEnabled = true
        
        vmNameTextField.stringValue = vmList[row].name ?? "86Box - MacBoxVM"
        vmDescriptionTextField.stringValue = vmList[row].description ?? ""
        
        return true
    }
}

// ------------------------------------
// TextField Delegate
// ------------------------------------
extension MainViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        if let textField = obj.object as? NSTextField {
            if textField.stringValue.count > nameTextFieldMaxLimit {
                textField.stringValue = String(textField.stringValue.dropLast())
            }
        }
    }
}
