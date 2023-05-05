package fr.acinq.phoenix.utils

import fr.acinq.lightning.blockchain.electrum.ElectrumMiniWallet
import fr.acinq.lightning.blockchain.electrum.WalletState
import fr.acinq.lightning.channel.*
import fr.acinq.lightning.db.IncomingPayment
import fr.acinq.lightning.db.LightningOutgoingPayment
import fr.acinq.lightning.db.OutgoingPayment
import fr.acinq.lightning.io.NativeSocketException
import fr.acinq.lightning.io.TcpSocket
import fr.acinq.lightning.utils.Connection
import kotlinx.coroutines.flow.StateFlow

/**
 * Class types from lightning-kmp & bitcoin-kmp are not exported to iOS unless we explicitly
 * reference them within PhoenixShared, either as a public parameter or return type.
 *
 * This problem is restricted to iOS, and does not affect Android.
 */

fun IncomingPayment.Origin.asInvoice(): IncomingPayment.Origin.Invoice? = when (this) {
    is IncomingPayment.Origin.Invoice -> this
    else -> null
}

fun IncomingPayment.Origin.asKeySend(): IncomingPayment.Origin.KeySend? = when (this) {
    is IncomingPayment.Origin.KeySend -> this
    else -> null
}

fun IncomingPayment.Origin.asSwapIn(): IncomingPayment.Origin.SwapIn? = when (this) {
    is IncomingPayment.Origin.SwapIn -> this
    else -> null
}

fun IncomingPayment.Origin.asOnChain(): IncomingPayment.Origin.OnChain? = when (this) {
    is IncomingPayment.Origin.OnChain -> this
    else -> null
}

fun IncomingPayment.ReceivedWith.asLightningPayment(): IncomingPayment.ReceivedWith.LightningPayment? = when (this) {
    is IncomingPayment.ReceivedWith.LightningPayment -> this
    else -> null
}

fun IncomingPayment.ReceivedWith.asNewChannel(): IncomingPayment.ReceivedWith.NewChannel? = when (this) {
    is IncomingPayment.ReceivedWith.NewChannel -> this
    else -> null
}

fun IncomingPayment.ReceivedWith.asSpliceIn(): IncomingPayment.ReceivedWith.SpliceIn? = when (this) {
    is IncomingPayment.ReceivedWith.SpliceIn -> this
    else -> null
}

fun LightningOutgoingPayment.Details.asNormal(): LightningOutgoingPayment.Details.Normal? = when (this) {
    is LightningOutgoingPayment.Details.Normal -> this
    else -> null
}

fun LightningOutgoingPayment.Details.asKeySend(): LightningOutgoingPayment.Details.KeySend? = when (this) {
    is LightningOutgoingPayment.Details.KeySend -> this
    else -> null
}

fun LightningOutgoingPayment.Details.asSwapOut(): LightningOutgoingPayment.Details.SwapOut? = when (this) {
    is LightningOutgoingPayment.Details.SwapOut -> this
    else -> null
}

fun LightningOutgoingPayment.Status.asPending(): LightningOutgoingPayment.Status.Pending? = when (this) {
    is LightningOutgoingPayment.Status.Pending -> this
    else -> null
}

fun LightningOutgoingPayment.Status.asFailed(): LightningOutgoingPayment.Status.Completed.Failed? = when (this) {
    is LightningOutgoingPayment.Status.Completed.Failed -> this
    else -> null
}

fun LightningOutgoingPayment.Status.asSucceeded(): LightningOutgoingPayment.Status.Completed.Succeeded? = when (this) {
    is LightningOutgoingPayment.Status.Completed.Succeeded -> this
    else -> null
}

fun LightningOutgoingPayment.Status.asOffChain(): LightningOutgoingPayment.Status.Completed.Succeeded.OffChain? = when (this) {
    is LightningOutgoingPayment.Status.Completed.Succeeded.OffChain -> this
    else -> null
}

fun ChannelState.asOffline(): Offline? = when (this) {
    is Offline -> this
    else -> null
}
fun ChannelState.asClosing(): Closing? = when (this) {
    is Closing -> this
    else -> null
}
fun ChannelState.asClosed(): Closed? = when (this) {
    is Closed -> this
    else -> null
}
fun ChannelState.asAborted(): Aborted? = when (this) {
    is Aborted -> this
    else -> null
}

fun TcpSocket.TLS.asDisabled(): TcpSocket.TLS.DISABLED? = when (this) {
    is TcpSocket.TLS.DISABLED -> this
    else -> null
}

fun TcpSocket.TLS.asTrustedCertificates(): TcpSocket.TLS.TRUSTED_CERTIFICATES? = when (this) {
    is TcpSocket.TLS.TRUSTED_CERTIFICATES -> this
    else -> null
}

fun TcpSocket.TLS.asPinnedPublicKey(): TcpSocket.TLS.PINNED_PUBLIC_KEY? = when (this) {
    is TcpSocket.TLS.PINNED_PUBLIC_KEY -> this
    else -> null
}

fun TcpSocket.TLS.asUnsafeCertificates(): TcpSocket.TLS.UNSAFE_CERTIFICATES? = when (this) {
    is TcpSocket.TLS.UNSAFE_CERTIFICATES -> this
    else -> null
}

fun Connection.asClosed(): Connection.CLOSED? = when (this) {
    is Connection.CLOSED -> this
    else -> null
}

fun Connection.asEstablishing(): Connection.ESTABLISHING? = when (this) {
    is Connection.ESTABLISHING -> this
    else -> null
}

fun Connection.isEstablished(): Connection.ESTABLISHED? = when (this) {
    is Connection.ESTABLISHED -> this
    else -> null
}

fun NativeSocketException.asPOSIX(): NativeSocketException.POSIX? = when (this) {
    is NativeSocketException.POSIX -> this
    else -> null
}

fun NativeSocketException.asDNS(): NativeSocketException.DNS? = when (this) {
    is NativeSocketException.DNS -> this
    else -> null
}

fun NativeSocketException.asTLS(): NativeSocketException.TLS? = when (this) {
    is NativeSocketException.TLS -> this
    else -> null
}

fun ElectrumMiniWallet.currentWalletState(): WalletState = this.walletStateFlow.value
