import Foundation
import AppKit

final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Preference Keys
    enum Keys {
        static let appLanguage = "snapmaster_app_language"
        static let appTheme = "snapmaster_app_theme"
        static let saveDirectory = "snapmaster_save_directory"
        static let autoCopyToClipboard = "snapmaster_auto_copy_clipboard"
        static let showFloatingThumbnail = "snapmaster_show_floating_thumbnail"
        static let playCaptureSound = "snapmaster_play_capture_sound"
        static let thumbnailDuration = "snapmaster_thumbnail_duration"
        static let defaultFormat = "snapmaster_default_format"
        static let watermarkEnabled = "snapmaster_watermark_enabled"
        static let watermarkText = "snapmaster_watermark_text"
        static let watermarkOpacity = "snapmaster_watermark_opacity"
        static let beautifyPadding = "snapmaster_beautify_padding"
        static let beautifyCornerRadius = "snapmaster_beautify_corner_radius"
        static let beautifyGradientIndex = "snapmaster_beautify_gradient_index"
    }
    
    @Published var appLanguage: AppLanguage {
        didSet {
            defaults.set(appLanguage.rawValue, forKey: Keys.appLanguage)
            DispatchQueue.main.async {
                MenuBarManager.shared.rebuildMenu()
            }
        }
    }
    
    @Published var appTheme: AppTheme {
        didSet {
            defaults.set(appTheme.rawValue, forKey: Keys.appTheme)
            applyTheme()
        }
    }
    
    @Published var saveDirectory: URL {
        didSet {
            defaults.set(saveDirectory.path, forKey: Keys.saveDirectory)
        }
    }
    
    @Published var autoCopyToClipboard: Bool {
        didSet {
            defaults.set(autoCopyToClipboard, forKey: Keys.autoCopyToClipboard)
        }
    }
    
    @Published var showFloatingThumbnail: Bool {
        didSet {
            defaults.set(showFloatingThumbnail, forKey: Keys.showFloatingThumbnail)
        }
    }
    
    @Published var playCaptureSound: Bool {
        didSet {
            defaults.set(playCaptureSound, forKey: Keys.playCaptureSound)
        }
    }
    
    @Published var thumbnailDuration: Double {
        didSet {
            defaults.set(thumbnailDuration, forKey: Keys.thumbnailDuration)
        }
    }
    
    @Published var defaultFormat: String {
        didSet {
            defaults.set(defaultFormat, forKey: Keys.defaultFormat)
        }
    }
    
    @Published var watermarkEnabled: Bool {
        didSet {
            defaults.set(watermarkEnabled, forKey: Keys.watermarkEnabled)
        }
    }
    
    @Published var watermarkText: String {
        didSet {
            defaults.set(watermarkText, forKey: Keys.watermarkText)
        }
    }
    
    @Published var watermarkOpacity: Double {
        didSet {
            defaults.set(watermarkOpacity, forKey: Keys.watermarkOpacity)
        }
    }
    
    @Published var beautifyPadding: Double {
        didSet {
            defaults.set(beautifyPadding, forKey: Keys.beautifyPadding)
        }
    }
    
    @Published var beautifyCornerRadius: Double {
        didSet {
            defaults.set(beautifyCornerRadius, forKey: Keys.beautifyCornerRadius)
        }
    }
    
    @Published var beautifyGradientIndex: Int {
        didSet {
            defaults.set(beautifyGradientIndex, forKey: Keys.beautifyGradientIndex)
        }
    }
    
    private init() {
        // Language & Theme Initialization
        if let langStr = defaults.string(forKey: Keys.appLanguage),
           let lang = AppLanguage(rawValue: langStr) {
            self.appLanguage = lang
        } else {
            // Mặc định Tiếng Việt
            self.appLanguage = .vietnamese
        }
        
        if let themeStr = defaults.string(forKey: Keys.appTheme),
           let theme = AppTheme(rawValue: themeStr) {
            self.appTheme = theme
        } else {
            self.appTheme = .system
        }
        
        // Default Save Directory: ~/Pictures/SnapMaster
        let picturesURL = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first!
        let defaultSnapDir = picturesURL.appendingPathComponent("SnapMaster", isDirectory: true)
        
        if let savedPath = defaults.string(forKey: Keys.saveDirectory) {
            self.saveDirectory = URL(fileURLWithPath: savedPath)
        } else {
            self.saveDirectory = defaultSnapDir
        }
        
        self.autoCopyToClipboard = defaults.object(forKey: Keys.autoCopyToClipboard) as? Bool ?? true
        self.showFloatingThumbnail = defaults.object(forKey: Keys.showFloatingThumbnail) as? Bool ?? true
        self.playCaptureSound = defaults.object(forKey: Keys.playCaptureSound) as? Bool ?? true
        self.thumbnailDuration = defaults.object(forKey: Keys.thumbnailDuration) as? Double ?? 5.0
        self.defaultFormat = defaults.string(forKey: Keys.defaultFormat) ?? "png"
        self.watermarkEnabled = defaults.bool(forKey: Keys.watermarkEnabled)
        self.watermarkText = defaults.string(forKey: Keys.watermarkText) ?? "Created with SnapMaster"
        self.watermarkOpacity = defaults.object(forKey: Keys.watermarkOpacity) as? Double ?? 0.8
        self.beautifyPadding = defaults.object(forKey: Keys.beautifyPadding) as? Double ?? 32.0
        self.beautifyCornerRadius = defaults.object(forKey: Keys.beautifyCornerRadius) as? Double ?? 16.0
        self.beautifyGradientIndex = defaults.integer(forKey: Keys.beautifyGradientIndex)
        
        createSaveDirectoryIfNeeded()
        applyTheme()
    }
    
    /// Áp dụng theme lên toàn bộ giao diện macOS AppKit
    func applyTheme() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch self.appTheme {
            case .system:
                NSApp.appearance = nil
            case .light:
                NSApp.appearance = NSAppearance(named: .aqua)
            case .dark:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            }
        }
    }
    
    func createSaveDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: saveDirectory.path) {
            try? FileManager.default.createDirectory(at: saveDirectory, withIntermediateDirectories: true)
        }
    }
    
    func generateTimestampedFilename(prefix: String = "Capture", ext: String = "png") -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        let timestamp = formatter.string(from: Date())
        let filename = "\(prefix)_\(timestamp).\(ext)"
        return saveDirectory.appendingPathComponent(filename)
    }
}
