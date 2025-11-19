import Foundation

/// Unified deposit quote that chains Fiat → USDT → PAXG
/// Combines OnMeta (on-ramp) quote with DEX swap quote for seamless UX
struct UnifiedDepositQuote {
    // MARK: - Input
    let fiatCurrency: FiatCurrency
    let fiatAmount: Decimal
    
    // MARK: - Step 1: Fiat → USDT (OnMeta)
    let usdtAmount: Decimal
    let onMetaFee: Decimal
    let exchangeRate: Decimal  // Fiat to USDT rate
    
    // MARK: - Step 2: USDT → PAXG (DEX Swap)
    let paxgAmount: Decimal
    let goldPrice: Decimal     // USDT per PAXG
    let swapFee: Decimal       // Gas cost in USDT
    let priceImpact: Decimal   // Percentage
    let swapRoute: String
    
    // MARK: - Combined
    let totalFees: Decimal     // OnMeta fee + Swap fee (in fiat)
    let effectiveRate: Decimal // Fiat per PAXG
    let estimatedTime: String
    
    // MARK: - Display Helpers
    
    /// Display fiat input amount with symbol
    var displayFiatAmount: String {
        fiatCurrency.format(fiatAmount)
    }
    
    /// Display USDT intermediate amount
    var displayUsdtAmount: String {
        CurrencyFormatter.formatToken(usdtAmount, symbol: "USDT", maxDecimals: 2)
    }
    
    /// Display final PAXG output amount (highlighted)
    var displayPaxgAmount: String {
        CurrencyFormatter.formatToken(paxgAmount, symbol: "PAXG", maxDecimals: 6)
    }
    
    /// Display OnMeta fee in fiat
    var displayOnMetaFee: String {
        fiatCurrency.format(onMetaFee)
    }
    
    /// Display swap fee in fiat
    var displaySwapFee: String {
        let swapFeeInFiat = swapFee * exchangeRate
        return fiatCurrency.format(swapFeeInFiat)
    }
    
    /// Display total fees in fiat
    var displayTotalFees: String {
        fiatCurrency.format(totalFees)
    }
    
    /// Display total fee percentage
    var displayFeePercentage: String {
        guard fiatAmount > 0 else { return "0%" }
        let percentage = (totalFees / fiatAmount) * 100
        return String(format: "%.2f%%", NSDecimalNumber(decimal: percentage).doubleValue)
    }
    
    /// Display effective rate (how much fiat per 1 PAXG)
    var displayEffectiveRate: String {
        "\(fiatCurrency.format(effectiveRate)) per PAXG"
    }
    
    /// Display exchange rate (fiat to USDT)
    var displayExchangeRate: String {
        "1 USDT ≈ \(fiatCurrency.format(exchangeRate))"
    }
    
    /// Display gold price
    var displayGoldPrice: String {
        CurrencyFormatter.formatUSD(goldPrice) + " per PAXG"
    }
    
    /// Display price impact (warn if high)
    var displayPriceImpact: String {
        String(format: "%.2f%%", NSDecimalNumber(decimal: priceImpact).doubleValue)
    }
    
    var isPriceImpactHigh: Bool {
        priceImpact > ServiceConstants.highPriceImpactThreshold
    }
    
    // MARK: - Breakdown for UI
    
    /// Detailed breakdown steps
    var breakdown: [BreakdownStep] {
        [
            BreakdownStep(
                number: "1",
                title: "Buy USDT",
                description: "\(displayFiatAmount) → \(displayUsdtAmount)",
                fee: displayOnMetaFee,
                provider: fiatCurrency.preferredProvider.name
            ),
            BreakdownStep(
                number: "2",
                title: "Swap to PAXG",
                description: "\(displayUsdtAmount) → \(displayPaxgAmount)",
                fee: displaySwapFee,
                provider: "1inch DEX"
            )
        ]
    }
    
    struct BreakdownStep {
        let number: String
        let title: String
        let description: String
        let fee: String
        let provider: String
    }
    
    // MARK: - Summary
    
    /// One-line summary for quick display
    var summary: String {
        "\(displayFiatAmount) → \(displayPaxgAmount) (Fee: \(displayFeePercentage))"
    }
    
    /// Detailed summary for quote card
    var detailedSummary: String {
        """
        You pay: \(displayFiatAmount)
        You receive: \(displayPaxgAmount)
        Effective rate: \(displayEffectiveRate)
        Total fees: \(displayTotalFees) (\(displayFeePercentage))
        Estimated time: \(estimatedTime)
        """
    }
}

// MARK: - Builder (for creating from separate quotes)

extension UnifiedDepositQuote {
    /// Create unified quote from OnMeta and DEX quotes
    static func from(
        fiatCurrency: FiatCurrency,
        fiatAmount: Decimal,
        onMetaQuote: OnMetaService.Quote,
        dexQuote: DEXSwapService.SwapQuote
    ) -> UnifiedDepositQuote {
        // Calculate total fees in fiat
        let swapFeeInFiat = dexQuote.estimatedGasDecimal * onMetaQuote.exchangeRate
        let totalFeesInFiat = onMetaQuote.providerFee + swapFeeInFiat
        
        // Calculate effective rate (fiat per PAXG)
        let effectiveRate = fiatAmount / dexQuote.toAmount
        
        return UnifiedDepositQuote(
            fiatCurrency: fiatCurrency,
            fiatAmount: fiatAmount,
            usdtAmount: onMetaQuote.usdtAmount,
            onMetaFee: onMetaQuote.providerFee,
            exchangeRate: onMetaQuote.exchangeRate,
            paxgAmount: dexQuote.toAmount,
            goldPrice: ServiceConstants.goldPriceUSDT,
            swapFee: dexQuote.estimatedGasDecimal,
            priceImpact: dexQuote.priceImpact,
            swapRoute: dexQuote.route,
            totalFees: totalFeesInFiat,
            effectiveRate: effectiveRate,
            estimatedTime: "10-20 minutes"
        )
    }
}

// MARK: - Validation

extension UnifiedDepositQuote {
    /// Validate quote is within acceptable limits
    var isValid: Bool {
        return fiatAmount > 0 &&
               usdtAmount > 0 &&
               paxgAmount > 0 &&
               !isPriceImpactHigh
    }
    
    /// Get validation warnings
    var warnings: [String] {
        var warnings: [String] = []
        
        if isPriceImpactHigh {
            warnings.append("High price impact: \(displayPriceImpact)")
        }
        
        if totalFees / fiatAmount > 0.05 {  // >5% fees
            warnings.append("High fees: \(displayFeePercentage)")
        }
        
        return warnings
    }
}

