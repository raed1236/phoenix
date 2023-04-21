/*
 * Copyright 2023 ACINQ SAS
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

package fr.acinq.phoenix.db.payments

import fr.acinq.lightning.db.ChannelCloseOutgoingPayment
import fr.acinq.lightning.db.SpliceOutgoingPayment
import fr.acinq.lightning.utils.UUID
import fr.acinq.lightning.utils.sat
import fr.acinq.lightning.utils.toByteVector32
import fr.acinq.phoenix.db.PaymentsDatabase

class ChannelCloseOutgoingQueries(val database: PaymentsDatabase) {
    private val channelCloseQueries = database.channelCloseOutgoingPaymentQueries

    fun getChannelCloseOutgoingPayment(id: UUID): ChannelCloseOutgoingPayment? {
        return channelCloseQueries.getChannelCloseOutgoing(id.toString(), ::mapChannelCloseOutgoingPayment).executeAsOneOrNull()
    }

    fun addChannelCloseOutgoingPayment(payment: ChannelCloseOutgoingPayment) {
        val (closingInfoType, closingInfoBlob) = payment.mapClosingTypeToDb()
        channelCloseQueries.insertChannelCloseOutgoing(
            id = payment.id.toString(),
            amount_sat = payment.amountSatoshi.sat,
            address = payment.address,
            is_default_address = if (payment.isSentToDefaultAddress) 1 else 0,
            mining_fees_sat = payment.miningFees.sat,
            tx_id = payment.txId.toByteArray(),
            created_at = payment.createdAt,
            confirmed_at = payment.confirmedAt,
            channel_id = payment.channelId.toByteArray(),
            closing_info_type = closingInfoType,
            closing_info_blob = closingInfoBlob,
        )
    }

    fun setConfirmed(id: UUID, confirmedAt: Long) {
        channelCloseQueries.setConfirmed(confirmed_at = confirmedAt, id = id.toString())
    }

    companion object {
        fun mapChannelCloseOutgoingPayment(
            id: String,
            amount_sat: Long,
            address: String,
            is_default_address: Long,
            mining_fees_sat: Long,
            tx_id: ByteArray,
            created_at: Long,
            confirmed_at: Long?,
            channel_id: ByteArray,
            closing_info_type: OutgoingPartClosingInfoTypeVersion,
            closing_info_blob: ByteArray
        ): ChannelCloseOutgoingPayment {
            return ChannelCloseOutgoingPayment(
                id = UUID.fromString(id),
                amountSatoshi = amount_sat.sat,
                address = address,
                isSentToDefaultAddress = is_default_address == 1L,
                miningFees = mining_fees_sat.sat,
                txId = tx_id.toByteVector32(),
                createdAt = created_at,
                confirmedAt = confirmed_at,
                channelId = channel_id.toByteVector32(),
                closingType = OutgoingPartClosingInfoData.deserialize(closing_info_type, closing_info_blob),
            )
        }
    }
}