import SwiftUI
import PhoenixShared

extension Encodable {
	func jsonEncode() -> Data? {
		return try? JSONEncoder().encode(self)
	}
}

extension Data {
	func jsonDecode<Element: Decodable>() -> Element? {
		return try? JSONDecoder().decode(Element.self, from: self)
	}
}

/**
 * Here we define various types stored in UserDefaults, which conform to `Codable`.
 */

enum CurrencyType: String, CaseIterable, Codable {
	case fiat
	case bitcoin
}

enum Theme: String, CaseIterable, Codable {
	case light
	case dark
	case system
	
	func localized() -> String {
		switch self {
		case .light  : return NSLocalizedString("Light", comment: "App theme option")
		case .dark   : return NSLocalizedString("Dark", comment: "App theme option")
		case .system : return NSLocalizedString("System", comment: "App theme option")
		}
	}
	
	func toInterfaceStyle() -> UIUserInterfaceStyle {
		switch self {
		case .light  : return .light
		case .dark   : return .dark
		case .system : return .unspecified
		}
	}
	
	func toColorScheme() -> ColorScheme? {
		switch self {
		case .light  : return ColorScheme.light
		case .dark   : return ColorScheme.dark
		case .system : return nil
		}
	}
}

enum PushPermissionQuery: String, Codable {
	case neverAskedUser
	case userDeclined
	case userAccepted
}

struct ElectrumConfigPrefs: Equatable, Codable {
	let host: String
	let port: UInt16
	let pinnedPubKey: String?
	
	private let version: Int // for potential future upgrades
	
	init(host: String, port: UInt16, pinnedPubKey: String?) {
		self.host = host
		self.port = port
		self.pinnedPubKey = pinnedPubKey
		self.version = 2
	} 
	
	var serverAddress: Lightning_kmpServerAddress {
		if let pinnedPubKey = pinnedPubKey {
			return Lightning_kmpServerAddress(
				host : host,
				port : Int32(port),
				tls  : Lightning_kmpTcpSocketTLS.PINNED_PUBLIC_KEY(pubKey: pinnedPubKey)
			)
		} else {
			return Lightning_kmpServerAddress(
				host : host,
				port : Int32(port),
				tls  : Lightning_kmpTcpSocketTLS.TRUSTED_CERTIFICATES(expectedHostName: nil)
			)
		}
	}

}

struct LiquidityPolicy: Equatable, Codable {
	let maxFeeSats: Int64?
	let maxFeeBasisPoints: Int32?
	
	static func emptyPolicy() -> LiquidityPolicy {
		return LiquidityPolicy(
			maxFeeSats: nil,
			maxFeeBasisPoints: nil
		)
	}
	
	var effectiveMaxFeeSats: Int64 {
		return maxFeeSats ?? NodeParamsManager.companion.defaultLiquidityPolicy.maxAbsoluteFee.sat
	}
	
	var effectiveMaxFeeBasisPoints: Int32 {
		return maxFeeBasisPoints ?? NodeParamsManager.companion.defaultLiquidityPolicy.maxRelativeFeeBasisPoints
	}
	
	func toKotlin() -> Lightning_kmpLiquidityPolicy {
		
		let sats = effectiveMaxFeeSats
		let basisPoints = effectiveMaxFeeBasisPoints
		
		return Lightning_kmpLiquidityPolicy.Auto(
			maxAbsoluteFee: Bitcoin_kmpSatoshi(sat: sats),
			maxRelativeFeeBasisPoints: basisPoints
		)
	}
}

struct MaxFees: Equatable, Codable {
	let feeBaseSat: Int64
	let feeProportionalMillionths: Int64
	
	static func fromTrampolineFees(_ fees: Lightning_kmpTrampolineFees) -> MaxFees {
		return MaxFees(
			feeBaseSat: fees.feeBase.sat,
			feeProportionalMillionths: fees.feeProportional
		)
	}
	
	func toKotlin() -> PhoenixShared.MaxFees {
		return PhoenixShared.MaxFees(
			feeBase: Bitcoin_kmpSatoshi(sat: self.feeBaseSat),
			feeProportionalMillionths: self.feeProportionalMillionths
		)
	}
}

enum RecentPaymentsConfig: Equatable, Codable, Identifiable {
	case withinTime(seconds: Int)
	case mostRecent(count: Int)
	case inFlightOnly
	
	var id: String {
		switch self {
		case .withinTime(let seconds):
			return "withinTime(seconds=\(seconds))"
		case .mostRecent(let count):
			return "mostRecent(count=\(count)"
		case .inFlightOnly:
			return "inFlightOnly"
		}
	}
}
