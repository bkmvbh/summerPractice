//
//  CameraFile.swift
//  summerPractice
//
//  Created by Ильмир Шарафутдинов on 24.07.2025.
//

import SwiftUI
import AVFoundation
import MediaPipeTasksVision
import SwiftUI

struct CameraView: View {
    @StateObject private var model = CameraModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Превью камеры
            CameraPreview(session: model.session)
                .ignoresSafeArea()
            
            // Интерфейс
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                Spacer()
                
                // Отображение жеста
                Text(model.gesture)
                    .font(.system(size: 60, weight: .bold))
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(10)
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

import AVFoundation
import MediaPipeTasksVision

final class CameraModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // MARK: - Конфигурация
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let mediaPipeQueue = DispatchQueue(label: "mediapipe.processing.queue")
    
    // MARK: - Свойства
    @Published var gesture: String = ""
    @Published var lastError: Error?
    
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var handLandmarker: HandLandmarker?
    private var landmarkerDelegate: HandLandmarkerDelegate?
    
    // MARK: - Жизненный цикл
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
        
        // 1. Настройка устройства
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                 for: .video,
                                                 position: .front) else {
            throw CameraError.deviceUnavailable
        }
        
        // 2. Настройка формата
        try device.lockForConfiguration()
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        device.unlockForConfiguration()
        
        // 3. Добавление входа
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.inputConfigurationFailed }
        session.addInput(input)
        
        // 4. Настройка выхода
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(videoOutput) else { throw CameraError.outputConfigurationFailed }
        session.addOutput(videoOutput)
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        
        // 5. Настройка соединения
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
                print("✅ MediaPipe успешно инициализирован")
            } catch {
                self.handleError(error)
            }
        }
    }
    
    private func configureHandLandmarker() throws {
        // 1. Проверка модели
        guard let modelPath = Bundle.main.path(forResource: "hand_landmarker", ofType: "task") else {
            throw CameraError.modelNotFound
        }
        
        // 2. Настройка опций
        let options = try HandLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .liveStream
        options.numHands = 1
        options.minHandDetectionConfidence = 0.7
        options.minTrackingConfidence = 0.5
        
        // 3. Настройка делегата
        self.landmarkerDelegate = HandLandmarkerDelegate(model: self)
        options.handLandmarkerLiveStreamDelegate = landmarkerDelegate
        
        // 4. Инициализация
        self.handLandmarker = try HandLandmarker(options: options)
    }
    
    // MARK: - Управление сессией
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
    func captureOutput(_ output: AVCaptureOutput,
                     didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
        mediaPipeQueue.async {
            self.processFrame(sampleBuffer: sampleBuffer)
        }
    }
    
    private func processFrame(sampleBuffer: CMSampleBuffer) {
        // 1. Проверка состояния
        guard self.handLandmarker != nil else {
            DispatchQueue.main.async {
                self.gesture = "MediaPipe не готов"
            }
            return
        }
        
        // 2. Получение изображения
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            DispatchQueue.main.async {
                self.gesture = "Ошибка видеобуфера"
            }
            return
        }
        
        // 3. Обработка кадра
        do {
            let image = try MPImage(pixelBuffer: pixelBuffer, orientation: .up)
            let timestampMs = Int(Date().timeIntervalSince1970 * 1000)
            
            try self.handLandmarker?.detectAsync(image: image, timestampInMilliseconds: timestampMs)
        } catch {
            self.handleError(error)
        }
    }
    
    // MARK: - Обработка результатов
    func processHandLandmarks(_ result: HandLandmarkerResult) {
        DispatchQueue.main.async {
            guard let landmarks = result.landmarks.first else {
                self.gesture = "✋ Рука не найдена"
                return
            }
            
            self.detectGestures(from: landmarks)
        }
    }
    
    private func detectGestures(from landmarks: [NormalizedLandmark]) {
        // 1. Основные точки
        let thumbTip = landmarks[4]
        let indexTip = landmarks[8]
        let middleTip = landmarks[12]
        let ringTip = landmarks[16]
        let pinkyTip = landmarks[20]
        
        // 2. Жест "Кулак" 👊
        let thumbIndexDistance = hypot(thumbTip.x - indexTip.x, thumbTip.y - indexTip.y)
        if thumbIndexDistance < 0.05 {
            self.gesture = "👊 Кулак"
            return
        }
        
        // 3. Жест "виктори" ✌️
        if indexTip.y < middleTip.y && middleTip.y < ringTip.y && middleTip.y < pinkyTip.y {
            self.gesture = "✌️ Виктори"
            return
        }
        
        // 4. По умолчанию - открытая ладонь
        self.gesture = "🖐️ Ладонь"
    }
    
    // MARK: - Обработка ошибок
    private func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.lastError = error
            print("❌ Ошибка: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Вложенные типы
    private class HandLandmarkerDelegate: NSObject, HandLandmarkerLiveStreamDelegate {
        weak var model: CameraModel?
        
        init(model: CameraModel) {
            self.model = model
        }
        
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
        case deviceUnavailable
        case inputConfigurationFailed
        case outputConfigurationFailed
        case modelNotFound
        case noResults
        case permissionDenied
        
        var errorDescription: String? {
            switch self {
            case .deviceUnavailable: return "Камера недоступна"
            case .inputConfigurationFailed: return "Ошибка настройки входа"
            case .outputConfigurationFailed: return "Ошибка настройки выхода"
            case .modelNotFound: return "Модель не найдена"
            case .noResults: return "Нет результатов распознавания"
            case .permissionDenied: return "Нет доступа к камере"
            }
        }
    }
}
