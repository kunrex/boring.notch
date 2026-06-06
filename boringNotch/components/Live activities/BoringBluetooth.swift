//
//  BoringBluetooth.swift
//  boringNotch
//
//  Created by Kunal Kashyap on 06/06/26.
//

import SwiftUI

struct BoringBluetoothView: View {
    let icon: String
    let eventType: BluetoothStatusViewModel.EventType

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(eventType == .connected ? Color.blue : Color.secondary)
    }
}
