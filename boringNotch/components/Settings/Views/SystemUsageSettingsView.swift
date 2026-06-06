//
//  SystemUsageSettingsView.swift
//  boringNotch
// 
//  Created by Kunal Kashyap on 07/06/2026.
//

import Defaults
import SwiftUI

struct SystemUsageSettings: View {
    @Default(.enableSystemUsage) var enabled
    @Default(.systemUsageUpdateInterval) var updateInterval

    var body: some View {
        Form {
            Section {
                Defaults.Toggle(key: .enableSystemUsage) {
                    Text("Enable System Usage")
                }
                .tint(.effectiveAccent)
            } header: {
                Text("General")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Sample Rate")
                        Spacer()
                        Text(String(format: "%.1fs", updateInterval))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $updateInterval, in: 0.5...10.0, step: 0.5)
                        .tint(.effectiveAccent)
                        .disabled(!enabled)
                }
            } header: {
                Text("Monitoring")
            } footer: {
                Text("How often system stats are refreshed. Lower values are more responsive but take up more resources.")
                    .foregroundStyle(.secondary)
            }
            .disabled(!enabled)
        }
        .formStyle(.grouped)
        .navigationTitle("System Usage")
    }
}
