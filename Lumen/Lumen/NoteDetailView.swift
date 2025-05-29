
import SwiftUI
import SwiftData
import AVFoundation

struct NoteDetailView: View {
    @Bindable var note: Note
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioPlayerManager = AudioPlayerManager()
    
    private let groqService = GroqService()
    @State private var isGeneratingSummary = false
    @State private var summaryToShow: AttributedString? = nil
    @State private var transcriptionExpanded = false
    @State private var showSummaryAnimation = false

    @State private var isLoadingAnimating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(note.title)
                    .font(.largeTitle.bold())
                    .padding(.top)

                Text(formatDate(note.creationDate))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 10)

                if let audioPath = note.audioFilePath, let audioURL = URL(string: audioPath) {
                    AudioPlayerView(audioURL: audioURL, audioPlayerManager: audioPlayerManager)
                        .padding(.bottom, 10)
                } else {
                    Text("No audio recording available.")
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading) {
                    Text("Transcription")
                        .font(.title2.weight(.semibold))
                    Text(transcriptionDisplay())
                        .font(.body)
                        .lineLimit(transcriptionExpanded ? nil : 3)
                        .padding(.top, 2)
                    if !(note.transcription ?? "").isEmpty {
                        Button(transcriptionExpanded ? "Show Less" : "Show More") {
                            withAnimation(.easeInOut) {
                                transcriptionExpanded.toggle()
                            }
                        }
                        .padding(.top, 5)
                    } else {
                        Text("No transcription available.")
                            .foregroundColor(.secondary)
                            .padding(.top, 2)
                    }
                }
                .padding(.bottom, 10)

                VStack(alignment: .leading) {
                    Text("AI Summary")
                        .font(.title2.weight(.semibold))
                    
                    if isGeneratingSummary {
                        HStack(spacing: 10) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Generating summary...")
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 10)
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else if let summary = summaryToShow {
                        Text(summary)
                            .font(.body)
                            .padding(.top, 5)
                            .opacity(showSummaryAnimation ? 1 : 0)
                            .animation(.easeIn(duration: 0.5).delay(0.2), value: showSummaryAnimation)
                            .onAppear {
                                showSummaryAnimation = true
                            }
                    } else if note.summary != nil && summaryToShow == nil {
                        Text("Loading summary...")
                            .onAppear {
                                processAndSetSummary(note.summary)
                            }
                    }
                     else {
                        Text("No summary generated yet.")
                            .foregroundColor(.secondary)
                            .padding(.top, 5)
                    }
                }
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Note Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if note.summary == nil, let transcription = note.transcription, !transcription.isEmpty {
                generateSummary()
            } else if let existingSummary = note.summary {
                processAndSetSummary(existingSummary)
            }
        }
        .onDisappear {
            audioPlayerManager.stop()
        }
    }

    private func transcriptionDisplay() -> String {
        guard let trans = note.transcription, !trans.isEmpty else {
            return "Transcription not available."
        }
        if transcriptionExpanded {
            return trans
        } else {
            if let firstSentenceEnd = trans.firstIndex(of: ".") {
                return String(trans[...firstSentenceEnd])
            }
            return String(trans.prefix(150)) + (trans.count > 150 ? "..." : "")
        }
    }
    
    private func generateSummary() {
        guard let transcription = note.transcription, !transcription.isEmpty else {
            print("No transcription available to generate summary.")
            return
        }
        isGeneratingSummary = true
        showSummaryAnimation = false

        Task {
            do {
                let rawSummary = try await groqService.generateSummary(for: transcription)
                await MainActor.run {
                    note.summary = rawSummary
                    processAndSetSummary(rawSummary)
                    isGeneratingSummary = false
                    saveContext()
                }
            } catch {
                await MainActor.run {
                    print("Failed to generate summary: \(error.localizedDescription)")
                    isGeneratingSummary = false
                    summaryToShow = AttributedString("Failed to generate summary.")
                    showSummaryAnimation = true
                }
            }
        }
    }

    private func processAndSetSummary(_ rawSummary: String?) {
        guard let rawSummary = rawSummary else {
            summaryToShow = AttributedString("Summary not available.")
            showSummaryAnimation = true
            return
        }

        var attributedString = AttributedString(rawSummary)
        
        do {
            let regex = try NSRegularExpression(pattern: "\\*\\*(.*?)\\*\\*", options: [])
            let nsRange = NSRange(rawSummary.startIndex..<rawSummary.endIndex, in: rawSummary)
            
            var newAttributedString = AttributedString()
            var lastProcessedEndIndex = rawSummary.startIndex

            for match in regex.matches(in: rawSummary, options: [], range: nsRange).reversed() {
                guard let boldRange = Range(match.range(at: 1), in: rawSummary),
                      let fullMatchRange = Range(match.range(at: 0), in: rawSummary) else { continue }
                
                if fullMatchRange.upperBound < lastProcessedEndIndex {
                     newAttributedString.append(AttributedString(rawSummary[fullMatchRange.upperBound..<lastProcessedEndIndex]))
                }
                
                var boldedPart = AttributedString(rawSummary[boldRange])
                boldedPart.font = .body.bold()
                newAttributedString.append(boldedPart)
                
                lastProcessedEndIndex = fullMatchRange.lowerBound
            }
            if lastProcessedEndIndex > rawSummary.startIndex {
                 newAttributedString.append(AttributedString(rawSummary[rawSummary.startIndex..<lastProcessedEndIndex]))
            }

            var finalAttributedString = AttributedString()
            var currentIndex = rawSummary.startIndex
            while let rangeStart = rawSummary[currentIndex...].firstRange(of: "**") {
                finalAttributedString.append(AttributedString(rawSummary[currentIndex..<rangeStart.lowerBound]))
                currentIndex = rangeStart.upperBound
                if let rangeEnd = rawSummary[currentIndex...].firstRange(of: "**") {
                    var boldText = AttributedString(rawSummary[currentIndex..<rangeEnd.lowerBound])
                    boldText.font = .body.bold()
                    finalAttributedString.append(boldText)
                    currentIndex = rangeEnd.upperBound
                } else {
                    finalAttributedString.append(AttributedString(rawSummary[currentIndex...]))
                    break
                }
            }
            if currentIndex < rawSummary.endIndex {
                finalAttributedString.append(AttributedString(rawSummary[currentIndex...]))
            }
            summaryToShow = finalAttributedString


        } catch {
            print("Regex error for bolding: \(error)")
            summaryToShow = AttributedString(rawSummary)
        }
        withAnimation {
            showSummaryAnimation = true
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, yyyy"
        return formatter.string(from: date)
    }
    
    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save model context from DetailView: \(error.localizedDescription)")
        }
    }
}

struct AudioPlayerView: View {
    let audioURL: URL
    @ObservedObject var audioPlayerManager: AudioPlayerManager

    var body: some View {
        VStack {
            HStack {
                Button {
                    audioPlayerManager.isPlaying ? audioPlayerManager.pause() : audioPlayerManager.play(url: audioURL)
                } label: {
                    Image(systemName: audioPlayerManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading) {
                    Slider(value: $audioPlayerManager.currentTime, in: 0...(audioPlayerManager.duration > 0 ? audioPlayerManager.duration : 1), onEditingChanged: { editing in
                        if !editing {
                            audioPlayerManager.seek(to: audioPlayerManager.currentTime)
                        }
                    })
                    HStack {
                        Text(formatTime(audioPlayerManager.currentTime))
                        Spacer()
                        Text(formatTime(audioPlayerManager.duration))
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            if audioPlayerManager.errorMessage != nil {
                Text(audioPlayerManager.errorMessage!)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 5)
            }
        }
        .onDisappear {
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}


class AudioPlayerManager: ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var errorMessage: String? = nil
    
    private var displayLink: CADisplayLink?

    func play(url: URL) {
        stop()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            audioPlayer?.play()
            isPlaying = true
            errorMessage = nil
            
            startDisplayLink()
        } catch {
            print("AudioPlayer Playback Error: \(error.localizedDescription)")
            errorMessage = "Error playing audio: \(error.localizedDescription)"
            isPlaying = false
        }
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopDisplayLink()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        stopDisplayLink()
    }
    
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        if !isPlaying {
            self.currentTime = time
        }
    }
    
    private func startDisplayLink() {
        stopDisplayLink()
        displayLink = CADisplayLink(target: self, selector: #selector(updateCurrentTime))
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    @objc private func updateCurrentTime() {
        guard let player = audioPlayer, player.isPlaying else {
            if isPlaying { isPlaying = false }
            stopDisplayLink()
            return
        }
        currentTime = player.currentTime
        
        if currentTime >= duration - 0.1 {
            stop()
        }
    }
    
    deinit {
        stopDisplayLink()
    }
}

