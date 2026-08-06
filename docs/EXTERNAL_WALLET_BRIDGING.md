# External Wallet Bridging

Status: dependency baseline only

Date reviewed: 2026-08-07

## Reown dependency and license review

Pub resolved `reown_appkit` **1.7.6**. The package archive SHA-256 recorded in
`pubspec.lock` is
`6ea7d0145608d41f38c2286119dfbf1cdabad6644ebe8c8ecb13c0177dae14ee`.
The reviewed license text is the package artifact
`reown_appkit-1.7.6/LICENSE`, SHA-256
`5EB00FF6EA068D9DBAB1AFB20E6D44B5992A6955E7623D1271C5BE98947861E6`.
It identifies itself as the **Reown Community License Agreement**, released
20 August 2025; the package does not declare an SPDX license identifier.

For a distributed application using AppKit, the confirmed legal licensee must
ensure that the following distribution requirements are met:

- include `Portions © 2025 Reown, Inc. All Rights Reserved` in product notices,
  a readme, or an about surface;
- provide a copy of the license with the application;
- satisfy the applicable logo and branding requirements; and
- use the Reown network unless Reown explicitly approves otherwise.

The license also states royalty-free thresholds of 2,500,000 remote processing
calls per month and 500 monthly active users, after which a commercial license
is required. This records the package text, not a conclusion that Plawie's
planned use qualifies for a particular tier or for production release.

## Product and release terminology

`Plawie` is the user-facing product name. `clawa` is the current package
identifier in `pubspec.yaml`; neither name is asserted here to be a legal
entity. `Release owner` means the accountable distributor or release
maintainer. Before production enablement, the release owner must record the
confirmed legal licensee identity in the dated release review described below.

## Service terms requiring release-time confirmation

The package license alone does not establish the applicable Reown account,
project, subscription, billing, branding entitlement, acceptable-use rules,
privacy/data-processing terms, geographic restrictions, or how current usage is
measured. Before enabling connected mode, the release owner must review and
accept the then-current [Reown Terms of Service](https://reown.com/terms-of-service),
[pricing and project limits](https://reown.com/pricing), and
[Flutter project configuration guidance](https://docs.reown.com/appkit/flutter/cloud/relay).
The release must use a valid Plawie-specific project ID, restrict it to the
shipped application identity where supported, keep it out of source control,
and confirm that the selected plan and branding treatment cover expected use.

## Planned enablement evidence

Task 11 owns the following release evidence and must complete it before
connected mode can be enabled:

- keep a dated production release review/checklist in
  `docs/EXTERNAL_WALLET_BRIDGING.md`, including the confirmed legal licensee
  identity and the applicable configuration, license, service terms, plan,
  branding, and projected-usage decisions;
- add the shipped Reown license copy under
  `android/app/src/main/assets/licenses/`; and
- provide the required attribution and branding in an in-app About or legal
  surface.

These assets and UI are intentionally not created in Task 1. If any required
evidence or shipped surface is absent, the feature gate must remain disabled.

## Task 1 release decision

This round adds dependencies only. No connected LI.FI execution implementation
exists in the current app. Before such code is added or shipped, Task 2 must
introduce the planned compile-time `ENABLE_LIFI_CONNECTED_BRIDGE` feature gate,
defaulting to disabled. That gate may be enabled only after a valid Reown
project configuration is supplied and the release owner completes and records
the current license, service-terms, attribution, branding, and projected-usage
check. An unresolved check requires the gate to remain disabled; dependency
resolution is not production approval.

Task 11 will expand this document with operational architecture, threat model,
recovery, release gates, and user-flow guidance.
