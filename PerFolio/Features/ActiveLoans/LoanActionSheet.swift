import SwiftUI

struct LoanActionSheet: View {
    let action: LoanAction
    @ObservedObject var handler: LoanActionHandler
    var onSuccess: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String = ""
    @State private var localError: String?
    
    var body: some View {
        NavigationStack {
            Form {
                if let message = localError {
                    Text(message)
                        .font(.footnote)
                        .foregroundColor(.red)
                }
                
                Text(action.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                
                if action.requiresAmount {
                    Section(header: Text("Amount (\(action.unit))")) {
                        TextField(action.unit, text: $amountText)
                            .keyboardType(.decimalPad)
                    }
                }
                
                if handler.isPerforming {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Submitting transaction...")
                                .font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle(action.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(handler.isPerforming ? "Working..." : action.confirmTitle) {
                        submit()
                    }
                    .disabled(handler.isPerforming)
                }
            }
            .onAppear {
                amountText = action.defaultAmountText
            }
        }
    }
    
    private func submit() {
        localError = nil
        
        switch action {
        case .close(let position):
            Task {
                do {
                    try await handler.close(position: position)
                    onSuccess()
                    dismiss()
                } catch {
                    localError = error.localizedDescription
                }
            }
        case .payBack(let position):
            guard let amount = decimalAmount() else { return }
            Task {
                do {
                    try await handler.repay(position: position, amount: amount)
                    onSuccess()
                    dismiss()
                } catch {
                    localError = error.localizedDescription
                }
            }
        case .addCollateral(let position):
            guard let amount = decimalAmount() else { return }
            Task {
                do {
                    try await handler.addCollateral(position: position, amount: amount)
                    onSuccess()
                    dismiss()
                } catch {
                    localError = error.localizedDescription
                }
            }
        case .withdrawCollateral(let position):
            guard let amount = decimalAmount() else { return }
            Task {
                do {
                    try await handler.withdraw(position: position, amount: amount)
                    onSuccess()
                    dismiss()
                } catch {
                    localError = error.localizedDescription
                }
            }
        }
    }
    
    private func decimalAmount() -> Decimal? {
        guard let value = Decimal(string: amountText.trimmingCharacters(in: .whitespacesAndNewlines)),
              value > 0 else {
            localError = "Enter a valid amount greater than zero."
            return nil
        }
        return value
    }
}
