import SwiftUI
import SwiftData

struct AddNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var noteText: String = ""
    @State private var isProcessing = false
    @State private var showingDocumentPicker = false
    
    private let groqService = GroqService()

    init() {}

    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $noteText)
                    .frame(height: 300)
                    .border(Color.gray.opacity(0.5), width: 1)
                    .padding()

                HStack {
                    Button("Import from File") {
                        showingDocumentPicker = true
                    }
                    .padding()

                    Spacer()

                    Button("Save Note") {
                        processAndSaveNote()
                    }
                    .padding()
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                }
                
                if isProcessing {
                    ProgressView("Processing Note...")
                        .padding()
                }

                Spacer()
            }
            .navigationTitle("Add New Note")
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(documentContent: $noteText)
            }
        }
    }

    private func processAndSaveNote() {
        guard !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isProcessing = true

        Task {
            do {
                let title = try await groqService.generateTitle(for: noteText)
                let summary = try await groqService.generateSummary(for: noteText)

                await MainActor.run {
                    let newNote = Note(
                        title: title.isEmpty ? "Uploaded Note" : title,
                        creationDate: Date(),
                        audioFilePath: nil,
                        transcription: noteText,
                        summary: summary
                    )
                    modelContext.insert(newNote)
                    saveContext()
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    print("Error processing note: \(error.localizedDescription)")
                    let newNote = Note(
                        title: "Uploaded Note (Processing Failed)",
                        creationDate: Date(),
                        audioFilePath: nil,
                        transcription: noteText,
                        summary: "AI processing failed: \(error.localizedDescription)"
                    )
                    modelContext.insert(newNote)
                    saveContext()
                    isProcessing = false
                    dismiss()
                }
            }
        }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            print("Failed to save model context from AddNoteView: \(error.localizedDescription)")
        }
    }
}
