import SwiftUI
import SegmentedPicker
import PhoenixShared
import os.log

#if DEBUG && true
fileprivate var log = Logger(
	subsystem: Bundle.main.bundleIdentifier!,
	category: "ChannelInfoPopup"
)
#else
fileprivate var log = Logger(OSLog.disabled)
#endif


struct ChannelInfoPopup: View, ViewName {
	
	enum Tab: String, CaseIterable {
		case summary
		case rawData
		
		func localized() -> String {
			switch self {
			case .summary : return NSLocalizedString("Summary",
					comment: "ChannelsConfigurationView/ChannelInfoPopup/TabBar")
			case .rawData : return NSLocalizedString("Raw Data",
					comment: "ChannelsConfigurationView/ChannelInfoPopup/TabBar")
			}
		}
	}
	
	let channel: LocalChannelInfo
	@Binding var sharing: String?
	@ObservedObject var toast: Toast
	
	@State var selectedTab: Tab = .summary
	@State var showBlockchainExplorerOptions = false
	
	@Environment(\.colorScheme) var colorScheme: ColorScheme
	@Environment(\.popoverState) var popoverState: PopoverState
	
	@ViewBuilder
	var body: some View {
		
		VStack {
			header()
			content()
			footer()
		}
	}
	
	@ViewBuilder
	func header() -> some View {
		
		HStack(alignment: VerticalAlignment.center, spacing: 0) {
			Spacer()
			
			SegmentedPicker(Tab.allCases, selectedIndex: selectedTabIndex()) { tab, isSelected in
				Text(verbatim: tab.localized())
					.foregroundColor(isSelected ? .primary : .secondary )
					.padding(.horizontal, 16)
					.padding(.vertical, 8)
			} selection: {
				VStack(spacing: 0) {
					Spacer()
					Color.appAccent.frame(height: 1)
				}
			}
			.animation(.easeInOut(duration: 0.3), value: selectedTab)
			
			Spacer()
		}
		.padding(.top, 5)
		.padding([.leading, .trailing])
		.padding(.bottom, 10)
		.background(
			Color(UIColor.secondarySystemBackground)
		)
	}
	
	@ViewBuilder
	func content() -> some View {
		
		switch selectedTab {
		case .summary:
			ScrollView(.vertical) {
				ChannelInfoPopup_Summary(channel: channel, sharing: $sharing)
			}
			.frame(maxHeight: 300)
			
		case .rawData:
			ScrollView {
				Text(channel.json)
					.font(.caption)
					.padding()
			}
			.environment(\.layoutDirection, .leftToRight) // issue #237
			.frame(maxWidth: .infinity, alignment: .leading)
			.frame(maxHeight: 300)
		}
	}
	
	@ViewBuilder
	func footer() -> some View {
		
		HStack {
			Button {
				UIPasteboard.general.string = channel.json
				toast.pop(
					NSLocalizedString("Copied to pasteboard!", comment: "Toast message"),
					colorScheme: colorScheme.opposite
				)
			} label: {
				Image(systemName: "square.on.square")
					.resizable()
					.scaledToFit()
					.frame(width: 22, height: 22)
			}

			Divider()
				.frame(height: 30)
				.padding([.leading, .trailing], 8)

			Button {
				sharing = channel.json
			} label: {
				Image(systemName: "square.and.arrow.up")
					.resizable()
					.scaledToFit()
					.frame(width: 22, height: 22)
			}

			Spacer()
			Button("Close") {
				closePopover()
			}
			.font(.title2)
		}
		.padding(.top, 10)
		.padding([.leading, .trailing])
		.padding(.bottom, 10)
		.background(
			Color(UIColor.secondarySystemBackground)
		)
	}
	
	func selectedTabIndex() -> Binding<Tab.AllCases.Index?> {
		return Binding<Tab.AllCases.Index?>(
			get: { Tab.allCases.firstIndex(of: selectedTab) },
			set: { if let idx = $0 { selectedTab = Tab.allCases[idx] } else { selectedTab = .summary } }
		)
	}
	
	func closePopover() -> Void {
		log.trace("[\(viewName)] closePopover()")
		
		popoverState.close()
	}
}

// --------------------------------------------------
// MARK: -
// --------------------------------------------------

fileprivate struct ChannelInfoPopup_Summary: InfoGridView, ViewName {
	
	let channel: LocalChannelInfo
	@Binding var sharing: String?
	
	// <InfoGridView Protocol>
	let minKeyColumnWidth: CGFloat = 50
	let maxKeyColumnWidth: CGFloat = 150 // 200
	
	@State var keyColumnSizes: [InfoGridRow_KeyColumn_Size] = []
	func setKeyColumnSizes(_ sizes: [InfoGridRow_KeyColumn_Size]) {
		keyColumnSizes = sizes
	}
	func getKeyColumnSizes() -> [InfoGridRow_KeyColumn_Size] {
		return keyColumnSizes
	}
	
	@State var rowSizes: [InfoGridRow_Size] = []
	func setRowSizes(_ sizes: [InfoGridRow_Size]) {
		rowSizes = sizes
	}
	func getRowSizes() -> [InfoGridRow_Size] {
		return rowSizes
	}
	// </InfoGridView Protocol>
	
	@State var showBlockchainExplorerOptions = false
	
	private let verticalSpacingBetweenRows: CGFloat = 12
	private let horizontalSpacingBetweenColumns: CGFloat = 8
	
	@EnvironmentObject var currencyPrefs: CurrencyPrefs
	
	// --------------------------------------------------
	// MARK: View Builders
	// --------------------------------------------------
	
	@ViewBuilder
	var infoGridRows: some View {
		
		VStack(
			alignment : HorizontalAlignment.leading,
			spacing   : verticalSpacingBetweenRows
		) {

			channelIdRow()
			stateRow()
			canSendRow()
			activeCommitments()
			inactiveCommitments()

		} // </VStack>
		.padding()
	}
	
	@ViewBuilder
	func keyColumn_standard(_ title: String) -> some View {
		
		Text(title.lowercased())
			.font(.subheadline)
			.fontWeight(.thin)
			.multilineTextAlignment(.trailing)
			.foregroundColor(.secondary)
	}
	
	@ViewBuilder
	func keyColumn_indented(identifier: String, title: String) -> some View {
		
		HStack(alignment: VerticalAlignment.top, spacing: 0) {
			Divider()
				.frame(width: 4, height: 1)
				.overlay(Color.appAccent)
				.padding(.horizontal, 8)
			
			keyColumn_standard(title)
		}
	}
	
	@ViewBuilder
	func indentedRowBackground(_ identifier: String) -> some View {
		if let height = rowSize(identifier: identifier)?.height {
			Divider()
				.frame(width: 4, height: height)
				.overlay(Color.appAccent)
				.padding(.leading, 8)
		}
	}
	
	@ViewBuilder
	func channelIdRow() -> some View {
		let identifier: String = #function
		
		InfoGridRow(
			identifier: identifier,
			vAlignment: .firstTextBaseline,
			hSpacing: horizontalSpacingBetweenColumns,
			keyColumnWidth: keyColumnWidth(identifier: identifier),
			keyColumnAlignment: .leading
		) {
			keyColumn_standard(
				NSLocalizedString("channel id", comment: "Label in ChannelInfoPopup_Summary")
			)
		} valueColumn: {
			
			let text = channel.channelId
			Text(text)
				.lineLimit(1)
				.truncationMode(.middle)
				.contextMenu {
					Button(action: {
						UIPasteboard.general.string = text
					}) {
						Text("Copy")
					}
				}
			
		} // </InfoGridRow>
	}
	
	@ViewBuilder
	func stateRow() -> some View {
		let identifier: String = #function
		
		InfoGridRow(
			identifier: identifier,
			vAlignment: .firstTextBaseline,
			hSpacing: horizontalSpacingBetweenColumns,
			keyColumnWidth: keyColumnWidth(identifier: identifier),
			keyColumnAlignment: .leading
		) {
			keyColumn_standard(
				NSLocalizedString("state", comment: "Label in ChannelInfoPopup_Summary")
			)
		} valueColumn: {
			
			Text(channel.stateName)
		}
	}
	
	@ViewBuilder
	func canSendRow() -> some View {
		let identifier: String = #function
		
		if let localBalance = channel.localBalance {
			
			InfoGridRow(
				identifier: identifier,
				vAlignment: .firstTextBaseline,
				hSpacing: horizontalSpacingBetweenColumns,
				keyColumnWidth: keyColumnWidth(identifier: identifier),
				keyColumnAlignment: .leading
			) {
				keyColumn_standard(
					NSLocalizedString("can send", comment: "Label in ChannelInfoPopup_Summary")
				)
			} valueColumn: {
				
				let sats = Utils.formatBitcoin(
					msat: localBalance,
					bitcoinUnit: .sat,
					policy: .showMsatsIfZeroSats
				)
				
				Text(sats.string)
			}
		}
	}
	
	@ViewBuilder
	func activeCommitments() -> some View {
		let identifier: String = #function
		
		if !channel.commitmentsInfo.isEmpty {
			
			VStack(alignment: HorizontalAlignment.leading, spacing: 0) {
				
				InfoGridRow(
					identifier: identifier,
					vAlignment: .firstTextBaseline,
					hSpacing: horizontalSpacingBetweenColumns,
					keyColumnWidth: keyColumnWidth(identifier: identifier),
					keyColumnAlignment: .leading
				) {
					keyColumn_standard(
						NSLocalizedString("active commitments", comment: "Label in ChannelInfoPopup_Summary")
					)
				} valueColumn: {
					Text(verbatim: "")
				}
				
				ForEach(channel.commitmentsInfo, id: \.fundingTxId) { commitment in
					Spacer().frame(height: verticalSpacingBetweenRows)
					commitment_txIndex(commitment)
					commitment_fundingTx(commitment)
					commitment_balance(commitment)
					commitment_capacity(commitment)
				}
			}
		}
	}
	
	@ViewBuilder
	func inactiveCommitments() -> some View {
		let identifier: String = #function
		
		if !channel.inactiveCommitmentsInfo.isEmpty {
			
			VStack(alignment: HorizontalAlignment.leading, spacing: 0) {
				
				InfoGridRow(
					identifier: identifier,
					vAlignment: .firstTextBaseline,
					hSpacing: horizontalSpacingBetweenColumns,
					keyColumnWidth: keyColumnWidth(identifier: identifier),
					keyColumnAlignment: .leading
				) {
					keyColumn_standard(
						NSLocalizedString("inactive commitments", comment: "Label in ChannelInfoPopup_Summary")
					)
				} valueColumn: {
					Text(verbatim: "")
				}
				
				ForEach(channel.inactiveCommitmentsInfo, id: \.fundingTxId) { commitment in
					Spacer().frame(height: verticalSpacingBetweenRows)
					commitment_txIndex(commitment)
					commitment_fundingTx(commitment)
					commitment_balance(commitment)
					commitment_capacity(commitment)
				}
			}
		}
	}
	
	@ViewBuilder
	func commitment_txIndex(_ commitment: LocalChannelInfo.CommitmentInfo) -> some View {
		let identifier: String = "\(#function)|\(commitment.fundingTxId)"
		
		InfoGridRow(
			identifier: identifier,
			vAlignment: .firstTextBaseline,
			hSpacing: horizontalSpacingBetweenColumns,
			keyColumnWidth: keyColumnWidth(identifier: identifier),
			keyColumnAlignment: .leading
		) {
			keyColumn_indented(
				identifier: identifier,
				title: NSLocalizedString("tx index", comment: "Label in ChannelInfoPopup_Summary")
			)
		} valueColumn: {
			
			Text(commitment.fundingTxIndex.description)
				.padding(.bottom, verticalSpacingBetweenRows)
			
		} // </InfoGridRow>
		.background(indentedRowBackground(identifier), alignment: Alignment.topLeading)
	}
	
	@ViewBuilder
	func commitment_fundingTx(_ commitment: LocalChannelInfo.CommitmentInfo) -> some View {
		let identifier: String = "\(#function)|\(commitment.fundingTxId)"

		InfoGridRow(
			identifier: identifier,
			vAlignment: .firstTextBaseline,
			hSpacing: horizontalSpacingBetweenColumns,
			keyColumnWidth: keyColumnWidth(identifier: identifier),
			keyColumnAlignment: .leading
		) {
			keyColumn_indented(
				identifier: identifier,
				title: NSLocalizedString("funding tx", comment: "Label in ChannelInfoPopup_Summary")
			)
		} valueColumn: {

			let txId = commitment.fundingTxId
			Button {
				showBlockchainExplorerOptions = true
			} label: {
				HStack(alignment: VerticalAlignment.firstTextBaseline, spacing: 4) {
					Text(txId).lineLimit(1).truncationMode(.middle)
					Image(systemName: "link").imageScale(.small)
				}
			}
			.padding(.bottom, verticalSpacingBetweenRows)
			.confirmationDialog("Blockchain Explorer",
				isPresented: $showBlockchainExplorerOptions,
				titleVisibility: .automatic
			) {
				Button {
					exploreTx(txId, website: BlockchainExplorer.WebsiteMempoolSpace())
				} label: {
					Text(verbatim: "Mempool.space") // no localization needed
				}
				Button {
					exploreTx(txId, website: BlockchainExplorer.WebsiteBlockstreamInfo())
				} label: {
					Text(verbatim: "Blockstream.info") // no localization needed
				}
				Button("Copy transaction id") {
					copyTxId(txId)
				}
			} // </confirmationDialog>

		} // </InfoGridRow>
		.background(indentedRowBackground(identifier), alignment: Alignment.topLeading)
	}
	
	@ViewBuilder
	func commitment_balance(_ commitment: LocalChannelInfo.CommitmentInfo) -> some View {
		let identifier: String = "\(#function)|\(commitment.fundingTxId)"

		InfoGridRow(
			identifier: identifier,
			vAlignment: .firstTextBaseline,
			hSpacing: horizontalSpacingBetweenColumns,
			keyColumnWidth: keyColumnWidth(identifier: identifier),
			keyColumnAlignment: .leading
		) {
			keyColumn_indented(
				identifier: identifier,
				title: NSLocalizedString("balance", comment: "Label in ChannelInfoPopup_Summary")
			)
		} valueColumn: {

			let amt = Utils.formatBitcoin(
				msat: commitment.balanceForSend,
				bitcoinUnit: .sat,
				policy: .showMsatsIfNonZero
			)
			Text(amt.string)
				.padding(.bottom, verticalSpacingBetweenRows)

		} // </InfoGridRow>
		.background(indentedRowBackground(identifier), alignment: Alignment.topLeading)
	}
	
	@ViewBuilder
	func commitment_capacity(_ commitment: LocalChannelInfo.CommitmentInfo) -> some View {
		let identifier: String = "\(#function)|\(commitment.fundingTxId)"

		InfoGridRow(
			identifier: identifier,
			vAlignment: .firstTextBaseline,
			hSpacing: horizontalSpacingBetweenColumns,
			keyColumnWidth: keyColumnWidth(identifier: identifier),
			keyColumnAlignment: .leading
		) {
			keyColumn_indented(
				identifier: identifier,
				title: NSLocalizedString("capacity", comment: "Label in ChannelInfoPopup_Summary")
			)
		} valueColumn: {

			let amt = Utils.formatBitcoin(
				sat: commitment.fundingAmount,
				bitcoinUnit: .sat
			)
			Text(amt.string)

		} // </InfoGridRow>
		.background(indentedRowBackground(identifier), alignment: Alignment.topLeading)
	}
	
	// --------------------------------------------------
	// MARK: Actions
	// --------------------------------------------------
	
	func exploreTx(_ txId: String, website: BlockchainExplorer.Website) {
		log.trace("exploreTX()")
		
		let txUrlStr = Biz.business.blockchainExplorer.txUrl(txId: txId, website: website)
		if let txUrl = URL(string: txUrlStr) {
			UIApplication.shared.open(txUrl)
		}
	}
	
	func copyTxId(_ txId: String) {
		log.trace("copyTxId()")
		
		UIPasteboard.general.string = txId
	}
}
