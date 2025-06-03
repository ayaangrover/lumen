import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID = UUID()
    var title: String = "Untitled"
    var creationDate: Date = Date()
    var audioFilePath: String? = nil
    var transcription: String? = nil
    var summary: String? = nil

    init(id: UUID = UUID(),
         title: String = "Untitled",
         creationDate: Date = Date(),
         audioFilePath: String? = nil,
         transcription: String? = nil,
         summary: String? = nil) {
        self.id = id
        self.title = title
        self.creationDate = creationDate
        self.audioFilePath = audioFilePath
        self.transcription = transcription
        self.summary = summary
    }
}
