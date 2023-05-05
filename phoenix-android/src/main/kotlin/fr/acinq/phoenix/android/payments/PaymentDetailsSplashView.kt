/*
 * Copyright 2022 ACINQ SAS
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package fr.acinq.phoenix.android.payments

import androidx.compose.animation.graphics.ExperimentalAnimationGraphicsApi
import androidx.compose.animation.graphics.res.animatedVectorResource
import androidx.compose.animation.graphics.res.rememberAnimatedVectorPainter
import androidx.compose.animation.graphics.vector.AnimatedImageVector
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.MaterialTheme
import androidx.compose.material.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import fr.acinq.bitcoin.ByteVector32
import fr.acinq.lightning.blockchain.electrum.getConfirmations
import fr.acinq.lightning.blockchain.fee.FeeratePerByte
import fr.acinq.lightning.blockchain.fee.FeeratePerKw
import fr.acinq.lightning.channel.Command
import fr.acinq.lightning.db.*
import fr.acinq.lightning.utils.msat
import fr.acinq.lightning.utils.sat
import fr.acinq.lightning.utils.sum
import fr.acinq.phoenix.android.LocalBitcoinUnit
import fr.acinq.phoenix.android.R
import fr.acinq.phoenix.android.business
import fr.acinq.phoenix.android.components.*
import fr.acinq.phoenix.android.utils.*
import fr.acinq.phoenix.android.utils.Converter.toPrettyString
import fr.acinq.phoenix.android.utils.Converter.toRelativeDateString
import fr.acinq.phoenix.data.WalletPaymentId
import fr.acinq.phoenix.data.WalletPaymentInfo
import fr.acinq.phoenix.utils.extensions.errorMessage
import fr.acinq.phoenix.utils.extensions.minDepthForFunding
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch


@Composable
fun PaymentDetailsSplashView(
    onBackClick: () -> Unit,
    data: WalletPaymentInfo,
    onDetailsClick: (WalletPaymentId) -> Unit,
    onMetadataDescriptionUpdate: (WalletPaymentId, String?) -> Unit,
    fromEvent: Boolean,
) {
    val payment = data.payment
    SplashLayout(
        header = { DefaultScreenHeader(onBackClick = onBackClick) },
        topContent = { PaymentStatus(data.payment, fromEvent) }
    ) {
        AmountWithAltView(
            amount = payment.amount,
            amountTextStyle = MaterialTheme.typography.body1.copy(fontSize = 30.sp),
            separatorSpace = 4.dp,
            isOutgoing = payment is OutgoingPayment
        )

        Spacer(modifier = Modifier.height(36.dp))
        PrimarySeparator(height = 6.dp)
        Spacer(modifier = Modifier.height(36.dp))

        PaymentDescriptionView(data = data, onMetadataDescriptionUpdate = onMetadataDescriptionUpdate)
        PaymentDestinationView(payment = payment)
        PaymentFeeView(payment = payment)

        when (payment) {
            is ChannelCloseOutgoingPayment -> {
                ConfirmationView(payment.txId, payment.channelId)
            }
            is SpliceOutgoingPayment -> {
                ConfirmationView(payment.txId, payment.channelId)
            }
            is IncomingPayment -> {
//                Text(text = "${payment.received?.receivedWith?.filterIsInstance<IncomingPayment.ReceivedWith.OnChainIncomingPayment>()}")
                payment.received?.receivedWith?.filterIsInstance<IncomingPayment.ReceivedWith.OnChainIncomingPayment>()?.map { it.txId to it.channelId }?.firstOrNull()?.let { (txId, channelId) ->
                    ConfirmationView(txId = txId, channelId = channelId)
                }
            }
            else -> {}
        }

        data.payment.errorMessage()?.let { errorMessage ->
            Spacer(modifier = Modifier.height(8.dp))
            SplashLabelRow(label = stringResource(id = R.string.paymentdetails_error_label)) {
                Text(text = errorMessage)
            }
        }
        Spacer(modifier = Modifier.height(48.dp))
        BorderButton(
            text = stringResource(id = R.string.paymentdetails_details_button),
            borderColor = borderColor,
            textStyle = MaterialTheme.typography.caption,
            icon = R.drawable.ic_tool,
            iconTint = MaterialTheme.typography.caption.color,
            onClick = { onDetailsClick(data.id()) },
        )
    }
}

@Composable
private fun PaymentStatus(
    payment: WalletPayment,
    fromEvent: Boolean,
) {
    val peerManager = business.peerManager
    when (payment) {
        is LightningOutgoingPayment -> when (payment.status) {
            is LightningOutgoingPayment.Status.Pending -> PaymentStatusIcon(
                message = { Text(text = stringResource(id = R.string.paymentdetails_status_sent_pending)) },
                imageResId = R.drawable.ic_payment_details_pending_static,
                isAnimated = false,
                color = mutedTextColor
            )
            is LightningOutgoingPayment.Status.Completed.Failed -> PaymentStatusIcon(
                message = { Text(text = annotatedStringResource(id = R.string.paymentdetails_status_sent_failed), textAlign = TextAlign.Center) },
                imageResId = R.drawable.ic_payment_details_failure_static,
                isAnimated = false,
                color = negativeColor
            )
            is LightningOutgoingPayment.Status.Completed.Succeeded -> PaymentStatusIcon(
                message = {
                    Text(text = annotatedStringResource(id = R.string.paymentdetails_status_sent_successful, payment.completedAt?.toRelativeDateString() ?: ""))
                },
                imageResId = if (fromEvent) R.drawable.ic_payment_details_success_animated else R.drawable.ic_payment_details_success_static,
                isAnimated = fromEvent,
                color = positiveColor,
            )
        }
        is ChannelCloseOutgoingPayment -> when (payment.confirmedAt) {
            null -> {
                val nodeParams = business.nodeParamsManager.nodeParams.value
                // TODO get depth for closing
                PaymentStatusIcon(
                    message = {
                        Text(text = stringResource(id = R.string.paymentdetails_status_unconfirmed))
//                        closingDepth?.let { minDepth ->
//                            Text(
//                                text = stringResource(id = R.string.paymentdetails_status_unconfirmed_details, minDepth, 10 * minDepth),
//                                style = MaterialTheme.typography.caption
//                            )
//                        }
                    },
                    imageResId = R.drawable.ic_payment_details_pending_onchain_static,
                    isAnimated = false,
                    color = mutedTextColor,
                )
            }
            else -> PaymentStatusIcon(
                message = {
                    Text(text = annotatedStringResource(id = R.string.paymentdetails_status_channelclose_confirmed, payment.completedAt?.toRelativeDateString() ?: ""))
                },
                imageResId = if (fromEvent) R.drawable.ic_payment_details_success_animated else R.drawable.ic_payment_details_success_static,
                isAnimated = fromEvent,
                color = positiveColor,
            )
        }
        is SpliceOutgoingPayment -> when (payment.confirmedAt) {
            null -> PaymentStatusIcon(
                message = { Text(text = stringResource(id = R.string.paymentdetails_status_unconfirmed)) },
                imageResId = R.drawable.ic_payment_details_pending_onchain_static,
                isAnimated = false,
                color = mutedTextColor,
            )
            else -> PaymentStatusIcon(
                message = {
                    Text(text = annotatedStringResource(id = R.string.paymentdetails_status_sent_successful, payment.completedAt!!.toRelativeDateString()))
                },
                imageResId = if (fromEvent) R.drawable.ic_payment_details_success_animated else R.drawable.ic_payment_details_success_static,
                isAnimated = fromEvent,
                color = positiveColor,
            )
        }
        is IncomingPayment -> {
            val received = payment.received
            when {
                received == null -> {
                    PaymentStatusIcon(
                        message = { Text(text = stringResource(id = R.string.paymentdetails_status_received_pending)) },
                        imageResId = R.drawable.ic_payment_details_pending_static,
                        isAnimated = false,
                        color = mutedTextColor
                    )
                }
                received.receivedWith.isEmpty() -> {
                    PaymentStatusIcon(
                        message = { Text(text = stringResource(id = R.string.paymentdetails_status_received_paytoopen_pending)) },
                        isAnimated = false,
                        imageResId = R.drawable.ic_clock,
                        color = mutedTextColor,
                    )
                }
                received.receivedWith.any { it is IncomingPayment.ReceivedWith.OnChainIncomingPayment && it.confirmedAt == null } -> {
                    val nodeParams = business.nodeParamsManager.nodeParams.value
                    val channelMinDepth by produceState<Int?>(initialValue = null, key1 = Unit) {
                        nodeParams?.let { params ->
                            val channelId = payment.received?.receivedWith?.filterIsInstance<IncomingPayment.ReceivedWith.OnChainIncomingPayment>()?.firstOrNull()?.channelId
                            channelId?.let { peerManager.getChannelWithCommitments(it)?.minDepthForFunding(params) }
                        }
                    }
                    PaymentStatusIcon(
                        message = {
                            Text(text = stringResource(id = R.string.paymentdetails_status_unconfirmed))
                            channelMinDepth?.let { minDepth ->
                                Text(
                                    text = stringResource(id = R.string.paymentdetails_status_unconfirmed_details, minDepth, 10 * minDepth),
                                    style = MaterialTheme.typography.caption,
                                    textAlign = TextAlign.Center,
                                )
                            }
                        },
                        isAnimated = false,
                        imageResId = R.drawable.ic_clock,
                        color = mutedTextColor,
                    )
                }
                payment.completedAt == null -> {
                    PaymentStatusIcon(
                        message = {
                            Text(text = stringResource(id = R.string.paymentdetails_status_received_pending))
                        },
                        imageResId = R.drawable.ic_payment_details_pending_static,
                        isAnimated = false,
                        color = mutedTextColor
                    )
                }
                else -> {
                    PaymentStatusIcon(
                        message = {
                            Text(text = annotatedStringResource(id = R.string.paymentdetails_status_received_successful, payment.completedAt!!.toRelativeDateString()))
                        },
                        imageResId = if (fromEvent) R.drawable.ic_payment_details_success_animated else R.drawable.ic_payment_details_success_static,
                        isAnimated = fromEvent,
                        color = positiveColor,
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalAnimationGraphicsApi::class)
@Composable
private fun PaymentStatusIcon(
    message: @Composable ColumnScope.() -> Unit,
    isAnimated: Boolean,
    imageResId: Int,
    color: Color,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        val scope = rememberCoroutineScope()
        var atEnd by remember { mutableStateOf(false) }
        Image(
            painter = if (isAnimated) {
                rememberAnimatedVectorPainter(AnimatedImageVector.animatedVectorResource(imageResId), atEnd)
            } else {
                painterResource(id = imageResId)
            },
            contentDescription = null,
            colorFilter = ColorFilter.tint(color),
            modifier = Modifier.size(80.dp)
        )
        if (isAnimated) {
            LaunchedEffect(key1 = Unit) {
                scope.launch {
                    delay(150)
                    atEnd = true
                }
            }
        }
        Spacer(Modifier.height(16.dp))
        Column {
            message()
        }
    }

}

@Composable
private fun PaymentDescriptionView(
    data: WalletPaymentInfo,
    onMetadataDescriptionUpdate: (WalletPaymentId, String?) -> Unit,
) {
    var showEditDescriptionDialog by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val payment = data.payment
    val paymentDesc = remember(payment) { payment.smartDescription(context) }
    val customDesc = remember(data) { data.metadata.userDescription?.takeIf { it.isNotBlank() } }
    SplashLabelRow(label = stringResource(id = R.string.paymentdetails_desc_label)) {
        val finalDesc = paymentDesc ?: customDesc
        Text(
            text = finalDesc ?: stringResource(id = R.string.paymentdetails_no_description),
            style = if (finalDesc == null) MaterialTheme.typography.caption.copy(fontStyle = FontStyle.Italic) else MaterialTheme.typography.body1
        )
        if (paymentDesc != null && customDesc != null) {
            Spacer(modifier = Modifier.height(8.dp))
            HSeparator(width = 50.dp)
            Spacer(modifier = Modifier.height(8.dp))
            Text(text = customDesc)
        }
        Button(
            text = stringResource(
                id = when (customDesc) {
                    null -> R.string.paymentdetails_attach_desc_button
                    else -> R.string.paymentdetails_edit_desc_button
                }
            ),
            textStyle = MaterialTheme.typography.button.copy(fontSize = 12.sp),
            modifier = Modifier.offset(x = (-8).dp),
            icon = R.drawable.ic_text,
            space = 6.dp,
            shape = CircleShape,
            padding = PaddingValues(8.dp),
            onClick = { showEditDescriptionDialog = true }
        )
    }

    if (showEditDescriptionDialog) {
        EditPaymentDetails(
            initialDescription = data.metadata.userDescription,
            onConfirm = {
                onMetadataDescriptionUpdate(data.id(), it?.trim()?.takeIf { it.isNotBlank() })
                showEditDescriptionDialog = false
            },
            onDismiss = { showEditDescriptionDialog = false }
        )
    }
}

@Composable
private fun PaymentDestinationView(payment: WalletPayment) {
    when (payment) {
        is LightningOutgoingPayment -> {
            Spacer(modifier = Modifier.height(8.dp))
            SplashLabelRow(label = stringResource(id = R.string.paymentdetails_destination_label)) {
                Text(
                    text = when (val details = payment.details) {
                        is LightningOutgoingPayment.Details.Normal -> details.paymentRequest.nodeId.toString()
                        is LightningOutgoingPayment.Details.KeySend -> "Keysend"
                        is LightningOutgoingPayment.Details.SwapOut -> details.address
                    }
                )
            }
        }
        is OnChainOutgoingPayment -> {
            Spacer(modifier = Modifier.height(8.dp))
            SplashLabelRow(label = stringResource(id = R.string.paymentdetails_destination_label)) {
                Text(text = payment.address)
            }
        }
        else -> Unit
    }
}

@Composable
private fun PaymentFeeView(payment: WalletPayment) {
    val btcUnit = LocalBitcoinUnit.current
    when (payment) {
        is OutgoingPayment -> {
            Spacer(modifier = Modifier.height(8.dp))
            SplashLabelRow(label = stringResource(id = R.string.paymentdetails_fees_label)) {
                Text(text = payment.fees.toPrettyString(btcUnit, withUnit = true, mSatDisplayPolicy = MSatDisplayPolicy.SHOW_IF_ZERO_SATS))
            }
        }
        is IncomingPayment -> {
            val receivedWithNewChannel = payment.received?.receivedWith?.filterIsInstance<IncomingPayment.ReceivedWith.NewChannel>() ?: emptyList()
            val receivedWithSpliceIn = payment.received?.receivedWith?.filterIsInstance<IncomingPayment.ReceivedWith.SpliceIn>() ?: emptyList()
            if ((receivedWithNewChannel + receivedWithSpliceIn).isNotEmpty()) {
                val serviceFee = receivedWithNewChannel.map { it.serviceFee }.sum() + receivedWithSpliceIn.map { it.serviceFee }.sum()
                val fundingFee = receivedWithNewChannel.map { it.miningFee }.sum() + receivedWithSpliceIn.map { it.miningFee }.sum()
                Spacer(modifier = Modifier.height(8.dp))
                if (serviceFee > 0.msat) {
                    SplashLabelRow(
                        label = stringResource(id = R.string.paymentdetails_service_fees_label),
                        helpMessage = stringResource(R.string.paymentdetails_service_fees_desc)
                    ) {
                        Text(text = serviceFee.toPrettyString(btcUnit, withUnit = true, mSatDisplayPolicy = MSatDisplayPolicy.SHOW))
                    }
                    Spacer(modifier = Modifier.height(8.dp))
                }

                SplashLabelRow(
                    label = stringResource(id = R.string.paymentdetails_funding_fees_label),
                    helpMessage = stringResource(R.string.paymentdetails_funding_fees_desc)
                ) {
                    Text(text = fundingFee.toPrettyString(btcUnit, withUnit = true, mSatDisplayPolicy = MSatDisplayPolicy.HIDE))
                }
            }
        }
    }
}

@Composable
private fun EditPaymentDetails(
    initialDescription: String?,
    onConfirm: (String?) -> Unit,
    onDismiss: () -> Unit
) {
    var description by rememberSaveable { mutableStateOf(initialDescription) }
    Dialog(
        onDismiss = onDismiss,
        buttons = {
            Button(onClick = onDismiss, text = stringResource(id = R.string.btn_cancel))
            Button(
                onClick = { onConfirm(description) },
                text = stringResource(id = R.string.btn_save)
            )
        }
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp)
        ) {
            Text(text = stringResource(id = R.string.paymentdetails_edit_dialog_title))
            Spacer(modifier = Modifier.height(16.dp))
            TextInput(
                modifier = Modifier.fillMaxWidth(),
                text = description ?: "",
                onTextChange = { description = it.takeIf { it.isNotBlank() } },
            )
        }
    }
}

@Composable
private fun ConfirmationView(
    txId: ByteVector32,
    channelId: ByteVector32,
) {
    val electrumClient = business.electrumClient
    var confirmation by remember { mutableStateOf<Int?>(null) }
    LaunchedEffect(key1 = txId) {
        confirmation = electrumClient.getConfirmations(txId)
    }
    SplashLabelRow(
        label = stringResource(id = R.string.paymentdetails_onchain_confirmation),
        helpMessage = "How many confirmations the on-chain transaction for this payment has"
    ) {
        confirmation?.let { conf ->
            Text(text = "$conf")

            if (conf == 0) {
                var showBumpTxDialog by remember { mutableStateOf(false) }
                val scope = rememberCoroutineScope()
                val peerManager = business.peerManager

                if (showBumpTxDialog) {
                    Dialog(
                        onDismiss = { showBumpTxDialog = false },
                        title = "Bump transaction",
                        buttons = null,
                    ) {
//                        var estimateRes by remember { mutableStateOf<Command.Splice.Response?>(null)}
                        var spliceRes by remember { mutableStateOf<Command.Splice.Response?>(null)}
                        Text(text = "This transaction is unconfirmed. You can bump it with CPFP.")
                        Text(text = "**** splice-res=$spliceRes")
                        Spacer(modifier = Modifier.height(16.dp))
                        Button(text= "Do it for 50 sat/b", onClick = {
                            scope.launch {
                                val peer = peerManager.getPeer()
                                val res = peer.estimateFeeForSpliceCpfp(
                                    channelId = channelId,
                                    targetFeerate = FeeratePerKw(FeeratePerByte(50.sat))
                                )
                                if (res != null) {
                                    val (actualFeerate, fee) = res
                                    spliceRes = peer.spliceCpfp(channelId, actualFeerate)
                                }
                            }
                        })
                    }
                }

                Button(
                    text = "Bump transaction",
                    onClick = { showBumpTxDialog = true }
                )
            }
        } ?: ProgressView(text = "getting transaction details...", padding = PaddingValues(0.dp))
    }
}
