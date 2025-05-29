import SwiftUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Note.creationDate, order: .reverse) private var notes: [Note]
    @Query(sort: \ChatMessageModel.timestamp, order: .forward) private var persistedMessages: [ChatMessageModel]

    @State private var currentMessage: String = ""
    @State private var isSendingMessage = false
    
    private let groqService = GroqService()

    var body: some View {
        NavigationView {
            VStack {
                ScrollViewReader { scrollViewProxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(persistedMessages) { message in
                                MessageView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .onChange(of: persistedMessages.count) { _ in
                        if let lastMessage = persistedMessages.last {
                            withAnimation {
                                scrollViewProxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                HStack {
                    TextField("Ask something...", text: $currentMessage, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...5)
                        .padding(.leading)

                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                    }
                    .padding(.trailing)
                    .disabled(currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSendingMessage)
                }
                .padding(.bottom)
                .padding(.top, 5)
                
                if isSendingMessage {
                    ProgressView("Thinking...")
                        .padding(.bottom)
                }
            }
            .navigationTitle("AI Chat")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: Button("Close") {
                dismiss()
            })
            .onAppear {
                if persistedMessages.isEmpty {
                    let greetingMessage = ChatMessageModel(role: .assistant, content: "Hello! How can I help you today? I have access to your notes.")
                    modelContext.insert(greetingMessage)
                }
            }
        }
    }

    private func sendMessage() {
        let userMessageContent = currentMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userMessageContent.isEmpty else { return }

        let userMessage = ChatMessageModel(role: .user, content: userMessageContent)
        modelContext.insert(userMessage)
        
        currentMessage = ""
        isSendingMessage = true

        Task {
            do {
                let notesContext = prepareNotesContext()
                let assistantResponseContent = try await groqService.generateChatResponse(prompt: userMessageContent, notesContext: notesContext, chatHistory: persistedMessages)
                
                await MainActor.run {
                    let assistantMessage = ChatMessageModel(role: .assistant, content: assistantResponseContent)
                    modelContext.insert(assistantMessage)
                    isSendingMessage = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessageModel(role: .assistant, content: "Sorry, I encountered an error: \(error.localizedDescription)")
                    modelContext.insert(errorMessage)
                    isSendingMessage = false
                }
            }
        }
    }
    
    private func prepareNotesContext() -> String {
        var context = "User's Notes Context:\n"
        if notes.isEmpty {
            context += "The user currently has no notes.\n"
        } else {
            for note in notes {
                context += "Note Title: \(note.title)\n"
                if let transcription = note.transcription, !transcription.isEmpty {
                    context += "Transcription/Content: \(transcription)\n"
                }
                if let summary = note.summary, !summary.isEmpty {
                    context += "Summary: \(summary)\n"
                }
                context += "---\n"
            }
        }
        return context
    }
}

struct MessageView: View {
    let message: ChatMessageModel
    
    private func attributedString(from markdown: String) -> AttributedString {
        var attributedString = AttributedString()
        var currentIndex = markdown.startIndex

        while let boldStartRange = markdown[currentIndex...].firstRange(of: "**") {
            if boldStartRange.lowerBound > currentIndex {
                attributedString.append(AttributedString(markdown[currentIndex..<boldStartRange.lowerBound]))
            }
            
            currentIndex = boldStartRange.upperBound
            if let boldEndRange = markdown[currentIndex...].firstRange(of: "**") {
                var boldContent = AttributedString(markdown[currentIndex..<boldEndRange.lowerBound])
                boldContent.font = .system(.body).bold()
                attributedString.append(boldContent)
                currentIndex = boldEndRange.upperBound
            } else {
                attributedString.append(AttributedString(markdown[boldStartRange.lowerBound...]))
                currentIndex = markdown.endIndex
                break
            }
        }

        if currentIndex < markdown.endIndex {
            attributedString.append(AttributedString(markdown[currentIndex...]))
        }
        
        if attributedString.runs.isEmpty && !markdown.isEmpty && markdown.firstRange(of: "**") == nil {
            return AttributedString(markdown)
        }

        return attributedString
    }

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
                Text(attributedString(from: message.content))
                    .padding(15)
                    .background(Color.blue.opacity(0.8))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .trailing)
            } else {
                Text(attributedString(from: message.content))
                    .padding(15)
                    .background(Color(UIColor.secondarySystemBackground))
                    .foregroundColor(Color(UIColor.label))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: .leading)
                Spacer()
            }
        }
    }
}
