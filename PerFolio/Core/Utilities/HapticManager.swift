import UIKit
import AudioToolbox

/// Centralized haptic feedback manager with user preference support
final class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // MARK: - User Preferences
    
    var isHapticEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: "hapticEnabled") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "hapticEnabled")
        }
    }
    
    var isSoundEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "soundEnabled")
        }
    }
    
    // MARK: - Haptic Generators
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    // MARK: - Public Methods
    
    /// Light impact (button taps, toggles)
    func light() {
        guard isHapticEnabled else { return }
        impactLight.prepare()
        impactLight.impactOccurred()
        playSound(if: isSoundEnabled, type: .light)
    }
    
    /// Medium impact (important actions)
    func medium() {
        guard isHapticEnabled else { return }
        impactMedium.prepare()
        impactMedium.impactOccurred()
        playSound(if: isSoundEnabled, type: .medium)
    }
    
    /// Heavy impact (critical actions, errors)
    func heavy() {
        guard isHapticEnabled else { return }
        impactHeavy.prepare()
        impactHeavy.impactOccurred()
        playSound(if: isSoundEnabled, type: .heavy)
    }
    
    /// Selection change (picker, slider)
    func selection() {
        guard isHapticEnabled else { return }
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
        playSound(if: isSoundEnabled, type: .selection)
    }
    
    /// Success notification
    func success() {
        guard isHapticEnabled else { return }
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
        playSound(if: isSoundEnabled, type: .success)
    }
    
    /// Warning notification
    func warning() {
        guard isHapticEnabled else { return }
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.warning)
        playSound(if: isSoundEnabled, type: .warning)
    }
    
    /// Error notification
    func error() {
        guard isHapticEnabled else { return }
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.error)
        playSound(if: isSoundEnabled, type: .error)
    }
    
    // MARK: - Sound Effects
    
    private enum SoundType {
        case light, medium, heavy, selection, success, warning, error
        
        var systemSoundID: SystemSoundID {
            switch self {
            case .light: return 1519 // Peek
            case .medium: return 1520 // Pop
            case .heavy: return 1521 // Cancelled
            case .selection: return 1104 // Tock
            case .success: return 1054 // SentMessage
            case .warning: return 1053 // ReceivedMessage
            case .error: return 1073 // JBL_Begin
            }
        }
    }
    
    private func playSound(if enabled: Bool, type: SoundType) {
        guard enabled else { return }
        AudioServicesPlaySystemSound(type.systemSoundID)
    }
}

