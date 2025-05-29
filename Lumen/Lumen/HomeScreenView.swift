import SwiftUI
import SwiftData

struct HomeScreenView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var audioRecorderManager = AudioRecorderManager()
    @Query(sort: \Note.creationDate, order: .reverse) private var notes: [Note]

    @State private var isRecording = false
    @State private var showRecordingUI = false
    @State private var isMicMuted = false
    @State private var showingAddNoteView = false
    @State private var showingChatView = false
    @State private var showingSettingsView = false
    private let groqService = GroqService()

    @Namespace private var recordingButtonAnimation

    let recordButtonGradient = LinearGradient(
        gradient: Gradient(colors: [Color.red.opacity(0.7), Color.red.opacity(0.9)]),
        startPoint: .top,
        endPoint: .bottom
    )

    let uploadButtonGradient = LinearGradient(
        gradient: Gradient(colors: [Color.green.opacity(0.7), Color.green.opacity(0.9)]),
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    if !showRecordingUI {
                        HStack {
                            Button {
                                showingSettingsView = true
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.title2)
                                    .padding(.top)
                            }
                            Spacer()
                            Text("Lumen")
                                .font(.largeTitle.bold())
                                .padding(.top)
                            Spacer()
                            Button {
                                showingChatView = true
                            } label: {
                                Image(systemName: "message")
                                    .font(.title2)
                                    .padding(.top)
                            }
                        }
                        .padding(.horizontal)
                        
                        if notes.isEmpty {
                            ContentUnavailableView(
                                "No Notes Yet",
                                systemImage: "note.text.badge.plus",
                                description: Text("Tap the record button to create your first AI-powered note.")
                            )
                        } else {
                            List {
                                ForEach(notes) { note in
                                    NavigationLink(destination: NoteDetailView(note: note)) {
                                        VStack(alignment: .leading) {
                                            Text(note.title)
                                                .font(.headline)
                                                .lineLimit(1)
                                            Text(formatDateWithTime(note.creationDate))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .onDelete(perform: deleteNotes)
                            }
                            .listStyle(.plain)
                        }
                    }

                    Spacer()

                    if isRecording && showRecordingUI {
                        VStack {
                            Button {
                                toggleMute()
                            } label: {
                                Image(systemName: isMicMuted ? "mic.slash.fill" : "mic.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .matchedGeometryEffect(id: "recordButtonIcon", in: recordingButtonAnimation)
                            .frame(width: 120, height: 120)
                            .background(recordButtonGradient)
                            .clipShape(Circle())
                            .shadow(radius: 10)
                            .padding(.bottom, 10)
                            
                            Text(audioRecorderManager.formatTime(audioRecorderManager.recordingTime))
                                .font(.title2.monospacedDigit())
                                .fontWeight(.semibold)
                                .foregroundColor(Color.primary)
                                .contentTransition(.numericText(countsDown: false))
                                .animation(.spring(), value: audioRecorderManager.recordingTime)
                                .padding(.top, 5)
                            
                            Button("Stop Recording") {
                                stopRecording()
                            }
                            .padding(.top, 20)
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.5)), removal: .opacity.combined(with: .scale(scale: 0.8))))
                    } else if !showRecordingUI {
                        HStack(spacing: 15) {
                            Button {
                                startRecording()
                            } label: {
                                HStack {
                                    Image(systemName: "mic.fill")
                                        .matchedGeometryEffect(id: "recordButtonIcon", in: recordingButtonAnimation)
                                    Text("Record")
                                        .matchedGeometryEffect(id: "recordButtonText", in: recordingButtonAnimation)
                                }
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(recordButtonGradient)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                                .shadow(radius: 5)
                            }

                            Button {
                                showingAddNoteView = true
                            } label: {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                    Text("Upload")
                                }
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(uploadButtonGradient)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                                .shadow(radius: 5)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.interactiveSpring(response: 0.5, dampingFraction: 0.7, blendDuration: 0.5), value: isRecording)
                .animation(.easeInOut(duration: 0.4), value: showRecordingUI)
            }
            .navigationTitle("Lumen")
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddNoteView) {
                AddNoteView()
            }
            .sheet(isPresented: $showingChatView) {
                ChatView()
            }
            .sheet(isPresented: $showingSettingsView) {
                SettingsView()
            }
        }
    }

    private func startRecording() {
        withAnimation {
            showRecordingUI = true
            isRecording = true
        }
        audioRecorderManager.startRecording()
    }

    private func stopRecording() {
        let recordingResult = audioRecorderManager.stopRecording()
        
        if let recordedFileURL = recordingResult.audioFileURL {
            if recordingResult.finalTranscription.isEmpty {
                let newNote = Note(
                    title: "Empty Note",
                    creationDate: Date(),
                    audioFilePath: recordedFileURL.absoluteString,
                    transcription: "No speech was detected.",
                    summary: "No speech was detected."
                )
                modelContext.insert(newNote)
                saveContext()
            } else {
                let transcriptionToUse = recordingResult.finalTranscription
                let newNote = Note(
                    title: "Processing Title...",
                    creationDate: Date(),
                    audioFilePath: recordedFileURL.absoluteString,
                    transcription: transcriptionToUse
                )
                modelContext.insert(newNote)
                saveContext()
                
                Task {
                    do {
                        let aiTitle = try await groqService.generateTitle(for: transcriptionToUse)
                        await MainActor.run {
                            newNote.title = aiTitle.isEmpty ? "Untitled Recording" : aiTitle
                            saveContext()
                        }
                    } catch {
                        await MainActor.run {
                            print("Failed to generate title: \(error.localizedDescription)")
                            newNote.title = "Untitled Recording"
                            saveContext()
                        }
                    }
                }
            }
        } else {
            if recordingResult.finalTranscription.isEmpty {
                let newNote = Note(
                    title: "Empty Note",
                    creationDate: Date(),
                    audioFilePath: nil,
                    transcription: "No speech was detected.",
                    summary: "No speech was detected."
                )
                modelContext.insert(newNote)
                saveContext()
            } else {
                let newNote = Note(
                    title: "Processing Title...",
                    creationDate: Date(),
                    audioFilePath: nil,
                    transcription: recordingResult.finalTranscription
                )
                modelContext.insert(newNote)
                saveContext()
                Task {
                    do {
                        let aiTitle = try await groqService.generateTitle(for: recordingResult.finalTranscription)
                        await MainActor.run {
                            newNote.title = aiTitle.isEmpty ? "Transcription Note" : aiTitle
                            saveContext()
                        }
                    } catch {
                        await MainActor.run {
                            print("Failed to generate title for transcription-only note: \(error.localizedDescription)")
                            newNote.title = "Transcription Note"
                            saveContext()
                        }
                    }
                }
            }
        }
        
        withAnimation {
            isRecording = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showRecordingUI = false
            }
        }
        isMicMuted = false
    }

    private func deleteNotes(offsets: IndexSet) {
        withAnimation {
            offsets.map { notes[$0] }.forEach(modelContext.delete)
            saveContext()
        }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save model context: \(error.localizedDescription)")
        }
    }

    private func formatDateWithTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func toggleMute() {
        isMicMuted.toggle()
        if isMicMuted {
            audioRecorderManager.pauseRecordingEngine()
        } else {
            audioRecorderManager.resumeRecordingEngine()
        }
    }
}
