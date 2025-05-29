import Foundation
import SwiftData

@Model
final class Note {
    var id: UUID
    var title: String 
    var creationDate: Date
    var audioFilePath: String?
    var transcription: String?
    var summary: String?

    init(id: UUID = UUID(),
         title: String = "Processing Title...",
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
