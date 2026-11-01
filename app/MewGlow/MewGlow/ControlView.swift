//
//  ControlView.swift
//  MewGlow
//
//  "Control" tab — the main page of the app. Lets the user compose a
//  message + emoticon + color + brightness + effect, and send it to
//  the lamp.
//

import SwiftUI

struct ControlView: View {
    @EnvironmentObject var viewModel: LampViewModel
    @FocusState private var isMessageFieldFocused: Bool
    @State private var showCustomEmoticonSheet = false
    @State private var showCustomColorPicker = false
    @State private var customEmoticonInput = ""
    @State private var customPickedColor: Color = .white
    @State private var showEmptyMessageHint = false
    @State private var sendButtonPressed = false
    /// Custom color the user long-pressed on, awaiting delete confirmation.
    /// Preset colors never populate this — only user-added ones are removable.
    @State private var colorPendingDeletion: Color?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.softBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        catPreview
                        emoticonRow
                        messageInput
                        colorRow
                        brightnessSlider
                        effectRow
                        sendButton
                        statusView

                        #if DEBUG
                        simulateReplyButton
                        #endif
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
                .onTapGesture {
                    isMessageFieldFocused = false
                }
            }
            .navigationTitle("Control")
            .sheet(isPresented: $showCustomEmoticonSheet) {
                customEmoticonSheet
            }
        }
    }

    // MARK: - Cat Preview

    private var catPreview: some View {
        let brightnessFraction = viewModel.brightness / 100
        let glowOpacity = 0.12 + (brightnessFraction * 0.45)

        return ZStack {
            Circle()
                .fill(viewModel.selectedColor.opacity(glowOpacity))
                .frame(width: 190, height: 190)
                .animation(.easeInOut(duration: 0.3), value: viewModel.selectedColor)
                .animation(.easeInOut(duration: 0.2), value: viewModel.brightness)

            CatFaceView(tintColor: viewModel.selectedColor, brightness: brightnessFraction)
                .frame(width: 150, height: 150)
                .animation(.easeInOut(duration: 0.2), value: viewModel.brightness)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Emoticon Row

    private var emoticonRow: some View {
        HStack(spacing: 12) {
            ForEach(Presets.emoticons + viewModel.customEmoticons, id: \.self) { emoticon in
                emoticonBubble(emoticon)
            }
            addBubble {
                showCustomEmoticonSheet = true
            }
        }
    }

    private func emoticonBubble(_ emoticon: String) -> some View {
        let isSelected = viewModel.selectedEmoticon == emoticon
        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                viewModel.selectedEmoticon = emoticon
            }
        } label: {
            Text(emoticon)
                .font(.system(size: 11))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? AppTheme.paleYellow : Color.gray.opacity(0.15))
                )
                .overlay(
                    Circle()
                        .stroke(AppTheme.warmYellow, lineWidth: isSelected ? 2 : 0)
                )
                .scaleEffect(isSelected ? 1.08 : 1.0)
        }
        .foregroundColor(AppTheme.darkText)
    }

    private func addBubble(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .medium))
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.gray.opacity(0.15)))
        }
        .foregroundColor(AppTheme.darkText)
    }

    private var customEmoticonSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Enter a custom emoticon", text: $customEmoticonInput)
                    .textFieldStyle(.roundedBorder)
                    .padding(.top, 24)

                Button("Add") {
                    viewModel.addCustomEmoticon(customEmoticonInput)
                    customEmoticonInput = ""
                    showCustomEmoticonSheet = false
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.warmYellow)
                .foregroundColor(AppTheme.darkText)
                .disabled(customEmoticonInput.trimmingCharacters(in: .whitespaces).isEmpty)

                Spacer()
            }
            .padding()
            .navigationTitle("Custom Emoticon")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.height(220)])
        }
    }

    // MARK: - Message Input

    private var messageInput: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                TextField("Type a short message...", text: $viewModel.message, axis: .vertical)
                    .lineLimit(2...4)
                    .focused($isMessageFieldFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .padding(.trailing, 28)
                    .onChange(of: viewModel.message) { _, newValue in
                        if newValue.count > viewModel.messageCharacterLimit {
                            viewModel.message = String(newValue.prefix(viewModel.messageCharacterLimit))
                        }
                    }

                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.warmYellow)
                    .padding(.trailing, 14)
                    .padding(.bottom, 14)
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppTheme.warmYellow, lineWidth: 3)
            )

            HStack {
                if showEmptyMessageHint {
                    Text("Please enter a message")
                        .font(.caption2)
                        .foregroundColor(.red)
                }
                Spacer()
                Text("\(viewModel.message.count)/\(viewModel.messageCharacterLimit)")
                    .font(.caption2)
                    .foregroundColor(AppTheme.darkText.opacity(0.4))
            }
        }
    }

    // MARK: - Color Row

    private var colorRow: some View {
        HStack(spacing: 12) {
            ForEach(Array(Presets.colors.enumerated()), id: \.offset) { _, color in
                colorBubble(color, isCustom: false)
            }
            ForEach(Array(viewModel.customColors.enumerated()), id: \.offset) { _, color in
                colorBubble(color, isCustom: true)
            }
            addBubble {
                showCustomColorPicker = true
            }
            .overlay(
                ColorPicker("", selection: $customPickedColor, supportsOpacity: false)
                    .labelsHidden()
                    .opacity(showCustomColorPicker ? 0.02 : 0)
                    .allowsHitTesting(showCustomColorPicker)
                    .onChange(of: customPickedColor) { _, newColor in
                        if showCustomColorPicker {
                            viewModel.addCustomColor(newColor)
                            showCustomColorPicker = false
                        }
                    }
            )
        }
        .confirmationDialog(
            "Remove this color?",
            isPresented: Binding(
                get: { colorPendingDeletion != nil },
                set: { isPresented in if !isPresented { colorPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let color = colorPendingDeletion {
                    viewModel.removeCustomColor(color)
                }
                colorPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                colorPendingDeletion = nil
            }
        }
    }

    private func colorBubble(_ color: Color, isCustom: Bool) -> some View {
        let isSelected = colorsApproximatelyEqual(color, viewModel.selectedColor)
        return Circle()
            .fill(color)
            .frame(width: 40, height: 40)
            .overlay(
                Circle()
                    .stroke(color == .white ? AppTheme.lightGray : Color.clear, lineWidth: 1)
            )
            .overlay(
                Circle()
                    .stroke(isSelected ? AppTheme.darkText : Color.clear, lineWidth: 2)
            )
            .scaleEffect(isSelected ? 1.08 : 1.0)
            .onTapGesture {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    viewModel.selectedColor = color
                }
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                guard isCustom else { return }
                colorPendingDeletion = color
            }
    }

    private func colorsApproximatelyEqual(_ a: Color, _ b: Color) -> Bool {
        a.toRGB255() == b.toRGB255()
    }

    // MARK: - Brightness Slider

    private var brightnessSlider: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Brightness")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppTheme.darkText)
                Spacer()
                Text("\(Int(viewModel.brightness))%")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(AppTheme.darkText.opacity(0.6))
            }

            YellowSlider(value: $viewModel.brightness, range: 0...100)
        }
    }

    // MARK: - Effect Row

    private var effectRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Light Effect")
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppTheme.darkText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(LightEffect.allCases) { effect in
                        capsuleButton(
                            title: effect.rawValue,
                            isSelected: viewModel.selectedEffect == effect
                        ) {
                            viewModel.selectedEffect = effect
                        }
                    }
                }
            }
        }
    }

    private func capsuleButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(isSelected ? AppTheme.paleYellow : Color.white)
                )
                .overlay(
                    Capsule().stroke(AppTheme.lightGray.opacity(0.6), lineWidth: 1)
                )
        }
        .foregroundColor(AppTheme.darkText)
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button {
            let trimmed = viewModel.message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                withAnimation { showEmptyMessageHint = true }
                return
            }
            showEmptyMessageHint = false

            withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                sendButtonPressed = true
            }
            viewModel.sendCommand()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                    sendButtonPressed = false
                }
            }
        } label: {
            Text("Send to Lamp")
                .font(.headline.weight(.bold))
                .foregroundColor(AppTheme.darkText)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppTheme.warmYellow)
                )
        }
        .scaleEffect(sendButtonPressed ? 0.97 : 1.0)
        .opacity(viewModel.isConnected ? 1.0 : 0.4)
        .disabled(!viewModel.isConnected)
    }

    // MARK: - Status View

    private var statusView: some View {
        HStack(spacing: 8) {
            if viewModel.commandStatus.isInProgress {
                ProgressView()
            } else if viewModel.commandStatus == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else if viewModel.commandStatus == .replied {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
            } else if viewModel.commandStatus == .failed {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }

            Text(viewModel.commandStatus.displayText)
                .font(.footnote)
                .foregroundColor(AppTheme.darkText.opacity(0.7))
        }
        .transition(.opacity)
        .animation(.easeInOut, value: viewModel.commandStatus)
    }

    #if DEBUG
    private var simulateReplyButton: some View {
        Button("Simulate Reply") {
            viewModel.simulateReply()
        }
        .font(.caption)
        .foregroundColor(AppTheme.darkText.opacity(0.4))
    }
    #endif
}

// MARK: - Cat Face

struct CatFaceView: View {
    var tintColor: Color = AppTheme.warmYellow
    var brightness: Double = 0.7

    var body: some View {
        ZStack {
            Image(systemName: "cat.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color.black.opacity(0.16))
                .scaleEffect(1.05)

            Image(systemName: "cat.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(tintColor.opacity(0.55 + brightness * 0.45))
        }
        .padding(8)
    }
}

// MARK: - Reusable Yellow Slider

struct YellowSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.paleYellow)
                .frame(height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.warmYellow, lineWidth: 2)
                )

            GeometryReader { geo in
                let span = range.upperBound - range.lowerBound
                let fraction = CGFloat((value - range.lowerBound) / span)
                let knobDiameter: CGFloat = 36
                let trackWidth = geo.size.width - knobDiameter
                let knobX = knobDiameter / 2 + fraction * trackWidth

                Circle()
                    .fill(Color.white)
                    .frame(width: knobDiameter, height: knobDiameter)
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                    .position(x: knobX, y: geo.size.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let clampedX = min(max(drag.location.x, knobDiameter / 2), geo.size.width - knobDiameter / 2)
                                let newFraction = (clampedX - knobDiameter / 2) / trackWidth
                                value = range.lowerBound + Double(newFraction) * span
                            }
                    )
            }
            .frame(height: 44)
        }
    }
}

#Preview {
    ControlView()
        .environmentObject(LampViewModel())
}
