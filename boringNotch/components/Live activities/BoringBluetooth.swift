//
//  BoringBluetooth.swift
//  boringNotch
//
//  Created by Kunal Kashyap on 06/06/26.
//

import SwiftUI

struct BoringBluetoothView: View {
    let eventType: BluetoothStatusViewModel.EventType

    var iconStatus: String {
        if eventType == .connected {
            return "antenna.radiowaves.left.and.right"
        }
        else {
            return "antenna.radiowaves.left.and.right.slash"
        }
    }

    var iconColor: Color {
        if eventType == .connected {
            return .blue
        }
        else {
            return .secondary
        }
    }

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: iconStatus)
                .font(.system(
                    size: 14, 
                    weight: .bold))
                .foregroundStyle(iconColor)
        }
    }
}
