import SwiftUI
import UniformTypeIdentifiers
import PDFKit 

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var documentContent: String
    var onDismiss: () -> Void = {}
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let supportedTypes: [UTType] = [
            UTType.plainText,
            UTType.text,
            UTType.rtf,
            UTType.utf8PlainText,
            UTType.pdf,
            UTType(importedAs: "org.openxmlformats.wordprocessingml.document"),
            UTType(importedAs: "com.microsoft.word.doc")
        ].compactMap { $0 }
        
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                parent.onDismiss()
                return
            }
            
            let shouldStopAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if shouldStopAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let typeIdentifier = try url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier
                let utType = UTType(typeIdentifier ?? "")

                let docxType = UTType(importedAs: "org.openxmlformats.wordprocessingml.document")
                let docType = UTType(importedAs: "com.microsoft.word.doc")

                if utType?.conforms(to: .pdf) == true {
                    if let pdfDocument = PDFDocument(url: url) {
                        parent.documentContent = pdfDocument.string ?? "Could not extract text from PDF."
                    } else {
                        parent.documentContent = "Failed to load PDF document."
                    }
                } else if (docxType != nil && utType?.conforms(to: docxType) == true) || (docType != nil && utType?.conforms(to: docType) == true) {
                    parent.documentContent = "Text extraction from Word documents (.doc/.docx) is not fully supported. Please convert to plain text or PDF for best results."
                } else if utType?.conforms(to: .text) == true || utType?.conforms(to: .plainText) == true || utType?.conforms(to: .rtf) == true {
                    parent.documentContent = try String(contentsOf: url, encoding: .utf8)
                } else {
                    parent.documentContent = "Unsupported file type. Please select a text file or PDF."
                }
            } catch {
                print("Error processing file: \(error.localizedDescription)")
                parent.documentContent = "Error reading file: \(error.localizedDescription)"
            }
            parent.onDismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onDismiss()
        }
    }
}
