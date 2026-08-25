# LIVELVL 现实奖励兑换 MVP Implementation Plan

> For agentic workers: REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

Goal: Build a fully local integer-ledger reality-rewards store that converts XP into coins, lets users manage rewards, atomically redeems them, preserves history snapshots, and leaves the collectible-card domain unchanged.

Architecture: A sibling Rewards domain owns immutable CoinTransaction rows, RewardProduct rows, RewardRedemption snapshots, and a file-backed RewardProductImageStore. CoinLedgerService handles XP import, task earning, and bounded reversal; RewardStoreService handles product and redemption transactions. SwiftUI views consume these services and never call CardRewardService.

Tech Stack: SwiftUI, SwiftData, Swift Testing, iOS 17+, PhotosUI, Application Support.

Spec: docs/superpowers/specs/2026-08-26-rewards-mvp-design.md

## Global Constraints

- Use integer coinUnit: 1 XP = 1 coinUnit and 10 coinUnit = 1.0 displayed coin.
- Import existing XP exactly once under legacy-xp-import before new task earning.
- Reverse only available balance; never create a negative balance or debt.
- Products are user-created, editable, archivable, and never hard-deleted.
- Successful redemption atomically inserts a debit and immutable product snapshot.
- Repeated redemption request keys are idempotent.
- Redemption history starts pending and can become fulfilled; no refunds or cancellation.
- Store only stable image references in SwiftData under Application Support/RewardProductImages.
- Debug reset deletes reward transactions, products, redemptions, and RewardProductImages.
- Do not modify CardRewardService, collection reward models, queue ordering, or card-flight coordinate logic.
- Never touch the user-owned main-worktree project.pbxproj, UserInterfaceState.xcuserstate, or .tmp/.
- Every production behavior follows RED, verify failure, GREEN, verify focused and full tests, then refactor.

---

### Task 1: Add reward value types and persistent models

Files:
- Create LIVELVL/LIVELVL/Rewards/RewardModels.swift
- Create LIVELVL/LIVELVL/Rewards/CoinLedger.swift
- Create LIVELVL/LIVELVLTests/RewardModelsTests.swift
- Create LIVELVL/LIVELVLTests/CoinLedgerTests.swift
- Modify LIVELVL/LIVELVL/Item.swift
- Modify LIVELVL/LIVELVL/LIVELVLApp.swift

Interfaces:
- CoinTransaction, CoinTransactionKind, RewardProduct, RewardRedemption, RewardRedemptionStatus, CoinLedgerService, and CoinDisplayFormatter.
- CoinLedgerService.balance(in:) returns integer coin units.
- CoinLedgerService.ensureLegacyXPImported(progress:in:), awardTask(completion:in:), and reverseTask(completion:in:) are throwing, MainActor-isolated operations.
- Completion gains a stable id UUID for ledger idempotency only.

- [ ] Step 1: Write failing pure tests. Assert CoinDisplayFormatter renders 0, 1, and 123 units as 0.0, 0.1, and 12.3; assert blank names and zero prices throw exact validation errors.
- [ ] Step 2: Run xcodebuild test -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug -derivedDataPath /tmp/LIVELVLRewardsTask1Red CODE_SIGNING_ALLOWED=NO -only-testing:LIVELVLTests/CoinLedgerTests -only-testing:LIVELVLTests/RewardModelsTests. Confirm the failure is missing reward types.
- [ ] Step 3: Implement models. Use raw-backed enums for transaction kind and redemption status, signed amountCoinUnits, requestedCoinUnits, operationKey, sourceID, createdAt, and note. Add the three reward models to the app schema without changing collection declarations.
- [ ] Step 4: Add an in-memory SwiftData round-trip test for one transaction, product, and pending redemption, including IDs, integer amounts, image references, and status.
- [ ] Step 5: Run the focused suites, then the complete Debug suite. Fix production code only.
- [ ] Step 6: Commit with git commit -m "feat: add local reward ledger models".

### Task 2: Implement integer coin accounting and XP lifecycle

Files:
- Modify LIVELVL/LIVELVL/Rewards/CoinLedger.swift
- Modify LIVELVL/LIVELVLTests/CoinLedgerTests.swift
- Create LIVELVL/LIVELVLTests/TaskRewardCoordinatorTests.swift
- Create or modify LIVELVL/LIVELVL/Rewards/TaskRewardCoordinator.swift

Interfaces:
- Operation keys are legacy-xp-import, task-earned:<completion.id>, and task-revoked:<completion.id>.
- TaskRewardCoordinator coordinates XP/completion persistence and coin operations; it never calls CardRewardService.
- Collection reward processing remains a separate existing call in ContentView.

- [ ] Step 1: Write failing in-memory tests for one-time legacy import, repeated task earning, full reversal, bounded reversal after a redemption debit, and repeated reversal.
- [ ] Step 2: Run only CoinLedgerTests and TaskRewardCoordinatorTests and confirm RED.
- [ ] Step 3: Implement CoinLedgerService. Existing operationKey returns the original result; legacy import reads current totalXP once; award inserts a positive task-earned row; reversal inserts a negative row for min(requested, current nonnegative balance), preserving requested amount and actual amount.
- [ ] Step 4: Make task coordination failure-safe. The normal completion path must initialize the ledger before new earning, persist the completion and XP, award coins, then invoke the existing CardRewardService separately. If coin processing fails, do not report success. Reversal must leave completion and XP intact if coin reversal fails.
- [ ] Step 5: Run focused tests and the complete Debug suite. Confirm no existing CardRewardService test or source file changed.
- [ ] Step 6: Commit with git commit -m "feat: award and reverse task coins idempotently".

### Task 3: Add local product images and product lifecycle

Files:
- Create LIVELVL/LIVELVL/Rewards/RewardProductImageStore.swift
- Create LIVELVL/LIVELVLTests/RewardProductImageStoreTests.swift
- Create LIVELVL/LIVELVLTests/RewardStoreServiceTests.swift
- Create LIVELVL/LIVELVL/Rewards/RewardStoreService.swift

Interfaces:
- RewardProductImageStore.save(data:fileExtension:) returns a UUID-based stable reference.
- RewardProductImageStore.replace(oldReference:data:fileExtension:) writes a new reference and leaves the old file available until references are reconciled.
- RewardProductImageStore.removeIfUnreferenced(reference:references:) removes only a file under RewardProductImages.
- RewardStoreService.createProduct, updateProduct, and archiveProduct are save-once throwing operations.

- [ ] Step 1: Write failing tests for image save, replacement, invalid path rejection, and removal only when no product or redemption references remain.
- [ ] Step 2: Write failing product tests for trimmed-name validation, positive price, preserved createdAt, updatedAt changes, editing, archive, and archive idempotency.
- [ ] Step 3: Run the two focused suites and confirm RED.
- [ ] Step 4: Implement the file store using Application Support/RewardProductImages, UUID filenames, temporary writes, and scoped path construction. Do not access UserCardMedia.
- [ ] Step 5: Implement product create, edit, and archive. Archive hides active products and never deletes image files or history.
- [ ] Step 6: Run focused tests and complete Debug tests.
- [ ] Step 7: Commit with git commit -m "feat: manage local reward products and images".

### Task 4: Implement atomic redemption and immutable history

Files:
- Modify LIVELVL/LIVELVL/Rewards/RewardStoreService.swift
- Modify LIVELVL/LIVELVLTests/RewardStoreServiceTests.swift

Interfaces:
- RewardStoreService.redeem(product:requestKey:in:now:) returns RewardRedemption.
- RewardStoreService.markFulfilled(_:in:now:) throws.
- RewardStoreService.orderedHistory(_:) returns deterministic newest-first history.

- [ ] Step 1: Write failing tests for successful debit plus snapshot, insufficient balance with no side effects, archived product rejection, repeated request key, save-failure rollback, product edit snapshot isolation, and pending-to-fulfilled transition.
- [ ] Step 2: Run RewardStoreServiceTests and confirm RED.
- [ ] Step 3: Implement redemption. Resolve requestKey first; re-fetch product; reject archived products; calculate integer balance; insert one negative debit and one snapshot; call save once; rollback on every error.
- [ ] Step 4: Implement fulfillment as a one-way pending-to-fulfilled transition with fulfilledAt and no-op repeats. Sort history by redeemedAt descending, then id ascending.
- [ ] Step 5: Run focused tests and complete Debug tests.
- [ ] Step 6: Commit with git commit -m "feat: atomically redeem rewards and preserve history".

### Task 5: Replace the Rewards placeholder with accessible SwiftUI flows

Files:
- Create LIVELVL/LIVELVL/Rewards/RewardStoreView.swift
- Create LIVELVL/LIVELVL/Rewards/RewardProductEditorView.swift
- Create LIVELVL/LIVELVL/Rewards/RewardProductCardView.swift
- Create LIVELVL/LIVELVL/Rewards/RewardHistoryView.swift
- Create LIVELVL/LIVELVLTests/RewardViewStateTests.swift
- Modify LIVELVL/LIVELVL/MainTabView.swift
- Modify LIVELVL/LIVELVL/Rewards/RewardPlaceholderView.swift only if needed

Interfaces:
- RewardStoreView owns the Rewards Tab page and queries reward models.
- RewardProductEditorView uses sheet(item:) and explicit service/image-store dependencies.
- RewardHistoryView renders snapshots only; it never reads current product fields.
- The collection overlay and tab target code remain unchanged.

- [ ] Step 1: Write failing pure view-state tests for active-products filtering, insufficient-balance state, snapshot history text, distinct pending/fulfilled accessibility labels, and reduced-motion feedback plan.
- [ ] Step 2: Run only RewardViewStateTests and confirm RED.
- [ ] Step 3: Implement NavigationStack page with one-decimal balance card, active product list, add button, and history destination. Use small focused subviews and explicit initialization; do not put business rules in body.
- [ ] Step 4: Implement the editor with name, price, note, PhotosPicker static image selection, validation messages, and edit/create save paths. Stage image files through RewardProductImageStore.
- [ ] Step 5: Implement product cards with Edit, Archive, and Redeem. Confirmation shows name, price, current balance, and resulting balance. Insufficient balance is explained and has no mutation.
- [ ] Step 6: Generate and retain one requestKey for the confirmed redemption attempt. Use a service call guarded by local submitting state; repeated taps return the same redemption.
- [ ] Step 7: Add VoiceOver labels for name, price, note, availability, archive state, image fallback, timestamp, and fulfillment state. Ensure text wraps at large Dynamic Type. Reduce Motion uses opacity/color only.
- [ ] Step 8: Run xcodebuild build -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug -derivedDataPath /tmp/LIVELVLRewardsViewBuild CODE_SIGNING_ALLOWED=NO. Confirm four tabs and no edits to collection overlay source.
- [ ] Step 9: Commit with git commit -m "feat: add local reward store interface".

### Task 6: Integrate task lifecycle, reset, and restart recovery

Files:
- Modify LIVELVL/LIVELVL/ContentView.swift
- Modify LIVELVL/LIVELVL/Persistence/LocalDataResetService.swift
- Modify LIVELVL/LIVELVLTests/LocalDataResetServiceTests.swift
- Create LIVELVL/LIVELVLTests/RewardResetIntegrationTests.swift

Interfaces:
- Reset deletes CoinTransaction, RewardProduct, RewardRedemption, and RewardProductImages in addition to the existing explicit list.
- Existing UserCardMedia cleanup and partial-failure messages remain intact.
- Task completion/reversal calls the independent coin services and existing collection service in separate phases.

- [ ] Step 1: Write failing reset tests with all reward models, one product image, and existing collection data. Assert all reward rows and RewardProductImages disappear after reset, while existing cleanup still runs.
- [ ] Step 2: Run LocalDataResetServiceTests and RewardResetIntegrationTests and confirm RED.
- [ ] Step 3: Extend reset with explicit reward-model deletion and exact RewardProductImages removal. Preserve rollback and partial cleanup errors; never remove arbitrary Application Support content.
- [ ] Step 4: Add restart recovery tests by saving reward data, recreating an in-memory context with the same schema, and asserting balance, active/archive state, image references, snapshots, and statuses are identical.
- [ ] Step 5: Run focused tests and the complete Debug suite.
- [ ] Step 6: Commit with git commit -m "feat: reset reward ledger and recover local store".

### Task 7: Simulator acceptance and collection regression protection

Files:
- Create LIVELVL/LIVELVLTests/RewardCollectionIsolationTests.swift
- Modify only Rewards sources/tests unless an evidence-backed bug requires another file

- [ ] Step 1: Assert reward services operate with reward models isolated from collection models. Keep all existing CardRewardService and CardRewardPresentationTests unchanged unless a regression test needs a new assertion.
- [ ] Step 2: Run focused reward suites, then the full Debug command: xcodebuild test -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug -derivedDataPath /tmp/LIVELVLRewardsFull CODE_SIGNING_ALLOWED=NO.
- [ ] Step 3: Build and install Debug on the booted iPhone 17 Pro. Verify reset, task coin income, create/edit/archive, insufficient balance, successful redemption, double tap, restart recovery, image replacement, history snapshot, fulfillment, Dynamic Type, VoiceOver, Reduce Motion, and reset cleanup.
- [ ] Step 4: Re-run an existing collectible-card claim on the real simulator and inspect measured coordinates. Verify the card reaches the Collection Tab center, tab feedback completes before dismissal, queue order remains ordinary-before-hidden, and Reduce Motion still avoids spatial flight.
- [ ] Step 5: Run git diff --check, git status --short, and diff only the project file/user state paths. No user-owned main-worktree file may enter the branch.
- [ ] Step 6: Commit any required regression test or handoff documentation separately.

### Task 8: Final verification and review

- [ ] Step 1: Re-read the design spec and audit every invariant: integer accounting, one-time import, bounded reversal, nonnegative balance, atomic redemption, idempotency, snapshots, archive behavior, image cleanup, reset scope, accessibility, motion, collection isolation, and no network.
- [ ] Step 2: Request code review against baseline 47dcd8c. Fix all Critical and Important findings and rerun the affected focused tests.
- [ ] Step 3: Run the clean final Debug suite and Release build:
  xcodebuild test -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -configuration Debug -derivedDataPath /tmp/LIVELVLRewardsFinal CODE_SIGNING_ALLOWED=NO
  xcodebuild build -project LIVELVL/LIVELVL.xcodeproj -scheme LIVELVL -destination 'generic/platform=iOS Simulator' -configuration Release -derivedDataPath /tmp/LIVELVLRewardsRelease CODE_SIGNING_ALLOWED=NO
- [ ] Step 4: Report exact branch, commits, test counts, simulator evidence, and non-blocking warnings. Do not merge or push.

