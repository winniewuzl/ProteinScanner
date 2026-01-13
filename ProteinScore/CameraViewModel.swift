import AVFoundation
import Vision
import SwiftUI

class CameraViewModel: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var nutritionData: NutritionData?

    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let visionQueue = DispatchQueue(label: "vision.queue")

    private var lastProcessTime: Date = .distantPast
    private let processingInterval: TimeInterval = 0.5 // Process every 0.5 seconds

    private var lastDetectionTime: Date = .distantPast
    private let fadeOutDelay: TimeInterval = 3.0 // Fade out after 3 seconds
    private var fadeOutTimer: Timer?

    override init() {
        super.init()
        checkAuthorization()
    }

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        default:
            isAuthorized = false
        }
    }

    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .high

            // Setup camera input
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  self.session.canAddInput(input) else {
                print("Failed to setup camera input")
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(input)

            // Setup video output
            self.videoOutput.setSampleBufferDelegate(self, queue: self.visionQueue)
            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]

            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }

            self.session.commitConfiguration()
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
        }
    }

    private func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            self?.handleTextRecognition(request: request, error: error)
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        // Focus on center 70% of frame
        request.regionOfInterest = CGRect(x: 0.15, y: 0.15, width: 0.7, height: 0.7)

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("Failed to perform text recognition: \(error)")
        }
    }

    private func handleTextRecognition(request: VNRequest, error: Error?) {
        if let error = error {
            print("Text recognition error: \(error)")
            return
        }

        guard let observations = request.results as? [VNRecognizedTextObservation] else {
            return
        }

        let recognizedText = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        if !recognizedText.isEmpty {
            print("=== OCR Output ===")
            for (index, text) in recognizedText.enumerated() {
                print("\(index): \(text)")
            }
            print("==================")

            // Parse nutrition data
            if let nutritionData = NutritionParser.parse(from: recognizedText) {
                print("=== Parsed Nutrition ===")
                print("Calories: \(nutritionData.calories)")
                print("Protein: \(nutritionData.protein)g")
                print("Ratio: \(String(format: "%.1f", nutritionData.ratio)) g/100cal")
                print("========================")

                // Update published property on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.nutritionData = nutritionData
                    self.lastDetectionTime = Date()

                    // Cancel existing timer and create new one
                    self.fadeOutTimer?.invalidate()
                    self.fadeOutTimer = Timer.scheduledTimer(withTimeInterval: self.fadeOutDelay, repeats: false) { [weak self] _ in
                        self?.nutritionData = nil
                    }
                }
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) >= processingInterval else {
            return
        }
        lastProcessTime = now

        processFrame(sampleBuffer)
    }
}
