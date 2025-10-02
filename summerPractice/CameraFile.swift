//
//  CameraFile.swift
//  summerPractice
//
//  Created by Ильмир Шарафутдинов on 24.07.2025.
//

import SwiftUI
import AVFoundation
import MediaPipeTasksVision

// MARK: - Возможные действия
enum GestureAction: String {
    case playPause = "▶️⏸ Пауза/Плей"
    case nextScreen = "➡️ Следующий экран"
    case like = "❤️ Лайк"
    case select = "✅ Выбор элемента"
    case stop = "⏹ Стоп"
}

// MARK: - Основное окно камеры
struct CameraView: View {
    @ObservedObject var model: CameraModel
    var showCloseButton: Bool = true
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            CameraPreview(session: model.session)
                .ignoresSafeArea()
            
            VStack {
                if showCloseButton {
                    HStack {
                        Spacer()
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .padding()
                        }
                    }
                }
                
                Spacer()
                
                VStack(spacing: 10) {
                    Text(model.gesture)
                        .font(.system(size: 60, weight: .bold))
                        .padding()
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(10)
                    
                    if let action = model.lastAction {
                        Text(action.rawValue)
                            .font(.title2)
                            .foregroundColor(.yellow)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .onAppear { model.startSession() }
        .onDisappear { model.stopSession() }
        .alert("Ошибка", isPresented: .constant(model.lastError != nil)) {
            Button("OK") { model.lastError = nil }
        } message: {
            Text(model.lastError?.localizedDescription ?? "")
        }
    }
}

// MARK: - Превью камеры
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}

// MARK: - Модель камеры
final class CameraModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let mediaPipeQueue = DispatchQueue(label: "mediapipe.processing.queue")
    
    @Published var gesture: String = ""
    @Published var lastError: Error?
    @Published var lastAction: GestureAction?
    
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    
    private var handLandmarker: HandLandmarker?
    private var landmarkerDelegate: HandLandmarkerDelegate?
    
    private var gestureHistory: [String] = []
    private var gestureStartTime: Date?
    private let minHoldDuration: TimeInterval = 0.3
    private let minRepeatCount = 3
    
    override init() {
        super.init()
        setupCamera()
        setupMediaPipe()
    }
    
    // MARK: - Настройка камеры
    private func setupCamera() {
        sessionQueue.async {
            do {
                try self.configureCaptureSession()
            } catch {
                self.handleError(error)
            }
        }
    }
    
    private func configureCaptureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw CameraError.deviceUnavailable
        }
        
        try device.lockForConfiguration()
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        device.unlockForConfiguration()
        
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.inputConfigurationFailed }
        session.addInput(input)
        
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(videoOutput) else { throw CameraError.outputConfigurationFailed }
        session.addOutput(videoOutput)
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        
        if let connection = videoOutput.connection(with: .video) {
            connection.videoOrientation = .portrait
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = true
            }
        }
    }
    
    // MARK: - Настройка MediaPipe
    private func setupMediaPipe() {
        mediaPipeQueue.async {
            do {
                try self.configureHandLandmarker()
                print("✅ MediaPipe инициализирован")
            } catch {
                self.handleError(error)
            }
        }
    }
    
    private func configureHandLandmarker() throws {
        guard let modelPath = Bundle.main.path(forResource: "hand_landmarker", ofType: "task") else {
            throw CameraError.modelNotFound
        }
        
        let options = try HandLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .liveStream
        options.numHands = 2
        options.minHandDetectionConfidence = 0.7
        options.minTrackingConfidence = 0.5
        
        self.landmarkerDelegate = HandLandmarkerDelegate(model: self)
        options.handLandmarkerLiveStreamDelegate = landmarkerDelegate
        self.handLandmarker = try HandLandmarker(options: options)
    }
    
    // MARK: - Сессия
    func startSession() {
        sessionQueue.async {
            guard !self.session.isRunning else { return }
            self.session.startRunning()
        }
    }
    
    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }
    
    // MARK: - Обработка кадров
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        mediaPipeQueue.async {
            self.processFrame(sampleBuffer: sampleBuffer)
        }
    }
    
    private func processFrame(sampleBuffer: CMSampleBuffer) {
        guard let handLandmarker = handLandmarker else {
            DispatchQueue.main.async { self.gesture = "MediaPipe не готов" }
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            DispatchQueue.main.async { self.gesture = "Ошибка видеобуфера" }
            return
        }
        
        do {
            let image = try MPImage(pixelBuffer: pixelBuffer, orientation: .up)
            let timestampMs = Int(Date().timeIntervalSince1970 * 1000)
            try handLandmarker.detectAsync(image: image, timestampInMilliseconds: timestampMs)
        } catch {
            self.handleError(error)
        }
    }
    
    // MARK: - Обработка результатов
    func processHandLandmarks(_ result: HandLandmarkerResult) {
        DispatchQueue.main.async {
            if result.landmarks.isEmpty {
                self.gesture = "✋ Рука не найдена"
                return
            }
            
            var detectedGestures: [String] = []
            for landmarks in result.landmarks {
                detectedGestures.append(self.detectGestures(from: landmarks))
            }
            
            let combined = detectedGestures.joined(separator: " + ")
            self.gesture = combined
            self.handleGesture(combined)
        }
    }
    
    private func handleGesture(_ currentGesture: String) {
        let now = Date()
        if gestureHistory.last != currentGesture {
            gestureHistory.removeAll()
            gestureStartTime = now
        }
        gestureHistory.append(currentGesture)
        
        if let start = gestureStartTime, now.timeIntervalSince(start) >= minHoldDuration {
            if gestureHistory.suffix(minRepeatCount).allSatisfy({ $0 == currentGesture }) {
                performAction(for: currentGesture)
                gestureHistory.removeAll()
                gestureStartTime = nil
            }
        }
    }
    
    private func detectGestures(from landmarks: [NormalizedLandmark]) -> String {
        let thumbTip = landmarks[4], indexTip = landmarks[8]
        let middleTip = landmarks[12], ringTip = landmarks[16], pinkyTip = landmarks[20]
        let indexMCP = landmarks[5], middleMCP = landmarks[9], ringMCP = landmarks[13], pinkyMCP = landmarks[17]
        let thumbIP = landmarks[3], wrist = landmarks[0]
        
        func isFingerOpen(tip: NormalizedLandmark, mcp: NormalizedLandmark) -> Bool { tip.y < mcp.y }
        func isFingerClosed(tip: NormalizedLandmark, mcp: NormalizedLandmark) -> Bool { tip.y > mcp.y }
        
        // 👍 Лайк
        let thumbUp = thumbTip.y < thumbIP.y && thumbTip.x < wrist.x + 0.2
        let fingersFolded = isFingerClosed(tip: indexTip, mcp: indexMCP) &&
                            isFingerClosed(tip: middleTip, mcp: middleMCP) &&
                            isFingerClosed(tip: ringTip, mcp: ringMCP) &&
                            isFingerClosed(tip: pinkyTip, mcp: pinkyMCP)
        if thumbUp && fingersFolded { return "👍" }
        
        // 🖐️ Ладонь
        let allOpen = isFingerOpen(tip: indexTip, mcp: indexMCP) &&
                      isFingerOpen(tip: middleTip, mcp: middleMCP) &&
                      isFingerOpen(tip: ringTip, mcp: ringMCP) &&
                      isFingerOpen(tip: pinkyTip, mcp: pinkyMCP)
        if allOpen { return "🖐️" }
        
        // 👊 Кулак
        let allClosed = isFingerClosed(tip: indexTip, mcp: indexMCP) &&
                        isFingerClosed(tip: middleTip, mcp: middleMCP) &&
                        isFingerClosed(tip: ringTip, mcp: ringMCP) &&
                        isFingerClosed(tip: pinkyTip, mcp: pinkyMCP)
        if allClosed { return "👊" }
        
        // ✌️ Виктори
        let indexOpen = isFingerOpen(tip: indexTip, mcp: indexMCP)
        let middleOpen = isFingerOpen(tip: middleTip, mcp: middleMCP)
        let ringClosed = isFingerClosed(tip: ringTip, mcp: ringMCP)
        let pinkyClosed = isFingerClosed(tip: pinkyTip, mcp: pinkyMCP)
        if indexOpen && middleOpen && ringClosed && pinkyClosed { return "✌️" }
        
        // 👆 Указательный
        let indexUp = indexTip.y < landmarks[6].y
        let middleFolded = middleTip.y > landmarks[10].y
        let ringFolded = ringTip.y > landmarks[14].y
        let pinkyFolded = pinkyTip.y > landmarks[18].y
        if indexUp && middleFolded && ringFolded && pinkyFolded { return "👆" }
        
        return "🤷"
    }
    
    private func performAction(for gesture: String) {
        switch gesture {
        case "👊": lastAction = .playPause
        case "✌️": lastAction = .nextScreen
        case "👍": lastAction = .like
        case "🖐️": lastAction = .stop
        default: return
        }
        print("🎬 Действие: \(lastAction!.rawValue)")
    }
    
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.lastError = error
            print("❌ Ошибка: \(error.localizedDescription)")
        }
    }
    
    private class HandLandmarkerDelegate: NSObject, HandLandmarkerLiveStreamDelegate {
        weak var model: CameraModel?
        init(model: CameraModel) { self.model = model }
        
        func handLandmarker(_ handLandmarker: HandLandmarker,
                            didFinishDetection result: HandLandmarkerResult?,
                            timestampInMilliseconds: Int,
                            error: Error?) {
            if let error = error {
                self.model?.handleError(error)
                return
            }
            guard let result = result else {
                self.model?.handleError(CameraError.noResults)
                return
            }
            self.model?.processHandLandmarks(result)
        }
    }
    
    enum CameraError: Error, LocalizedError {
        case deviceUnavailable, inputConfigurationFailed, outputConfigurationFailed
        case modelNotFound, noResults, permissionDenied
        
        var errorDescription: String? {
            switch self {
            case .deviceUnavailable: return "Камера недоступна"
            case .inputConfigurationFailed: return "Ошибка входа"
            case .outputConfigurationFailed: return "Ошибка выхода"
            case .modelNotFound: return "Модель не найдена"
            case .noResults: return "Нет результатов"
            case .permissionDenied: return "Нет доступа к камере"
            }
        }
    }
}
