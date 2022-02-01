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

package fr.acinq.phoenix.android.init

import androidx.compose.foundation.layout.*
import androidx.compose.material.Checkbox
import androidx.compose.material.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import fr.acinq.phoenix.android.CF
import fr.acinq.phoenix.android.R
import fr.acinq.phoenix.android.components.BorderButton
import fr.acinq.phoenix.android.components.TextInput
import fr.acinq.phoenix.android.components.mvi.MVIView
import fr.acinq.phoenix.android.controllerFactory
import fr.acinq.phoenix.android.security.KeyState
import fr.acinq.phoenix.android.security.SeedManager
import fr.acinq.phoenix.android.utils.logger
import fr.acinq.phoenix.controllers.init.RestoreWallet

@Composable
fun RestoreWalletView(
    onSeedWritten: () -> Unit
) {
    val log = logger("RestoreWallet")
    val context = LocalContext.current

    val vm: InitViewModel = viewModel(factory = InitViewModel.Factory(controllerFactory, CF::initialization))

    val keyState = produceState<KeyState>(initialValue = KeyState.Unknown, true) {
        value = SeedManager.getSeedState(context)
    }

    when (keyState.value) {
        is KeyState.Absent -> {
            MVIView(CF::restoreWallet) { model, postIntent ->
                Column(
                    modifier = Modifier
                        .padding(24.dp)
                        .fillMaxWidth()
                ) {
                    var wordsInput by remember { mutableStateOf("") }
                    when (model) {
                        is RestoreWallet.Model.Ready -> {
                            var showDisclaimer by remember { mutableStateOf(true) }
                            var hasCheckedWarning by remember { mutableStateOf(false) }
                            if (showDisclaimer) {
                                Text(stringResource(R.string.restore_disclaimer_message))
                                Row(Modifier.padding(vertical = 24.dp), verticalAlignment = Alignment.CenterVertically) {
                                    Checkbox(hasCheckedWarning, onCheckedChange = { hasCheckedWarning = it })
                                    Spacer(Modifier.width(16.dp))
                                    Text(stringResource(R.string.restore_disclaimer_checkbox))
                                }
                                BorderButton(
                                    text = R.string.restore_disclaimer_next,
                                    icon = R.drawable.ic_arrow_next,
                                    onClick = { showDisclaimer = false },
                                    enabled = hasCheckedWarning
                                )
                            } else {
                                Text(stringResource(R.string.restore_instructions))
                                TextInput(
                                    text = wordsInput,
                                    onTextChange = { wordsInput = it },
                                    maxLines = 4,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(vertical = 32.dp)
                                )
                                BorderButton(
                                    text = R.string.restore_import_button,
                                    icon = R.drawable.ic_check_circle,
                                    onClick = { postIntent(RestoreWallet.Intent.Validate(wordsInput.split(" "))) },
                                    enabled = wordsInput.isNotBlank()
                                )
                            }
                        }
                        is RestoreWallet.Model.InvalidMnemonics -> {
                            Text(stringResource(R.string.restore_error))
                        }
                        is RestoreWallet.Model.ValidMnemonics -> {
                            val writingState = vm.writingState
                            if (writingState is WritingSeedState.Error) {
                                Text(stringResource(id = R.string.autocreate_error, writingState.e.localizedMessage ?: writingState.e::class.java.simpleName))
                            } else {
                                Text(stringResource(R.string.restore_in_progress))
                                LaunchedEffect(keyState) {
                                    vm.writeSeed(context, wordsInput.split(" "), false, onSeedWritten)
                                }
                            }
                        }
                        else -> {
                            Text(stringResource(id = R.string.restore_in_progress))
                        }
                    }
                }
            }
        }
        KeyState.Unknown -> {
            Text(stringResource(id = R.string.startup_wait))
        }
        else -> {
            // we should not be here
            Text(stringResource(id = R.string.startup_wait))
            LaunchedEffect(true) {
                onSeedWritten()
            }
        }
    }
}