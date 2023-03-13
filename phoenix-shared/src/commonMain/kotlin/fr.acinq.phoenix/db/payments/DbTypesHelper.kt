/*
 * Copyright 2021 ACINQ SAS
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

import io.ktor.utils.io.charsets.*
import io.ktor.utils.io.core.*
import kotlinx.serialization.json.Json
import kotlinx.serialization.modules.SerializersModule
import kotlinx.serialization.modules.polymorphic
import kotlinx.serialization.modules.subclass

object DbTypesHelper {
    /** Decode a byte array and apply a deserialization handler. */
    fun <T> decodeBlob(blob: ByteArray, handler: (String, Json) -> T) = handler(String(bytes = blob, charset = Charsets.UTF_8), Json)

    val module = SerializersModule {
        polymorphic(IncomingReceivedWithData.Part::class) {
            subclass(IncomingReceivedWithData.Part.Htlc.V0::class)
            @Suppress("DEPRECATION")
            subclass(IncomingReceivedWithData.Part.NewChannel.V0::class)
            subclass(IncomingReceivedWithData.Part.NewChannel.V1::class)
            subclass(IncomingReceivedWithData.Part.SpliceIn.V0::class)
        }
    }

    val polymorphicFormat = Json { serializersModule = module }
}