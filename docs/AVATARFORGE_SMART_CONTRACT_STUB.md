# AvatarForge Smart-Contract Stub

**Status:** Planned only; no contract or program is deployed.

This document is the deliberate boundary for the future AvatarForge commerce
layer. The current Android app validates local asset manifests and models
future asset states, but it does not claim token ownership, mint NFTs, create
rentals, escrow assets, or submit chain transactions.

## Not implemented

- no Solidity, Rust, Anchor, ABI, bytecode, program ID, contract address, or
  treasury address;
- no chain or token decision;
- no creator wallet connection or signing flow;
- no mint, listing, rental, escrow, royalty, refund, or dispute transaction;
- no server callback that can promote an asset to `minted` or `rented`;
- no cached entitlement that survives rental expiry.

## Future interface boundary

When AvatarForge is revisited, the web portal and reviewed contract/program
must define these externally verifiable records before Android integration:

1. canonical asset-manifest hash and compatible runtime version;
2. creator identity, license URL, and permitted app actions;
3. chain/network, collection or program, token/asset identifier, and transaction
   reference;
4. creator, network, and platform split rules;
5. rental start/end, permitted use, revocation, refund, dispute, and takedown
   semantics;
6. an authenticated read API or indexer proof that Android can revalidate.

Only after those records, contracts/programs, storage, support, and recovery
paths are reviewed should the app map a verified external record into the
`minted` or `rented` states. Until then, AvatarForge remains a local/equip
preview and this file is the stub—not a promise of a deployed protocol.
