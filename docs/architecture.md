# Architecture notes

## Persistence boundary

`DataService` owns the persistence contract. Profiles are normalized before use and a session token/expiry pair acts as a lease so two live servers do not independently modify the same player profile.

A normal save uses `UpdateAsync` and only accepts the write while the stored session token still belongs to the current server. Failed saves mark the runtime record unsafe so progression can be locked rather than continuing after persistence becomes uncertain.

## Player-to-player ownership transfer

A theft has a stricter consistency requirement than an ordinary save because the same critter must not exist in both profiles.

The transfer sequence is:

```text
victim profile
    │
    ├── write persistent _Outgoing transaction
    ├── remove critter from victim pad
    └── save victim first
            │
            ▼
      grant to recipient
            │
            ├── write recipient _Receipts[id]
            └── save recipient
                    │
                    ▼
          clear victim _Outgoing[id]
```

If delivery is interrupted, `DataService.Recover` can inspect the donor's outgoing transactions. Recipient receipts prevent the same transfer from being granted twice.

This is deliberately biased toward preserving durable ownership state rather than making the interaction appear instantly successful when persistence is uncertain.

## Server authority

`PlayerStateService`, `HeistService` and `TheftService` keep consequential state on the server. Interaction handlers validate the player's current state and relevant world state before progressing an action.

Examples include:

- distance/proximity checks;
- per-action rate limits and token-bucket throttling;
- zone and alive-state validation;
- cooldown/shield checks;
- protected-pad checks;
- one active heist/theft at a time;
- simultaneous thief exclusion;
- cleanup when either participant resets or leaves.

The client is responsible for presentation and requests; it does not decide rewards or ownership.

## Economy

`EconomyConfig` centralizes deterministic economy rules. Critter value is derived from species base income and mutation multiplier. Passive income additionally applies rebirth and collection bonuses.

Rolls use configured rarity weights, mutation weights, tier roll counts and luck modifiers. Base placement prefers an empty slot; when full, a higher-value critter can replace the weakest eligible slot, otherwise the new critter is auto-sold.

## QA strategy

The QA layer covers three different failure classes:

1. **Synthetic/statistical:** probability distributions, serialization and deterministic economy boundaries.
2. **Multiplayer/concurrency:** ownership transfer, competing thieves, shields, disconnect/reset recovery, base assignment and runtime cleanup with eight players.
3. **Endurance:** repeated real movement/heist loops over at least 15 minutes with instance-growth and orphan-object assertions.
