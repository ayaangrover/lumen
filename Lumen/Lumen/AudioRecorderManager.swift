import Foundation
import AVFoundation
import Speech

class AudioRecorderManager: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var audioFileURL: URL?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var liveTranscription: String = ""
    @Published var audioLevel: Float = 0.0

    private var timer: Timer?
    private var audioSession: AVAudioSession

    override init() {
        self.audioSession = AVAudioSession.sharedInstance()
        super.init()
        setupSpeechRecognizer()
    }

    private func setupSpeechRecognizer() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
                    print("Speech recognition authorized.")
                case .denied:
                    print("Speech recognition authorization denied.")
                case .restricted:
                    print("Speech recognition restricted.")
                case .notDetermined:
                    print("Speech recognition not determined.")
                @unknown default:
                    fatalError("Unknown SFSpeechRecognizer authorization status.")
                }
            }
        }
    }

    func startRecording() {
        guard !isRecording else {
            print("Already recording.")
            return
        }

        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
            return
        }

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        let inputNode = audioEngine.inputNode
        let documentPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let timestamp = Date().timeIntervalSince1970
        audioFileURL = documentPath.appendingPathComponent("recording-\(timestamp).m4a")
        guard let fileURL = audioFileURL else { return }

        do {
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            audioFile = try AVAudioFile(forWriting: fileURL, settings: recordingFormat.settings)
        } catch {
            print("Could not create audio file for writing: \(error.localizedDescription)")
            return
        }
        
        liveTranscription = ""
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create SFSpeechAudioBufferRecognitionRequest")
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            var isFinal = false
            if let result = result {
                self.liveTranscription = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine?.stop()
                inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
                if isFinal {
                    print("Final transcription: \(self.liveTranscription)")
                }
                if let error = error {
                    print("Speech recognition error: \(error.localizedDescription)")
                }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, when) in
            guard let self = self else { return }
            do {
                try self.audioFile?.write(from: buffer)
                
                self.recognitionRequest?.append(buffer)
                
                let channelData = buffer.floatChannelData?[0]
                let channelDataSize = Int(buffer.frameLength)
                var outEnvelope: Float = 0
                var sum: Float = 0
                if let channelData = channelData {
                    for i in 0..<channelDataSize {
                        sum += fabsf(channelData[i])
                    }
                    outEnvelope = sum / Float(channelDataSize)
                }
                DispatchQueue.main.async {
                    self.audioLevel = outEnvelope * 20
                }

            } catch {
                print("Error writing audio buffer to file or processing: \(error.localizedDescription)")
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            startTimer()
            print("Started recording to: \(fileURL.path)")
        } catch {
            print("Could not start audio engine: \(error.localizedDescription)")
            isRecording = false
            recognitionRequest.endAudio()
            recognitionTask?.cancel()
            recognitionTask = nil
            inputNode.removeTap(onBus: 0)
            return
        }
    }

    func stopRecording() -> (audioFileURL: URL?, finalTranscription: String) {
        guard isRecording else {
            print("Not recording.")
            return (nil, liveTranscription)
        }
        
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioFile = nil
        
        recognitionRequest?.endAudio()

        isRecording = false
        stopTimer()
        audioLevel = 0.0
        
        let finalTranscriptionText = self.liveTranscription

        print("Stopped recording. File at: \(audioFileURL?.path ?? "No path"). Final Transcription: \(finalTranscriptionText)")
        
        return (audioFileURL, finalTranscriptionText)
    }

    func pauseRecordingEngine() {
        guard let engine = audioEngine, engine.isRunning else {
            print("Audio engine is not running or not initialized.")
            return
        }
        engine.pause()
        print("Audio engine paused.")
    }

    func resumeRecordingEngine() {
        guard let engine = audioEngine, !engine.isRunning else {
            if audioEngine == nil {
                print("Audio engine not initialized. Cannot resume.")
            } else if ((audioEngine?.isRunning) != nil) {
                print("Audio engine is already running.")
            }
            return
        }
        do {
            try audioEngine?.start()
            print("Audio engine resumed.")
        } catch {
            print("Error resuming audio engine: \(error.localizedDescription)")
        }
    }

    private func startTimer() {
        recordingTime = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.recordingTime += 1
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    deinit {
        stopTimer()
        if audioEngine?.isRunning ?? false {
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
        recognitionTask?.cancel()
    }
}
