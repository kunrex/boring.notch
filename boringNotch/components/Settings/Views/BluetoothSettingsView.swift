//
//  BluetoothSettingsView.swift
//  boringNotch
//
//  Created by Kunal Kashyap on 06/06/26.
//

import Defaults
import SwiftUI

struct Bluetooth: View {
    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .showBluetoothLiveActivities) {
                    Text("Show Bluetooth live activities")
                }
            } header: {
                Text("General")
            }
        }
        .onAppear {
            Task { @MainActor in
                await XPCHelperClient.shared.isAccessibilityAuthorized()
            }
        }
        .accentColor(.effectiveAccent)
        .navigationTitle("Bluetooth")
    }
}
