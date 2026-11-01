//
//  ConnectView.swift
//  MewGlow
//
//  "Device" tab — shows connection status and lets the user connect to
//  the ESP32 companion lamp.
//

import SwiftUI

struct ConnectView: View {
    @EnvironmentObject var viewModel: LampViewModel
    @State private var isButtonPressed = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.softBackground.ignoresSafeArea()

                VStack(spacing: 32) {
                    statusIndicator
                        .padding(.top, 12)

                    deviceCard

                    Spacer()

                    connectButton

                    if viewModel.connectionStatus == .connected {
                        disconnectButton
                    }

                    Spacer()
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationTitle("Device")
        }
    }

    // MARK: - Status Dot

    private var statusIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.connectionStatus.indicatorColor)
                .frame(width: 12, height: 12)
            Text(viewModel.connectionStatus.displayText)
                .font(.footnote)
                .foregroundColor(AppTheme.darkText.opacity(0.7))
        }
    }

    // MARK: - Device Card

    private var deviceCard: some View {
        VStack(spacing: 8) {
            Text("MewGlow Lamp")
                .font(.headline)
                .foregroundColor(AppTheme.darkText)
            Text("Remote Companion Light")
                .font(.subheadline)
                .foregroundColor(AppTheme.darkText.opacity(0.6))
            Text(viewModel.connectionStatus.displayText)
                .font(.footnote.weight(.medium))
                .foregroundColor(AppTheme.darkText.opacity(0.5))
                .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(AppTheme.paleYellow, lineWidth: 1)
                )
        )
    }

    // MARK: - Big Circular Connect Button

    private var connectButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isButtonPressed = true
            }
            viewModel.connect()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isButtonPressed = false
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(AppTheme.paleYellow)
                    .frame(width: 220, height: 220)

                Circle()
                    .stroke(AppTheme.warmYellow, lineWidth: 3)
                    .frame(width: 236, height: 236)

                if viewModel.connectionStatus == .connecting {
                    ProgressView()
                        .tint(AppTheme.darkText)
                } else {
                    Text(viewModel.connectionStatus.buttonText)
                        .font(.title3.weight(.medium))
                        .foregroundColor(AppTheme.darkText)
                }
            }
        }
        .scaleEffect(isButtonPressed ? 0.95 : 1.0)
        .disabled(viewModel.connectionStatus == .connecting)
    }

    // MARK: - Disconnect Button

    private var disconnectButton: some View {
        Button {
            withAnimation(.easeInOut) {
                viewModel.disconnect()
            }
        } label: {
            Text("Disconnect")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.red.opacity(0.8))
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    Capsule()
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(.top, 8)
    }
}

#Preview {
    ConnectView()
        .environmentObject(LampViewModel())
}
