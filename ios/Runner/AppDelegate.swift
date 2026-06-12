import Flutter
import UIKit
import AVFoundation
import Vision
import Photos
import NaturalLanguage
import Speech

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

// ============================================================
// NativeFeatures — iOS 原生能力
// ============================================================
class NativeFeatures: NSObject, UIImagePickerControllerDelegate,
                      UINavigationControllerDelegate, SFSpeechRecognizerDelegate {

    static let CHANNEL_NAME = "com.yzh.vidlang/ios_features"

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
        case "lookUp":                  handleLookUp(call, result)
        case "segmentWords":            handleSegmentWords(call, result)
        case "speak":                   handleSpeak(call, result)
        case "stopSpeaking":            handleStopSpeaking(result)
        case "isSpeaking":              handleIsSpeaking(result)
        case "extractTextFromImage":    handleExtractTextFromImage(call, result)
        case "extractTextFromCamera":   handleExtractTextFromCamera(result)
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
    // 说明：iOS 18 Translation API 是 SwiftUI 专用（TranslationSession 需挂载到 View），
    //      无法从 FlutterMethodChannel 调用。翻译能力由 Flutter 端的 NativeService
    //      （付费→AiService→Edge Function Qwen，免费→系统词典+简单翻译）统一处理。
    //      这里提供简单降级：英文→中文通用词映射 + 返回原文。
    private func handleTranslate(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let text = args["text"] as? String, !text.isEmpty else {
            result(["success": false, "error": "Invalid arguments"])
            return
        }
        let sourceLang = args["sourceLanguage"] as? String ?? "en"
        let targetLang = args["targetLanguage"] as? String ?? "zh-Hans"

        // 简单降级翻译（英文→中文常用词）
        let translated: String
        if sourceLang.hasPrefix("en") && targetLang.hasPrefix("zh") {
            translated = simpleTranslateENtoZH(text)
        } else {
            translated = text
        }

        result(["success": true, "sourceText": text, "translatedText": translated,
                "sourceLanguage": sourceLang, "targetLanguage": targetLang])
    }

    private func simpleTranslateENtoZH(_ text: String) -> String {
        let dict: [String: String] = [
            "hello": "你好", "world": "世界", "good": "好的", "bad": "坏的",
            "love": "爱", "friend": "朋友", "family": "家庭", "time": "时间",
            "day": "天", "night": "夜晚", "morning": "早晨", "evening": "傍晚",
            "happy": "快乐", "sad": "悲伤", "big": "大", "small": "小",
            "hot": "热", "cold": "冷", "new": "新", "old": "旧",
            "beautiful": "美丽", "important": "重要", "different": "不同",
            "yes": "是", "no": "不", "please": "请", "thank": "谢谢",
            "sorry": "抱歉", "welcome": "欢迎", "goodbye": "再见",
            "water": "水", "food": "食物", "home": "家", "work": "工作",
            "school": "学校", "book": "书", "music": "音乐", "art": "艺术",
            "science": "科学", "history": "历史", "nature": "自然",
            "people": "人们", "child": "孩子", "man": "男人", "woman": "女人",
            "name": "名字", "place": "地方", "idea": "想法", "story": "故事",
            "question": "问题", "answer": "答案", "problem": "困难",
        ]
        let lower = text.lowercased()
        if let match = dict[lower] { return match }
        // 短语逐词翻译
        let words = lower.split(separator: " ")
        let translatedWords = words.map { dict[String($0)] ?? String($0) }
        let joined = translatedWords.joined(separator: " ")
        return joined != lower ? joined : text
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
