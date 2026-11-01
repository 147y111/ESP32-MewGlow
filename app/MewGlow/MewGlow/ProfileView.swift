//
//  ProfileView.swift
//  MewGlow
//
//  Created by shaoxuan on 7/29/26.
//


//
//  ProfileView.swift
//  MewGlow
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var viewModel: LampViewModel

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.softBackground.ignoresSafeArea()

                Form {
                    Section("Lamp Status") {
                        HStack {
                            Circle()
                                .fill(viewModel.connectionStatus.indicatorColor)
                                .frame(width: 10, height: 10)
                            Text(viewModel.connectionStatus.displayText)
                                .foregroundColor(AppTheme.darkText.opacity(0.7))
                        }

                        if viewModel.isConnected {
                            Button("Disconnect") {
                                viewModel.disconnect()
                            }
                            .foregroundColor(.red)
                        }
                    }

                    Section("Connection Settings") {
                        Text("Auto-detect on local network")
                            .foregroundColor(AppTheme.darkText.opacity(0.5))
                    }

                    Section("Default Brightness") {
                        VStack {
                            Slider(value: $viewModel.defaultBrightness, in: 0...100, step: 1)
                                .tint(AppTheme.warmYellow)
                            Text("\(Int(viewModel.defaultBrightness))%")
                                .font(.caption)
                                .foregroundColor(AppTheme.darkText.opacity(0.6))
                        }
                    }

                    Section {
                        Toggle("Do Not Disturb", isOn: $viewModel.isDoNotDisturbEnabled)
                            .tint(AppTheme.warmYellow)
                    } footer: {
                        Text("When enabled, remote commands to the lamp are blocked.")
                    }

                    Section("About MewGlow") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MewGlow")
                                .font(.headline)
                            Text("A little light from someone far away.")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.darkText.opacity(0.6))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(LampViewModel())
}