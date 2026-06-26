import Flutter
import UIKit
import AVFoundation
import Vision
import Photos
import NaturalLanguage
import Speech
import Translation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var nativeFeaturesSetup = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    DispatchQueue.main.async { [weak self] in
      self?.setupNativeFeaturesIfPossible()
    }
    return ok
  }

  // 修复 Failed to change device orientation 的问题
  // 根据 Flutter 控制器当前的旋转设置，动态返回支持的方向
  override func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
      if let rootViewController = self.window?.rootViewController {
          if let flutterViewController = rootViewController as? FlutterViewController {
              // FlutterViewController 通常会自动处理方向，但为了避免 iOS 16+ 抛出异常
              // 我们返回 .allButUpsideDown，让 Flutter 内部的 SystemChrome.setPreferredOrientations 去控制具体的旋转
              return .allButUpsideDown
          }
      }
      return .portrait
  }

  private func setupNativeFeaturesIfPossible() {
    if nativeFeaturesSetup { return }
    if let controller = window?.rootViewController as? FlutterViewController {
      NativeFeatures.setup(with: controller)
      nativeFeaturesSetup = true
      return
    }
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      for w in windowScene.windows {
        if let controller = w.rootViewController as? FlutterViewController {
          NativeFeatures.setup(with: controller)
          nativeFeaturesSetup = true
          return
        }
        if let nav = w.rootViewController as? UINavigationController,
           let controller = nav.viewControllers.first as? FlutterViewController {
          NativeFeatures.setup(with: controller)
          nativeFeaturesSetup = true
          return
        }
      }
    }
  }
}

// ============================================================
// NativeFeatures — iOS 原生能力
// ============================================================
class NativeFeatures: NSObject, UIImagePickerControllerDelegate,
                      UINavigationControllerDelegate, SFSpeechRecognizerDelegate {

    static let CHANNEL_NAME = "com.yzh.vidlang/ios_features"
    private static var preparedTranslationPairs: Set<String> = []

    static func setup(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: CHANNEL_NAME,
            binaryMessenger: controller.binaryMessenger
        )
        let instance = NativeFeatures()
        channel.setMethodCallHandler { call, result in
            instance.handle(call, result: result)
        }
    }

    // ── 路由 ──
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "translate":               handleTranslate(call, result)
        case "openAppSettings":         handleOpenAppSettings(result)
        case "lookUp":                  handleLookUp(call, result)
        case "segmentWords":            handleSegmentWords(call, result)
        case "speak":                   handleSpeak(call, result)
        case "stopSpeaking":            handleStopSpeaking(result)
        case "isSpeaking":              handleIsSpeaking(result)
        case "extractTextFromImage":    handleExtractTextFromImage(call, result)
        case "extractTextFromCamera":   handleExtractTextFromCamera(result)
        case "openCameraTranslatePage": handleOpenCameraTranslatePage(result)
        case "analyzeImage":            handleAnalyzeImage(call, result)
        case "analyzeImageFromCamera":  handleAnalyzeImageFromCamera(result)
        case "extractSubtitles":        handleExtractSubtitles(call, result)
        case "getAvailableLanguages":   handleGetAvailableLanguages(result)
        case "hasCameraPermission":     handleHasCameraPermission(result)
        case "requestCameraPermission": handleRequestCameraPermission(result)
        case "hasPhotoLibraryPermission":      handleHasPhotoLibraryPermission(result)
        case "requestPhotoLibraryPermission":   handleRequestPhotoLibraryPermission(result)
        case "hasSpeechPermission":            handleHasSpeechPermission(result)
        case "requestSpeechPermission":        handleRequestSpeechPermission(result)
        case "startSpeechRecognition":         handleStartSpeechRecognition(result)
        case "stopSpeechRecognition":          handleStopSpeechRecognition(result)
        case "isSpeechRecognitionAvailable":   handleIsSpeechRecognitionAvailable(result)
        case "getDeviceIdiom":                  handleGetDeviceIdiom(result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleOpenAppSettings(_ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            guard let url = URL(string: UIApplication.openSettingsURLString),
                  UIApplication.shared.canOpenURL(url) else {
                result(false); return
            }
            UIApplication.shared.open(url, options: [:]) { ok in
                result(ok)
            }
        }
    }

    // ─────────── TTS ───────────
    private let synthesizer = AVSpeechSynthesizer()

    private func handleSpeak(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String else {
            result(false); return
        }
        do {
            let s = AVAudioSession.sharedInstance()
            try s.setCategory(.playback, mode: .spokenAudio,
                              options: [.duckOthers, .mixWithOthers])
            try s.setActive(true)
        } catch { result(false); return }

        let lang = args["language"] as? String ?? "en-US"
        let rate = args["rate"] as? Double ?? 0.5
        let pitch = args["pitch"] as? Double ?? 1.0

        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: lang)
        let cr = min(max(rate, 0.0), 1.0)
        u.rate = AVSpeechUtteranceMinimumSpeechRate +
            Float(cr) * (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate)
        u.pitchMultiplier = Float(min(max(pitch, 0.5), 2.0))

        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        synthesizer.speak(u)
        result(true)
    }

    private func handleStopSpeaking(_ result: @escaping FlutterResult) {
        synthesizer.stopSpeaking(at: .immediate)
        result(nil)
    }
    private func handleIsSpeaking(_ result: @escaping FlutterResult) {
        result(synthesizer.isSpeaking)
    }

    // ─────────── 翻译 ───────────
    private func handleTranslate(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String, !text.isEmpty else {
            result(["success": false, "error": "Invalid arguments"])
            return
        }

        let sourceLang = args["sourceLanguage"] as? String ?? "en"
        let targetLang = args["targetLanguage"] as? String ?? "zh-Hans"

        if #available(iOS 26.0, macOS 15.0, *) {
            Task {
                do {
                    let source = Locale.Language(identifier: sourceLang)
                    let target = Locale.Language(identifier: targetLang)
                    let session = try TranslationSession(installedSource: source, target: target)

                    let pairKey = "\(sourceLang)->\(targetLang)"
                    if !NativeFeatures.preparedTranslationPairs.contains(pairKey) {
                        do {
                            try await session.prepareTranslation()
                            NativeFeatures.preparedTranslationPairs.insert(pairKey)
                        } catch {
                            result(["success": false, "error": "Translation language download failed: \(error.localizedDescription)"])
                            return
                        }
                    }

                    let response = try await session.translate(text)
                    result([
                        "success": true,
                        "sourceText": text,
                        "translatedText": response.targetText,
                        "sourceLanguage": sourceLang,
                        "targetLanguage": targetLang
                    ])
                } catch {
                    result(["success": false, "error": "Translation failed: \(error.localizedDescription)"])
                }
            }
        } else {
            result(["success": false, "error": "iOS 26+ required for native translation. Please use AI translation mode."])
        }
    }

    // MARK: - 词典查询
    private func handleLookUp(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let word = args["word"] as? String else {
            result(["success": false, "error": "Invalid arguments"]); return
        }
        let has = UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word)
        result(["success": true, "word": word, "hasDefinition": has,
                "definition": has ? "系统词典有定义" : ""])
    }

    // MARK: - 分词
    private func handleSegmentWords(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String else {
            result(["success": false, "words": []]); return
        }
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(.english)
        var words: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let w = String(text[range]).trimmingCharacters(in: .whitespaces)
            if !w.isEmpty { words.append(w) }
            return true
        }
        result(["success": true, "words": words])
    }

    // MARK: - OCR
    private func handleExtractTextFromImage(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String else {
            result(["success": false, "text": "", "lines": []]); return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let text = self.performOCR(on: imagePath)
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            DispatchQueue.main.async {
                result(["success": true, "text": text,
                        "lines": lines.map { ["text": $0, "confidence": 1.0, "rect": [0,0,0,0]] }])
            }
        }
    }

    private func handleExtractTextFromCamera(_ result: @escaping FlutterResult) {
        startCameraCapture(mode: "ocr", result: result)
    }

    private func handleOpenCameraTranslatePage(_ result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            guard let vc = self.topViewController() else {
                result(["success": false, "text": "", "lines": [], "error": "No view controller"])
                return
            }
            let cameraVC = CameraTranslateViewController()
            cameraVC.onResult = { ocrResult in
                result(ocrResult)
            }
            cameraVC.onCancel = {
                result(["success": false, "text": "", "lines": [], "error": "User cancelled"])
            }
            vc.present(cameraVC, animated: true)
        }
    }

    private func performOCR(on imagePath: String) -> String {
        guard let url = URL(string: imagePath),
              let data = try? Data(contentsOf: url),
              let img = UIImage(data: data)?.cgImage else { return "" }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = .accurate
        req.usesLanguageCorrection = true
        do {
            try VNImageRequestHandler(cgImage: img, options: [:]).perform([req])
            return (req.results as? [VNRecognizedTextObservation])?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n") ?? ""
        } catch { return "" }
    }

    // MARK: - 图片分析（占位）
    private func handleAnalyzeImage(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        result(["success": false, "description": "", "chineseDescription": "",
                "labels": [], "chineseLabels": [], "error": "Not implemented"])
    }
    private func handleAnalyzeImageFromCamera(_ result: @escaping FlutterResult) {
        startCameraCapture(mode: "analysis", result: result)
    }

    // MARK: - 字幕提取（占位）
    private func handleExtractSubtitles(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        result(["success": false, "error": "Not implemented"])
    }

    // MARK: - 语言列表
    private func handleGetAvailableLanguages(_ result: @escaping FlutterResult) {
        result(Array(Set(AVSpeechSynthesisVoice.speechVoices().map { $0.language })))
    }

    // MARK: - 权限
    private func handleHasCameraPermission(_ result: @escaping FlutterResult) {
        result(AVCaptureDevice.authorizationStatus(for: .video) == .authorized)
    }
    private func handleRequestCameraPermission(_ result: @escaping FlutterResult) {
        AVCaptureDevice.requestAccess(for: .video) { result($0) }
    }
    private func handleHasPhotoLibraryPermission(_ result: @escaping FlutterResult) {
        if #available(iOS 14, *) {
            result(PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized)
        } else {
            result(PHPhotoLibrary.authorizationStatus() == .authorized)
        }
    }
    private func handleRequestPhotoLibraryPermission(_ result: @escaping FlutterResult) {
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                result(status == .authorized)
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                result(status == .authorized)
            }
        }
    }

    // ─────────── 语音识别（跟读）───────────
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var pendingSpeechResult: FlutterResult?

    private func handleHasSpeechPermission(_ result: @escaping FlutterResult) {
        result(SFSpeechRecognizer.authorizationStatus() == .authorized)
    }
    private func handleRequestSpeechPermission(_ result: @escaping FlutterResult) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async { result(status == .authorized) }
        }
    }
    private func handleIsSpeechRecognitionAvailable(_ result: @escaping FlutterResult) {
        result(SFSpeechRecognizer.authorizationStatus() == .authorized)
    }

    // MARK: - Device Info
    private func handleGetDeviceIdiom(_ result: @escaping FlutterResult) {
        let idiom = UIDevice.current.userInterfaceIdiom
        result(idiom == .pad ? "pad" : "phone")
    }

    private func handleStartSpeechRecognition(_ result: @escaping FlutterResult) {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            result(["success": false, "error": "speech_permission_denied",
                    "message": "请在设置中开启语音识别权限"]); return
        }
        stopRecognition()

        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
        guard let r = speechRecognizer, r.isAvailable else {
            result(["success": false, "error": "recognizer_unavailable",
                    "message": "语音识别器不可用"]); return
        }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            result(["success": false, "error": "audio_session_error",
                    "message": error.localizedDescription]); return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let req = recognitionRequest else {
            result(["success": false, "error": "request_error",
                    "message": "无法创建识别请求"]); return
        }
        req.shouldReportPartialResults = true
        req.taskHint = .dictation

        let inputNode = audioEngine.inputNode
        let fmt = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: fmt) { buffer, _ in
            req.append(buffer)
        }

        var last = ""
        pendingSpeechResult = result

        recognitionTask = r.recognitionTask(with: req) { [weak self] r, err in
            guard let self else { return }
            if let err {
                DispatchQueue.main.async {
                    self.pendingSpeechResult?(["success": false, "error": "recognition_error",
                                               "message": err.localizedDescription])
                    self.pendingSpeechResult = nil
                    self.stopRecognition()
                }
                return
            }
            let text = r?.bestTranscription.formattedString ?? ""
            let isFinal = r?.isFinal ?? false
            if !text.isEmpty && text != last {
                last = text
                DispatchQueue.main.async {
                    self.pendingSpeechResult?(["success": true, "partial": !isFinal,
                                               "text": text, "isFinal": isFinal])
                }
            }
            if isFinal {
                DispatchQueue.main.async {
                    self.pendingSpeechResult = nil
                    self.stopRecognition()
                }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            result(["success": false, "error": "audio_engine_error",
                    "message": error.localizedDescription])
            stopRecognition()
        }
    }

    private func handleStopSpeechRecognition(_ result: @escaping FlutterResult) {
        stopRecognition()
        result(true)
    }

    private func stopRecognition() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        speechRecognizer = nil
        pendingSpeechResult = nil
    }

    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer,
                          availabilityDidChange available: Bool) {}

    // ─────────── 相机 ───────────
    private var pendingCameraResult: FlutterResult?
    private var pendingCameraMode: String?

    private func startCameraCapture(mode: String, result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            if self.pendingCameraResult != nil {
                result(FlutterError(code: "BUSY", message: "Camera busy", details: nil))
                return
            }
            guard UIImagePickerController.isSourceTypeAvailable(.camera),
                  let vc = self.topViewController() else {
                result(["success": false, "error": "Camera unavailable"])
                return
            }
            self.pendingCameraResult = result
            self.pendingCameraMode = mode
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.allowsEditing = false
            picker.delegate = self
            vc.present(picker, animated: true)
        }
    }

    private func topViewController() -> UIViewController? {
        for scene in UIApplication.shared.connectedScenes {
            if let ws = scene as? UIWindowScene {
                for w in ws.windows where w.isKeyWindow {
                    return topViewController(from: w.rootViewController)
                }
            }
        }
        if let w = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            return topViewController(from: w.rootViewController)
        }
        return nil
    }

    private func topViewController(from root: UIViewController?) -> UIViewController? {
        if let nav = root as? UINavigationController { return topViewController(from: nav.visibleViewController) }
        if let tab = root as? UITabBarController { return topViewController(from: tab.selectedViewController) }
        if let p = root?.presentedViewController { return topViewController(from: p) }
        return root
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        let r = pendingCameraResult
        pendingCameraResult = nil; pendingCameraMode = nil
        picker.dismiss(animated: true) { r?(["success": false, "error": "User cancelled"]) }
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        let r = pendingCameraResult
        let mode = pendingCameraMode
        pendingCameraResult = nil; pendingCameraMode = nil
        let img = info[.originalImage] as? UIImage
        picker.dismiss(animated: true) {
            guard let r, let mode, let img else { r?(["success": false]); return }
            DispatchQueue.global(qos: .userInitiated).async {
                let dir = FileManager.default.temporaryDirectory
                let fn = "vidlang_\(UUID().uuidString).jpg"
                let url = dir.appendingPathComponent(fn)
                guard let d = img.jpegData(compressionQuality: 0.92) else {
                    DispatchQueue.main.async { r(["success": false, "error": "Encode failed"]) }; return
                }
                do { try d.write(to: url, options: .atomic) } catch {
                    DispatchQueue.main.async { r(["success": false, "error": "Write failed"]) }; return
                }
                let path = url.absoluteString
                if mode == "ocr" {
                    let text = self.performOCR(on: path)
                    let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    DispatchQueue.main.async {
                        r(["success": true, "text": text,
                           "lines": lines.map { ["text": $0, "confidence": 1.0, "rect": [0,0,0,0]] }])
                    }
                } else {
                    DispatchQueue.main.async { r(["success": false, "error": "Unknown mode"]) }
                }
            }
        }
    }
}

// ============================================================
// CameraTranslateViewController — 拍照翻译原生页面
// 类似 iPhone 翻译 App 的相机模式：
// - 实时相机预览 + Vision OCR 识别文字
// - 在照片上叠加显示识别到的文字和翻译
// - 点击识别文字可划词查义
// - 支持重新拍照
// ============================================================
class CameraTranslateViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var onResult: (([String: Any]) -> Void)?
    var onCancel: (() -> Void)?

    private var captureSession: AVCaptureSession?
    private var photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var overlayView: CameraTranslateOverlayView!

    // Live OCR
    private var ocrRequest = VNRecognizeTextRequest()
    private var lastOCRText = ""
    private var isProcessingPhoto = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCamera()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupUI() {
        view.backgroundColor = .black

        // Overlay for recognized text + translation
        overlayView = CameraTranslateOverlayView()
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.onRetap = { [weak self] in self?.retakePhoto() }
        overlayView.onWordTap = { [weak self] word in self?.handleWordTap(word) }
        view.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Top bar: back button
        let topBar = UIView()
        topBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topBar)
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44),
        ])

        let backBtn = UIButton(type: .system)
        backBtn.setImage(UIImage(systemName: "arrow.backward"), for: .normal)
        backBtn.tintColor = .white
        backBtn.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        backBtn.layer.cornerRadius = 18
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        backBtn.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        topBar.addSubview(backBtn)
        NSLayoutConstraint.activate([
            backBtn.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 16),
            backBtn.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            backBtn.widthAnchor.constraint(equalToConstant: 36),
            backBtn.heightAnchor.constraint(equalToConstant: 36),
        ])

        let titleLabel = UILabel()
        titleLabel.text = "拍照翻译"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: backBtn.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
        ])

        // Bottom bar: capture button
        let bottomBar = UIView()
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.addSubview(bottomBar)
        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 120),
        ])

        let captureBtn = UIButton(type: .system)
        captureBtn.backgroundColor = .white
        captureBtn.layer.cornerRadius = 35
        captureBtn.layer.borderWidth = 4
        captureBtn.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        captureBtn.translatesAutoresizingMaskIntoConstraints = false
        captureBtn.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        bottomBar.addSubview(captureBtn)
        NSLayoutConstraint.activate([
            captureBtn.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            captureBtn.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor, constant: -10),
            captureBtn.widthAnchor.constraint(equalToConstant: 70),
            captureBtn.heightAnchor.constraint(equalToConstant: 70),
        ])
    }

    private func setupCamera() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        do {
            let input = try AVCaptureDeviceInput(device: device)
            session.addInput(input)
        } catch { return }

        session.addOutput(photoOutput)

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(preview, at: 0)
        previewLayer = preview

        // Setup live OCR
        ocrRequest.recognitionLevel = .accurate
        ocrRequest.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    @objc private func backTapped() {
        dismiss(animated: true)
        onCancel?()
    }

    @objc private func capturePhoto() {
        if isProcessingPhoto { return }
        isProcessingPhoto = true
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func retakePhoto() {
        overlayView.reset()
        captureSession?.startRunning()
        // Remove the captured photo layer if any
        if let sublayers = view.layer.sublayers {
            for layer in sublayers {
                if layer is CALayer && layer !== previewLayer && layer.delegate === nil && layer.contents != nil {
                    layer.removeFromSuperlayer()
                }
            }
        }
    }

    // AVCapturePhotoCaptureDelegate
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        isProcessingPhoto = false
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            // Perform OCR on captured photo
            guard let cgImage = image.cgImage else { return }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            var observations: [VNRecognizedTextObservation] = []
            do {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])
                observations = request.results as? [VNRecognizedTextObservation] ?? []
            } catch { return }

            let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }

            // Build word-level results with bounding boxes
            var wordResults: [[String: Any]] = []
            let imgWidth = CGFloat(cgImage.width)
            let imgHeight = CGFloat(cgImage.height)
            for obs in observations {
                guard let candidate = obs.topCandidates(1).first else { continue }
                let bbox = obs.boundingBox
                // Vision bbox is normalized 0-1, origin bottom-left
                let rect = [
                    Int(bbox.origin.x * imgWidth),
                    Int((1 - bbox.origin.y - bbox.height) * imgHeight),
                    Int(bbox.width * imgWidth),
                    Int(bbox.height * imgHeight)
                ] as [Int]
                wordResults.append([
                    "text": candidate.string,
                    "confidence": candidate.confidence,
                    "rect": rect,
                ])
            }

            DispatchQueue.main.async {
                // Stop camera, show captured photo
                self.captureSession?.stopRunning()

                // Show captured image as background
                let imageView = UIImageView(image: image)
                imageView.contentMode = .scaleAspectFill
                imageView.frame = self.view.bounds
                imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                self.view.insertSubview(imageView, at: 0)

                // Update overlay with recognized text
                self.overlayView.updateWithResult(text: text, lines: wordResults)

                // Also return result to Flutter via callback
                self.onResult?([
                    "success": true,
                    "text": text,
                    "lines": lines.map { ["text": $0, "confidence": 1.0, "rect": [0,0,0,0]] },
                ])
            }
        }
    }

    private func handleWordTap(_ word: String) {
        // Word tap on native overlay — could show system dictionary
        let has = UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word)
        if has, let vc = topViewController() {
            let dictVC = UIReferenceLibraryViewController(term: word)
            let nav = UINavigationController(rootViewController: dictVC)
            vc.present(nav, animated: true)
        }
    }

    private func topViewController() -> UIViewController? {
        var vc: UIViewController? = self
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }
}

// ============================================================
// CameraTranslateOverlayView — 叠加在相机/照片上的文字识别+翻译视图
// ============================================================
class CameraTranslateOverlayView: UIView {
    var onRetap: (() -> Void)?
    var onWordTap: ((String) -> Void)?

    private var scrollView: UIScrollView!
    private var textLabel: UILabel!
    private var translationLabel: UILabel!
    private var retakeBtn: UIButton!
    private var resultContainer: UIView!
    private var hasResult = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupSubviews()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupSubviews() {
        backgroundColor = .clear

        // Result container (hidden initially)
        resultContainer = UIView()
        resultContainer.translatesAutoresizingMaskIntoConstraints = false
        resultContainer.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        resultContainer.layer.cornerRadius = 16
        resultContainer.isHidden = true
        addSubview(resultContainer)
        NSLayoutConstraint.activate([
            resultContainer.topAnchor.constraint(equalTo: topAnchor, constant: 52),
            resultContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            resultContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            resultContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -130),
        ])

        scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        resultContainer.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: resultContainer.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: resultContainer.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: resultContainer.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: resultContainer.bottomAnchor, constant: -12),
        ])

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // Recognized text
        textLabel = UILabel()
        textLabel.textColor = .white
        textLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        textLabel.textAlignment = .center
        textLabel.numberOfLines = 0
        textLabel.isUserInteractionEnabled = true
        stack.addArrangedSubview(textLabel)

        // Add tap gesture for word lookup
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTextTap(_:)))
        textLabel.addGestureRecognizer(tapGesture)

        // Translation
        translationLabel = UILabel()
        translationLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        translationLabel.font = UIFont.systemFont(ofSize: 16)
        translationLabel.textAlignment = .center
        translationLabel.numberOfLines = 0
        translationLabel.isHidden = true
        stack.addArrangedSubview(translationLabel)

        // Retake button (bottom)
        retakeBtn = UIButton(type: .system)
        retakeBtn.setTitle("重新拍照", for: .normal)
        retakeBtn.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        retakeBtn.tintColor = .white
        retakeBtn.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        retakeBtn.layer.cornerRadius = 20
        retakeBtn.translatesAutoresizingMaskIntoConstraints = false
        retakeBtn.addTarget(self, action: #selector(retakeTapped), for: .touchUpInside)
        retakeBtn.isHidden = true
        addSubview(retakeBtn)
        NSLayoutConstraint.activate([
            retakeBtn.centerXAnchor.constraint(equalTo: centerXAnchor),
            retakeBtn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -40),
            retakeBtn.widthAnchor.constraint(equalToConstant: 140),
            retakeBtn.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    func updateWithResult(text: String, lines: [[String: Any]]) {
        hasResult = true
        resultContainer.isHidden = false
        retakeBtn.isHidden = false
        textLabel.text = text

        // Try to translate using system Translation API
        translateText(text)
    }

    func reset() {
        hasResult = false
        resultContainer.isHidden = true
        retakeBtn.isHidden = true
        textLabel.text = nil
        translationLabel.text = nil
        translationLabel.isHidden = true
    }

    private func translateText(_ text: String) {
        if #available(iOS 26.0, *) {
            Task {
                do {
                    let source = Locale.Language(identifier: "en")
                    let target = Locale.Language(identifier: "zh-Hans")
                    let session = try TranslationSession(installedSource: source, target: target)
                    try await session.prepareTranslation()
                    let response = try await session.translate(text)
                    DispatchQueue.main.async { [weak self] in
                        self?.translationLabel.text = response.targetText
                        self?.translationLabel.isHidden = false
                    }
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        self?.translationLabel.isHidden = true
                    }
                }
            }
        }
    }

    @objc private func retakeTapped() {
        onRetap?()
    }

    @objc private func handleTextTap(_ gesture: UITapGestureRecognizer) {
        guard let label = gesture.view as? UILabel,
              let text = label.text, !text.isEmpty else { return }

        let location = gesture.location(in: label)
        let index = closestCharacterIndex(to: location, in: label)

        // Find the word at the tap location
        let characters = Array(text)
        var start = index
        var end = index

        // Expand to word boundaries
        while start > 0 && characters[start - 1].isLetter { start -= 1 }
        while end < characters.count - 1 && characters[end + 1].isLetter { end += 1 }

        let word = String(characters[start...end]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !word.isEmpty && word.allSatisfy({ $0.isLetter }) {
            onWordTap?(word)
        }
    }

    private func closestCharacterIndex(to point: CGPoint, in label: UILabel) -> Int {
        guard let text = label.text, !text.isEmpty else { return 0 }
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage(attributedString: label.attributedText ?? NSAttributedString(string: text))
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: label.bounds.size)
        textContainer.lineBreakMode = label.lineBreakMode
        textContainer.maximumNumberOfLines = label.numberOfLines
        layoutManager.addTextContainer(textContainer)

        let index = layoutManager.characterIndex(for: point, in: textContainer, fractionOfDistanceBetweenInsertionPoints: nil)
        return min(index, text.count - 1)
    }
}
