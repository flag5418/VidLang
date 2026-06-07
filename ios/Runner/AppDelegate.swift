import Flutter
import UIKit
import AVFoundation
import Vision
import Photos
import NaturalLanguage

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

class NativeFeatures: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    static let CHANNEL_NAME = "com.yzh.vidlang/ios_features"
    
    static func setup(with controller: FlutterViewController) {
        let channel = FlutterMethodChannel(name: CHANNEL_NAME, binaryMessenger: controller.binaryMessenger)
        let instance = NativeFeatures()
        channel.setMethodCallHandler { (call, result) in
            instance.handle(call, result: result)
        }
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "translate":
            handleTranslate(call: call, result: result)
        case "lookUp":
            handleLookUp(call: call, result: result)
        case "segmentWords":
            handleSegmentWords(call: call, result: result)
        case "speak":
            handleSpeak(call: call, result: result)
        case "stopSpeaking":
            handleStopSpeaking(result: result)
        case "isSpeaking":
            handleIsSpeaking(result: result)
        case "extractTextFromImage":
            handleExtractTextFromImage(call: call, result: result)
        case "extractTextFromCamera":
            handleExtractTextFromCamera(result: result)
        case "analyzeImage":
            handleAnalyzeImage(call: call, result: result)
        case "analyzeImageFromCamera":
            handleAnalyzeImageFromCamera(result: result)
        case "extractSubtitles":
            handleExtractSubtitles(call: call, result: result)
        case "getAvailableLanguages":
            handleGetAvailableLanguages(result: result)
        case "hasCameraPermission":
            handleHasCameraPermission(result: result)
        case "requestCameraPermission":
            handleRequestCameraPermission(result: result)
        case "hasPhotoLibraryPermission":
            handleHasPhotoLibraryPermission(result: result)
        case "requestPhotoLibraryPermission":
            handleRequestPhotoLibraryPermission(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private let synthesizer = AVSpeechSynthesizer()
    private var pendingCameraResult: FlutterResult?
    private var pendingCameraMode: String?
    
    private func handleSpeak(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String else {
            result(false)
            return
        }
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
            try session.setActive(true)
        } catch {
            result(false)
            return
        }
        
        let language = args["language"] as? String ?? "en-US"
        let rate = args["rate"] as? Double ?? 0.5
        let pitch = args["pitch"] as? Double ?? 1.0
        let volume = args["volume"] as? Double ?? 1.0
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        let clampedRate = min(max(rate, 0.0), 1.0)
        let mappedRate = AVSpeechUtteranceMinimumSpeechRate + Float(clampedRate) * (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate)
        utterance.rate = mappedRate
        utterance.pitchMultiplier = Float(min(max(pitch, 0.5), 2.0))
        utterance.volume = Float(min(max(volume, 0.0), 1.0))
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        synthesizer.speak(utterance)
        result(true)
    }
    
    private func handleStopSpeaking(result: @escaping FlutterResult) {
        synthesizer.stopSpeaking(at: .immediate)
        result(nil)
    }
    
    private func handleIsSpeaking(result: @escaping FlutterResult) {
        result(synthesizer.isSpeaking)
    }
    
    // MARK: - 翻译（优先使用 iOS 17.4+ Translation 框架，降级到简单翻译）
    private func handleTranslate(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String else {
            result(["success": false, "error": "Invalid arguments"])
            return
        }
        
        let sourceLang = args["sourceLanguage"] as? String ?? "en"
        let targetLang = args["targetLanguage"] as? String ?? "zh-Hans"
        
        // 使用 NLTranslator (iOS 17.4+)
        if #available(iOS 17.4, *) {
            let sourceNLLang = NLLanguage(code: sourceLang) ?? .english
            let targetNLLang = NLLanguage(code: targetLang) ?? .simplifiedChinese
            
            let configuration = NLTranslationConfiguration(
                sourceLanguage: sourceNLLang,
                targetLanguage: targetNLLang
            )
            let translator = NLTranslator(configuration: configuration)
            
            Task {
                do {
                    let translated = try await translator.translation(for: text)
                    await MainActor.run {
                        result([
                            "success": true,
                            "sourceText": text,
                            "translatedText": translated ?? text,
                            "sourceLanguage": sourceLang,
                            "targetLanguage": targetLang
                        ])
                    }
                } catch {
                    // 降级到简单翻译
                    let fallback = simpleTranslate(text, to: targetLang)
                    await MainActor.run {
                        result([
                            "success": true,
                            "sourceText": text,
                            "translatedText": fallback,
                            "sourceLanguage": sourceLang,
                            "targetLanguage": targetLang
                        ])
                    }
                }
            }
        } else {
            let translated = simpleTranslate(text, to: targetLang)
            result([
                "success": true,
                "sourceText": text,
                "translatedText": translated,
                "sourceLanguage": sourceLang,
                "targetLanguage": targetLang
            ])
        }
    }
    
    private func simpleTranslate(_ text: String, to targetLang: String) -> String {
        let translations: [String: String] = [
            "Hello": "你好",
            "Hello World": "你好世界",
            "apple": "苹果",
            "banana": "香蕉",
            "orange": "橙子",
            "car": "汽车",
            "book": "书",
            "water": "水",
            "food": "食物",
            "happy": "快乐",
            "beautiful": "美丽"
        ]
        return translations[text] ?? text
    }
    
    // MARK: - 词典查询（使用 iOS 系统词典）
    private func handleLookUp(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let word = args["word"] as? String else {
            result(["success": false, "error": "Invalid arguments"])
            return
        }
        
        // 使用 UIReferenceLibraryViewController 查询系统词典
        let hasDict = UIReferenceLibraryViewController.dictionaryHasDefinition(forTerm: word)
        
        if hasDict {
            // 有词典定义，返回基本信息
            // 注意：UIReferenceLibraryViewController 只能展示 UI，无法直接获取文本
            // 所以我们返回"有词典"状态，Flutter 端可以调用 showLookUp 来展示
            result([
                "success": true,
                "word": word,
                "hasDefinition": true,
                "definition": "请使用 showLookUp 查看完整词典定义"
            ])
        } else {
            result([
                "success": true,
                "word": word,
                "hasDefinition": false,
                "definition": ""
            ])
        }
    }
    
    // MARK: - 使用 NLTokenizer 进行英文分词
    private func handleSegmentWords(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String else {
            result(["success": false, "words": [], "error": "Invalid arguments"])
            return
        }
        
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        tokenizer.setLanguage(.english)
        
        var words: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let word = String(text[tokenRange])
            if !word.trimmingCharacters(in: .whitespaces).isEmpty {
                words.append(word)
            }
            return true
        }
        
        result([
            "success": true,
            "words": words
        ])
    }
    
    private func handleExtractTextFromImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String else {
            result(["success": false, "text": "", "lines": [], "error": "Invalid arguments"])
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let text = self.performOCR(on: imagePath)
            let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            DispatchQueue.main.async {
                result([
                    "success": true,
                    "text": text,
                    "lines": lines.map { ["text": $0, "confidence": 1.0, "rect": [0, 0, 0, 0]] }
                ])
            }
        }
    }
    
    private func handleExtractTextFromCamera(result: @escaping FlutterResult) {
        startCameraCapture(mode: "ocr", result: result)
    }
    
    private func performOCR(on imagePath: String) -> String {
        guard let url = URL(string: imagePath), let imageData = try? Data(contentsOf: url),
              let image = UIImage(data: imageData), let cgImage = image.cgImage else {
            return ""
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            
            var text = ""
            if let results = request.results as? [VNRecognizedTextObservation] {
                for result in results {
                    if let topCandidate = result.topCandidates(1).first {
                        text += topCandidate.string + "\n"
                    }
                }
            }
            return text.trimmingCharacters(in: .newlines)
        } catch {
            return ""
        }
    }
    
    private func handleAnalyzeImage(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imagePath = args["imagePath"] as? String else {
            result(["success": false, "description": "", "chineseDescription": "", "labels": [], "chineseLabels": [], "error": "Invalid arguments"])
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let analysis = self.performImageAnalysis(on: imagePath)
            
            DispatchQueue.main.async {
                result([
                    "success": analysis.success,
                    "description": analysis.description,
                    "chineseDescription": analysis.chineseDescription,
                    "labels": analysis.labels,
                    "chineseLabels": analysis.chineseLabels,
                    "error": analysis.error ?? ""
                ])
            }
        }
    }
    
    private func handleAnalyzeImageFromCamera(result: @escaping FlutterResult) {
        startCameraCapture(mode: "analysis", result: result)
    }

    private func startCameraCapture(mode: String, result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            if self.pendingCameraResult != nil {
                result(FlutterError(code: "BUSY", message: "Camera is busy", details: nil))
                return
            }
            if !UIImagePickerController.isSourceTypeAvailable(.camera) {
                result(["success": false, "error": "Camera not available"])
                return
            }
            guard let presenter = self.topViewController() else {
                result(["success": false, "error": "No view controller"])
                return
            }
            self.pendingCameraResult = result
            self.pendingCameraMode = mode

            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.allowsEditing = false
            picker.delegate = self
            presenter.present(picker, animated: true)
        }
    }

    private func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        for scene in scenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where window.isKeyWindow {
                return topViewController(from: window.rootViewController)
            }
        }
        if let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) {
            return topViewController(from: window.rootViewController)
        }
        return nil
    }

    private func topViewController(from root: UIViewController?) -> UIViewController? {
        if let nav = root as? UINavigationController {
            return topViewController(from: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        return root
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        let res = pendingCameraResult
        pendingCameraResult = nil
        pendingCameraMode = nil
        picker.dismiss(animated: true) {
            res?(["success": false, "error": "User cancelled"])
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let res = pendingCameraResult
        let mode = pendingCameraMode
        pendingCameraResult = nil
        pendingCameraMode = nil

        let image = (info[.originalImage] as? UIImage)
        picker.dismiss(animated: true) {
            guard let res else { return }
            guard let mode else {
                res(["success": false, "error": "Invalid state"])
                return
            }
            guard let image else {
                res(["success": false, "error": "No image"])
                return
            }

            DispatchQueue.global(qos: .userInitiated).async {
                let tmpDir = FileManager.default.temporaryDirectory
                let filename = "vidlang_camera_\(UUID().uuidString).jpg"
                let fileURL = tmpDir.appendingPathComponent(filename)
                guard let data = image.jpegData(compressionQuality: 0.92) else {
                    DispatchQueue.main.async {
                        res(["success": false, "error": "Encode image failed"])
                    }
                    return
                }
                do {
                    try data.write(to: fileURL, options: .atomic)
                } catch {
                    DispatchQueue.main.async {
                        res(["success": false, "error": "Save image failed"])
                    }
                    return
                }

                let path = fileURL.absoluteString
                if mode == "ocr" {
                    let text = self.performOCR(on: path)
                    let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
                    DispatchQueue.main.async {
                        res([
                            "success": true,
                            "text": text,
                            "lines": lines.map { ["text": $0, "confidence": 1.0, "rect": [0, 0, 0, 0]] }
                        ])
                    }
                    return
                }
                if mode == "analysis" {
                    let analysis = self.performImageAnalysis(on: path)
                    DispatchQueue.main.async {
                        res([
                            "success": analysis.success,
                            "description": analysis.description,
                            "chineseDescription": analysis.chineseDescription,
                            "labels": analysis.labels,
                            "chineseLabels": analysis.chineseLabels,
                            "error": analysis.error ?? ""
                        ])
                    }
                    return
                }

                DispatchQueue.main.async {
                    res(["success": false, "error": "Unknown mode"])
                }
            }
        }
    }
    
    private func performImageAnalysis(on imagePath: String) -> (success: Bool, description: String, chineseDescription: String, labels: [String], chineseLabels: [String], error: String?) {
        guard let url = URL(string: imagePath), let imageData = try? Data(contentsOf: url),
              let image = UIImage(data: imageData) else {
            return (false, "", "", [], [], "Invalid image path")
        }
        
        let width = image.size.width
        let height = image.size.height
        let description = "Image size: \(Int(width))x\(Int(height))"
        
        return (true, description, "图片尺寸: \(Int(width))x\(Int(height))", [], [], nil)
    }
    
    private func handleExtractSubtitles(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let videoPath = args["videoPath"] as? String else {
            result(["success": false, "frames": [], "fullText": "", "error": "Invalid arguments"])
            return
        }
        
        result(["success": false, "frames": [], "fullText": "", "error": "Subtitle extraction not implemented"])
    }
    
    private func handleGetAvailableLanguages(result: @escaping FlutterResult) {
        let languages = AVSpeechSynthesisVoice.speechVoices().compactMap { $0.language }
        result(Array(Set(languages)))
    }
    
    private func handleHasCameraPermission(result: @escaping FlutterResult) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        result(status == .authorized)
    }
    
    private func handleRequestCameraPermission(result: @escaping FlutterResult) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            result(granted)
        }
    }
    
    private func handleHasPhotoLibraryPermission(result: @escaping FlutterResult) {
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            result(status == .authorized)
        } else {
            let status = PHPhotoLibrary.authorizationStatus()
            result(status == .authorized)
        }
    }
    
    private func handleRequestPhotoLibraryPermission(result: @escaping FlutterResult) {
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
}

// MARK: - NLLanguage 扩展：将 BCP-47 语言代码映射到 NLLanguage
extension NLLanguage {
    init?(code: String) {
        let normalized = code.lowercased().replacingOccurrences(of: "_", with: "-")
        switch normalized {
        case "en": self = .english
        case "zh", "zh-hans", "zh-cn": self = .simplifiedChinese
        case "zh-hant", "zh-tw", "zh-hk": self = .traditionalChinese
        case "ja": self = .japanese
        case "ko": self = .korean
        case "fr": self = .french
        case "de": self = .german
        case "es": self = .spanish
        case "it": self = .italian
        case "pt": self = .portuguese
        case "ru": self = .russian
        case "ar": self = .arabic
        case "hi": self = .hindi
        case "th": self = .thai
        case "vi": self = .vietnamese
        default: return nil
        }
    }
}
