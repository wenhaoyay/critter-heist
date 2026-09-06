# Critter Heist

**Server-authoritative multiplayer Roblox game systems built in Luau.**

Critter Heist is an 8-player collection/heist game built around persistent progression, risk/reward runs, passive-income critters and player-to-player theft. The game is still in active development; this repository is a **curated portfolio snapshot** of the engineering systems rather than the complete Roblox place.

> **Status:** active development. The game is not presented here as a publicly released experience.

## What this repository demonstrates

### Persistent multiplayer state

Player progression is stored through Roblox DataStore `UpdateAsync` with bounded retry/backoff, schema normalization, session leases and defensive profile validation. The persistence layer also handles offline income and safe profile release.

The PvP theft path has an additional durability problem: one player's saved asset has to move to another player without duplication or accidental loss if a server operation is interrupted. `DataService.Transfer` therefore uses a persistent outgoing transfer record plus recipient receipts so recovery can be idempotent.

### Server-authoritative interactions

Client interaction is treated as a request, not as proof that an action is valid. Server-side checks cover state validity, distance/proximity, action rate limits, zone state, cooldowns, shields, protected pads, simultaneous theft conflicts and transfer state before rewards or ownership changes are committed.

### Economy and progression

The shared economy layer contains:

- six progression zones;
- six rarity tiers;
- six mutations;
- **36 species × 6 mutations = 216 collectible combinations**;
- weighted rarity/mutation rolls with luck modifiers;
- passive and offline income;
- treadmill, base and luck upgrades;
- collection bonuses and rebirth scaling;
- replacement/auto-sell logic when a base is full;
- timed Golden Rush modifiers.

### Multiplayer QA

The project includes automated/synthetic and multiplayer QA rather than relying only on manual Studio play-testing.

The saved QA snapshots in this repository record:

- **17/17 synthetic tests passed**, including 100,000-roll rarity and mutation distribution checks, profile serialization, corrupted-profile handling, economy thresholds and all 216 model combinations;
- **27/27 final multiplayer checks passed** with 8 players, including unique base assignment, simultaneous guardians, theft rejection cases, ownership transfer exactly once, player reset/leave recovery, protected/shielded critters and cleanup/leak checks;
- a solo endurance script that continues real movement/heist loops for at least **900 seconds (15 minutes)** and asserts runtime-error, orphan-carry, UI-duplication and instance-growth conditions.

These JSON files are retained as test-result snapshots; they are not intended to substitute for rerunning QA against future game revisions.

## Start here

For a technical review, the two most representative modules are:

- [`src/server/DataService.luau`](src/server/DataService.luau) — profile leases, defensive saves and crash-tolerant player-to-player ownership transfer.
- [`src/server/TheftService.luau`](src/server/TheftService.luau) — server-authoritative theft lifecycle, validation, cancellation, bust and commit paths.

The deterministic economy rules are in [`src/shared/EconomyConfig.luau`](src/shared/EconomyConfig.luau), while the QA evidence is under [`qa/`](qa/).

## Architecture

```text
Roblox client
    │
    │ interaction requests / UI events
    ▼
Server bootstrap
    ├── PlayerStateService    session state, rate limits, spatial validation
    ├── DataService           DataStore persistence, leases, transfer recovery
    ├── BaseService           base ownership, pads, shields and upgrades
    ├── TrainingService       movement-power progression
    ├── HeistService          PvE cage-run state
    ├── TheftService          player-to-player theft lifecycle
    ├── CritterService        placement, carry models and collection updates
    ├── RewardService         daily/rebirth/reward decisions
    ├── EventService          timed Golden Rush state
    └── TelemetryService      event instrumentation
            │
            ▼
Shared deterministic rules
    ├── GameConfig
    ├── EconomyConfig
    ├── CritterRegistry
    └── ZoneRegistry
```

See [`docs/architecture.md`](docs/architecture.md) for the persistence and theft-transfer flows.

## Repository layout

```text
src/
  shared/    deterministic game/economy definitions
  server/    persistence, authority, progression and heist/theft services
  client/    selected interaction/audio/FX bootstrap code
qa/
  synthetic.luau
  multiplayer.luau
  solo-endurance.luau
  *-results.json
```

## Why this is a curated snapshot

The complete development workspace also contains the Roblox `.rbxl` place, procedural world-building/presentation code, full UI implementation and art-pass code. Those pieces are intentionally not published here.

The goal of this repository is to make the underlying multiplayer engineering inspectable without publishing the entire game or every presentation asset.

The source files are snapshots from the active project, so some modules reference private presentation/world modules that are not included here. This repository is therefore for **technical review**, not a one-command reproduction of the full experience.

## Current limitations

- Active work in progress; balance and content are still changing.
- No public experience link yet.
- The public repository excludes the full Roblox place and presentation layer.
- Saved QA results describe the tested snapshot and should be rerun after material changes.
- The internal `PrototypeStage` value in the captured configuration reflects that snapshot's QA milestone; it should not be read as a claim that the overall game has been publicly shipped.
