import Foundation

/// Fetches borrow positions directly from the Fluid Vault Resolver so loans
/// survive reinstalls and stay in sync with on-chain data.
@MainActor
final class FluidPositionsService {
    
    private let web3Client: Web3Client
    private let vaultConfigService: VaultConfigService
    private let priceOracleService: PriceOracleService
    
    init(
        web3Client: Web3Client = Web3Client(),
        vaultConfigService: VaultConfigService? = nil,
        priceOracleService: PriceOracleService? = nil
    ) {
        self.web3Client = web3Client
        self.vaultConfigService = vaultConfigService ?? VaultConfigService(web3Client: web3Client)
        self.priceOracleService = priceOracleService ?? PriceOracleService()
    }
    
    func fetchPositions(for owner: String) async throws -> [BorrowPosition] {
        async let configTask = vaultConfigService.fetchVaultConfig()
        async let priceTask = priceOracleService.fetchPAXGPrice()
        async let rawTask = fetchRawPositions(owner: owner)
        
        let (config, paxgPrice, rawPositions) = try await (configTask, priceTask, rawTask)
        
        return rawPositions
            .filter { !$0.isLiquidated && !$0.isSupplyPosition && $0.borrow > 0 }
            .compactMap { raw -> BorrowPosition? in
                let collateralHex = "0x" + raw.collateralHex
                let borrowHex = "0x" + raw.borrowHex
                
                return BorrowPosition.from(
                    nftId: raw.nftId,
                    owner: owner,
                    vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
                    collateralWei: collateralHex,
                    borrowSmallestUnit: borrowHex,
                    paxgPrice: paxgPrice,
                    liquidationThreshold: config.liquidationThreshold,
                    maxLTV: config.maxLTV
                )
            }
    }
    
    // MARK: - Resolver Call
    
    private func fetchRawPositions(owner: String) async throws -> [ResolverPosition] {
        let selector = "919ddbf0"  // keccak256("positionsByUser(address)")
        let cleanOwner = owner.replacingOccurrences(of: "0x", with: "").paddingLeft(to: 64, with: "0")
        let callData = "0x" + selector + cleanOwner
        
        let result = try await web3Client.ethCall(
            to: ContractAddresses.fluidVaultResolver,
            data: callData
        )
        
        guard let data = Data(hexString: result) else {
            return []
        }
        
        return decodeUserPositions(from: data)
    }
    
    private func decodeUserPositions(from data: Data) -> [ResolverPosition] {
        guard let positionsOffset = data.wordToInt(at: 0) else { return [] }
        let lengthOffset = positionsOffset
        guard let length = data.wordToInt(at: lengthOffset) else { return [] }
        
        var positions: [ResolverPosition] = []
        let tupleSize = 12 * 32
        
        for index in 0..<length {
            let base = lengthOffset + 32 + (index * tupleSize)
            guard base + tupleSize <= data.count else { break }
            
            let nftId = data.wordToUIntString(at: base)
            let isLiquidated = data.wordToBool(at: base + 2 * 32)
            let isSupplyPosition = data.wordToBool(at: base + 3 * 32)
            let supplyHex = data.wordHex(at: base + 9 * 32)
            let borrowHex = data.wordHex(at: base + 10 * 32)
            
            positions.append(
                ResolverPosition(
                    nftId: nftId,
                    collateralHex: supplyHex,
                    borrowHex: borrowHex,
                    isLiquidated: isLiquidated,
                    isSupplyPosition: isSupplyPosition
                )
            )
        }
        
        return positions
    }
}

// MARK: - DTOs

private struct ResolverPosition {
    let nftId: String
    let collateralHex: String
    let borrowHex: String
    let isLiquidated: Bool
    let isSupplyPosition: Bool
    
    var borrow: Decimal {
        decimalFromHex(borrowHex, decimals: 6)
    }
}

// MARK: - ABI Helpers

private func decimalFromHex(_ hex: String, decimals: Int) -> Decimal {
    let cleanHex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "0"))
    guard !cleanHex.isEmpty else { return 0 }
    var result: Decimal = 0
    for char in cleanHex {
        if let digit = char.hexDigitValue {
            result = result * 16 + Decimal(digit)
        }
    }
    return result / pow(Decimal(10), decimals)
}

private extension Data {
    init?(hexString: String) {
        let clean = hexString.replacingOccurrences(of: "0x", with: "")
        let length = clean.count
        guard length % 2 == 0 else { return nil }
        
        var data = Data(capacity: length / 2)
        var index = clean.startIndex
        while index < clean.endIndex {
            let nextIndex = clean.index(index, offsetBy: 2)
            let byteString = clean[index..<nextIndex]
            if let byte = UInt8(byteString, radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
            index = nextIndex
        }
        self = data
    }
    
    func wordToInt(at offset: Int) -> Int? {
        guard offset + 32 <= count else { return nil }
        let word = self[offset..<offset + 32]
        let hex = word.map { String(format: "%02x", $0) }.joined()
        return Int(hex, radix: 16)
    }
    
    func wordHex(at offset: Int) -> String {
        guard offset + 32 <= count else { return "0" }
        return self[offset..<offset + 32].map { String(format: "%02x", $0) }.joined()
    }
    
    func wordToUIntString(at offset: Int) -> String {
        let hex = wordHex(at: offset)
        return String(Int(hex, radix: 16) ?? 0)
    }
    
    func wordToBool(at offset: Int) -> Bool {
        guard offset + 32 <= count else { return false }
        return self[offset + 31] == 1
    }
    
    subscript(range: Range<Int>) -> Data {
        self.subdata(in: range)
    }
}
