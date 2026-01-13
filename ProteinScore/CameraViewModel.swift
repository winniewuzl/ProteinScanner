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

    // Temporal smoothing buffer for anti-jitter
    private var recentReadings: [NutritionData] = []
    private let smoothingBufferSize = 5  // Keep last 5 readings

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

            // Setup camera input with macro mode support
            let camera = self.getBestCameraDevice()

            guard let camera = camera,
                  let input = try? AVCaptureDeviceInput(device: camera),
                  self.session.canAddInput(input) else {
                print("Failed to setup camera input")
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(input)

            // Configure camera focus settings
            self.configureCameraFocus(camera)

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

    private func getBestCameraDevice() -> AVCaptureDevice? {
        // Try to get triple camera (iPhone 13 Pro+ with macro mode)
        if let tripleCamera = AVCaptureDevice.default(.builtInTripleCamera, for: .video, position: .back) {
            return tripleCamera
        }

        // Fallback to dual camera
        if let dualCamera = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
            return dualCamera
        }

        // Fallback to wide angle
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }

    private func configureCameraFocus(_ camera: AVCaptureDevice) {
        do {
            try camera.lockForConfiguration()

            // Enable continuous autofocus for close-up scanning
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }

            // Enable subject area change monitoring for automatic refocus
            if camera.isSubjectAreaChangeMonitoringEnabled {
                camera.isSubjectAreaChangeMonitoringEnabled = true
            }

            // Enable auto exposure for varying lighting conditions
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }

            camera.unlockForConfiguration()
        } catch {
            print("Failed to configure camera focus: \(error)")
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

        // OCR Precision Tuning
        request.recognitionLevel = .accurate  // Force accurate mode for font variations
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.015  // Filter out fine print noise (1.5% of image height)

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

        // Group observations into rows based on Y-coordinate
        let groupedRows = groupObservationsIntoRows(observations)

        if !groupedRows.isEmpty {
            print("=== OCR Output (Row-Grouped) ===")
            for (index, row) in groupedRows.enumerated() {
                print("\(index): \(row)")
            }
            print("==================================")

            // Parse nutrition data
            if let nutritionData = NutritionParser.parse(from: groupedRows) {
                print("=== Parsed Nutrition ===")
                print("Calories: \(nutritionData.calories)")
                print("Protein: \(nutritionData.protein)g")
                print("Ratio: \(String(format: "%.1f", nutritionData.ratio)) g/100cal")
                print("========================")

                // Add to smoothing buffer and get median
                let smoothedData = self.addToSmoothingBuffer(nutritionData)

                // Update published property on main thread
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.nutritionData = smoothedData
                    self.lastDetectionTime = Date()

                    // Cancel existing timer and create new one
                    self.fadeOutTimer?.invalidate()
                    self.fadeOutTimer = Timer.scheduledTimer(withTimeInterval: self.fadeOutDelay, repeats: false) { [weak self] _ in
                        self?.nutritionData = nil
                        self?.recentReadings.removeAll()  // Clear buffer when hiding
                    }
                }
            }
        }
    }

    private func addToSmoothingBuffer(_ newReading: NutritionData) -> NutritionData {
        // Add new reading to buffer
        recentReadings.append(newReading)

        // Keep only last N readings
        if recentReadings.count > smoothingBufferSize {
            recentReadings.removeFirst()
        }

        // Need at least 3 readings for meaningful median
        guard recentReadings.count >= 3 else {
            return newReading
        }

        // Calculate median calories and protein
        let sortedCalories = recentReadings.map { $0.calories }.sorted()
        let sortedProtein = recentReadings.map { $0.protein }.sorted()

        let medianCalories = sortedCalories[sortedCalories.count / 2]
        let medianProtein = sortedProtein[sortedProtein.count / 2]

        return NutritionData(calories: medianCalories, protein: medianProtein)
    }

    private func groupObservationsIntoRows(_ observations: [VNRecognizedTextObservation]) -> [String] {
        // Create array of (text, midY, minX) tuples
        struct TextItem {
            let text: String
            let midY: CGFloat
            let minX: CGFloat
        }

        let items: [TextItem] = observations.compactMap { observation in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            let bounds = observation.boundingBox
            let midY = bounds.midY
            let minX = bounds.minX
            return TextItem(text: text, midY: midY, minX: minX)
        }

        guard !items.isEmpty else { return [] }

        // Sort by Y coordinate (top to bottom)
        let sortedByY = items.sorted { $0.midY > $1.midY }  // Vision uses bottom-left origin

        // Group items into rows (within 2% vertical threshold)
        var rows: [[TextItem]] = []
        let verticalThreshold: CGFloat = 0.02

        for item in sortedByY {
            if let lastRow = rows.last,
               let lastItem = lastRow.first,
               abs(item.midY - lastItem.midY) < verticalThreshold {
                // Add to existing row
                rows[rows.count - 1].append(item)
            } else {
                // Start new row
                rows.append([item])
            }
        }

        // Sort each row by X coordinate (left to right) and join text
        let joinedRows = rows.map { row -> String in
            let sortedRow = row.sorted { $0.minX < $1.minX }
            return sortedRow.map { $0.text }.joined(separator: " ")
        }

        return joinedRows
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
