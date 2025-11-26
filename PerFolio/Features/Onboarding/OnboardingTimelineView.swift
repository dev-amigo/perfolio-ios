import SwiftUI

/// Game Center-style onboarding timeline view for first-time users
struct OnboardingTimelineView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @EnvironmentObject var themeManager: ThemeManager
    
    // Callback for navigation
    var onNavigate: ((String) -> Void)?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - Always visible
            headerView
                .onTapGesture {
                    viewModel.toggleExpanded()
                }
            
            // Expandable content
            if viewModel.isExpanded {
                timelineContent
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                    ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "4A90E2").opacity(0.9),
                            Color(hex: "357ABD").opacity(0.9)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
            
            // Title and progress
            VStack(alignment: .leading, spacing: 4) {
                Text("Get Started")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("\(viewModel.completedStepsCount) of \(viewModel.totalSteps) steps completed")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
            
            Spacer()
            
            // Progress circle and chevron
            HStack(spacing: 12) {
                // Progress circle
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                        .frame(width: 32, height: 32)
                    
                    Circle()
                        .trim(from: 0, to: viewModel.progressPercentage)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 32, height: 32)
                        .rotationEffect(.degrees(-90))
                    
                    if viewModel.allStepsCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                
                // Expand/collapse chevron
                Image(systemName: viewModel.isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(viewModel.isExpanded ? 0 : 180))
            }
        }
        .padding(16)
    }
    
    // MARK: - Timeline Content
    
    private var timelineContent: some View {
        VStack(spacing: 12) {
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 16)
            
            // Steps
            VStack(spacing: 12) {
                ForEach(viewModel.getSteps(navigationHandler: handleNavigation), id: \.number) { step in
                    TimelineStepCard(
                        stepNumber: step.number,
                        title: step.title,
                        description: step.description,
                        actionTitle: step.actionTitle,
                        isCompleted: step.isCompleted,
                        action: step.action
                    )
                    .environmentObject(themeManager)
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Navigation Handler
    
    private func handleNavigation(_ destination: String) {
        AppLogger.log("📍 Navigating to: \(destination)", category: "onboarding")
        onNavigate?(destination)
        
        // Collapse after navigation
        if viewModel.isExpanded {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                viewModel.toggleExpanded()
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ScrollView {
            OnboardingTimelineView { destination in
                print("Navigate to: \(destination)")
            }
        }
    }
    .environmentObject(ThemeManager())
}

