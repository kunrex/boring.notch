//
//  LockScreenMusicPanel.swift
//  boringNotch
// 
// Created by Kunal Kashyap on 07/07/2026.
//

import SwiftUI
import Defaults

struct LockScreenMusicPanel: View {
    static let panelSize = CGSize(width: 380, height: 160)
    static let cornerRadius: CGFloat = 26

    @ObservedObject var musicManager = MusicManager.shared
    @ObservedObject var animator: LockScreenPanelAnimator
    @Default(.lockSreenWidgetGlassStyle) var glassStyle

    @State private var sliderValue: Double = 0
    @State private var isDragging: Bool = false
    @State private var lastDragged: Date = .distantPast

    var body: some View {
        ZStack {
            backgroundLayer
            contentLayer
        }
        .frame(width: Self.panelSize.width, height: Self.panelSize.height)
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(glassStyle == .liquid ? 0.15 : 0.35), lineWidth: glassStyle == .liquid ? 0.9 : 1.4)
        }
        .shadow(color: .black.opacity(0.32), radius: 24, x: 0, y: 12)
        .scaleEffect(animator.isPresented ? 1 : 0.92, anchor: .center)
        .opacity(animator.isPresented ? 1 : 0)
        .animation(.spring(response: 0.52, dampingFraction: 0.8), value: animator.isPresented)
        .onAppear { sliderValue = musicManager.elapsedTime }
    }

    private var contentLayer: some View {
        HStack(spacing: 14) {
            Image(nsImage: musicManager.albumArt)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(musicManager.songTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(musicManager.artistName)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }

                TimelineView(.animation(minimumInterval: 1, paused: !musicManager.isPlaying)) { ctx in
                    MusicSliderView(
                        sliderValue: $sliderValue,
                        duration: Binding(
                            get: { musicManager.songDuration },
                            set: { musicManager.songDuration = $0 }
                        ),
                        lastDragged: $lastDragged,
                        color: musicManager.avgColor,
                        dragging: $isDragging,
                        currentDate: ctx.date,
                        timestampDate: musicManager.timestampDate,
                        elapsedTime: musicManager.elapsedTime,
                        playbackRate: musicManager.playbackRate,
                        isPlaying: musicManager.isPlaying
                    ) { newValue in
                        musicManager.seek(to: newValue)
                    }
                }

                HStack() {
                    Button { musicManager.previousTrack() } label: {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button { musicManager.togglePlay() } label: {
                        Image(systemName: musicManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()

                    Button { musicManager.nextTrack() } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        if glassStyle == .liquid {
            if #available(macOS 26.0, *) {
                Rectangle()
                    .fill(Color.clear)
                    .glassEffect(.clear.interactive(), in: .rect(cornerRadius: Self.cornerRadius))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                frostedBackground
            }
        } else {
            frostedBackground
        }
    }

    private var frostedBackground: some View {
        RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
