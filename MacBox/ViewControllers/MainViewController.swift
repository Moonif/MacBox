//
//  ViewController.swift
//  MacBox
//
//  Created by Moonif on 4/9/23.
//

import Cocoa

class MainViewController: NSViewController {

    // IBOutlets
    @IBOutlet weak var vmsTableView: NSTableView!
    @IBOutlet weak var startVMButton: NSButton!
    @IBOutlet weak var deleteVMButton: NSButton!
    
    // Variables
    private let homeDirURL = URL(fileURLWithPath: "MacBox", isDirectory: true, relativeTo: FileManager.default.homeDirectoryForCurrentUser)
    var vmList: [VM] = []
    private var currentSelectedVM: Int?
    
    // View did load
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set delegates
        vmsTableView.delegate = self
        vmsTableView.dataSource = self
        
        configView()
        initFiles()
    }
    
    // Config views initial properties
    private func configView() {
        startVMButton.isEnabled = false
        deleteVMButton.isEnabled = false
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
    private func writeConfigFile(overwrite: Bool = false) {
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
            if !FileManager.default.fileExists(atPath: configFileURL.path) || overwrite {
                do {
                    try configStr.write(to: configFileURL, atomically: true, encoding: .utf8)
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
            }
        } else {
            // Fallback on earlier versions
            let configFileURL = homeDirURL.appendingPathComponent("Config")
            if !FileManager.default.fileExists(atPath: configFileURL.path) || overwrite {
                do {
                    try configStr.write(to: configFileURL, atomically: true, encoding: .utf8)
                } catch {
                    print("Error: \(error.localizedDescription)")
                }
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
    
    // Add VM to the table view
    func addVM(vm: VM) {
        vmList.append(vm)
        vmsTableView.reloadData()
        writeConfigFile(overwrite: true)
    }
    
// ------------------------------------
// IBActions
// ------------------------------------
    
    // Start VM button action
    @IBAction func startVMButtonAction(_ sender: NSButton) {
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
            let args:[String] = ["-n", "-b","net.86Box.86Box","--args","-P","\(vmPath)","-V",vmName]
            process.arguments = args
            
            process.executableURL = URL(fileURLWithPath:"/usr/bin/open")
            
            let errorPipe = Pipe()
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            // Run the process
            do{
                try process.run()
            } catch {
                print("Error: \(error.localizedDescription)")
            }
        }
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
                writeConfigFile(overwrite: true)
                
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
        
        return true
    }
}
