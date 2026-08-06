package com.openclaw.plawie

import android.hardware.biometrics.BiometricManager
import android.security.keystore.KeyProperties
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class WalletAuthenticatorPolicyTest {
    @Test
    fun `biometric APIs and Android Keystore use their own authenticator masks`() {
        val expectedBiometricApiMask =
            BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
        val expectedKeyStoreMask =
            KeyProperties.AUTH_BIOMETRIC_STRONG or
                KeyProperties.AUTH_DEVICE_CREDENTIAL

        assertEquals(expectedBiometricApiMask, WalletAuthenticatorPolicy.biometricApiMask)
        assertEquals(expectedKeyStoreMask, WalletAuthenticatorPolicy.keyStoreMask)
        assertNotEquals(WalletAuthenticatorPolicy.biometricApiMask, WalletAuthenticatorPolicy.keyStoreMask)
    }
}
