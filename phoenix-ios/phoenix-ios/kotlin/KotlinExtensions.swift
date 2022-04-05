import Foundation
import PhoenixShared
import Combine
import CryptoKit

extension PhoenixBusiness {
	
	func getPeer() -> Lightning_kmpPeer? {
		self.peerManager.peerState.value_ as? Lightning_kmpPeer
	}
}

extension WalletPaymentInfo {
	
	func paymentDescription(includingUserDescription: Bool = true) -> String? {
		
		let sanitize = { (input: String?) -> String? in
			
			if let trimmedInput = input?.trimmingCharacters(in: .whitespacesAndNewlines) {
				if trimmedInput.count > 0 {
					return trimmedInput
				}
			}
			
			return nil
		}
		
		if includingUserDescription {
			if let description = sanitize(metadata.userDescription) {
				return description
			}
		}
		if let description = sanitize(metadata.lnurl?.description_) {
			return description
		}
		
		if let incomingPayment = payment as? Lightning_kmpIncomingPayment {
			
			if let invoice = incomingPayment.origin.asInvoice() {
				return sanitize(invoice.paymentRequest.description_)
			} else if let _ = incomingPayment.origin.asKeySend() {
				return NSLocalizedString("Donation", comment: "Payment description for received KeySend")
			} else if let swapIn = incomingPayment.origin.asSwapIn() {
				return sanitize(swapIn.address)
			}
			
		} else if let outgoingPayment = payment as? Lightning_kmpOutgoingPayment {
			
			if let normal = outgoingPayment.details.asNormal() {
				return sanitize(normal.paymentRequest.desc())
			} else if let _ = outgoingPayment.details.asKeySend() {
				return NSLocalizedString("Donation", comment: "Payment description for received KeySend")
			} else if let swapOut = outgoingPayment.details.asSwapOut() {
				return sanitize(swapOut.address)
			} else if let _ = outgoingPayment.details.asChannelClosing() {
				return NSLocalizedString("Channel closing", comment: "Payment description for channel closing")
			}
		}
		
		return nil
	}
}

extension WalletPaymentMetadata {
	
	static func empty() -> WalletPaymentMetadata {
		return WalletPaymentMetadata(
			lnurl: nil,
			originalFiat: nil,
			userDescription: nil,
			userNotes: nil,
			modifiedAt: nil
		)
	}
}

extension PaymentsManager {
	
	func getCachedPayment(
		row: WalletPaymentOrderRow,
		options: WalletPaymentFetchOptions
	) -> WalletPaymentInfo? {
		
		return fetcher.getCachedPayment(row: row, options: options)
	}
	
	func getCachedStalePayment(
		row: WalletPaymentOrderRow,
		options: WalletPaymentFetchOptions
	) -> WalletPaymentInfo? {
		
		return fetcher.getCachedStalePayment(row: row, options: options)
	}
	
	func getPayment(
		row: WalletPaymentOrderRow,
		options: WalletPaymentFetchOptions,
		completion: @escaping (WalletPaymentInfo?) -> Void
	) -> Void {
		
		fetcher.getPayment(row: row, options: options) { (result: WalletPaymentInfo?, _: Error?) in
			
			completion(result)
		}
	}
}

struct FetchQueueBatchResult {
	let rowids: [Int64]
	let rowidMap: [Int64: WalletPaymentId]
	let rowMap: [WalletPaymentId : WalletPaymentInfo]
	let metadataMap: [WalletPaymentId : KotlinByteArray]
	let incomingStats: CloudKitDb.MetadataStats
	let outgoingStats: CloudKitDb.MetadataStats
	
	func uniquePaymentIds() -> Set<WalletPaymentId> {
		return Set<WalletPaymentId>(rowidMap.values)
	}
	
	func rowidsMatching(_ query: WalletPaymentId) -> [Int64] {
		var results = [Int64]()
		for (rowid, paymentRowId) in rowidMap {
			if paymentRowId == query {
				results.append(rowid)
			}
		}
		return results
	}
	
	static func empty() -> FetchQueueBatchResult {
		
		return FetchQueueBatchResult(
			rowids: [],
			rowidMap: [:],
			rowMap: [:],
			metadataMap: [:],
			incomingStats: CloudKitDb.MetadataStats(),
			outgoingStats: CloudKitDb.MetadataStats()
		)
	}
}

extension CloudKitDb.FetchQueueBatchResult {
	
	func convertToSwift() -> FetchQueueBatchResult {
		
		// We are experiencing crashes like this:
		//
		// for (rowid, paymentRowId) in batch.rowidMap {
		//      ^^^^^
		// Crash: Could not cast value of type '__NSCFNumber' to 'PhoenixSharedLong'.
		//
		// This appears to be some kind of bug in Kotlin.
		// So we're going to make a clean migration.
		// And we need to do so without swift-style enumeration in order to avoid crashing.
		
		var _rowids = [Int64]()
		var _rowidMap = [Int64: WalletPaymentId]()
		
		for i in 0 ..< self.rowids.count { // cannot enumerate self.rowidMap
			
			let value_kotlin = rowids[i]
			let value_swift = value_kotlin.int64Value
			
			_rowids.append(value_swift)
			if let paymentRowId = self.rowidMap[value_kotlin] {
				_rowidMap[value_swift] = paymentRowId
			}
		}
		
		return FetchQueueBatchResult(
			rowids: _rowids,
			rowidMap: _rowidMap,
			rowMap: self.rowMap,
			metadataMap: self.metadataMap,
			incomingStats: self.incomingStats,
			outgoingStats: self.outgoingStats
		)
	}
}

extension Lightning_kmpIncomingPayment {
	
	var createdAtDate: Date {
		return Date(timeIntervalSince1970: (Double(createdAt) / Double(1_000)))
	}
}

extension Lightning_kmpIncomingPayment.Received {
	
	var receivedAtDate: Date {
		return Date(timeIntervalSince1970: (Double(receivedAt) / Double(1_000)))
	}
}

extension Lightning_kmpOutgoingPayment {
	
	var createdAtDate: Date {
		return Date(timeIntervalSince1970: (Double(createdAt) / Double(1_000)))
	}
}

extension Lightning_kmpOutgoingPayment.Part {
	
	var createdAtDate: Date {
		return Date(timeIntervalSince1970: (Double(createdAt) / Double(1_000)))
	}
}

extension Lightning_kmpOutgoingPayment.PartStatusSucceeded {
	
	var completedAtDate: Date {
		return Date(timeIntervalSince1970: (Double(completedAt) / Double(1_000)))
	}
}

extension Lightning_kmpOutgoingPayment.PartStatusFailed {
	
	var completedAtDate: Date {
		return Date(timeIntervalSince1970: (Double(completedAt) / Double(1_000)))
	}
}

extension Lightning_kmpOutgoingPayment.StatusCompleted {
	
	var completedAtDate: Date {
		return Date(timeIntervalSince1970: (Double(completedAt) / Double(1_000)))
	}
}

extension Lightning_kmpPaymentRequest {
	
	var timestampDate: Date {
		return Date(timeIntervalSince1970: Double(timestampSeconds))
	}
}

extension Lightning_kmpConnection {
	
	func localizedText() -> String {
		switch self {
		case .closed       : return NSLocalizedString("Offline", comment: "Connection state")
		case .establishing : return NSLocalizedString("Connecting...", comment: "Connection state")
		case .established  : return NSLocalizedString("Connected", comment: "Connection state")
		default            : return NSLocalizedString("Unknown", comment: "Connection state")
		}
	}
}

extension Bitcoin_kmpByteVector32 {
	
	static func random() -> Bitcoin_kmpByteVector32 {
		
		let key = SymmetricKey(size: .bits256) // 256 / 8 = 32
		
		let data = key.withUnsafeBytes {(bytes: UnsafeRawBufferPointer) -> Data in
			return Data(bytes: bytes.baseAddress!, count: bytes.count)
		}
		
		return Bitcoin_kmpByteVector32(bytes: data.toKotlinByteArray())
	}
}

extension ConnectionsManager {
	
	var currentValue: Connections {
		return connections.value_ as! Connections
	}
	
	var publisher: CurrentValueSubject<Connections, Never> {

		let publisher = CurrentValueSubject<Connections, Never>(currentValue)

		let swiftFlow = SwiftFlow<Connections>(origin: connections)
		swiftFlow.watch {[weak publisher](connections: Connections?) in
			publisher?.send(connections!)
		}

		return publisher
	}
}

extension ExchangeRate {
	
	var timestamp: Date {
		return Date(timeIntervalSince1970: (Double(timestampMillis) / Double(1_000)))
	}
}

extension LNUrl.Auth {
	
	static var defaultActionPromptTitle: String {
		return NSLocalizedString("Authenticate", comment: "lnurl-auth: login button title")
	}
	
	var actionPromptTitle: String {
		if let action = self.action() {
			switch action {
				case .register_ : return NSLocalizedString("Register",     comment: "lnurl-auth: login button title")
				case .login     : return NSLocalizedString("Login",        comment: "lnurl-auth: login button title")
				case .link      : return NSLocalizedString("Link",         comment: "lnurl-auth: login button title")
				case .auth      : return NSLocalizedString("Authenticate", comment: "lnurl-auth: login button title")
				default         : break
			}
		}
		return LNUrl.Auth.defaultActionPromptTitle
	}
	
	static var defaultActionSuccessTitle: String {
		return NSLocalizedString("Authenticated", comment: "lnurl-auth: success text")
	}
	
	var actionSuccessTitle: String {
		if let action = self.action() {
			switch action {
				case .register_ : return NSLocalizedString("Registered",    comment: "lnurl-auth: success text")
				case .login     : return NSLocalizedString("Logged In",     comment: "lnurl-auth: success text")
				case .link      : return NSLocalizedString("Linked",        comment: "lnurl-auth: success text")
				case .auth      : return NSLocalizedString("Authenticated", comment: "lnurl-auth: success text")
				default         : break
			}
		}
		return LNUrl.Auth.defaultActionSuccessTitle
	}
}

extension FiatCurrency {
	
	var shortName: String {
		let (code, mkt) = splitShortName
		return code + mkt
	}
	
	var splitShortName: (String, String) {
		
		if name.count <= 3 {
			return (name.uppercased(), "")
			
		} else {
			let splitIdx = name.index(name.startIndex, offsetBy: 3)
			
			let code = name[name.startIndex ..< splitIdx]
			let mkt = name[splitIdx ..< name.endIndex]
				.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
			
			return (code.uppercased(), mkt.lowercased())
		}
	}
	
	private var longName_englishTranslation: String { switch self {
		case .aed   : return "United Arab Emirates Dirham"
		case .afn   : return "Afghan Afghani"
		case .all   : return "Albanian Lek"
		case .amd   : return "Armenian Dram"
		case .ang   : return "Netherlands Antillean Guilder"
		case .aoa   : return "Angolan Kwanza"
		case .arsBm : return "Argentine Peso (blue market)"
		case .ars   : return "Argentine Peso"
		case .aud   : return "Australian Dollar"
		case .awg   : return "Aruban Florin"
		case .azn   : return "Azerbaijani Manat"
		case .bam   : return "Bosnia-Herzegovina Convertible Mark"
		case .bbd   : return "Barbadian Dollar"
		case .bdt   : return "Bangladeshi Taka"
		case .bgn   : return "Bulgarian Lev"
		case .bhd   : return "Bahraini Dinar"
		case .bif   : return "Burundian Franc"
		case .bmd   : return "Bermudan Dollar"
		case .bnd   : return "Brunei Dollar"
		case .bob   : return "Bolivian Boliviano"
		case .brl   : return "Brazilian Real"
		case .bsd   : return "Bahamian Dollar"
		case .btn   : return "Bhutanese Ngultrum"
		case .bwp   : return "Botswanan Pula"
		case .bzd   : return "Belize Dollar"
		case .cad   : return "Canadian Dollar"
		case .cdf   : return "Congolese Franc"
		case .chf   : return "Swiss Franc"
		case .clp   : return "Chilean Peso"
		case .cny   : return "Chinese Yuan"
		case .cop   : return "Colombian Peso"
		case .crc   : return "Costa Rican Colón"
		case .cup   : return "Cuban Peso"
		case .cve   : return "Cape Verdean Escudo"
		case .czk   : return "Czech Koruna"
		case .djf   : return "Djiboutian Franc"
		case .dkk   : return "Danish Krone"
		case .dop   : return "Dominican Peso"
		case .dzd   : return "Algerian Dinar"
		case .egp   : return "Egyptian Pound"
		case .ern   : return "Eritrean Nakfa"
		case .etb   : return "Ethiopian Birr"
		case .eur   : return "Euro"
		case .fjd   : return "Fijian Dollar"
		case .fkp   : return "Falkland Islands Pound"
		case .gbp   : return "Great British Pound"
		case .gel   : return "Georgian Lari"
		case .ghs   : return "Ghanaian Cedi"
		case .gip   : return "Gibraltar Pound"
		case .gmd   : return "Gambian Dalasi"
		case .gnf   : return "Guinean Franc"
		case .gtq   : return "Guatemalan Quetzal"
		case .gyd   : return "Guyanaese Dollar"
		case .hkd   : return "Hong Kong Dollar"
		case .hnl   : return "Honduran Lempira"
		case .hrk   : return "Croatian Kuna"
		case .htg   : return "Haitian Gourde"
		case .huf   : return "Hungarian Forint"
		case .idr   : return "Indonesian Rupiah"
		case .ils   : return "Israeli New Sheqel"
		case .inr   : return "Indian Rupee"
		case .iqd   : return "Iraqi Dinar"
		case .irr   : return "Iranian Rial"
		case .isk   : return "Icelandic Króna"
		case .jep   : return "Jersey Pound"
		case .jmd   : return "Jamaican Dollar"
		case .jod   : return "Jordanian Dinar"
		case .jpy   : return "Japanese Yen"
		case .kes   : return "Kenyan Shilling"
		case .kgs   : return "Kyrgystani Som"
		case .khr   : return "Cambodian Riel"
		case .kmf   : return "Comorian Franc"
		case .kpw   : return "North Korean Won"
		case .krw   : return "South Korean Won"
		case .kwd   : return "Kuwaiti Dinar"
		case .kyd   : return "Cayman Islands Dollar"
		case .kzt   : return "Kazakhstani Tenge"
		case .lak   : return "Laotian Kip"
		case .lbp   : return "Lebanese Pound"
		case .lkr   : return "Sri Lankan Rupee"
		case .lrd   : return "Liberian Dollar"
		case .lsl   : return "Lesotho Loti"
		case .lyd   : return "Libyan Dinar"
		case .mad   : return "Moroccan Dirham"
		case .mdl   : return "Moldovan Leu"
		case .mga   : return "Malagasy Ariary"
		case .mkd   : return "Macedonian Denar"
		case .mmk   : return "Myanmar Kyat"
		case .mnt   : return "Mongolian Tugrik"
		case .mop   : return "Macanese Pataca"
		case .mtl   : return "Maltese Lira"
		case .mur   : return "Mauritian Rupee"
		case .mvr   : return "Maldivian Rufiyaa"
		case .mwk   : return "Malawian Kwacha"
		case .mxn   : return "Mexican Peso"
		case .myr   : return "Malaysian Ringgit"
		case .mzn   : return "Mozambican Metical"
		case .nad   : return "Namibian Dollar"
		case .ngn   : return "Nigerian Naira"
		case .nio   : return "Nicaraguan Córdoba"
		case .nok   : return "Norwegian Krone"
		case .npr   : return "Nepalese Rupee"
		case .nzd   : return "New Zealand Dollar"
		case .omr   : return "Omani Rial"
		case .pab   : return "Panamanian Balboa"
		case .pen   : return "Peruvian Sol"
		case .pgk   : return "Papua New Guinean Kina"
		case .php   : return "Philippine Peso"
		case .pkr   : return "Pakistani Rupee"
		case .pln   : return "Polish Zloty"
		case .pyg   : return "Paraguayan Guarani"
		case .qar   : return "Qatari Rial"
		case .ron   : return "Romanian Leu"
		case .rsd   : return "Serbian Dinar"
		case .rub   : return "Russian Ruble"
		case .rwf   : return "Rwandan Franc"
		case .sar   : return "Saudi Riyal"
		case .sbd   : return "Solomon Islands Dollar"
		case .scr   : return "Seychellois Rupee"
		case .sdg   : return "Sudanese Pound"
		case .sek   : return "Swedish Krona"
		case .sgd   : return "Singapore Dollar"
		case .shp   : return "Saint Helena Pound"
		case .sll   : return "Sierra Leonean Leone"
		case .sos   : return "Somali Shilling"
		case .srd   : return "Surinamese Dollar"
		case .syp   : return "Syrian Pound"
		case .szl   : return "Swazi Lilangeni"
		case .thb   : return "Thai Baht"
		case .tjs   : return "Tajikistani Somoni"
		case .tmt   : return "Turkmenistani Manat"
		case .tnd   : return "Tunisian Dinar"
		case .top   : return "Tongan Paʻanga"
		case .try_  : return "Turkish Lira"
		case .ttd   : return "Trinidad and Tobago Dollar"
		case .twd   : return "Taiwan Dollar"
		case .tzs   : return "Tanzanian Shilling"
		case .uah   : return "Ukrainian Hryvnia"
		case .ugx   : return "Ugandan Shilling"
		case .usd   : return "United States Dollar"
		case .uyu   : return "Uruguayan Peso"
		case .uzs   : return "Uzbekistan Som"
		case .vnd   : return "Vietnamese Dong"
		case .vuv   : return "Vanuatu Vatu"
		case .wst   : return "Samoan Tala"
		case .xaf   : return "CFA Franc BEAC"
		case .xcd   : return "East Caribbean Dollar"
		case .xof   : return "CFA Franc BCEAO"
		case .xpf   : return "CFP Franc"
		case .yer   : return "Yemeni Rial"
		case .zar   : return "South African Rand"
		case .zmw   : return "Zambian Kwacha"
		default     : return self.shortName
	}}
	
	private var longName_manualTranslation: String { switch self {
		case .aed   : return NSLocalizedString("AED", tableName: "Currencies", comment: "United Arab Emirates Dirham")
		case .afn   : return NSLocalizedString("AFN", tableName: "Currencies", comment: "Afghan Afghani")
		case .all   : return NSLocalizedString("ALL", tableName: "Currencies", comment: "Albanian Lek")
		case .amd   : return NSLocalizedString("AMD", tableName: "Currencies", comment: "Armenian Dram")
		case .ang   : return NSLocalizedString("ANG", tableName: "Currencies", comment: "Netherlands Antillean Guilder")
		case .aoa   : return NSLocalizedString("AOA", tableName: "Currencies", comment: "Angolan Kwanza")
		case .arsBm : return NSLocalizedString("ARSbm", tableName: "Currencies", comment: "Argentine Peso (blue market)")
		case .ars   : return NSLocalizedString("ARS", tableName: "Currencies", comment: "Argentine Peso")
		case .aud   : return NSLocalizedString("AUD", tableName: "Currencies", comment: "Australian Dollar")
		case .awg   : return NSLocalizedString("AWG", tableName: "Currencies", comment: "Aruban Florin")
		case .azn   : return NSLocalizedString("AZN", tableName: "Currencies", comment: "Azerbaijani Manat")
		case .bam   : return NSLocalizedString("BAM", tableName: "Currencies", comment: "Bosnia-Herzegovina Convertible Mark")
		case .bbd   : return NSLocalizedString("BBD", tableName: "Currencies", comment: "Barbadian Dollar")
		case .bdt   : return NSLocalizedString("BDT", tableName: "Currencies", comment: "Bangladeshi Taka")
		case .bgn   : return NSLocalizedString("BGN", tableName: "Currencies", comment: "Bulgarian Lev")
		case .bhd   : return NSLocalizedString("BHD", tableName: "Currencies", comment: "Bahraini Dinar")
		case .bif   : return NSLocalizedString("BIF", tableName: "Currencies", comment: "Burundian Franc")
		case .bmd   : return NSLocalizedString("BMD", tableName: "Currencies", comment: "Bermudan Dollar")
		case .bnd   : return NSLocalizedString("BND", tableName: "Currencies", comment: "Brunei Dollar")
		case .bob   : return NSLocalizedString("BOB", tableName: "Currencies", comment: "Bolivian Boliviano")
		case .brl   : return NSLocalizedString("BRL", tableName: "Currencies", comment: "Brazilian Real")
		case .bsd   : return NSLocalizedString("BSD", tableName: "Currencies", comment: "Bahamian Dollar")
		case .btn   : return NSLocalizedString("BTN", tableName: "Currencies", comment: "Bhutanese Ngultrum")
		case .bwp   : return NSLocalizedString("BWP", tableName: "Currencies", comment: "Botswanan Pula")
		case .bzd   : return NSLocalizedString("BZD", tableName: "Currencies", comment: "Belize Dollar")
		case .cad   : return NSLocalizedString("CAD", tableName: "Currencies", comment: "Canadian Dollar")
		case .cdf   : return NSLocalizedString("CDF", tableName: "Currencies", comment: "Congolese Franc")
		case .chf   : return NSLocalizedString("CHF", tableName: "Currencies", comment: "Swiss Franc")
		case .clp   : return NSLocalizedString("CLP", tableName: "Currencies", comment: "Chilean Peso")
		case .cny   : return NSLocalizedString("CNY", tableName: "Currencies", comment: "Chinese Yuan")
		case .cop   : return NSLocalizedString("COP", tableName: "Currencies", comment: "Colombian Peso")
		case .crc   : return NSLocalizedString("CRC", tableName: "Currencies", comment: "Costa Rican Colón")
		case .cup   : return NSLocalizedString("CUP", tableName: "Currencies", comment: "Cuban Peso")
		case .cve   : return NSLocalizedString("CVE", tableName: "Currencies", comment: "Cape Verdean Escudo")
		case .czk   : return NSLocalizedString("CZK", tableName: "Currencies", comment: "Czech Koruna")
		case .djf   : return NSLocalizedString("DJF", tableName: "Currencies", comment: "Djiboutian Franc")
		case .dkk   : return NSLocalizedString("DKK", tableName: "Currencies", comment: "Danish Krone")
		case .dop   : return NSLocalizedString("DOP", tableName: "Currencies", comment: "Dominican Peso")
		case .dzd   : return NSLocalizedString("DZD", tableName: "Currencies", comment: "Algerian Dinar")
		case .egp   : return NSLocalizedString("EGP", tableName: "Currencies", comment: "Egyptian Pound")
		case .ern   : return NSLocalizedString("ERN", tableName: "Currencies", comment: "Eritrean Nakfa")
		case .etb   : return NSLocalizedString("ETB", tableName: "Currencies", comment: "Ethiopian Birr")
		case .eur   : return NSLocalizedString("EUR", tableName: "Currencies", comment: "Euro")
		case .fjd   : return NSLocalizedString("FJD", tableName: "Currencies", comment: "Fijian Dollar")
		case .fkp   : return NSLocalizedString("FKP", tableName: "Currencies", comment: "Falkland Islands Pound")
		case .gbp   : return NSLocalizedString("GBP", tableName: "Currencies", comment: "Great British Pound")
		case .gel   : return NSLocalizedString("GEL", tableName: "Currencies", comment: "Georgian Lari")
		case .ghs   : return NSLocalizedString("GHS", tableName: "Currencies", comment: "Ghanaian Cedi")
		case .gip   : return NSLocalizedString("GIP", tableName: "Currencies", comment: "Gibraltar Pound")
		case .gmd   : return NSLocalizedString("GMD", tableName: "Currencies", comment: "Gambian Dalasi")
		case .gnf   : return NSLocalizedString("GNF", tableName: "Currencies", comment: "Guinean Franc")
		case .gtq   : return NSLocalizedString("GTQ", tableName: "Currencies", comment: "Guatemalan Quetzal")
		case .gyd   : return NSLocalizedString("GYD", tableName: "Currencies", comment: "Guyanaese Dollar")
		case .hkd   : return NSLocalizedString("HKD", tableName: "Currencies", comment: "Hong Kong Dollar")
		case .hnl   : return NSLocalizedString("HNL", tableName: "Currencies", comment: "Honduran Lempira")
		case .hrk   : return NSLocalizedString("HRK", tableName: "Currencies", comment: "Croatian Kuna")
		case .htg   : return NSLocalizedString("HTG", tableName: "Currencies", comment: "Haitian Gourde")
		case .huf   : return NSLocalizedString("HUF", tableName: "Currencies", comment: "Hungarian Forint")
		case .idr   : return NSLocalizedString("IDR", tableName: "Currencies", comment: "Indonesian Rupiah")
		case .ils   : return NSLocalizedString("ILS", tableName: "Currencies", comment: "Israeli New Sheqel")
		case .inr   : return NSLocalizedString("INR", tableName: "Currencies", comment: "Indian Rupee")
		case .iqd   : return NSLocalizedString("IQD", tableName: "Currencies", comment: "Iraqi Dinar")
		case .irr   : return NSLocalizedString("IRR", tableName: "Currencies", comment: "Iranian Rial")
		case .isk   : return NSLocalizedString("ISK", tableName: "Currencies", comment: "Icelandic Króna")
		case .jep   : return NSLocalizedString("JEP", tableName: "Currencies", comment: "Jersey Pound")
		case .jmd   : return NSLocalizedString("JMD", tableName: "Currencies", comment: "Jamaican Dollar")
		case .jod   : return NSLocalizedString("JOD", tableName: "Currencies", comment: "Jordanian Dinar")
		case .jpy   : return NSLocalizedString("JPY", tableName: "Currencies", comment: "Japanese Yen")
		case .kes   : return NSLocalizedString("KES", tableName: "Currencies", comment: "Kenyan Shilling")
		case .kgs   : return NSLocalizedString("KGS", tableName: "Currencies", comment: "Kyrgystani Som")
		case .khr   : return NSLocalizedString("KHR", tableName: "Currencies", comment: "Cambodian Riel")
		case .kmf   : return NSLocalizedString("KMF", tableName: "Currencies", comment: "Comorian Franc")
		case .kpw   : return NSLocalizedString("KPW", tableName: "Currencies", comment: "North Korean Won")
		case .krw   : return NSLocalizedString("KRW", tableName: "Currencies", comment: "South Korean Won")
		case .kwd   : return NSLocalizedString("KWD", tableName: "Currencies", comment: "Kuwaiti Dinar")
		case .kyd   : return NSLocalizedString("KYD", tableName: "Currencies", comment: "Cayman Islands Dollar")
		case .kzt   : return NSLocalizedString("KZT", tableName: "Currencies", comment: "Kazakhstani Tenge")
		case .lak   : return NSLocalizedString("LAK", tableName: "Currencies", comment: "Laotian Kip")
		case .lbp   : return NSLocalizedString("LBP", tableName: "Currencies", comment: "Lebanese Pound")
		case .lkr   : return NSLocalizedString("LKR", tableName: "Currencies", comment: "Sri Lankan Rupee")
		case .lrd   : return NSLocalizedString("LRD", tableName: "Currencies", comment: "Liberian Dollar")
		case .lsl   : return NSLocalizedString("LSL", tableName: "Currencies", comment: "Lesotho Loti")
		case .lyd   : return NSLocalizedString("LYD", tableName: "Currencies", comment: "Libyan Dinar")
		case .mad   : return NSLocalizedString("MAD", tableName: "Currencies", comment: "Moroccan Dirham")
		case .mdl   : return NSLocalizedString("MDL", tableName: "Currencies", comment: "Moldovan Leu")
		case .mga   : return NSLocalizedString("MGA", tableName: "Currencies", comment: "Malagasy Ariary")
		case .mkd   : return NSLocalizedString("MKD", tableName: "Currencies", comment: "Macedonian Denar")
		case .mmk   : return NSLocalizedString("MMK", tableName: "Currencies", comment: "Myanmar Kyat")
		case .mnt   : return NSLocalizedString("MNT", tableName: "Currencies", comment: "Mongolian Tugrik")
		case .mop   : return NSLocalizedString("MOP", tableName: "Currencies", comment: "Macanese Pataca")
		case .mtl   : return NSLocalizedString("MTL", tableName: "Currencies", comment: "Maltese Lira")
		case .mur   : return NSLocalizedString("MUR", tableName: "Currencies", comment: "Mauritian Rupee")
		case .mvr   : return NSLocalizedString("MVR", tableName: "Currencies", comment: "Maldivian Rufiyaa")
		case .mwk   : return NSLocalizedString("MWK", tableName: "Currencies", comment: "Malawian Kwacha")
		case .mxn   : return NSLocalizedString("MXN", tableName: "Currencies", comment: "Mexican Peso")
		case .myr   : return NSLocalizedString("MYR", tableName: "Currencies", comment: "Malaysian Ringgit")
		case .mzn   : return NSLocalizedString("MZN", tableName: "Currencies", comment: "Mozambican Metical")
		case .nad   : return NSLocalizedString("NAD", tableName: "Currencies", comment: "Namibian Dollar")
		case .ngn   : return NSLocalizedString("NGN", tableName: "Currencies", comment: "Nigerian Naira")
		case .nio   : return NSLocalizedString("NIO", tableName: "Currencies", comment: "Nicaraguan Córdoba")
		case .nok   : return NSLocalizedString("NOK", tableName: "Currencies", comment: "Norwegian Krone")
		case .npr   : return NSLocalizedString("NPR", tableName: "Currencies", comment: "Nepalese Rupee")
		case .nzd   : return NSLocalizedString("NZD", tableName: "Currencies", comment: "New Zealand Dollar")
		case .omr   : return NSLocalizedString("OMR", tableName: "Currencies", comment: "Omani Rial")
		case .pab   : return NSLocalizedString("PAB", tableName: "Currencies", comment: "Panamanian Balboa")
		case .pen   : return NSLocalizedString("PEN", tableName: "Currencies", comment: "Peruvian Sol")
		case .pgk   : return NSLocalizedString("PGK", tableName: "Currencies", comment: "Papua New Guinean Kina")
		case .php   : return NSLocalizedString("PHP", tableName: "Currencies", comment: "Philippine Peso")
		case .pkr   : return NSLocalizedString("PKR", tableName: "Currencies", comment: "Pakistani Rupee")
		case .pln   : return NSLocalizedString("PLN", tableName: "Currencies", comment: "Polish Zloty")
		case .pyg   : return NSLocalizedString("PYG", tableName: "Currencies", comment: "Paraguayan Guarani")
		case .qar   : return NSLocalizedString("QAR", tableName: "Currencies", comment: "Qatari Rial")
		case .ron   : return NSLocalizedString("RON", tableName: "Currencies", comment: "Romanian Leu")
		case .rsd   : return NSLocalizedString("RSD", tableName: "Currencies", comment: "Serbian Dinar")
		case .rub   : return NSLocalizedString("RUB", tableName: "Currencies", comment: "Russian Ruble")
		case .rwf   : return NSLocalizedString("RWF", tableName: "Currencies", comment: "Rwandan Franc")
		case .sar   : return NSLocalizedString("SAR", tableName: "Currencies", comment: "Saudi Riyal")
		case .sbd   : return NSLocalizedString("SBD", tableName: "Currencies", comment: "Solomon Islands Dollar")
		case .scr   : return NSLocalizedString("SCR", tableName: "Currencies", comment: "Seychellois Rupee")
		case .sdg   : return NSLocalizedString("SDG", tableName: "Currencies", comment: "Sudanese Pound")
		case .sek   : return NSLocalizedString("SEK", tableName: "Currencies", comment: "Swedish Krona")
		case .sgd   : return NSLocalizedString("SGD", tableName: "Currencies", comment: "Singapore Dollar")
		case .shp   : return NSLocalizedString("SHP", tableName: "Currencies", comment: "Saint Helena Pound")
		case .sll   : return NSLocalizedString("SLL", tableName: "Currencies", comment: "Sierra Leonean Leone")
		case .sos   : return NSLocalizedString("SOS", tableName: "Currencies", comment: "Somali Shilling")
		case .srd   : return NSLocalizedString("SRD", tableName: "Currencies", comment: "Surinamese Dollar")
		case .syp   : return NSLocalizedString("SYP", tableName: "Currencies", comment: "Syrian Pound")
		case .szl   : return NSLocalizedString("SZL", tableName: "Currencies", comment: "Swazi Lilangeni")
		case .thb   : return NSLocalizedString("THB", tableName: "Currencies", comment: "Thai Baht")
		case .tjs   : return NSLocalizedString("TJS", tableName: "Currencies", comment: "Tajikistani Somoni")
		case .tmt   : return NSLocalizedString("TMT", tableName: "Currencies", comment: "Turkmenistani Manat")
		case .tnd   : return NSLocalizedString("TND", tableName: "Currencies", comment: "Tunisian Dinar")
		case .top   : return NSLocalizedString("TOP", tableName: "Currencies", comment: "Tongan Paʻanga")
		case .try_  : return NSLocalizedString("TRY", tableName: "Currencies", comment: "Turkish Lira")
		case .ttd   : return NSLocalizedString("TTD", tableName: "Currencies", comment: "Trinidad and Tobago Dollar")
		case .twd   : return NSLocalizedString("TWD", tableName: "Currencies", comment: "Taiwan Dollar")
		case .tzs   : return NSLocalizedString("TZS", tableName: "Currencies", comment: "Tanzanian Shilling")
		case .uah   : return NSLocalizedString("UAH", tableName: "Currencies", comment: "Ukrainian Hryvnia")
		case .ugx   : return NSLocalizedString("UGX", tableName: "Currencies", comment: "Ugandan Shilling")
		case .usd   : return NSLocalizedString("USD", tableName: "Currencies", comment: "United States Dollar")
		case .uyu   : return NSLocalizedString("UYU", tableName: "Currencies", comment: "Uruguayan Peso")
		case .uzs   : return NSLocalizedString("UZS", tableName: "Currencies", comment: "Uzbekistan Som")
		case .vnd   : return NSLocalizedString("VND", tableName: "Currencies", comment: "Vietnamese Dong")
		case .vuv   : return NSLocalizedString("VUV", tableName: "Currencies", comment: "Vanuatu Vatu")
		case .wst   : return NSLocalizedString("WST", tableName: "Currencies", comment: "Samoan Tala")
		case .xaf   : return NSLocalizedString("XAF", tableName: "Currencies", comment: "CFA Franc BEAC")
		case .xcd   : return NSLocalizedString("XCD", tableName: "Currencies", comment: "East Caribbean Dollar")
		case .xof   : return NSLocalizedString("XOF", tableName: "Currencies", comment: "CFA Franc BCEAO")
		case .xpf   : return NSLocalizedString("XPF", tableName: "Currencies", comment: "CFP Franc")
		case .yer   : return NSLocalizedString("YER", tableName: "Currencies", comment: "Yemeni Rial")
		case .zar   : return NSLocalizedString("ZAR", tableName: "Currencies", comment: "South African Rand")
		case .zmw   : return NSLocalizedString("ZMW", tableName: "Currencies", comment: "Zambian Kwacha")
		default     : return ""
	}}
	
	var longName: String {
		let manualTranslation = longName_manualTranslation
		if !manualTranslation.isEmpty && manualTranslation != self.shortName {
			return manualTranslation
		}
		
		var autoTranslation: String? = nil
		
		let currentLocale = Locale.current
		if currentLocale.languageCode != "en" {
			autoTranslation = currentLocale.localizedString(forCurrencyCode: self.shortName)
		}
		
		return autoTranslation ?? longName_englishTranslation
	}
	
	var flag: String { switch self {
		case .aed   : return "🇦🇪" // United Arab Emirates Dirham
		case .afn   : return "🇦🇫" // Afghan Afghani
		case .all   : return "🇦🇱" // Albanian Lek
		case .amd   : return "🇦🇲" // Armenian Dram
		case .ang   : return "🇳🇱" // Netherlands Antillean Guilder
		case .aoa   : return "🇦🇴" // Angolan Kwanza
		case .arsBm : return "🇦🇷" // Argentine Peso (blue market)
		case .ars   : return "🇦🇷" // Argentine Peso
		case .aud   : return "🇦🇺" // Australian Dollar
		case .awg   : return "🇦🇼" // Aruban Florin
		case .azn   : return "🇦🇿" // Azerbaijani Manat
		case .bam   : return "🇧🇦" // Bosnia-Herzegovina Convertible Mark
		case .bbd   : return "🇧🇧" // Barbadian Dollar
		case .bdt   : return "🇧🇩" // Bangladeshi Taka
		case .bgn   : return "🇧🇬" // Bulgarian Lev
		case .bhd   : return "🇧🇭" // Bahraini Dinar
		case .bif   : return "🇧🇮" // Burundian Franc
		case .bmd   : return "🇧🇲" // Bermudan Dollar
		case .bnd   : return "🇧🇳" // Brunei Dollar
		case .bob   : return "🇧🇴" // Bolivian Boliviano
		case .brl   : return "🇧🇷" // Brazilian Real
		case .bsd   : return "🇧🇸" // Bahamian Dollar
		case .btn   : return "🇧🇹" // Bhutanese Ngultrum
		case .bwp   : return "🇧🇼" // Botswanan Pula
		case .bzd   : return "🇧🇿" // Belize Dollar
		case .cad   : return "🇨🇦" // Canadian Dollar
		case .cdf   : return "🇨🇩" // Congolese Franc
		case .chf   : return "🇨🇭" // Swiss Franc
		case .clp   : return "🇨🇱" // Chilean Peso
		case .cny   : return "🇨🇳" // Chinese Yuan
		case .cop   : return "🇨🇴" // Colombian Peso
		case .crc   : return "🇨🇷" // Costa Rican Colón
		case .cup   : return "🇨🇺" // Cuban Peso
		case .cve   : return "🇨🇻" // Cape Verdean Escudo
		case .czk   : return "🇨🇿" // Czech Koruna
		case .djf   : return "🇩🇯" // Djiboutian Franc
		case .dkk   : return "🇩🇰" // Danish Krone
		case .dop   : return "🇩🇴" // Dominican Peso
		case .dzd   : return "🇩🇿" // Algerian Dinar
		case .egp   : return "🇪🇬" // Egyptian Pound
		case .ern   : return "🇪🇷" // Eritrean Nakfa
		case .etb   : return "🇪🇹" // Ethiopian Birr
		case .eur   : return "🇪🇺" // Euro
		case .fjd   : return "🇫🇯" // Fijian Dollar
		case .fkp   : return "🇫🇰" // Falkland Islands Pound
		case .gbp   : return "🇬🇧" // British Pound Sterling
		case .gel   : return "🇬🇪" // Georgian Lari
		case .ghs   : return "🇬🇭" // Ghanaian Cedi
		case .gip   : return "🇬🇮" // Gibraltar Pound
		case .gmd   : return "🇬🇲" // Gambian Dalasi
		case .gnf   : return "🇬🇳" // Guinean Franc
		case .gtq   : return "🇬🇹" // Guatemalan Quetzal
		case .gyd   : return "🇬🇾" // Guyanaese Dollar
		case .hkd   : return "🇭🇰" // Hong Kong Dollar
		case .hnl   : return "🇭🇳" // Honduran Lempira
		case .hrk   : return "🇭🇷" // Croatian Kuna
		case .htg   : return "🇭🇹" // Haitian Gourde
		case .huf   : return "🇭🇺" // Hungarian Forint
		case .idr   : return "🇮🇩" // Indonesian Rupiah
		case .ils   : return "🇮🇱" // Israeli New Sheqel
		case .inr   : return "🇮🇳" // Indian Rupee
		case .iqd   : return "🇮🇶" // Iraqi Dinar
		case .irr   : return "🇮🇷" // Iranian Rial
		case .isk   : return "🇮🇸" // Icelandic Króna
		case .jep   : return "🇯🇪" // Jersey Pound
		case .jmd   : return "🇯🇲" // Jamaican Dollar
		case .jod   : return "🇯🇴" // Jordanian Dinar
		case .jpy   : return "🇯🇵" // Japanese Yen
		case .kes   : return "🇰🇪" // Kenyan Shilling
		case .kgs   : return "🇰🇬" // Kyrgystani Som
		case .khr   : return "🇰🇭" // Cambodian Riel
		case .kmf   : return "🇰🇲" // Comorian Franc
		case .kpw   : return "🇰🇵" // North Korean Won
		case .krw   : return "🇰🇷" // South Korean Won
		case .kwd   : return "🇰🇼" // Kuwaiti Dinar
		case .kyd   : return "🇰🇾" // Cayman Islands Dollar
		case .kzt   : return "🇰🇿" // Kazakhstani Tenge
		case .lak   : return "🇱🇦" // Laotian Kip
		case .lbp   : return "🇱🇧" // Lebanese Pound
		case .lkr   : return "🇱🇰" // Sri Lankan Rupee
		case .lrd   : return "🇱🇷" // Liberian Dollar
		case .lsl   : return "🇱🇸" // Lesotho Loti
		case .lyd   : return "🇱🇾" // Libyan Dinar
		case .mad   : return "🇲🇦" // Moroccan Dirham
		case .mdl   : return "🇲🇩" // Moldovan Leu
		case .mga   : return "🇲🇬" // Malagasy Ariary
		case .mkd   : return "🇲🇰" // Macedonian Denar
		case .mmk   : return "🇲🇲" // Myanmar Kyat
		case .mnt   : return "🇲🇳" // Mongolian Tugrik
		case .mop   : return "🇲🇴" // Macanese Pataca
		case .mtl   : return "🇲🇹" // Maltese Lira
		case .mur   : return "🇲🇺" // Mauritian Rupee
		case .mvr   : return "🇲🇻" // Maldivian Rufiyaa
		case .mwk   : return "🇲🇼" // Malawian Kwacha
		case .mxn   : return "🇲🇽" // Mexican Peso
		case .myr   : return "🇲🇾" // Malaysian Ringgit
		case .mzn   : return "🇲🇿" // Mozambican Metical
		case .nad   : return "🇳🇦" // Namibian Dollar
		case .ngn   : return "🇳🇬" // Nigerian Naira
		case .nio   : return "🇳🇮" // Nicaraguan Córdoba
		case .nok   : return "🇳🇴" // Norwegian Krone
		case .npr   : return "🇳🇵" // Nepalese Rupee
		case .nzd   : return "🇳🇿" // New Zealand Dollar
		case .omr   : return "🇴🇲" // Omani Rial
		case .pab   : return "🇵🇦" // Panamanian Balboa
		case .pen   : return "🇵🇪" // Peruvian Nuevo Sol
		case .pgk   : return "🇵🇬" // Papua New Guinean Kina
		case .php   : return "🇵🇭" // Philippine Peso
		case .pkr   : return "🇵🇰" // Pakistani Rupee
		case .pln   : return "🇵🇱" // Polish Zloty
		case .pyg   : return "🇵🇾" // Paraguayan Guarani
		case .qar   : return "🇶🇦" // Qatari Rial
		case .ron   : return "🇷🇴" // Romanian Leu
		case .rsd   : return "🇷🇸" // Serbian Dinar
		case .rub   : return "🇷🇺" // Russian Ruble
		case .rwf   : return "🇷🇼" // Rwandan Franc
		case .sar   : return "🇸🇦" // Saudi Riyal
		case .sbd   : return "🇸🇧" // Solomon Islands Dollar
		case .scr   : return "🇸🇨" // Seychellois Rupee
		case .sdg   : return "🇸🇩" // Sudanese Pound
		case .sek   : return "🇸🇪" // Swedish Krona
		case .sgd   : return "🇸🇬" // Singapore Dollar
		case .shp   : return "🇸🇭" // Saint Helena Pound
		case .sll   : return "🇸🇱" // Sierra Leonean Leone
		case .sos   : return "🇸🇴" // Somali Shilling
		case .srd   : return "🇸🇷" // Surinamese Dollar
		case .syp   : return "🇸🇾" // Syrian Pound
		case .szl   : return "🇸🇿" // Swazi Lilangeni
		case .thb   : return "🇹🇭" // Thai Baht
		case .tjs   : return "🇹🇯" // Tajikistani Somoni
		case .tmt   : return "🇹🇲" // Turkmenistani Manat
		case .tnd   : return "🇹🇳" // Tunisian Dinar
		case .top   : return "🇹🇴" // Tongan Paʻanga
		case .try_  : return "🇹🇷" // Turkish Lira
		case .ttd   : return "🇹🇹" // Trinidad and Tobago Dollar
		case .twd   : return "🇹🇼" // New Taiwan Dollar
		case .tzs   : return "🇹🇿" // Tanzanian Shilling
		case .uah   : return "🇺🇦" // Ukrainian Hryvnia
		case .ugx   : return "🇺🇬" // Ugandan Shilling
		case .usd   : return "🇺🇸" // United States Dollar
		case .uyu   : return "🇺🇾" // Uruguayan Peso
		case .uzs   : return "🇺🇿" // Uzbekistan Som
		case .vnd   : return "🇻🇳" // Vietnamese Dong
		case .vuv   : return "🇻🇺" // Vanuatu Vatu
		case .wst   : return "🇼🇸" // Samoan Tala
		case .xaf   : return "🇨🇲" // CFA Franc BEAC        - multiple options, chose country with highest GDP
		case .xcd   : return "🇱🇨" // East Caribbean Dollar - multiple options, chose country with highest GDP
		case .xof   : return "🇨🇮" // CFA Franc BCEAO       - multiple options, chose country with highest GDP
		case .xpf   : return "🇳🇨" // CFP Franc             - multiple options, chose country with highest GDP
		case .yer   : return "🇾🇪" // Yemeni Rial
		case .zar   : return "🇿🇦" // South African Rand
		case .zmw   : return "🇿🇲" // Zambian Kwacha
		default     : return "🏳️"
	}}
	
	fileprivate struct _Key {
		static var matchingLocales = 0
	}
	
	func matchingLocales() -> [Locale] {
		executeOnce(storageKey: &_Key.matchingLocales) {
			
			var matchingLocales = [Locale]()
			for identifier in Locale.availableIdentifiers {
			
				let locale = Locale(identifier: identifier)
				if let currencyCode = locale.currencyCode,
					currencyCode.caseInsensitiveCompare(self.name) == .orderedSame
				{
					matchingLocales.append(locale)
				}
			}
			
			return matchingLocales
		}
	}
}

extension BitcoinUnit {
	
	var shortName: String {
		return name.lowercased()
	}
	
	var explanation: String {
		
		let s = FormattedAmount.fractionGroupingSeparator // narrow no-break space
		switch (self) {
			case BitcoinUnit.sat  : return "0.000\(s)000\(s)01 BTC"
			case BitcoinUnit.bit  : return "0.000\(s)001 BTC"
			case BitcoinUnit.mbtc : return "0.001 BTC"
			case BitcoinUnit.btc  : return "1 BTC"
			default               : break
		}
		
		return self.name
	}
}
