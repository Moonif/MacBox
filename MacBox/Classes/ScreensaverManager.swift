//
//  ScreensaverManager.swift
//  MacBox
//
//  Created by Moonif on 5/18/24.
//

import IOKit.pwr_mgt

class ScreensaverManager {
    private var assertionID: IOPMAssertionID = 0
    private let assertionName = "Moonif.MacBox.preventsleep" as CFString
    var sleepDisabled = false
    
    // Disable screensaver & screen sleep
    func disableScreensaver() {
        if !sleepDisabled {
            sleepDisabled = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep as CFString,
                                                        IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                        assertionName,
                                                        &assertionID) == kIOReturnSuccess
        }
    }
    
    // Enable screensaver & screen sleep (release the assertion)
    func enableScreensaver() {
        if sleepDisabled {
            IOPMAssertionRelease(assertionID)
            sleepDisabled = false
        }
    }
}
