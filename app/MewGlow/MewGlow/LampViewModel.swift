//
//  LampViewModel.swift
//  MewGlow
//
//  Central view model shared across ConnectView, ControlView, and
//  ProfileView. Owns all mutable app state and talks to LampService.
//

import SwiftUI
import Combine

@MainActor
final class LampViewModel: ObservableObject {

    // MARK: - Connection State

    @Published var isConnected: Bool = false
    @Published var connectionStatus: ConnectionStatus = .notConnected

    // MARK: - Control State

    @Published var message: String = ""
    @Published var selectedEmoticon: String = Presets.emoticons.first ?? "(^_^)"
    @Published var customEmoticons: [String] = []

    @Published var selectedColor: Color = Presets.colors.first ?? AppTheme.warmYellow
    @Published var customColors: [Color] = []

    @Published var brightness: Double = 70 // 0-100
    @Published var selectedEffect: LightEffect = .steady

    // MARK: - Command Feedback

    @Published var commandStatus: CommandStatus = .idle

    // MARK: - Settings

    @Published var isDoNotDisturbEnabled: Bool = false
    @Published var defaultBrightness: Double = 70

    // MARK: - Character Limit

    let messageCharacterLimit = 30

    // MARK: - Dependencies

    private let service = LampService()

    // MARK: - Connection

    func connect() {
        guard connectionStatus != .connecting else { return }

        connectionStatus = .connecting
        isConnected = false

        Task {
            do {
                try await service.connect()
                connectionStatus = .connected
                isConnected = true
            } catch {
                connectionStatus = .failed
                isConnected = false
            }
        }
    }

    func disconnect() {
        connectionStatus = .notConnected
        isConnected = false
    }

    // MARK: - Sending Commands

    func sendCommand() {
        guard isConnected else {
            commandStatus = .failed
            return
        }
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        guard !isDoNotDisturbEnabled else {
            commandStatus = .failed
            return
        }

        let rgb = selectedColor.toRGB255()
        let command = LampCommand(
            text: message,
            emoticon: selectedEmoticon,
            red: rgb.red,
            green: rgb.green,
            blue: rgb.blue,
            brightness: Int(brightness.rounded()),
            effect: selectedEffect.wireValue
        )

        commandStatus = .sending

        Task {
            do {
                try await service.send(command: command)

                try await Task.sleep(nanoseconds: 1_000_000_000)
                commandStatus = .received

                try await Task.sleep(nanoseconds: 1_000_000_000)
                commandStatus = .executing

                try await Task.sleep(nanoseconds: 2_000_000_000)
                commandStatus = .completed
            } catch {
                commandStatus = .failed
            }
        }
    }

    func simulateReply() {
        commandStatus = .replied
    }

    func resetCommandStatus() {
        commandStatus = .idle
    }

    // MARK: - Emoticons & Colors

    /// Adds a user-entered custom emoticon and selects it.
    func addCustomEmoticon(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        customEmoticons.append(trimmed)
        selectedEmoticon = trimmed
    }

    /// Removes an emoticon the user previously added via the custom
    /// emoticon sheet (long-press to delete). Preset emoticons are never
    /// removable — callers should only invoke this for emoticons already
    /// in customEmoticons. If the removed emoticon was selected, falls
    /// back to the first preset so a valid emoticon stays selected.
    func removeCustomEmoticon(_ emoticon: String) {
        customEmoticons.removeAll { $0 == emoticon }
        if selectedEmoticon == emoticon {
            selectedEmoticon = Presets.emoticons.first ?? "(^_^)"
        }
    }

    /// Adds a user-picked custom color and selects it.
    func addCustomColor(_ color: Color) {
        customColors.append(color)
        selectedColor = color
    }

    /// Removes a color the user previously added via the custom color
    /// picker (long-press to delete). Preset colors are never removable —
    /// callers should only invoke this for colors already in customColors.
    /// If the removed color was selected, falls back to the first preset
    /// so a valid color stays selected.
    func removeCustomColor(_ color: Color) {
        let rgb = color.toRGB255()
        customColors.removeAll { $0.toRGB255() == rgb }
        if selectedColor.toRGB255() == rgb {
            selectedColor = Presets.colors.first ?? AppTheme.warmYellow
        }
    }
}
