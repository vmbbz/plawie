# Wallet, Bridge, and Payment Release Checklist

Date: 2026-08-07

This checklist is fail-closed. A checked implementation item is not permission
to move funds. Controlled Mainnet spending requires a separate, fresh human
instruction and both visible approval surfaces.

## Identity and persistence

- [ ] Record the wallet address before installation and prove the same address
      remains after `adb install -r` with the same package/signing identity.
- [ ] Verify Base Mainnet, Robinhood Chain, and Base Sepolia show the same EVM
      address while balances/assets remain network-specific.
- [ ] Verify Create, Import, Export, Remove, damaged-envelope recovery, and
      legacy migration show Android authentication and accurate cancellation.
- [ ] Verify clearing app data/uninstall is documented as destructive; never do
      it during update-persistence acceptance.

## Network and signer policy

- [ ] Base Mainnet exposes ETH/native USDC; Robinhood exposes ETH/official USDG;
      Base Sepolia is visibly testnet.
- [ ] Robinhood requires explicit `0x` recipients and never offers Basenames.
- [ ] Android rejects wrong chain, wrong contract, arbitrary calldata, unlimited
      approval, replayed approval, and every Robinhood x402 payload.
- [ ] Release `ROBINHOOD_RPC_URL` is HTTPS and responsive without logging its
      value; missing configuration disables only internal Robinhood sends.

## Funding routes

- [ ] Live capability refresh offers Robinhood ETH and official USDG only when
      a current route to native Base USDC exists.
- [ ] Connected wallet selection is protocol/capability based; wallet names are
      test fixtures, not execution allowlists.
- [ ] Bridge review shows source chain, asset, exact amount, minimum Base USDC,
      destination, route, fees, and expiry before the external-wallet request.
- [ ] Robinhood funding warns to retain ETH gas and provides no full-balance ETH
      shortcut.
- [ ] Relay uses a new one-time address, exact amount, personal refund address,
      expiry, and no local `I sent it` completion claim.
- [ ] Cancel/reject, partial, refunded, failed, expired, and outcome-unknown
      paths never continue a provider top-up.
- [ ] Restart resumes redacted status only and never reconnects, signs, sends,
      or broadcasts a second time.

## Provider payment separation

- [ ] An insufficient first provider challenge is rejected before funding UI.
- [ ] Completed Base delivery switches the Wallet view to Base Mainnet and
      performs a fresh exact native-USDC balance read.
- [ ] The provider returns a new challenge after funding; any increased amount
      above the refreshed balance is rejected.
- [ ] Bridge review and provider x402 review are separate, and Android requires
      device authentication after provider approval.
- [ ] Chat, agent tools, notifications, deep links, and background state cannot
      approve, authenticate, sign, submit, or retry either transaction.
- [ ] Bridge and x402 receipts remain separate and contain no key, signature,
      raw calldata, wallet session, prompt, tool payload, or secret.

## Gateway and regression

- [ ] Native Gateway remains primary; no wallet/provider path selects PRoot.
- [ ] Gateway startup, node pairing, model discovery, context preservation,
      streaming, tools, and skill routes pass with Wallet changes installed.
- [ ] Flutter tests, Android JVM tests/lint, analyzer, secret scan, and artifact
      scan pass; generated registrants, APKs, bundles, logs, and reports remain
      untracked.
- [ ] Debug APK installs with `adb install -r` without clearing data and launches
      successfully; non-spending network switching and modal cancellation pass.

## External release ownership

- [ ] Reown licensee, current terms/plan, package restrictions, attribution,
      branding, legal bundle, and projected usage are recorded and approved.
- [ ] Reown project ID, dapp URL, production Robinhood RPC, and release signing
      are supplied outside source control.
- [ ] Controlled Mainnet bridge and x402 settlement evidence is reviewed before
      any corresponding release gate is enabled for users.
