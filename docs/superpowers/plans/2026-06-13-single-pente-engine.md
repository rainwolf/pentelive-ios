# Single Pente Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate the three forked Pente-rule implementations (ObjC `PenteGame`, the Swift `Table`, and MMAI) into one stateful Swift `PenteGame` engine that owns board state and returns a `MoveResult`, with thin renderers and a cross-checked AI.

**Architecture:** A stateful Swift `PenteGame` engine owns the board, capture counters, opening masks, and move cadence. Per-variant `RuleSet` recipe classes (one per variant) compose a single `Scan` rule-primitive layer, so every directional capture/poof/win scan exists exactly once. The ObjC `BoardViewController` and the Swift `Table` become thin renderers that read the engine via `stone(at:)` and drive UI/animation from `MoveResult`. Go moves to a sibling `GoGame` module. MMAI keeps its performance-critical C rules untouched and is guarded indirectly by a golden recorded-games corpus.

**Tech Stack:** Swift + Objective-C interop (`penteLive-Swift.h` for ObjC→Swift, bridging header for Swift→ObjC), XCTest (`PenteEngineTests` target), `xcodebuild`, CocoaPods workspace (`penteLive.xcworkspace`, app scheme `test1`, product/module name `penteLive`).

**Design decisions (locked during grilling; vocabulary in `CONTEXT.md`):**
- Engine is **stateful** and owns board + counters + masks + cadence; callers read state, never mutate rules.
- **One `RuleSet` class per variant**, each a thin recipe over the shared `Scan` primitives — no scan code is duplicated.
- The Swift engine is exposed to ObjC as **`SwiftPenteGame`** (`@objc(SwiftPenteGame)`); the legacy ObjC `PenteGame` is renamed `LegacyPenteGame` (Phase 2) and deleted (Phase 5). Swift callers use the Swift name `PenteGame`.
- **MMAI stays out** of the shared code path (its rules run ~10k×/move in a C search loop); a golden-corpus cross-check guards the engine now, with an MMAI apply-move oracle documented as a later step.
- **Go is a separate `GoGame`**; PenteGame's dead `goStoneGroup*` properties are removed.
- **Intentional behaviour change:** Connect6 win length is corrected from the legacy hardcoded 5-in-a-row to 6-in-a-row (Phase 2). Not exercised by the corpus winners, so it does not affect reproduction of golden snapshots.

**Phase order & dependencies:**
- **Phase 0** (test harness + golden corpus) must land first — later phases assert against it.
- **Phases 1 → 2** build the engine (Scan → RuleSets/PenteGame/MoveResult) and must precede the cutovers.
- **Phases 3 and 4** (Table and BoardViewController cutovers) depend on Phase 2 and can proceed in parallel.
- **Phase 5** (GoGame) is the most separable — it bypasses the Pente seam entirely and is safe to ship as a follow-up PR after Phases 0–4.

---

## Phase 0: Test harness + golden corpus

**Frozen test-target name: `PenteEngineTests`.** Every later phase reuses this exact name in the canonical test command, e.g. `xcodebuild test -workspace penteLive.xcworkspace -scheme test1 -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:PenteEngineTests/<TestClass>/<testMethod>`.

There is currently **no** wired XCTest target: `xcodebuild -list -workspace penteLive.xcworkspace` lists schemes but no test target, and `test1Tests/` holds only a `.DS_Store`. The only existing engine tests are the clang-standalone harness at `tests/PenteGameTests.m` (Foundation-only, run via a `clang` one-liner). Phase 0 stands up `PenteEngineTests` as a real Unit Testing Bundle, captures a **golden characterization corpus** from the *current* Objective-C `PenteGame` engine, and ships an **engine-agnostic** assertion helper that Phase 2 will use to prove the new Swift engine reproduces that corpus byte-for-byte.

**Two critical design facts, established by reading the source:**

1. The current engine is reached through `PenteGame.h` / `PenteGame.m`. `PenteGame.m` is self-contained (the standalone harness compiles it with `-framework Foundation` and nothing else), so it can be compiled directly into the test bundle. The board is an `AbstractBoard *` (`int (*)[19]`); callers assign a backing `int[19][19]` to `game.abstractBoard` then call `resetBoard`, exactly as `tests/PenteGameTests.m` does.
2. The existing `PenteGameVariant` enum (in `PenteGame.h`) has a **different integer ordering** than the frozen `PenteVariant` contract enum (e.g. ObjC `OPente=5, PoofPente=6, GPente=2` vs contract `oPente=2, poofPente=3, gpente=6`). The corpus therefore stores each variant as a **stable string name** (`"pente"`, `"keryoPente"`, `"oPente"`, ...), never a raw integer. The generator maps string → `PenteGameVariant`; Phase 2 maps the same string → `PenteVariant`. This decouples the committed golden files from either enum's ordering.

Phase 0 references **only** identifiers that exist today (the ObjC `PenteGame` API) plus new Phase-0 types (`CorpusCase`, `ExpectedSnapshot`, `EngineSnapshot`, `corpusMismatchReason`, `assertEngineMatchesCorpus`, `Corpus.loadCases`). It does **not** reference the not-yet-built Swift `PenteGame`/`PenteVariant`/`MoveResult`; the helper is engine-agnostic precisely so it compiles before those exist.

---

### Task 0.1: Add the `PenteEngineTests` unit-test target + bridging

**Files:**
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/HarnessSmokeTests.swift`
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcodeproj/project.pbxproj` (Xcode rewrites this when the target is added)

- [ ] **Step 1: Run the canonical command for the not-yet-existing target (expected FAIL).**
  ```bash
  cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/HarnessSmokeTests/testHarnessRuns 2>&1 | tail -5
  ```
  Expected FAIL — no such target/test exists yet, e.g.:
  ```
  xcodebuild: error: Tests in the target "PenteEngineTests" can't be run because "PenteEngineTests" isn't a member of the "test1" scheme, or no such target exists.
  ```
  (Exact wording varies; any "no such target / not a member of scheme" error confirms the RED state.)

- [ ] **Step 2: Add the Unit Testing Bundle target in Xcode (manual GUI step).**
  Open `penteLive.xcworkspace` in Xcode, then: **File ▸ New ▸ Target… ▸ iOS ▸ Test ▸ Unit Testing Bundle ▸ Next**. Set:
  - **Product Name:** `PenteEngineTests`
  - **Language:** Swift
  - **Project:** penteLive
  - **Target to be Tested:** `test1` (the app target; this auto-adds `PenteEngineTests` to the **test1** scheme's Test action and sets the test host).
  Click **Finish**. Xcode creates a `PenteEngineTests/` group with a default `PenteEngineTests.swift`; **delete that default file** (Move to Trash) so only the files this plan creates remain.

- [ ] **Step 3: Wire the current ObjC engine into the test target (manual GUI step).**
  Select the **PenteEngineTests** target ▸ **Build Phases ▸ Compile Sources ▸ +** and add `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/PenteGame.m`. (`PenteGame.m` is Foundation-only and self-contained, so no other ObjC sources are needed.) No bridging header is required in Phase 0 because the Swift test files do not call the ObjC engine — only the ObjC generator file does, and it imports `"PenteGame.h"` directly. ObjC test sources reach the engine with the relative quote-import `#import "../test1/PenteGame.h"` (resolved relative to the importing file's directory). **Bridging note for later phases:** the new `@objc` Swift `PenteGame`/`PenteVariant`/`MoveResult` are reached from this target via `@testable import penteLive` (the app's product module name is `penteLive`, `DEFINES_MODULE = YES`); ObjC callers in the app use the generated `penteLive-Swift.h`.

- [ ] **Step 4: Write the smoke test (minimal impl).**
  Create `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/HarnessSmokeTests.swift`:
  ```swift
  import XCTest

  /// Proves the PenteEngineTests bundle builds, hosts into test1, and runs.
  final class HarnessSmokeTests: XCTestCase {
      func testHarnessRuns() {
          XCTAssertEqual(2 + 2, 4)
      }
  }
  ```
  Ensure this file's **Target Membership** includes `PenteEngineTests` (Xcode does this automatically for files created inside the group; verify in the File Inspector).

- [ ] **Step 5: Run the smoke test (expected PASS).**
  ```bash
  cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/HarnessSmokeTests/testHarnessRuns 2>&1 | tail -8
  ```
  Expected PASS:
  ```
  Test Suite 'HarnessSmokeTests' passed at ...
       Executed 1 test, with 0 failures (0 unexpected) in ...
  ** TEST SUCCEEDED **
  ```
  (If `iPhone 16` is not installed, substitute any installed simulator from `xcrun simctl list devices available`; record the substitution and use it consistently for all later phases.)

- [ ] **Step 6: Commit.**
  ```bash
  cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS
  git add penteLive.xcodeproj/project.pbxproj PenteEngineTests/HarnessSmokeTests.swift
  git commit -m "test: add PenteEngineTests unit-test target and harness smoke test"
  ```

---

### Task 0.2: Golden corpus fixtures + ObjC snapshot generator

The corpus is **hand-authored** (8 deterministic move-lists, provided verbatim below) rather than scraped from recorded games: real games arrive only over the network in `DatabaseViewController.m` (`jsonResponse[@"moves"]`, line ~883) and `GamesTableViewController.m`, parsed as `NSNumber`/comma-split `NSString` lists — no committable offline source. Each move-list is parity-checked against `replayMoves` colour assignment (`color = (i % 2) + 1`, with Connect6 using `(((i%4)==0)||((i%4)==3)) ? 1 : 2`) so it exercises exactly the intended rule. Cases cover every required behaviour: a Pente pair capture, a Keryo 3-capture, a poof, the keryo-poof both-ends regression from commit 63986f7 (O-Pente), a 5-in-a-row win, a capture-threshold win, Connect6 cadence, and Gomoku.

The generator is **generate-if-missing**: the first run writes `PenteEngineTests/golden/<name>.json` next to the generator source (located via `__FILE__`); every later run re-runs the current engine and **verifies** the committed golden still matches (deep object comparison, so formatting/whitespace can never cause false failures). To intentionally regenerate after an engine change, delete `PenteEngineTests/golden/`.

**Files:**
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/CorpusSnapshotGeneratorTests.m`
- Create (generated, then committed): `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/golden/*.json`

- [ ] **Step 1: Write the generator/verifier test (this is both the failing test and the tool that creates the fixtures).**
  Create `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/CorpusSnapshotGeneratorTests.m`:
  ```objc
  //
  //  CorpusSnapshotGeneratorTests.m
  //  One-off golden-corpus generator/verifier for the CURRENT Objective-C
  //  PenteGame engine.
  //
  //  Generate-if-missing: the first run writes golden/<name>.json next to this
  //  source file; later runs re-run the engine and verify the committed golden
  //  still matches. To regenerate, delete PenteEngineTests/golden.
  //
  //  Variant is stored as a STABLE STRING name so the golden JSON is decoupled
  //  from enum ordering: the existing PenteGameVariant and the new Swift
  //  PenteVariant have DIFFERENT integer orders.
  //

  #import <XCTest/XCTest.h>
  #import "../test1/PenteGame.h"

  static int gBoardStorage[19][19];

  @interface CorpusSnapshotGeneratorTests : XCTestCase
  @end

  @implementation CorpusSnapshotGeneratorTests

  static PenteGameVariant VariantForName(NSString *name) {
      static NSDictionary<NSString *, NSNumber *> *map;
      static dispatch_once_t once;
      dispatch_once(&once, ^{
          map = @{
              @"pente": @(PenteGameVariantPente),
              @"keryoPente": @(PenteGameVariantKeryoPente),
              @"oPente": @(PenteGameVariantOPente),
              @"poofPente": @(PenteGameVariantPoofPente),
              @"dPente": @(PenteGameVariantDPente),
              @"dkPente": @(PenteGameVariantDKPente),
              @"gpente": @(PenteGameVariantGPente),
              @"swap2Pente": @(PenteGameVariantSwap2Pente),
              @"swap2Keryo": @(PenteGameVariantSwap2Keryo),
              @"gomoku": @(PenteGameVariantGomoku),
              @"connect6": @(PenteGameVariantConnect6),
          };
      });
      NSNumber *v = map[name];
      NSCAssert(v != nil, @"unknown variant name %@", name);
      return (PenteGameVariant)[v intValue];
  }

  // rowCol = row*19 + col. Each move-list is parity-checked so white (color 1)
  // lands on even move indices and black (color 2) on odd, per replayMoves.
  static NSArray<NSDictionary *> *Corpus(void) {
      return @[
          // Pente pair capture: W(5,5) B(5,6) Wneutral(0,0) B(5,7) W(5,8) closes
          // the pair -> (5,6),(5,7) removed, blackCaptures=2.
          @{ @"name": @"pente_pair_capture",
             @"variant": @"pente",
             @"moves": @[ @100, @101, @0, @102, @103 ] },
          // Keryo 3-capture (from tests/PenteGameTests.m testReplayKeryoCapture):
          // W B B B W on row 5 -> 3 black removed, blackCaptures=3.
          @{ @"name": @"keryo_triple_capture",
             @"variant": @"keryoPente",
             @"moves": @[ @100, @101, @240, @102, @280, @103, @104 ] },
          // Poof (self-capture): B(5,4) W(5,5) Wneutral(0,0) B(5,7) then
          // W(5,6) makes B W W B -> own (5,5),(5,6) poof, whiteCaptures=2.
          @{ @"name": @"poof_self_capture",
             @"variant": @"poofPente",
             @"moves": @[ @100, @99, @0, @102, @101 ] },
          // Keryo-poof both-ends regression (commit 63986f7): anti-diagonal
          // B(11,7) W(10,8) W(8,10) B(7,11), W places center (9,9) ->
          // B W W W B -> own (10,8),(9,9),(8,10) poof, whiteCaptures=3.
          @{ @"name": @"keryo_poof_antidiagonal",
             @"variant": @"oPente",
             @"moves": @[ @198, @216, @162, @144, @180 ] },
          // 5-in-a-row win (from testReplayPenteFiveInARowWin): white row 9
          // cols 9-13, black far away -> white wins.
          @{ @"name": @"pente_five_in_a_row_win",
             @"variant": @"pente",
             @"moves": @[ @180, @40, @181, @41, @182, @42, @183, @44, @184 ] },
          // Capture-threshold win: white closes 5 black pairs (rows
          // 10,12,14,16,18) -> blackCaptures=10 -> white wins. Lines are
          // pipelined so every closing flanker is a white (even-index) move;
          // index 18 is a harmless white neutral at (0,0).
          @{ @"name": @"pente_capture_threshold_win",
             @"variant": @"pente",
             @"moves": @[ @195, @196, @233, @197, @198, @234, @271, @235, @236,
                          @272, @309, @273, @274, @310, @347, @311, @312, @348,
                          @0, @349, @350 ] },
          // Connect6 cadence w,b,b,w,w,b (from testReplayConnect6Colors); no win.
          @{ @"name": @"connect6_cadence",
             @"variant": @"connect6",
             @"moves": @[ @0, @1, @2, @3, @4, @5 ] },
          // Gomoku 5-in-a-row win (no captures in Gomoku replay path).
          @{ @"name": @"gomoku_five_in_a_row_win",
             @"variant": @"gomoku",
             @"moves": @[ @180, @40, @181, @41, @182, @42, @183, @44, @184 ] },
      ];
  }

  static NSString *GoldenDir(void) {
      NSString *thisFile = [NSString stringWithUTF8String:__FILE__];
      return [[thisFile stringByDeletingLastPathComponent]
          stringByAppendingPathComponent:@"golden"];
  }

  // Runs the CURRENT ObjC engine over one case and returns its snapshot dict.
  static NSDictionary *SnapshotForCase(NSDictionary *c) {
      PenteGame *g = [[PenteGame alloc] init];
      g.abstractBoard = gBoardStorage;
      [g resetBoard];
      NSArray *moves = c[@"moves"];
      PenteGameVariant variant = VariantForName(c[@"variant"]);
      [g replayMoves:moves variant:variant untilMove:(NSInteger)[moves count]];
      int winner = [g winnerForVariant:variant moves:moves];

      NSMutableArray *board = [NSMutableArray arrayWithCapacity:19];
      for (int i = 0; i < 19; ++i) {
          NSMutableArray *row = [NSMutableArray arrayWithCapacity:19];
          for (int j = 0; j < 19; ++j) {
              [row addObject:@(gBoardStorage[i][j])];
          }
          [board addObject:row];
      }
      return @{
          @"name": c[@"name"],
          @"variant": c[@"variant"],
          @"moves": moves,
          @"expected": @{
              @"winner": @(winner),
              @"whiteCaptures": @(g.whiteCaptures),
              @"blackCaptures": @(g.blackCaptures),
              @"board": board,
          },
      };
  }

  - (NSDictionary *)snapshotNamed:(NSString *)name {
      for (NSDictionary *c in Corpus()) {
          if ([c[@"name"] isEqualToString:name]) {
              return SnapshotForCase(c);
          }
      }
      return nil;
  }

  - (void)testGenerateOrVerifyGoldenCorpus {
      NSFileManager *fm = [NSFileManager defaultManager];
      NSString *dir = GoldenDir();
      NSError *err = nil;
      [fm createDirectoryAtPath:dir
          withIntermediateDirectories:YES
                       attributes:nil
                            error:&err];
      XCTAssertNil(err, @"create golden dir: %@", err);

      NSInteger generated = 0, verified = 0;
      for (NSDictionary *c in Corpus()) {
          NSDictionary *snapshot = SnapshotForCase(c);
          NSString *path = [dir stringByAppendingPathComponent:
              [c[@"name"] stringByAppendingPathExtension:@"json"]];

          NSData *json = [NSJSONSerialization
              dataWithJSONObject:snapshot
                         options:(NSJSONWritingPrettyPrinted |
                                  NSJSONWritingSortedKeys)
                           error:&err];
          XCTAssertNotNil(json, @"serialize %@: %@", c[@"name"], err);

          if (![fm fileExistsAtPath:path]) {
              BOOL ok = [json writeToFile:path atomically:YES];
              XCTAssertTrue(ok, @"write golden %@", path);
              ++generated;
              continue;
          }
          NSData *existing = [NSData dataWithContentsOfFile:path];
          NSDictionary *existingObj =
              [NSJSONSerialization JSONObjectWithData:existing
                                              options:0
                                                error:&err];
          XCTAssertEqualObjects(existingObj, snapshot,
              @"golden %@ is stale; the current engine no longer reproduces it. "
               "Delete PenteEngineTests/golden to regenerate.", c[@"name"]);
          ++verified;
      }
      NSLog(@"[corpus] generated=%ld verified=%ld dir=%@",
            (long)generated, (long)verified, dir);

      // Sanity: named win/capture cases must really exercise their behaviour,
      // so a mis-authored move-list can never silently bake a wrong golden.
      XCTAssertEqual([[self snapshotNamed:@"pente_five_in_a_row_win"]
                         [@"expected"][@"winner"] intValue], 1);
      XCTAssertEqual([[self snapshotNamed:@"pente_capture_threshold_win"]
                         [@"expected"][@"winner"] intValue], 1);
      XCTAssertEqual([[self snapshotNamed:@"gomoku_five_in_a_row_win"]
                         [@"expected"][@"winner"] intValue], 1);
      XCTAssertEqual([[self snapshotNamed:@"keryo_triple_capture"]
                         [@"expected"][@"blackCaptures"] intValue], 3);
      XCTAssertEqual([[self snapshotNamed:@"poof_self_capture"]
                         [@"expected"][@"whiteCaptures"] intValue], 2);
      XCTAssertEqual([[self snapshotNamed:@"keryo_poof_antidiagonal"]
                         [@"expected"][@"whiteCaptures"] intValue], 3);
  }

  @end
  ```
  Add this file to the **PenteEngineTests** target membership (verify in the File Inspector). The `golden/` directory does not exist yet, so this is the RED step's mechanism.

- [ ] **Step 2: Run the generator to produce fixtures (expected PASS; writes golden files).**
  ```bash
  cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS
  rm -rf PenteEngineTests/golden
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/CorpusSnapshotGeneratorTests/testGenerateOrVerifyGoldenCorpus 2>&1 | tail -8
  ```
  Expected PASS, with the log line showing 8 files generated:
  ```
  [corpus] generated=8 verified=0 dir=/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/golden
       Executed 1 test, with 0 failures (0 unexpected) in ...
  ** TEST SUCCEEDED **
  ```

- [ ] **Step 3: Inspect the generated fixtures.**
  ```bash
  cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS
  ls PenteEngineTests/golden
  ```
  Expected 8 files:
  ```
  connect6_cadence.json          keryo_poof_antidiagonal.json   pente_capture_threshold_win.json  pente_pair_capture.json
  gomoku_five_in_a_row_win.json  keryo_triple_capture.json      pente_five_in_a_row_win.json
  ```

- [ ] **Step 4: Re-run to confirm VERIFY mode passes (idempotence; expected PASS).**
  ```bash
  cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/CorpusSnapshotGeneratorTests/testGenerateOrVerifyGoldenCorpus 2>&1 | tail -4
  ```
  Expected PASS with the log line now showing `generated=0 verified=8`:
  ```
  [corpus] generated=0 verified=8 dir=...
  ** TEST SUCCEEDED **
  ```

- [ ] **Step 5: Commit the generator and the committed golden corpus.**
  ```bash
  cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS
  git add penteLive.xcodeproj/project.pbxproj \
          PenteEngineTests/CorpusSnapshotGeneratorTests.m \
          PenteEngineTests/golden
  git commit -m "test: add golden characterization corpus and ObjC snapshot generator"
  ```

---

### Task 0.3: Engine-agnostic `assertEngineMatchesCorpus` helper

This is the reusable seam Phase 2 calls. It decodes the committed golden JSON (`CorpusCase` / `ExpectedSnapshot`), and compares an `EngineSnapshot` (which a later phase builds by driving the new Swift `PenteGame`) against the golden. It deliberately references **no** engine type — Phase 2 supplies the snapshot it produced from `stone(at:)`, `whiteCaptures`, `blackCaptures`, and the final `MoveResult.winner`, plus its own string → `PenteVariant` map.

**Files:**
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/CorpusSupport.swift`
- Create (Test): `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/CorpusHelperTests.swift`

- [ ] **Step 1: Write the failing helper test first.**
  Create `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/CorpusHelperTests.swift`:
  ```swift
  import XCTest

  final class CorpusHelperTests: XCTestCase {

      func testLoadsAllGoldenCases() throws {
          let cases = try Corpus.loadCases()
          XCTAssertEqual(cases.count, 8, "expected 8 committed golden fixtures")
          let names = Set(cases.map { $0.name })
          XCTAssertTrue(names.contains("keryo_poof_antidiagonal"))
          XCTAssertTrue(names.contains("pente_capture_threshold_win"))
      }

      func testMatchingSnapshotHasNoMismatch() throws {
          let cases = try Corpus.loadCases()
          let c = try XCTUnwrap(cases.first { $0.name == "pente_pair_capture" })
          let actual = EngineSnapshot(
              winner: c.expected.winner,
              whiteCaptures: c.expected.whiteCaptures,
              blackCaptures: c.expected.blackCaptures,
              board: c.expected.board)
          XCTAssertNil(corpusMismatchReason(c.expected, actual))
      }

      func testDetectsBoardMismatch() throws {
          let cases = try Corpus.loadCases()
          let c = try XCTUnwrap(cases.first { $0.name == "pente_pair_capture" })
          var board = c.expected.board
          board[0][0] = (board[0][0] == 0) ? 1 : 0   // flip one cell
          let actual = EngineSnapshot(
              winner: c.expected.winner,
              whiteCaptures: c.expected.whiteCaptures,
              blackCaptures: c.expected.blackCaptures,
              board: board)
          let reason = corpusMismatchReason(c.expected, actual)
          XCTAssertNotNil(reason)
          XCTAssertTrue(reason!.contains("board[0][0]"))
      }

      func testDetectsCaptureMismatch() throws {
          let cases = try Corpus.loadCases()
          let c = try XCTUnwrap(cases.first { $0.name == "keryo_triple_capture" })
          let actual = EngineSnapshot(
              winner: c.expected.winner,
              whiteCaptures: c.expected.whiteCaptures,
              blackCaptures: c.expected.blackCaptures + 1,
              board: c.expected.board)
          XCTAssertEqual(
              corpusMismatchReason(c.expected, actual)?.contains("blackCaptures"),
              true)
      }
  }
  ```
  Add to the **PenteEngineTests** target membership.

- [ ] **Step 2: Run the helper test (expected FAIL — types undefined).**
  ```bash
  cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/CorpusHelperTests 2>&1 | tail -8
  ```
  Expected FAIL — compile errors because `Corpus`, `EngineSnapshot`, `corpusMismatchReason` do not exist yet:
  ```
  error: cannot find 'Corpus' in scope
  error: cannot find 'EngineSnapshot' in scope
  error: cannot find 'corpusMismatchReason' in scope
  ** TEST FAILED **
  ```

- [ ] **Step 3: Write the helper (minimal impl).**
  Create `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/CorpusSupport.swift`:
  ```swift
  import Foundation
  import XCTest

  /// One decoded golden fixture: the variant + move list that were replayed,
  /// plus the snapshot the engine produced. `variant` is a STABLE STRING name so
  /// the corpus is decoupled from PenteVariant's integer ordering.
  struct CorpusCase: Decodable {
      let name: String
      let variant: String
      let moves: [Int]
      let expected: ExpectedSnapshot
  }

  struct ExpectedSnapshot: Decodable, Equatable {
      let winner: Int          // 0 none / 1 white / 2 black
      let whiteCaptures: Int
      let blackCaptures: Int
      let board: [[Int]]       // 19x19, 0 empty / 1 white / 2 black / -1 masked
  }

  /// Plain snapshot a later phase builds by driving the NEW Swift engine, kept
  /// free of any engine type (the engine types do not exist in this phase).
  struct EngineSnapshot: Equatable {
      let winner: Int
      let whiteCaptures: Int
      let blackCaptures: Int
      let board: [[Int]]
  }

  enum Corpus {
      /// golden/ sits next to this source file (committed alongside the tests).
      static var goldenDirectory: URL {
          URL(fileURLWithPath: #filePath)
              .deletingLastPathComponent()
              .appendingPathComponent("golden")
      }

      static func loadCases() throws -> [CorpusCase] {
          let urls = try FileManager.default
              .contentsOfDirectory(at: goldenDirectory,
                                   includingPropertiesForKeys: nil)
              .filter { $0.pathExtension == "json" }
              .sorted { $0.lastPathComponent < $1.lastPathComponent }
          let decoder = JSONDecoder()
          return try urls.map {
              try decoder.decode(CorpusCase.self, from: Data(contentsOf: $0))
          }
      }
  }

  /// Pure comparison: nil on match, else a human-readable reason. Phase 2 uses
  /// this to diff the NEW Swift engine's output against the golden corpus.
  func corpusMismatchReason(_ expected: ExpectedSnapshot,
                            _ actual: EngineSnapshot) -> String? {
      if expected.winner != actual.winner {
          return "winner: expected \(expected.winner), got \(actual.winner)"
      }
      if expected.whiteCaptures != actual.whiteCaptures {
          return "whiteCaptures: expected \(expected.whiteCaptures), "
               + "got \(actual.whiteCaptures)"
      }
      if expected.blackCaptures != actual.blackCaptures {
          return "blackCaptures: expected \(expected.blackCaptures), "
               + "got \(actual.blackCaptures)"
      }
      for r in 0..<19 {
          for c in 0..<19 {
              let e = expected.board[r][c]
              let a = actual.board[r][c]
              if e != a {
                  return "board[\(r)][\(c)] (rowCol \(r * 19 + c)): "
                       + "expected \(e), got \(a)"
              }
          }
      }
      return nil
  }

  /// Asserts the NEW engine's snapshot matches a golden case. Used by Phase 2.
  func assertEngineMatchesCorpus(_ corpusCase: CorpusCase,
                                 actual: EngineSnapshot,
                                 file: StaticString = #filePath,
                                 line: UInt = #line) {
      if let reason = corpusMismatchReason(corpusCase.expected, actual) {
          XCTFail("corpus '\(corpusCase.name)' [\(corpusCase.variant)] "
                + "mismatch — \(reason)", file: file, line: line)
      }
  }
  ```
  Add to the **PenteEngineTests** target membership.

- [ ] **Step 4: Run the helper test (expected PASS).**
  ```bash
  cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/CorpusHelperTests 2>&1 | tail -6
  ```
  Expected PASS:
  ```
       Executed 4 tests, with 0 failures (0 unexpected) in ...
  ** TEST SUCCEEDED **
  ```

- [ ] **Step 5: Run the entire target to confirm everything is green together.**
  ```bash
  cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests 2>&1 | tail -6
  ```
  Expected PASS (smoke + generator-verify + 4 helper tests):
  ```
       Executed 6 tests, with 0 failures (0 unexpected) in ...
  ** TEST SUCCEEDED **
  ```

- [ ] **Step 6: Commit.**
  ```bash
  cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS
  git add penteLive.xcodeproj/project.pbxproj \
          PenteEngineTests/CorpusSupport.swift \
          PenteEngineTests/CorpusHelperTests.swift
  git commit -m "test: add engine-agnostic assertEngineMatchesCorpus helper"
  ```

---

### Forward notes for later phases (not Phase 0 tasks)

- **Phase 2 usage:** for each `try Corpus.loadCases()`, map `case.variant` (string) → `PenteVariant` with a Phase-2-owned table (`"pente" → .pente`, `"keryoPente" → .keryoPente`, `"oPente" → .oPente`, `"poofPente" → .poofPente`, `"dPente" → .dPente`, `"dkPente" → .dkPente`, `"gpente" → .gpente`, `"swap2Pente" → .swap2Pente`, `"swap2Keryo" → .swap2Keryo`, `"gomoku" → .gomoku`, `"connect6" → .connect6`); construct `PenteGame(variant:)`; capture `let result = game.replay(case.moves, until: case.moves.count)`; build `EngineSnapshot(winner: result.winner, whiteCaptures: game.whiteCaptures, blackCaptures: game.blackCaptures, board: (0..<19).map { r in (0..<19).map { c in game.stone(at: r*19 + c) } })`; then call `assertEngineMatchesCorpus(case, actual:)`.
- **Duplicate-class cleanup:** because `test1/PenteGame.m` is compiled into both the app and `PenteEngineTests`, the runtime logs a benign "Class PenteGame is implemented in both …" warning. When Phase 2 makes the Swift engine authoritative, **delete `CorpusSnapshotGeneratorTests.m`** (the corpus is already committed) and **remove `test1/PenteGame.m` from the PenteEngineTests Compile Sources**; the warning disappears and the only remaining ObjC dependency is gone.
- **Regeneration:** the golden corpus is intentionally immutable. If a later phase deliberately changes engine behaviour, regenerate by `rm -rf PenteEngineTests/golden` and re-running the generator before it is removed (Phase 2), reviewing the JSON diff as the record of the behavioural change.
- **Coverage note:** the corpus exercises cadence, captures, poof/keryo-poof, and both win conditions, matching the ObjC `replayMoves`/`winnerForVariant` paths. Opening masks (`maskTournamentOpening`/`maskGPenteOpening`) are *not* applied by `replayMoves`, so they are covered by dedicated unit tests in later phases (mirroring `tests/PenteGameTests.m` `testMasks`), not by this corpus.
## Phase 1: Scan rule primitives (Swift)

This phase creates the single pure rule-primitive layer, `Scan`, in Swift. Every
directional rule in the legacy Objective-C engine (`test1/PenteGame.m`) is ported
**verbatim** into exactly one of three pure functions:

- `Scan.captures(on:at:color:run:)` — custodial capture (`run = 2` Pente,
  `run = 3` Keryo), ported from `detectCaptureOfOpponent:atPosition:` and
  `detectKeryoCaptureOfOpponent:atPosition:`.
- `Scan.poof(on:at:color:run:)` — self-capture "poof" (`run = 2` poof,
  `run = 3` keryo-poof), ported from `detectPoof:atPosition:` and
  `detectKeryoPoof:atPosition:`, including the corrected both-ends check from
  commit `63986f7`.
- `Scan.winLine(on:at:color:length:)` — N-in-a-row (`length = 5` Pente,
  `length = 6` Connect6), ported from `detectPenteOf:atPosition:`.

All three are **pure**: they take a plain `[[Int]]` board (`board[row][col]`,
values `0` empty / `1` white / `2` black / `-1` masked) by value and never mutate
the caller's board. Coordinates are `rowCol = row * 19 + col`.

**Semantics that are preserved exactly (faithfulness over elegance):**

- The `color` parameter is always the colour of the stone **just played** (the
  mover, called `myColor` in the legacy code). For `captures`, the returned
  `Capture.color` is the **captured (opponent)** colour. For `poof`, the poofed
  stones are the mover's own colour, so `Capture.color == color`. These match the
  legacy `capture.color` assignments line-for-line.
- `poof` emits the placed stone **first** (the legacy code inserts it at the front
  of the call's records via `insertObject:atIndex:capturesLength`), then the
  partner stones in detection order.
- `winLine` keeps the legacy strict bounds `i > 0 && i < 19 && j > 0 && j < 19`,
  which intentionally never scan into row 0 or column 0; tests place lines in the
  board interior so this edge quirk is not exercised.
- The number of returned `Capture`s equals the legacy capture-count increment for
  that move (used by `PenteGame` in a later phase: a colour's running tally is
  just the count of returned `Capture`s whose `color` matches that colour).

**Dependencies from Phase 0 (assumed present):**

- `Capture` (`@objc final class Capture: NSObject`, `init(position:color:)`) lives
  in the `PenteEngine` group and is compiled into the `penteLive` app module.
- An XCTest target named **`PenteEngineTests`** exists, is wired into the `test1`
  scheme's test action, hosts on the `penteLive` app, and the `penteLive` target is
  built with `ENABLE_TESTABILITY = YES` (Debug) so tests can `@testable import
  penteLive`. The module name is `penteLive` (the generated interop header is
  `penteLive-Swift.h`).

> Work on the feature branch created in Phase 0 (e.g. `engine/scan-primitives`).
> Do not commit to `main`.

---

### Task 1.1: Scan scaffold + custodial capture (`captures`)

Create `Scan.swift` and the `ScanTests.swift` test file, wire both into their Xcode
targets, then drive `Scan.captures` (both `run = 2` and `run = 3`) with TDD.

**Files**

- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/PenteEngine/Scan.swift`
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/ScanTests.swift`
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcodeproj/project.pbxproj` (add the two new files to their targets' build phases)

**Steps**

- [ ] **Step 1: Create an empty `Scan` enum so the module compiles.**
  Write `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/PenteEngine/Scan.swift`:

  ```swift
  //
  //  Scan.swift
  //  penteLive  (PenteEngine)
  //
  //  Pure directional rule primitives ported verbatim from the legacy
  //  Objective-C engine (test1/PenteGame.m). No state, no board mutation:
  //  every function takes a plain [[Int]] (board[row][col]) by value and
  //  returns its result. Coordinates use rowCol = row * 19 + col.
  //
  //  Cell values: 0 empty, 1 white, 2 black, -1 masked (a masked cell never
  //  equals a colour, so it is inert in every scan).
  //
  //  The `color` parameter is always the colour of the stone JUST PLAYED
  //  (the mover / "myColor" in the legacy code).
  //

  import Foundation

  enum Scan {
  }
  ```

- [ ] **Step 2: Add both new files to their Xcode targets.**
  `Scan.swift` must compile into the `penteLive` app target; `ScanTests.swift` into
  the `PenteEngineTests` target. Write `/tmp/add_scan_files.rb`:

  ```ruby
  require 'xcodeproj'

  project_path = '/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcodeproj'
  project = Xcodeproj::Project.open(project_path)

  app   = project.targets.find { |t| t.name == 'penteLive' }
  tests = project.targets.find { |t| t.name == 'PenteEngineTests' }
  raise 'penteLive target not found' unless app
  raise 'PenteEngineTests target not found' unless tests

  engine_group = project.main_group.find_subpath('test1/PenteEngine', true)
  engine_group.set_source_tree('SOURCE_ROOT')
  unless engine_group.files.any? { |f| f.path&.end_with?('Scan.swift') }
    scan_ref = engine_group.new_reference('test1/PenteEngine/Scan.swift')
    app.add_file_references([scan_ref])
  end

  tests_group = project.main_group.find_subpath('PenteEngineTests', true)
  tests_group.set_source_tree('SOURCE_ROOT')
  unless tests_group.files.any? { |f| f.path&.end_with?('ScanTests.swift') }
    test_ref = tests_group.new_reference('PenteEngineTests/ScanTests.swift')
    tests.add_file_references([test_ref])
  end

  project.save
  puts 'OK: files added to targets'
  ```

  Run it (install the gem first if needed):

  ```bash
  gem list -i xcodeproj >/dev/null 2>&1 || gem install xcodeproj
  ruby /tmp/add_scan_files.rb
  ```

  Expected output: `OK: files added to targets`.

- [ ] **Step 3: Write the failing capture tests.**
  Create `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/ScanTests.swift`:

  ```swift
  import XCTest
  @testable import penteLive

  final class ScanTests: XCTestCase {

      /// 19x19 board of empties; board[row][col], 0 empty / 1 white / 2 black / -1 masked.
      private func emptyBoard() -> [[Int]] {
          Array(repeating: Array(repeating: 0, count: 19), count: 19)
      }

      private func rc(_ row: Int, _ col: Int) -> Int { row * 19 + col }

      // MARK: - captures (run = 2 Pente, run = 3 Keryo)

      func testTwoStoneCustodialCapture() {
          var board = emptyBoard()
          // white(1) places at (9,9); two black(2) at (10,9),(11,9); white flanker (12,9).
          board[9][9] = 1
          board[10][9] = 2
          board[11][9] = 2
          board[12][9] = 1
          let captures = Scan.captures(on: board, at: rc(9, 9), color: 1, run: 2)
          XCTAssertEqual(captures.count, 2)
          XCTAssertEqual(captures.map { $0.position }, [rc(10, 9), rc(11, 9)])
          XCTAssertEqual(captures.map { $0.color }, [2, 2])
          // purity: the caller's board is untouched.
          XCTAssertEqual(board[10][9], 2)
          XCTAssertEqual(board[11][9], 2)
      }

      func testNoCaptureWhenOwnColourAtEndOfPair() {
          var board = emptyBoard()
          // white places at (9,9); (10,9) black, (11,9) WHITE (own colour), (12,9) white.
          board[9][9] = 1
          board[10][9] = 2
          board[11][9] = 1   // own colour where the 2nd captured stone would have to be
          board[12][9] = 1
          let captures = Scan.captures(on: board, at: rc(9, 9), color: 1, run: 2)
          XCTAssertTrue(captures.isEmpty)
      }

      func testThreeStoneKeryoCapture() {
          var board = emptyBoard()
          // white places at (9,9); three black at (10,9),(11,9),(12,9); white flanker (13,9).
          board[9][9] = 1
          board[10][9] = 2
          board[11][9] = 2
          board[12][9] = 2
          board[13][9] = 1
          let captures = Scan.captures(on: board, at: rc(9, 9), color: 1, run: 3)
          XCTAssertEqual(captures.count, 3)
          XCTAssertEqual(captures.map { $0.position }, [rc(10, 9), rc(11, 9), rc(12, 9)])
          XCTAssertEqual(captures.map { $0.color }, [2, 2, 2])
          // purity
          XCTAssertEqual(board[10][9], 2)
          XCTAssertEqual(board[13][9], 1)
      }

      func testKeryoRunDoesNotFireOnTwoStoneLine() {
          var board = emptyBoard()
          // Only two black stones; a run=3 scan must NOT capture them.
          board[9][9] = 1
          board[10][9] = 2
          board[11][9] = 2
          board[12][9] = 1   // flanker at distance 3, but keryo needs it at distance 4
          let captures = Scan.captures(on: board, at: rc(9, 9), color: 1, run: 3)
          XCTAssertTrue(captures.isEmpty)
      }
  }
  ```

- [ ] **Step 4: Run the tests — expect RED (member missing).**

  ```bash
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/ScanTests/testTwoStoneCustodialCapture
  ```

  Expected: compilation fails with `type 'Scan' has no member 'captures'`, ending in
  `** TEST FAILED **`.

- [ ] **Step 5: Implement `captures` (and the shared helpers).**
  Replace the `enum Scan {\n}` body in `Scan.swift` with:

  ```swift
  enum Scan {

      /// 8 neighbour directions, in the exact order the legacy engine scans them.
      private static let neighbours: [(Int, Int)] = [
          (-1, 0), (-1, -1), (0, -1), (1, -1),
          (1, 0), (1, 1), (0, 1), (-1, 1),
      ]

      private static func inBounds(_ i: Int, _ j: Int) -> Bool {
          i >= 0 && i < 19 && j >= 0 && j < 19
      }

      // MARK: - Custodial capture (run = 2 Pente, run = 3 Keryo)
      //
      // Ports detectCaptureOfOpponent:atPosition: (run = 2) and
      // detectKeryoCaptureOfOpponent:atPosition: (run = 3). For each of the 8
      // directions: if the far flanker (distance run+1) is the mover's colour and
      // the `run` stones between it and the placed stone are all the opponent's,
      // those stones are captured. The far flanker check matches the legacy
      // `abstractBoard[...] == myColor`; captured stones carry the opponent colour.
      static func captures(on board: [[Int]], at move: Int, color: Int, run: Int) -> [Capture] {
          var b = board
          let i = move / 19, j = move % 19
          let opponent = (color == 1) ? 2 : 1
          let far = run + 1
          var result: [Capture] = []
          for (di, dj) in neighbours {
              let fi = i + far * di, fj = j + far * dj
              guard inBounds(fi, fj), b[fi][fj] == color else { continue }
              var custodial = true
              for k in 1...run {
                  if b[i + k * di][j + k * dj] != opponent {
                      custodial = false
                      break
                  }
              }
              guard custodial else { continue }
              for k in 1...run {
                  let ci = i + k * di, cj = j + k * dj
                  b[ci][cj] = 0
                  result.append(Capture(position: ci * 19 + cj, color: opponent))
              }
          }
          return result
      }
  }
  ```

- [ ] **Step 6: Run the capture tests — expect GREEN.**

  ```bash
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/ScanTests/testTwoStoneCustodialCapture \
    -only-testing:PenteEngineTests/ScanTests/testNoCaptureWhenOwnColourAtEndOfPair \
    -only-testing:PenteEngineTests/ScanTests/testThreeStoneKeryoCapture \
    -only-testing:PenteEngineTests/ScanTests/testKeryoRunDoesNotFireOnTwoStoneLine
  ```

  Expected: all four pass, ending in `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit.**

  ```bash
  git add test1/PenteEngine/Scan.swift PenteEngineTests/ScanTests.swift penteLive.xcodeproj/project.pbxproj
  git commit -m "feat(engine): add Scan.captures custodial capture primitive"
  ```

---

### Task 1.2: Self-capture "poof" (`poof`, run 2 and keryo run 3)

Port `detectPoof:atPosition:` (run = 2) and `detectKeryoPoof:atPosition:`
(run = 3) into one pure `Scan.poof`. The run = 3 path includes the **corrected**
centred both-ends check (commit `63986f7`): the centred anti-diagonal case must
verify **both** partner stones of the 3-stone line, not one partner twice.

**Files**

- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/ScanTests.swift` (insert new test methods before the final `}` of `final class ScanTests`, ~line 78)
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/PenteEngine/Scan.swift` (insert the `poof` method before the closing brace of `enum Scan`, ~line 60)

**Steps**

- [ ] **Step 1: Write the failing poof tests.**
  Insert these methods into `ScanTests.swift`, immediately before the final closing
  brace of `final class ScanTests`:

  ```swift
      // MARK: - poof (run = 2)

      func testPoofSelfCapture() {
          var board = emptyBoard()
          // white pair (8,9) + (9,9 placed) flanked by black ends at (7,9) and (10,9).
          board[7][9] = 2
          board[8][9] = 1
          board[9][9] = 1   // placed
          board[10][9] = 2
          let poofed = Scan.poof(on: board, at: rc(9, 9), color: 1, run: 2)
          XCTAssertEqual(poofed.count, 2)
          // placed stone recorded first, then its partner.
          XCTAssertEqual(poofed.map { $0.position }, [rc(9, 9), rc(8, 9)])
          XCTAssertEqual(poofed.map { $0.color }, [1, 1])
          // purity
          XCTAssertEqual(board[8][9], 1)
          XCTAssertEqual(board[9][9], 1)
      }

      func testNoPoofWithoutBothOpponentEnds() {
          var board = emptyBoard()
          board[7][9] = 2   // one end is opponent
          board[8][9] = 1
          board[9][9] = 1   // placed
          board[10][9] = 0  // other end is EMPTY -> no poof
          let poofed = Scan.poof(on: board, at: rc(9, 9), color: 1, run: 2)
          XCTAssertTrue(poofed.isEmpty)
      }

      // MARK: - keryo-poof (run = 3)

      func testKeryoPoofThreeInLine() {
          var board = emptyBoard()
          // Three white in a column from the placed stone: (9,9),(8,9),(7,9),
          // flanked by black at (6,9) [far end] and (10,9) [opposite end].
          board[6][9] = 2
          board[7][9] = 1
          board[8][9] = 1
          board[9][9] = 1   // placed
          board[10][9] = 2
          let poofed = Scan.poof(on: board, at: rc(9, 9), color: 1, run: 3)
          XCTAssertEqual(poofed.count, 3)
          // placed first, then far partner (7,9), then near partner (8,9).
          XCTAssertEqual(poofed.map { $0.position }, [rc(9, 9), rc(7, 9), rc(8, 9)])
          XCTAssertEqual(poofed.map { $0.color }, [1, 1, 1])
      }

      func testKeryoPoofCentredBothPartnersPresent() {
          var board = emptyBoard()
          // placed (9,9) centred between partners (10,8) & (8,10), opponent ends
          // at (11,7) & (7,11) — the centred anti-diagonal case.
          board[9][9] = 1
          board[10][8] = 1
          board[8][10] = 1
          board[11][7] = 2
          board[7][11] = 2
          let poofed = Scan.poof(on: board, at: rc(9, 9), color: 1, run: 3)
          XCTAssertEqual(poofed.count, 3)
          XCTAssertEqual(poofed.map { $0.position }, [rc(9, 9), rc(10, 8), rc(8, 10)])
          XCTAssertEqual(poofed.map { $0.color }, [1, 1, 1])
      }

      func testKeryoPoofRequiresBothEndsNotOnePartnerTwice() {
          // Regression guard for commit 63986f7: the centred anti-diagonal case once
          // checked board[i+1][j-1] (one partner) twice instead of also checking the
          // other partner board[i-1][j+1]. Here that other partner (8,10) is MISSING,
          // so the buggy single-partner logic would still poof. Correct logic requires
          // BOTH partners present -> no poof.
          var board = emptyBoard()
          board[9][9] = 1
          board[10][8] = 1
          // board[8][10] intentionally left empty
          board[11][7] = 2
          board[7][11] = 2
          let poofed = Scan.poof(on: board, at: rc(9, 9), color: 1, run: 3)
          XCTAssertTrue(poofed.isEmpty)
      }
  ```

- [ ] **Step 2: Run the poof tests — expect RED (member missing).**

  ```bash
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/ScanTests/testPoofSelfCapture
  ```

  Expected: compilation fails with `type 'Scan' has no member 'poof'`, ending in
  `** TEST FAILED **`.

- [ ] **Step 3: Implement `poof`.**
  Insert this method into `Scan.swift`, immediately before the closing brace of
  `enum Scan`:

  ```swift
      // MARK: - Self-capture "poof" (run = 2 poof, run = 3 keryo-poof)
      //
      // Ports detectPoof:atPosition: (run = 2) and detectKeryoPoof:atPosition:
      // (run = 3). The mover's own stones are removed ("poof") when a line of them,
      // including the just-placed stone, is flanked at BOTH ends by the opponent.
      // Poofed stones carry the mover's colour (Capture.color == color). The placed
      // stone is emitted first (the legacy code inserts it at the front of this
      // call's records), then the partner stones in detection order.
      static func poof(on board: [[Int]], at move: Int, color: Int, run: Int) -> [Capture] {
          var b = board
          let i = move / 19, j = move % 19
          let opponent = (color == 1) ? 2 : 1
          var directional: [Capture] = []
          var poofed = false

          if run == 2 {
              // A pair (placed stone + 1 partner) flanked at both ends.
              for (di, dj) in neighbours {
                  let pi = i + di, pj = j + dj           // partner
                  let fi = i + 2 * di, fj = j + 2 * dj   // far end, beyond the partner
                  let oi = i - di, oj = j - dj           // opposite end, beyond the placed stone
                  guard inBounds(fi, fj), inBounds(oi, oj) else { continue }
                  if b[pi][pj] == color, b[fi][fj] == opponent, b[oi][oj] == opponent {
                      poofed = true
                      b[pi][pj] = 0
                      b[i][j] = 0
                      directional.append(Capture(position: pi * 19 + pj, color: color))
                  }
              }
          } else {
              // run == 3 keryo-poof.
              // (a) Three mover stones starting at the placed stone, flanked both ends.
              for (di, dj) in neighbours {
                  let p1i = i + di, p1j = j + dj           // near partner
                  let p2i = i + 2 * di, p2j = j + 2 * dj   // far partner
                  let fi = i + 3 * di, fj = j + 3 * dj      // far end
                  let oi = i - di, oj = j - dj              // opposite end
                  guard inBounds(fi, fj), inBounds(oi, oj) else { continue }
                  if b[p1i][p1j] == color, b[p2i][p2j] == color,
                     b[fi][fj] == opponent, b[oi][oj] == opponent {
                      poofed = true
                      b[p2i][p2j] = 0
                      b[p1i][p1j] = 0
                      b[i][j] = 0
                      directional.append(Capture(position: p2i * 19 + p2j, color: color))
                      directional.append(Capture(position: p1i * 19 + p1j, color: color))
                  }
              }
              // (b) Placed stone centred in three mover stones, flanked both ends.
              // BOTH partners (pa at +dir, pb at -dir) must be the mover's colour.
              // The bug fixed in 63986f7 checked one partner twice instead of both.
              let axes: [(Int, Int)] = [(1, 0), (1, 1), (0, 1), (1, -1)]
              for (di, dj) in axes {
                  let pai = i + di, paj = j + dj            // partner +dir
                  let pbi = i - di, pbj = j - dj            // partner -dir
                  let eai = i + 2 * di, eaj = j + 2 * dj    // end +2dir
                  let ebi = i - 2 * di, ebj = j - 2 * dj    // end -2dir
                  guard inBounds(eai, eaj), inBounds(ebi, ebj) else { continue }
                  if b[pai][paj] == color, b[pbi][pbj] == color,
                     b[eai][eaj] == opponent, b[ebi][ebj] == opponent {
                      poofed = true
                      b[pai][paj] = 0
                      b[pbi][pbj] = 0
                      b[i][j] = 0
                      directional.append(Capture(position: pai * 19 + paj, color: color))
                      directional.append(Capture(position: pbi * 19 + pbj, color: color))
                  }
              }
          }

          guard poofed else { return [] }
          // Placed stone first, then the partner records in detection order.
          var result: [Capture] = [Capture(position: i * 19 + j, color: color)]
          result.append(contentsOf: directional)
          return result
      }
  ```

- [ ] **Step 4: Run the poof tests — expect GREEN.**

  ```bash
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/ScanTests/testPoofSelfCapture \
    -only-testing:PenteEngineTests/ScanTests/testNoPoofWithoutBothOpponentEnds \
    -only-testing:PenteEngineTests/ScanTests/testKeryoPoofThreeInLine \
    -only-testing:PenteEngineTests/ScanTests/testKeryoPoofCentredBothPartnersPresent \
    -only-testing:PenteEngineTests/ScanTests/testKeryoPoofRequiresBothEndsNotOnePartnerTwice
  ```

  Expected: all five pass, ending in `** TEST SUCCEEDED **`. (If you port the
  pre-`63986f7` bug — checking `b[i+1][j-1]` twice — then
  `testKeryoPoofRequiresBothEndsNotOnePartnerTwice` fails because the incomplete
  line still poofs.)

- [ ] **Step 5: Commit.**

  ```bash
  git add test1/PenteEngine/Scan.swift PenteEngineTests/ScanTests.swift
  git commit -m "feat(engine): add keryo Scan.poof with both-ends guard"
  ```

---

### Task 1.3: Win line (`winLine`)

Port `detectPenteOf:atPosition:` into `Scan.winLine`: along each of the 4 axes,
count consecutive stones of `color` in both directions (accumulating across the
placed stone) and report a win when the run reaches `length`.

**Files**

- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/ScanTests.swift` (insert new test methods before the final `}` of `final class ScanTests`)
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/PenteEngine/Scan.swift` (insert the `winLine` method before the closing brace of `enum Scan`)

**Steps**

- [ ] **Step 1: Write the failing winLine tests.**
  Insert these methods into `ScanTests.swift`, immediately before the final closing
  brace of `final class ScanTests`:

  ```swift
      // MARK: - winLine (length = 5 Pente, length = 6 Connect6)

      func testWinLineHorizontalFive() {
          var board = emptyBoard()
          for c in 5...9 { board[9][c] = 1 }   // (9,5)..(9,9)
          XCTAssertTrue(Scan.winLine(on: board, at: rc(9, 9), color: 1, length: 5))
      }

      func testWinLineVerticalFive() {
          var board = emptyBoard()
          for r in 5...9 { board[r][9] = 2 }   // (5,9)..(9,9)
          XCTAssertTrue(Scan.winLine(on: board, at: rc(9, 9), color: 2, length: 5))
      }

      func testWinLineMainDiagonalFive() {
          var board = emptyBoard()
          for d in 0..<5 { board[5 + d][5 + d] = 1 }   // (5,5)..(9,9)
          XCTAssertTrue(Scan.winLine(on: board, at: rc(9, 9), color: 1, length: 5))
      }

      func testWinLineAntiDiagonalFiveCountingBothSides() {
          var board = emptyBoard()
          // Anti-diagonal through (9,9); placed in the MIDDLE so the win is only
          // found by accumulating both scan directions of one axis.
          board[7][11] = 1
          board[8][10] = 1
          board[9][9] = 1   // placed (middle of the five)
          board[10][8] = 1
          board[11][7] = 1
          XCTAssertTrue(Scan.winLine(on: board, at: rc(9, 9), color: 1, length: 5))
      }

      func testFourInARowIsNotAWin() {
          var board = emptyBoard()
          for c in 6...9 { board[9][c] = 1 }   // only four
          XCTAssertFalse(Scan.winLine(on: board, at: rc(9, 9), color: 1, length: 5))
      }

      func testConnect6NeedsSix() {
          var board = emptyBoard()
          for c in 4...9 { board[9][c] = 1 }   // six in a row, placed at (9,9)
          XCTAssertTrue(Scan.winLine(on: board, at: rc(9, 9), color: 1, length: 6))
          // five is not enough for connect6
          var five = emptyBoard()
          for c in 5...9 { five[9][c] = 1 }
          XCTAssertFalse(Scan.winLine(on: five, at: rc(9, 9), color: 1, length: 6))
      }
  ```

- [ ] **Step 2: Run the winLine tests — expect RED (member missing).**

  ```bash
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/ScanTests/testWinLineHorizontalFive
  ```

  Expected: compilation fails with `type 'Scan' has no member 'winLine'`, ending in
  `** TEST FAILED **`.

- [ ] **Step 3: Implement `winLine`.**
  Insert this method into `Scan.swift`, immediately before the closing brace of
  `enum Scan`:

  ```swift
      // MARK: - Win line (length = 5 Pente, length = 6 Connect6)
      //
      // Ports detectPenteOf:atPosition:. Along each of the 4 axes, count starts at 1
      // (the placed stone) and accumulates over BOTH directions of that axis before
      // resetting for the next axis; a win is reported as soon as the run reaches
      // `length` (legacy `penteCounter > 4` generalised to `count > length - 1`).
      // The strict bounds `> 0` / `< 19` are preserved verbatim from the legacy code,
      // which intentionally never scans into row 0 or column 0.
      static func winLine(on board: [[Int]], at move: Int, color: Int, length: Int) -> Bool {
          let row = move / 19, col = move % 19
          let axes: [((Int, Int), (Int, Int))] = [
              ((-1, 0), (1, 0)),    // vertical
              ((0, -1), (0, 1)),    // horizontal
              ((-1, -1), (1, 1)),   // main diagonal
              ((-1, 1), (1, -1)),   // anti-diagonal
          ]
          for (d1, d2) in axes {
              var count = 1
              for (di, dj) in [d1, d2] {
                  var i = row + di
                  var j = col + dj
                  while i > 0, i < 19, j > 0, j < 19 {
                      if board[i][j] == color {
                          count += 1
                          if count > length - 1 { return true }
                      } else {
                          break
                      }
                      i += di
                      j += dj
                  }
              }
          }
          return false
      }
  ```

- [ ] **Step 4: Run the full `ScanTests` suite — expect GREEN.**

  ```bash
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/ScanTests
  ```

  Expected: all 15 `ScanTests` methods pass, ending in `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit.**

  ```bash
  git add test1/PenteEngine/Scan.swift PenteEngineTests/ScanTests.swift
  git commit -m "feat(engine): add Scan.winLine N-in-a-row primitive"
  ```
## Phase 2: RuleSet recipes + PenteGame engine + MoveResult

This phase builds the stateful Swift engine on top of the pure `Scan` primitives
created in Phase 1. It introduces the `@objc` value types (`PenteVariant`,
`MoveResult`), the thin per-variant `RuleSet` recipes + factory, and the stateful
`@objc PenteGame` engine that drives capture animation in both UIs.

### Frozen-contract identifiers consumed (from Phase 0/1)

- `Scan.captures(on:at:color:run:) -> [Capture]`, `Scan.poof(on:at:color:run:) -> [Capture]`,
  `Scan.winLine(on:at:color:length:) -> Bool` — pure directional scans (Phase 1).
- `Capture` — `@objc final class Capture: NSObject { let position: Int; let color: Int; init(position:color:) }` (Phase 1).
- `assertEngineMatchesCorpus(_:actual:)`, `CorpusCase`, `ExpectedSnapshot`, `EngineSnapshot`,
  and `Corpus.loadCases()` — the engine-agnostic golden-corpus harness frozen in Phase 0
  (`PenteEngineTests/CorpusSupport.swift`); consumed in Task 2.6.
- Test target name **`PenteEngineTests`** — the XCTest target created and frozen in Phase 0
  (the pre-existing empty `PenteEngineTests/` directory is its source folder).

### Source-faithfulness decisions (read verbatim from `test1/PenteGame.m` / `PenteGame.h`)

These were verified by reading the legacy implementation and MUST be preserved:

1. **`Scan`'s `color:` parameter is the colour of the just-placed stone (the mover)**,
   consistent across `captures`/`poof`/`winLine`. The legacy `detectCaptureOfOpponent:`
   took the *opponent* colour, but the unified `Scan` (Phase 1) takes the mover colour and
   derives the opponent internally; each returned `Capture.color` is the colour of the
   *removed* stone (opponent for captures, mover for poofs), matching legacy
   `capture.color = opponentColor` (captures) and `capture.color = myColor` (poofs).

2. **Per-move operation order** (from `replayMoves:variant:untilMove:`, lines ~1070-1096):
   place the stone, then run **poofs first (ascending run)**, then **captures (ascending run)**,
   each applied to the board before the next scan:
   - Pente/GPente/DPente/Swap2Pente → `captures(run:2)`.
   - KeryoPente/DKPente/Swap2Keryo → `captures(run:2)` then `captures(run:3)`.
   - PoofPente → `poof(run:2)` then `captures(run:2)`.
   - OPente → `poof(run:2)`, `poof(run:3)`, `captures(run:2)`, `captures(run:3)`.
   - Gomoku/Connect6 → no poof, no captures.

3. **Colour cadence** (lines 1064-1067): alternating `color = (i % 2) + 1`; Connect6
   `color = (((i % 4) == 0) || ((i % 4) == 3)) ? 1 : 2` (W, B, B, W, W, B, B, W, …).

4. **Counters** (`whiteCaptures`/`blackCaptures` count *stones of that colour removed*):
   incrementing the captured stone's own colour by 1 per removed stone reproduces
   legacy `whiteCaptures += 2` (a captured white pair) and the poof increments exactly.

5. **Win** (`winnerForVariant:moves:`, lines ~1152-1179): if the mover makes a line of
   `winLength` → mover wins; else capture threshold — **Keryo family (`>= 15`)**
   vs **Pente family (`== 10`)**; Gomoku/Connect6 have no capture win. Connect6 uses
   `winLength = 6` (the prompt directs this; legacy `detectPenteOf` hard-codes 5 — an
   intentional correction). The winner field is NOT part of the corpus (corpus = board +
   counters from `replayMoves`), so this correction does not affect corpus reproduction.

6. **Opening masks** (`maskTournamentOpening`/`maskGPenteOpening`, lines ~1100-1126) are
   applied by the engine when **exactly 2 moves have been played** (legacy UI condition
   `[movesList count] == 2`), keyed by `RuleSet.opening`. They write `-1` into still-empty
   restricted cells. The legacy UI gated the *tournament* mask on "rated"; the engine treats
   the opening restriction as intrinsic to the variant (the rated/unrated split was a UI
   policy). Masks are a render-only overlay: they are cleared at the start of every
   `play()` (so scans never see `-1`) and normalised back to `0` in the corpus snapshot, so
   placements + counters reproduce legacy `replayMoves` exactly.

### Class-name collision (MUST do first — Task 2.1)

The legacy ObjC class is also named `PenteGame` (`@interface PenteGame` in
`test1/PenteGame.h`). The new Swift `@objc(SwiftPenteGame) final class PenteGame` would collide.
Because of that explicit `@objc(SwiftPenteGame)` annotation, Swift callers reference the new engine
as `PenteGame` while Objective-C callers (the Phase 4 view controllers, via the generated
`penteLive-Swift.h`) reference it as `SwiftPenteGame`. Task 2.1
renames the legacy class to `LegacyPenteGame` and updates its 3 callers + 2 `getGameName`
call sites, freeing the `PenteGame` name. The legacy class keeps working (temporary
coexistence) until a later phase migrates `MMAIViewController`/`BoardViewController`/
`DatabaseViewController` onto the new Swift engine.

---

### Task 2.1: Rename legacy ObjC `PenteGame` → `LegacyPenteGame` (free the name)

**Files**
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/PenteGame.h` (line 36)
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/PenteGame.m` (line 12)
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/GamesTableViewController.m` (lines 3566, 3668)
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/MMAIViewController.m` (lines 39, 65)
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/BoardViewController.m` (lines 97, 114)
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/DatabaseViewController.m` (lines 39, 69)

> Do NOT touch `PenteGameVariant` (the NS_ENUM typedef stays), `struct Capture`, the
> filenames, or the `#import "PenteGame.h"` lines. Only the class symbol `PenteGame` is renamed.

- [ ] **Step 1: Rename the interface.** In `test1/PenteGame.h`, change the class declaration:

  ```objc
  @interface LegacyPenteGame : NSObject {
  ```
  (was `@interface PenteGame : NSObject {`).

- [ ] **Step 2: Rename the implementation.** In `test1/PenteGame.m`, change:

  ```objc
  @implementation LegacyPenteGame
  ```
  (was `@implementation PenteGame`).

- [ ] **Step 3: Update the `getGameName` class-method callers.** In
  `test1/GamesTableViewController.m`, both call sites become `[LegacyPenteGame getGameName: gameInt]`:

  ```objc
  NSString *gameStr = [LegacyPenteGame getGameName: gameInt];   // line ~3566
  ```
  ```objc
  NSString *gameStr = [LegacyPenteGame getGameName:gameInt];    // line ~3668
  ```

- [ ] **Step 4: Update `MMAIViewController.m`.** Change the ivar declaration and the alloc:

  ```objc
  LegacyPenteGame *penteGame;                      // line ~39
  ```
  ```objc
  penteGame = [[LegacyPenteGame alloc] init];      // line ~65
  ```

- [ ] **Step 5: Update `BoardViewController.m`.** Change the global declaration and the alloc:

  ```objc
  LegacyPenteGame *penteGame;                      // line ~97
  ```
  ```objc
  penteGame = [[LegacyPenteGame alloc] init];      // line ~114
  ```

- [ ] **Step 6: Update `DatabaseViewController.m`.** Change the ivar declaration and the alloc:

  ```objc
  LegacyPenteGame *penteGame;                      // line ~39
  ```
  ```objc
  penteGame = [[LegacyPenteGame alloc] init];      // line ~69
  ```

- [ ] **Step 7: Verify the app still builds (no behaviour change).** Run:

  ```bash
  xcodebuild build -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16'
  ```
  Expected: `** BUILD SUCCEEDED **`. (The legacy engine is unchanged; the rename only
  frees the `PenteGame` symbol. Phase 0/1 corpus tests still pass.)

- [ ] **Step 8: Commit.**

  ```bash
  git add test1/PenteGame.h test1/PenteGame.m test1/GamesTableViewController.m \
    test1/MMAIViewController.m test1/BoardViewController.m test1/DatabaseViewController.m
  git commit -m "refactor(engine): rename legacy ObjC PenteGame to LegacyPenteGame"
  ```

---

### Task 2.2: `PenteVariant` (`@objc enum`, raw values frozen to legacy order)

**Files**
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/PenteEngine/PenteVariant.swift`
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/PenteVariantTests.swift`
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/Scripts/add_swift_file.rb`

> **Raw-value reconciliation:** the frozen contract lists the cases as
> `pente, keryoPente, oPente, poofPente, dPente, dkPente, gpente, swap2Pente, swap2Keryo, gomoku, connect6`,
> but the contract also states the ORDER MUST MATCH the legacy `PenteGameVariant`. The legacy
> NS_ENUM (verified in `PenteGame.h`) is `Pente=0, KeryoPente=1, GPente=2, DPente=3, DKPente=4,
> OPente=5, PoofPente=6, Swap2Pente=7, Swap2Keryo=8, Gomoku=9, Connect6=10`. We therefore pin
> **explicit raw values** to the legacy integers (the source of truth for stored game codes and
> the corpus), regardless of the contract's textual case listing.

- [ ] **Step 1: Create the project-membership helper** (reused by every subsequent file).
  Write `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/Scripts/add_swift_file.rb`:

  ```ruby
  # Usage: ruby Scripts/add_swift_file.rb <relative_file_path> <target_name> <group_path>
  require "xcodeproj"

  rel_path, target_name, group_path = ARGV
  abort("usage: add_swift_file.rb <path> <target> <group>") unless rel_path && target_name && group_path

  project = Xcodeproj::Project.open("penteLive.xcodeproj")
  target  = project.targets.find { |t| t.name == target_name } or abort("no target #{target_name}")
  group   = project.main_group.find_subpath(group_path, true)
  group.set_source_tree("SOURCE_ROOT")

  ref = group.files.find { |f| f.real_path.to_s.end_with?(rel_path) }
  ref ||= group.new_reference(rel_path)

  already = target.source_build_phase.files_references.include?(ref)
  target.add_file_references([ref]) unless already
  project.save
  puts "added #{rel_path} to #{target_name} (#{already ? "already present" : "new"})"
  ```

  Confirm the gem is available (it ships with the project's fastlane toolchain):

  ```bash
  gem list -i xcodeproj || gem install xcodeproj
  ```
  Expected: `true` (or a successful install).

- [ ] **Step 2: Write the failing test.** Create `PenteEngineTests/PenteVariantTests.swift`:

  ```swift
  import XCTest
  @testable import penteLive

  final class PenteVariantTests: XCTestCase {
      func testRawValuesMatchLegacyPenteGameVariantOrder() {
          // Raw values are FROZEN to the legacy PenteGameVariant NS_ENUM (PenteGame.h):
          // Pente=0, KeryoPente=1, GPente=2, DPente=3, DKPente=4, OPente=5,
          // PoofPente=6, Swap2Pente=7, Swap2Keryo=8, Gomoku=9, Connect6=10.
          XCTAssertEqual(PenteVariant.pente.rawValue, 0)
          XCTAssertEqual(PenteVariant.keryoPente.rawValue, 1)
          XCTAssertEqual(PenteVariant.gpente.rawValue, 2)
          XCTAssertEqual(PenteVariant.dPente.rawValue, 3)
          XCTAssertEqual(PenteVariant.dkPente.rawValue, 4)
          XCTAssertEqual(PenteVariant.oPente.rawValue, 5)
          XCTAssertEqual(PenteVariant.poofPente.rawValue, 6)
          XCTAssertEqual(PenteVariant.swap2Pente.rawValue, 7)
          XCTAssertEqual(PenteVariant.swap2Keryo.rawValue, 8)
          XCTAssertEqual(PenteVariant.gomoku.rawValue, 9)
          XCTAssertEqual(PenteVariant.connect6.rawValue, 10)
      }
  }
  ```

- [ ] **Step 3: Add the test file to the test target and run it (expected FAIL).**

  ```bash
  ruby Scripts/add_swift_file.rb PenteEngineTests/PenteVariantTests.swift PenteEngineTests PenteEngineTests
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/PenteVariantTests/testRawValuesMatchLegacyPenteGameVariantOrder
  ```
  Expected: **FAIL** — `error: cannot find 'PenteVariant' in scope`.

- [ ] **Step 4: Implement `PenteVariant.swift`.** Create `test1/PenteEngine/PenteVariant.swift`:

  ```swift
  import Foundation

  /// Game variants. Raw values are FROZEN to match the legacy ObjC
  /// `PenteGameVariant` NS_ENUM in PenteGame.h so existing integer game codes and
  /// the golden corpus continue to map correctly.
  @objc enum PenteVariant: Int {
      case pente = 0
      case keryoPente = 1
      case gpente = 2
      case dPente = 3
      case dkPente = 4
      case oPente = 5
      case poofPente = 6
      case swap2Pente = 7
      case swap2Keryo = 8
      case gomoku = 9
      case connect6 = 10
  }
  ```

- [ ] **Step 5: Add to the app target and re-run (expected PASS).**

  ```bash
  ruby Scripts/add_swift_file.rb test1/PenteEngine/PenteVariant.swift penteLive test1/PenteEngine
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/PenteVariantTests/testRawValuesMatchLegacyPenteGameVariantOrder
  ```
  Expected: `Test Suite 'PenteVariantTests' passed` / `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit.**

  ```bash
  git add Scripts/add_swift_file.rb test1/PenteEngine/PenteVariant.swift \
    PenteEngineTests/PenteVariantTests.swift penteLive.xcodeproj/project.pbxproj
  git commit -m "feat(engine): add @objc PenteVariant enum matching legacy order"
  ```

---

### Task 2.3: `MoveResult` (`@objc` value type)

**Files**
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/PenteEngine/MoveResult.swift`
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/MoveResultTests.swift`

- [ ] **Step 1: Write the failing test.** Create `PenteEngineTests/MoveResultTests.swift`:

  ```swift
  import XCTest
  @testable import penteLive

  final class MoveResultTests: XCTestCase {
      func testHoldsValues() {
          let caps = [Capture(position: 10, color: 2), Capture(position: 11, color: 2)]
          let r = MoveResult(captured: caps, poofed: true, winner: 1, placed: 2)
          XCTAssertEqual(r.captured.count, 2)
          XCTAssertEqual(r.captured[0].position, 10)
          XCTAssertEqual(r.captured[0].color, 2)
          XCTAssertTrue(r.poofed)
          XCTAssertEqual(r.winner, 1)
          XCTAssertEqual(r.placed, 2)
      }
  }
  ```

- [ ] **Step 2: Add the test file and run (expected FAIL).**

  ```bash
  ruby Scripts/add_swift_file.rb PenteEngineTests/MoveResultTests.swift PenteEngineTests PenteEngineTests
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/MoveResultTests/testHoldsValues
  ```
  Expected: **FAIL** — `error: cannot find 'MoveResult' in scope`.

- [ ] **Step 3: Implement `MoveResult.swift`.** Create `test1/PenteEngine/MoveResult.swift`:

  ```swift
  import Foundation

  /// Result of a single `PenteGame.play(_:)`. Drives capture animation in both UIs.
  @objc final class MoveResult: NSObject {
      /// Stones removed by this move (captures and/or poofs), in detection order.
      /// Each `Capture.color` is the colour of the *removed* stone.
      @objc let captured: [Capture]
      /// True when this move triggered at least one poof (self-capture).
      @objc let poofed: Bool
      /// 0 = no winner, 1 = white wins, 2 = black wins.
      @objc let winner: Int
      /// Colour just played (1 white, 2 black). 0 only for an empty replay.
      @objc let placed: Int

      @objc init(captured: [Capture], poofed: Bool, winner: Int, placed: Int) {
          self.captured = captured
          self.poofed = poofed
          self.winner = winner
          self.placed = placed
          super.init()
      }
  }
  ```

- [ ] **Step 4: Add to the app target and re-run (expected PASS).**

  ```bash
  ruby Scripts/add_swift_file.rb test1/PenteEngine/MoveResult.swift penteLive test1/PenteEngine
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/MoveResultTests/testHoldsValues
  ```
  Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit.**

  ```bash
  git add test1/PenteEngine/MoveResult.swift PenteEngineTests/MoveResultTests.swift \
    penteLive.xcodeproj/project.pbxproj
  git commit -m "feat(engine): add @objc MoveResult value type"
  ```

---

### Task 2.4: `RuleSet` protocol + per-variant recipes + `ruleSet(for:)` factory

**Files**
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/PenteEngine/RuleSet.swift`
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/RuleSetTests.swift`

The per-variant parameter table (derived from the dispatch + `winnerForVariant:`):

| variant | capture (run, threshold) | poof | winLength | opening | cadence |
|---|---|---|---|---|---|
| pente | (2, 10) | none | 5 | tournament | alternating |
| keryoPente | (3, 15) | none | 5 | tournament | alternating |
| gpente | (2, 10) | none | 5 | gpente | alternating |
| dPente | (2, 10) | none | 5 | none | alternating |
| dkPente | (3, 15) | none | 5 | none | alternating |
| oPente | (3, 10) | keryo | 5 | tournament | alternating |
| poofPente | (2, 10) | poof | 5 | tournament | alternating |
| swap2Pente | (2, 10) | none | 5 | swap2 | alternating |
| swap2Keryo | (3, 15) | none | 5 | swap2 | alternating |
| gomoku | nil | none | 5 | none | alternating |
| connect6 | nil | none | 6 | none | connect6 |

> `capture.run` is the *maximum* capture run; the engine runs `Scan.captures` for every run
> from 2 up to `run` (so Keryo/OPente run both 2-stone and 3-stone captures, matching the
> legacy `detectCapture…` + `detectKeryoCapture…` pair). OPente's threshold is **10** (it is
> NOT in the legacy `>= 15` family). `.swap2` applies no board mask (the swap2 colour protocol
> is out of scope for the replay engine, matching legacy `replayMoves`, which never masks for
> swap2). `poof == .keryo` runs both poof runs (2 and 3); `.poof` runs only run 2.

- [ ] **Step 1: Write the failing test.** Create `PenteEngineTests/RuleSetTests.swift`:

  ```swift
  import XCTest
  @testable import penteLive

  final class RuleSetTests: XCTestCase {
      private func assertCapture(_ r: RuleSet, run: Int, threshold: Int,
                                 file: StaticString = #filePath, line: UInt = #line) {
          XCTAssertEqual(r.capture?.run, run, file: file, line: line)
          XCTAssertEqual(r.capture?.threshold, threshold, file: file, line: line)
      }

      func testPente() {
          let r = ruleSet(for: .pente)
          assertCapture(r, run: 2, threshold: 10)
          XCTAssertEqual(r.poof, .none)
          XCTAssertEqual(r.winLength, 5)
          XCTAssertEqual(r.opening, .tournament)
          XCTAssertEqual(r.cadence, .alternating)
      }

      func testKeryoPente() {
          let r = ruleSet(for: .keryoPente)
          assertCapture(r, run: 3, threshold: 15)
          XCTAssertEqual(r.poof, .none)
          XCTAssertEqual(r.opening, .tournament)
      }

      func testGPente() {
          let r = ruleSet(for: .gpente)
          assertCapture(r, run: 2, threshold: 10)
          XCTAssertEqual(r.opening, .gpente)
      }

      func testDPente() {
          let r = ruleSet(for: .dPente)
          assertCapture(r, run: 2, threshold: 10)
          XCTAssertEqual(r.opening, .none)
      }

      func testDKPente() {
          let r = ruleSet(for: .dkPente)
          assertCapture(r, run: 3, threshold: 15)
          XCTAssertEqual(r.opening, .none)
      }

      func testOPente() {
          let r = ruleSet(for: .oPente)
          assertCapture(r, run: 3, threshold: 10)   // threshold 10, NOT keryo family
          XCTAssertEqual(r.poof, .keryo)
          XCTAssertEqual(r.opening, .tournament)
      }

      func testPoofPente() {
          let r = ruleSet(for: .poofPente)
          assertCapture(r, run: 2, threshold: 10)
          XCTAssertEqual(r.poof, .poof)
          XCTAssertEqual(r.opening, .tournament)
      }

      func testSwap2Pente() {
          let r = ruleSet(for: .swap2Pente)
          assertCapture(r, run: 2, threshold: 10)
          XCTAssertEqual(r.opening, .swap2)
      }

      func testSwap2Keryo() {
          let r = ruleSet(for: .swap2Keryo)
          assertCapture(r, run: 3, threshold: 15)
          XCTAssertEqual(r.opening, .swap2)
      }

      func testGomoku() {
          let r = ruleSet(for: .gomoku)
          XCTAssertNil(r.capture)
          XCTAssertEqual(r.poof, .none)
          XCTAssertEqual(r.winLength, 5)
          XCTAssertEqual(r.cadence, .alternating)
      }

      func testConnect6() {
          let r = ruleSet(for: .connect6)
          XCTAssertNil(r.capture)
          XCTAssertEqual(r.winLength, 6)
          XCTAssertEqual(r.cadence, .connect6)
      }
  }
  ```

- [ ] **Step 2: Add the test file and run (expected FAIL).**

  ```bash
  ruby Scripts/add_swift_file.rb PenteEngineTests/RuleSetTests.swift PenteEngineTests PenteEngineTests
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/RuleSetTests
  ```
  Expected: **FAIL** — `error: cannot find 'ruleSet' in scope` / `cannot find type 'RuleSet'`.

- [ ] **Step 3: Implement `RuleSet.swift`.** Create `test1/PenteEngine/RuleSet.swift`:

  ```swift
  import Foundation

  /// Self-capture flavour. `.poof` = 2-stone poof only; `.keryo` = 2-stone and 3-stone poof.
  enum PoofKind { case none, poof, keryo }

  /// Restricted-opening overlay applied at exactly 2 played moves.
  enum OpeningMask { case none, tournament, gpente, swap2 }

  /// Move-colour cadence.
  enum Cadence { case alternating, connect6 }

  /// A thin recipe: PARAMETERS ONLY. Recipes contain no scan code; the engine reads
  /// these parameters and drives `Scan`.
  protocol RuleSet {
      /// nil = no captures (Gomoku/Connect6). `run` is the maximum capture run length;
      /// the engine runs captures for every run 2...run. `threshold` is the legacy
      /// capture-loss limit (10 Pente family, 15 Keryo family).
      var capture: (run: Int, threshold: Int)? { get }
      var poof: PoofKind { get }
      var winLength: Int { get }
      var opening: OpeningMask { get }
      var cadence: Cadence { get }
  }

  struct PenteRules: RuleSet {
      let capture: (run: Int, threshold: Int)? = (2, 10)
      let poof: PoofKind = .none
      let winLength: Int = 5
      let opening: OpeningMask = .tournament
      let cadence: Cadence = .alternating
  }

  struct KeryoPenteRules: RuleSet {
      let capture: (run: Int, threshold: Int)? = (3, 15)
      let poof: PoofKind = .none
      let winLength: Int = 5
      let opening: OpeningMask = .tournament
      let cadence: Cadence = .alternating
  }

  struct GPenteRules: RuleSet {
      let capture: (run: Int, threshold: Int)? = (2, 10)
      let poof: PoofKind = .none
      let winLength: Int = 5
      let opening: OpeningMask = .gpente
      let cadence: Cadence = .alternating
  }

  struct DPenteRules: RuleSet {
      let capture: (run: Int, threshold: Int)? = (2, 10)
      let poof: PoofKind = .none
      let winLength: Int = 5
      let opening: OpeningMask = .none
      let cadence: Cadence = .alternating
  }

  struct DKPenteRules: RuleSet {
      let capture: (run: Int, threshold: Int)? = (3, 15)
      let poof: PoofKind = .none
      let winLength: Int = 5
      let opening: OpeningMask = .none
      let cadence: Cadence = .alternating
  }

  struct OPenteRules: RuleSet {
      let capture: (run: Int, threshold: Int)? = (3, 10)
      let poof: PoofKind = .keryo
      let winLength: Int = 5
      let opening: OpeningMask = .tournament
      let cadence: Cadence = .alternating
  }

  struct PoofPenteRules: RuleSet {
      let capture: (run: Int, threshold: Int)? = (2, 10)
      let poof: PoofKind = .poof
      let winLength: Int = 5
      let opening: OpeningMask = .tournament
      let cadence: Cadence = .alternating
  }

  struct Swap2PenteRules: RuleSet {
      let capture: (run: Int, threshold: Int)? = (2, 10)
      let poof: PoofKind = .none
      let winLength: Int = 5
      let opening: OpeningMask = .swap2
      let cadence: Cadence = .alternating
  }

  struct Swap2KeryoRules: RuleSet {
      let capture: (run: Int, threshold: Int)? = (3, 15)
      let poof: PoofKind = .none
      let winLength: Int = 5
      let opening: OpeningMask = .swap2
      let cadence: Cadence = .alternating
  }

  struct GomokuRules: RuleSet {
      let capture: (run: Int, threshold: Int)? = nil
      let poof: PoofKind = .none
      let winLength: Int = 5
      let opening: OpeningMask = .none
      let cadence: Cadence = .alternating
  }

  struct Connect6Rules: RuleSet {
      let capture: (run: Int, threshold: Int)? = nil
      let poof: PoofKind = .none
      let winLength: Int = 6
      let opening: OpeningMask = .none
      let cadence: Cadence = .connect6
  }

  /// Factory: maps a variant to its recipe.
  func ruleSet(for variant: PenteVariant) -> RuleSet {
      switch variant {
      case .pente:      return PenteRules()
      case .keryoPente: return KeryoPenteRules()
      case .gpente:     return GPenteRules()
      case .dPente:     return DPenteRules()
      case .dkPente:    return DKPenteRules()
      case .oPente:     return OPenteRules()
      case .poofPente:  return PoofPenteRules()
      case .swap2Pente: return Swap2PenteRules()
      case .swap2Keryo: return Swap2KeryoRules()
      case .gomoku:     return GomokuRules()
      case .connect6:   return Connect6Rules()
      }
  }
  ```

- [ ] **Step 4: Add to the app target and re-run (expected PASS).**

  ```bash
  ruby Scripts/add_swift_file.rb test1/PenteEngine/RuleSet.swift penteLive test1/PenteEngine
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/RuleSetTests
  ```
  Expected: `Test Suite 'RuleSetTests' passed` (11 tests).

- [ ] **Step 5: Commit.**

  ```bash
  git add test1/PenteEngine/RuleSet.swift PenteEngineTests/RuleSetTests.swift \
    penteLive.xcodeproj/project.pbxproj
  git commit -m "feat(engine): add RuleSet protocol, per-variant recipes, and factory"
  ```

---

### Task 2.5: `PenteGame` stateful `@objc` engine

**Files**
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/PenteEngine/PenteGame.swift`
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/PenteGameEngineTests.swift`

> All test coordinates are placed at interior cells (rows/cols 1–17) for win lines because
> the legacy `detectPenteOf` walk uses `i > 0 && i < 19 && j > 0 && j < 19` (it stops at the
> board edges); `Scan.winLine` (Phase 1) preserves that. Capture/poof tests are placed away
> from the edges too. The opening mask is transient (cleared at the start of each `play()`),
> so it never interferes with later moves in these multi-move sequences.

- [ ] **Step 1: Write the failing engine tests.** Create `PenteEngineTests/PenteGameEngineTests.swift`:

  ```swift
  import XCTest
  @testable import penteLive

  final class PenteGameEngineTests: XCTestCase {

      // MARK: Pente — 2-stone capture (white brackets a black pair)
      func testPenteCaptureRemovesBlackPair() {
          // W(9,5) … W(9,8) brackets B(9,6),B(9,7) → blackCaptures += 2
          let g = PenteGame(variant: .pente)
          let moves = [9*19+5, 9*19+6, 0, 9*19+7, 9*19+8]  // W B W B W
          let r = g.replay(moves, until: moves.count)
          XCTAssertEqual(r.placed, 1)
          XCTAssertEqual(r.captured.count, 2)
          XCTAssertEqual(Set(r.captured.map { $0.position }), [9*19+6, 9*19+7])
          XCTAssertTrue(r.captured.allSatisfy { $0.color == 2 })
          XCTAssertEqual(g.blackCaptures, 2)
          XCTAssertEqual(g.whiteCaptures, 0)
          XCTAssertEqual(g.stone(at: 9*19+6), 0)
          XCTAssertEqual(g.stone(at: 9*19+7), 0)
          XCTAssertEqual(g.stone(at: 9*19+5), 1)
          XCTAssertEqual(g.stone(at: 9*19+8), 1)
          XCTAssertFalse(r.poofed)
          XCTAssertEqual(r.winner, 0)
      }

      // MARK: Pente — win by 5 in a row (interior cells)
      func testPenteWinByFiveInARow() {
          let g = PenteGame(variant: .pente)
          // White at row 3 cols 2..6; black harmless at row 15.
          let moves = [3*19+2, 15*19+2, 3*19+3, 15*19+3, 3*19+4, 15*19+4,
                       3*19+5, 15*19+5, 3*19+6]
          let beforeWin = g.replay(moves, until: 7)   // after 4th white (cols 2..5)
          XCTAssertEqual(beforeWin.winner, 0)
          let r = g.replay(moves, until: moves.count)  // 5th white completes the line
          XCTAssertEqual(r.placed, 1)
          XCTAssertEqual(r.winner, 1)
      }

      // MARK: Keryo — 3-stone capture, threshold 15 (no win at 3)
      func testKeryoCaptureRemovesBlackTriple() {
          // W(9,5) … W(9,9) brackets B(9,6),B(9,7),B(9,8) at distance 4 → keryo capture
          let g = PenteGame(variant: .keryoPente)
          let moves = [9*19+5, 9*19+6, 0, 9*19+7, 1, 9*19+8, 9*19+9]  // W B W B W B W
          let r = g.replay(moves, until: moves.count)
          XCTAssertEqual(r.captured.count, 3)
          XCTAssertEqual(Set(r.captured.map { $0.position }), [9*19+6, 9*19+7, 9*19+8])
          XCTAssertEqual(g.blackCaptures, 3)
          XCTAssertEqual(g.stone(at: 9*19+6), 0)
          XCTAssertEqual(g.stone(at: 9*19+7), 0)
          XCTAssertEqual(g.stone(at: 9*19+8), 0)
          XCTAssertEqual(r.winner, 0)            // 3 < 15
      }

      // MARK: PoofPente — placing into a bracketed pair self-captures (run 2)
      func testPoofPenteSelfCapture() {
          // B(9,5) opp, W(9,6) my, W places (9,7), B(9,8) opp → W pair (9,6),(9,7) poofs
          let g = PenteGame(variant: .poofPente)
          let moves = [9*19+6, 9*19+5, 0, 9*19+8, 9*19+7]  // W B W B W
          let r = g.replay(moves, until: moves.count)
          XCTAssertTrue(r.poofed)
          XCTAssertEqual(r.captured.count, 2)
          XCTAssertEqual(Set(r.captured.map { $0.position }), [9*19+6, 9*19+7])
          XCTAssertTrue(r.captured.allSatisfy { $0.color == 1 })
          XCTAssertEqual(g.whiteCaptures, 2)
          XCTAssertEqual(g.blackCaptures, 0)
          XCTAssertEqual(g.stone(at: 9*19+6), 0)
          XCTAssertEqual(g.stone(at: 9*19+7), 0)
          XCTAssertEqual(r.placed, 1)
          XCTAssertEqual(r.winner, 0)
      }

      // MARK: OPente — 3-stone keryo poof (placed in the middle of 3), threshold 10
      func testOPenteKeryoPoof() {
          // Column j=2 (off-centre): B(1,2), W(2,2), W places (3,2), W(4,2), B(5,2)
          // → W triple (2,2),(3,2),(4,2) keryo-poofs (run 3). Run-2 poof does not fire.
          let g = PenteGame(variant: .oPente)
          let moves = [2*19+2, 1*19+2, 4*19+2, 5*19+2, 3*19+2]  // W B W B W
          let r = g.replay(moves, until: moves.count)
          XCTAssertTrue(r.poofed)
          XCTAssertEqual(r.captured.count, 3)
          XCTAssertEqual(Set(r.captured.map { $0.position }), [2*19+2, 3*19+2, 4*19+2])
          XCTAssertTrue(r.captured.allSatisfy { $0.color == 1 })
          XCTAssertEqual(g.whiteCaptures, 3)
          XCTAssertEqual(g.blackCaptures, 0)
          XCTAssertEqual(g.stone(at: 2*19+2), 0)
          XCTAssertEqual(g.stone(at: 3*19+2), 0)
          XCTAssertEqual(g.stone(at: 4*19+2), 0)
          XCTAssertEqual(g.stone(at: 1*19+2), 2)
          XCTAssertEqual(g.stone(at: 5*19+2), 2)
          XCTAssertEqual(r.winner, 0)            // 3 < 10
      }

      // MARK: Tournament opening mask (Pente) applied at exactly 2 moves, cleared after
      func testTournamentOpeningMask() {
          let g = PenteGame(variant: .pente)
          let moves = [0, 18*19+18, 5*19+5]      // W(0,0), B(18,18), W(5,5)
          _ = g.replay(moves, until: 2)
          XCTAssertEqual(g.stone(at: 9*19+9), -1)   // centre masked
          XCTAssertEqual(g.stone(at: 7*19+7), -1)   // corner of 5x5 masked
          XCTAssertEqual(g.stone(at: 0), 1)         // occupied cell unchanged
          XCTAssertEqual(g.stone(at: 6*19+6), 0)    // outside 5x5 not masked
          _ = g.replay(moves, until: 3)
          XCTAssertEqual(g.stone(at: 9*19+9), 0)    // mask cleared at move 3
      }

      // MARK: G-Pente opening mask adds the 4 arms to the tournament 5x5
      func testGPenteOpeningMask() {
          let g = PenteGame(variant: .gpente)
          let moves = [0, 18*19+18]              // both outside the restricted shape
          _ = g.replay(moves, until: 2)
          XCTAssertEqual(g.stone(at: 9*19+9), -1)   // centre
          XCTAssertEqual(g.stone(at: 9*19+12), -1)  // arm (9,12)
          XCTAssertEqual(g.stone(at: 9*19+13), -1)  // arm (9,13)
          XCTAssertEqual(g.stone(at: 9*19+6), -1)   // arm (9,6)
          XCTAssertEqual(g.stone(at: 9*19+5), -1)   // arm (9,5)
          XCTAssertEqual(g.stone(at: 12*19+9), -1)  // arm (12,9)
          XCTAssertEqual(g.stone(at: 5*19+9), -1)   // arm (5,9)
          XCTAssertEqual(g.stone(at: 9*19+14), 0)   // beyond the arm, not masked
      }

      // MARK: Connect6 cadence W,B,B,W,W,B,B,W
      func testConnect6Cadence() {
          let g = PenteGame(variant: .connect6)
          let expected = [1, 2, 2, 1, 1, 2, 2, 1]
          var placed: [Int] = []
          for i in 0..<8 { placed.append(g.play(i).placed) }
          XCTAssertEqual(placed, expected)
      }

      // MARK: Connect6 needs 6 in a row (5 is NOT a win)
      func testConnect6WinNeedsSix() {
          let g = PenteGame(variant: .connect6)
          // White indices 0,3,4,7,8,11 place (9,2)..(9,7); blacks harmless at row 15.
          let moves = [9*19+2, 15*19+2, 15*19+3, 9*19+3, 9*19+4, 15*19+4,
                       15*19+5, 9*19+5, 9*19+6, 15*19+6, 15*19+7, 9*19+7]
          let five = g.replay(moves, until: 9)     // white has cols 2..6 = 5 in a row
          XCTAssertEqual(five.winner, 0)
          let six = g.replay(moves, until: moves.count)
          XCTAssertEqual(six.placed, 1)
          XCTAssertEqual(six.winner, 1)
      }

      // MARK: Gomoku — 5 in a row wins, and capture geometry does NOT capture
      func testGomokuWinAndNoCapture() {
          let win = PenteGame(variant: .gomoku)
          let winMoves = [3*19+2, 15*19+2, 3*19+3, 15*19+3, 3*19+4, 15*19+4,
                          3*19+5, 15*19+5, 3*19+6]
          XCTAssertEqual(win.replay(winMoves, until: winMoves.count).winner, 1)

          let noCap = PenteGame(variant: .gomoku)
          let capMoves = [9*19+5, 9*19+6, 0, 9*19+7, 9*19+8]  // would capture in Pente
          let r = noCap.replay(capMoves, until: capMoves.count)
          XCTAssertEqual(r.captured.count, 0)
          XCTAssertEqual(noCap.blackCaptures, 0)
          XCTAssertEqual(noCap.stone(at: 9*19+6), 2)   // black pair NOT removed
          XCTAssertEqual(noCap.stone(at: 9*19+7), 2)
      }

      // MARK: reset clears board + counters
      func testReset() {
          let g = PenteGame(variant: .pente)
          _ = g.replay([9*19+5, 9*19+6, 0, 9*19+7, 9*19+8], until: 5)
          XCTAssertEqual(g.blackCaptures, 2)
          g.reset()
          XCTAssertEqual(g.blackCaptures, 0)
          XCTAssertEqual(g.whiteCaptures, 0)
          XCTAssertEqual(g.stone(at: 9*19+5), 0)
      }
  }
  ```

- [ ] **Step 2: Add the test file and run (expected FAIL).**

  ```bash
  ruby Scripts/add_swift_file.rb PenteEngineTests/PenteGameEngineTests.swift PenteEngineTests PenteEngineTests
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/PenteGameEngineTests
  ```
  Expected: **FAIL** — `error: cannot find 'PenteGame' in scope` (Swift engine not yet created).

- [ ] **Step 3: Implement `PenteGame.swift`.** Create `test1/PenteEngine/PenteGame.swift`:

  ```swift
  import Foundation

  /// Stateful game engine. Owns the board, capture counters, move index, and opening
  /// mask. Drives the pure `Scan` primitives via the variant's `RuleSet` recipe.
  /// `@objc`-exposed so ObjC callers reach it through the generated `penteLive-Swift.h`.
  @objc(SwiftPenteGame) final class PenteGame: NSObject {
      private let rules: RuleSet
      private var board: [[Int]]
      private var moveCount: Int = 0
      @objc private(set) var whiteCaptures: Int = 0
      @objc private(set) var blackCaptures: Int = 0

      @objc init(variant: PenteVariant) {
          self.rules = ruleSet(for: variant)
          self.board = Array(repeating: Array(repeating: 0, count: 19), count: 19)
          super.init()
      }

      @objc func reset() {
          board = Array(repeating: Array(repeating: 0, count: 19), count: 19)
          moveCount = 0
          whiteCaptures = 0
          blackCaptures = 0
      }

      /// Read-only accessor for renderers. Returns 0 empty, 1 white, 2 black, -1 masked.
      @objc func stone(at rowCol: Int) -> Int {
          return board[rowCol / 19][rowCol % 19]
      }

      @objc func play(_ move: Int) -> MoveResult {
          let placedColor = colorForMove(moveCount)

          // Masks are a render-only overlay; clear any before placing so scans never
          // see -1 (legacy replayMoves operated on a mask-free board).
          clearOpeningMask()
          board[move / 19][move % 19] = placedColor

          var captured: [Capture] = []
          var poofed = false

          // Poofs first (ascending run), matching legacy PoofPente/OPente order.
          if rules.poof != .none {
              let poofRuns = (rules.poof == .keryo) ? [2, 3] : [2]
              for run in poofRuns {
                  let removed = Scan.poof(on: board, at: move, color: placedColor, run: run)
                  apply(removed)
                  captured.append(contentsOf: removed)
                  if !removed.isEmpty { poofed = true }
              }
          }

          // Captures: run 2 up to capture.run (Keryo/OPente also run 3).
          if let cap = rules.capture {
              var run = 2
              while run <= cap.run {
                  let removed = Scan.captures(on: board, at: move, color: placedColor, run: run)
                  apply(removed)
                  captured.append(contentsOf: removed)
                  run += 1
              }
          }

          moveCount += 1
          let winner = computeWinner(lastMove: move, color: placedColor)
          applyOpeningMask()  // overlay applied last, on the snapshot returned to renderers
          return MoveResult(captured: captured, poofed: poofed, winner: winner, placed: placedColor)
      }

      @objc func replay(_ moves: [Int], until: Int) -> MoveResult {
          reset()
          var last = MoveResult(captured: [], poofed: false, winner: 0, placed: 0)
          var i = 0
          while i < until {
              last = play(moves[i])
              i += 1
          }
          return last
      }

      // MARK: - Internals

      private func colorForMove(_ index: Int) -> Int {
          switch rules.cadence {
          case .alternating:
              return (index % 2) + 1
          case .connect6:
              return (((index % 4) == 0) || ((index % 4) == 3)) ? 1 : 2
          }
      }

      /// Remove each captured/poofed stone and bump that colour's loss counter by one.
      private func apply(_ removed: [Capture]) {
          for cap in removed {
              board[cap.position / 19][cap.position % 19] = 0
              if cap.color == 1 { whiteCaptures += 1 } else { blackCaptures += 1 }
          }
      }

      private func computeWinner(lastMove: Int, color: Int) -> Int {
          if Scan.winLine(on: board, at: lastMove, color: color, length: rules.winLength) {
              return color
          }
          if let cap = rules.capture {
              if cap.threshold == 15 {                 // Keryo family: >= 15
                  if whiteCaptures >= 15 { return 2 }
                  if blackCaptures >= 15 { return 1 }
              } else {                                 // Pente family: == 10
                  if whiteCaptures == 10 { return 2 }
                  if blackCaptures == 10 { return 1 }
              }
          }
          return 0
      }

      private func applyOpeningMask() {
          guard moveCount == 2 else { return }
          switch rules.opening {
          case .tournament: maskTournamentOpening()
          case .gpente:     maskGPenteOpening()
          case .none, .swap2: break
          }
      }

      private func clearOpeningMask() {
          guard rules.opening == .tournament || rules.opening == .gpente else { return }
          for r in 0..<19 {
              for c in 0..<19 where board[r][c] == -1 {
                  board[r][c] = 0
              }
          }
      }

      private func maskTournamentOpening() {
          for i in 7..<12 {
              for j in 7..<12 where board[i][j] == 0 {
                  board[i][j] = -1
              }
          }
      }

      private func maskGPenteOpening() {
          maskTournamentOpening()
          for i in 1..<3 {
              if board[9][11 + i] == 0 { board[9][11 + i] = -1 }
              if board[9][7 - i] == 0 { board[9][7 - i] = -1 }
              if board[11 + i][9] == 0 { board[11 + i][9] = -1 }
              if board[7 - i][9] == 0 { board[7 - i][9] = -1 }
          }
      }
  }
  ```

- [ ] **Step 4: Add to the app target and re-run (expected PASS).**

  ```bash
  ruby Scripts/add_swift_file.rb test1/PenteEngine/PenteGame.swift penteLive test1/PenteEngine
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/PenteGameEngineTests
  ```
  Expected: `Test Suite 'PenteGameEngineTests' passed` (11 tests).

- [ ] **Step 5: Commit.**

  ```bash
  git add test1/PenteEngine/PenteGame.swift PenteEngineTests/PenteGameEngineTests.swift \
    penteLive.xcodeproj/project.pbxproj
  git commit -m "feat(engine): add stateful @objc PenteGame engine"
  ```

---

### Task 2.6: Corpus assertion — prove the engine reproduces the golden snapshots

**Files**
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/PenteGameCorpusTests.swift`

> **Phase 0 dependency.** Phase 0 froze the golden corpus and the engine-agnostic helper
> `assertEngineMatchesCorpus`. It exposes these identifiers to the `PenteEngineTests` target
> (`PenteEngineTests/CorpusSupport.swift`):
>
> ```swift
> struct CorpusCase: Decodable {                    // one decoded golden JSON file
>     let name: String
>     let variant: String                           // stable name; mapped to PenteVariant here
>     let moves: [Int]
>     let expected: ExpectedSnapshot
> }
> struct ExpectedSnapshot: Decodable, Equatable {   // the golden values loaded from JSON
>     let winner: Int
>     let whiteCaptures: Int
>     let blackCaptures: Int
>     let board: [[Int]]                            // 19x19, row-major
> }
> struct EngineSnapshot: Equatable {                // built here by driving the NEW engine
>     let winner: Int
>     let whiteCaptures: Int
>     let blackCaptures: Int
>     let board: [[Int]]
> }
> enum Corpus { static func loadCases() throws -> [CorpusCase] }
> func assertEngineMatchesCorpus(_ corpusCase: CorpusCase, actual: EngineSnapshot,
>                                file: StaticString = #filePath, line: UInt = #line)
> ```
>
> So this task loads every `CorpusCase` via `Corpus.loadCases()`, maps `case.variant`
> (a stable string) to a `PenteVariant`, drives the new Swift engine to produce an
> `EngineSnapshot`, and calls `assertEngineMatchesCorpus(_:actual:)` per case. The opening
> mask (`-1`) is a render-only overlay the legacy `replayMoves` (the corpus source) never
> wrote, so normalise it back to `0` before comparing.

- [ ] **Step 1: Write the corpus test.** Create `PenteEngineTests/PenteGameCorpusTests.swift`:

  ```swift
  import XCTest
  @testable import penteLive

  final class PenteGameCorpusTests: XCTestCase {

      /// Maps the corpus's stable variant string to the Swift `PenteVariant`. The golden
      /// JSON stores variants as names (decoupled from PenteVariant's integer ordering);
      /// note g-pente is `.gpente` (lowercase).
      private static let variantByName: [String: PenteVariant] = [
          "pente": .pente,
          "keryoPente": .keryoPente,
          "oPente": .oPente,
          "poofPente": .poofPente,
          "dPente": .dPente,
          "dkPente": .dkPente,
          "gpente": .gpente,
          "swap2Pente": .swap2Pente,
          "swap2Keryo": .swap2Keryo,
          "gomoku": .gomoku,
          "connect6": .connect6,
      ]

      func testEngineReproducesGoldenCorpus() throws {
          let cases = try Corpus.loadCases()
          XCTAssertEqual(cases.count, 8, "expected 8 committed golden fixtures")

          for corpusCase in cases {
              let variant = try XCTUnwrap(
                  Self.variantByName[corpusCase.variant],
                  "unmapped corpus variant '\(corpusCase.variant)'")

              // Drive the NEW Swift engine over the recorded move list (frozen engine API).
              let e = PenteGame(variant: variant)
              let result = e.replay(corpusCase.moves, until: corpusCase.moves.count)

              // Read all 361 cells via the frozen `stone(at:)` accessor (row-major).
              let flat = (0...360).map { e.stone(at: $0) }

              // Reshape to the 19x19 board the golden uses. The opening mask (-1) is a
              // render-only overlay the legacy replayMoves (the corpus source) never
              // wrote, so normalise it back to 0 before comparing.
              let board: [[Int]] = (0..<19).map { row in
                  (0..<19).map { col -> Int in
                      let v = flat[row * 19 + col]
                      return v == -1 ? 0 : v
                  }
              }

              let actual = EngineSnapshot(
                  winner: result.winner,
                  whiteCaptures: e.whiteCaptures,
                  blackCaptures: e.blackCaptures,
                  board: board)
              assertEngineMatchesCorpus(corpusCase, actual: actual)
          }
      }
  }
  ```

- [ ] **Step 2: Add the test file and run (expected PASS — proves reproduction).**

  ```bash
  ruby Scripts/add_swift_file.rb PenteEngineTests/PenteGameCorpusTests.swift PenteEngineTests PenteEngineTests
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/PenteGameCorpusTests/testEngineReproducesGoldenCorpus
  ```
  Expected: `Test Suite 'PenteGameCorpusTests' passed` — the new Swift `PenteGame` reproduces
  every golden snapshot (board placements, capture counters, and winner) for all variants.

- [ ] **Step 3: Run the full engine suite to confirm nothing regressed.**

  ```bash
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests
  ```
  Expected: all `PenteEngineTests` suites pass (Phase 0/1 corpus + Scan tests, plus
  `PenteVariantTests`, `MoveResultTests`, `RuleSetTests`, `PenteGameEngineTests`,
  `PenteGameCorpusTests`).

- [ ] **Step 4: Commit.**

  ```bash
  git add PenteEngineTests/PenteGameCorpusTests.swift penteLive.xcodeproj/project.pbxproj
  git commit -m "test(engine): assert new PenteGame reproduces golden corpus"
  ```

---

### Phase 2 done — exit criteria

- `PenteGame` (the legacy ObjC class) is renamed to `LegacyPenteGame`; the Swift `@objc PenteGame`
  owns the name. The app still builds; the 3 legacy callers + 2 `getGameName` callers compile
  against `LegacyPenteGame` (temporary coexistence until caller migration in a later phase).
- New Swift engine files exist under `test1/PenteEngine/`: `PenteVariant.swift`, `MoveResult.swift`,
  `RuleSet.swift`, `PenteGame.swift`, all added to the `penteLive` target.
- Per-variant unit tests + the Phase 0 golden-corpus assertion pass via the canonical
  `xcodebuild test … -only-testing:PenteEngineTests/…` command.
## Phase 3: Cut Table (Swift) over to the engine; delete its duplicate rules

This phase routes the Swift `Table` model (`test1/HelperClasses.swift`) through the stateful
`PenteGame` engine built in Phases 0–2 and deletes `Table`'s forked rule code. After this phase:

- `Table` owns a `private var engine: PenteGame`, rebuilt whenever `game` changes.
- `addMove` for Pente-family games delegates **placement + capture + poof + win + opening mask**
  to `engine.play(_:)` — the hand-rolled placing/`detectCapture`/`detectKeryoCapture`/`detectPoof`/
  `detectKeryoPoof`/inline-mask code is gone from `addMove`.
- `Table.abstractBoard`, `Table.whiteCaptures`, `Table.blackCaptures` are mirrored from the engine
  (`engine.stone(at:)`, `engine.whiteCaptures`, `engine.blackCaptures`) after every Pente-family
  move, so `LiveBoard` and `TableViewController` keep reading them **unchanged**.
- `MoveResult.captured` is wired into a brand-new capture animation in `LiveBoard` (the Swift Table
  UI previously had none).
- `Table.detectCapture` / `detectKeryoCapture` / `detectPoof` / `detectKeryoPoof` are **deleted**.
- `undoLastMove` / `addMoves` for Pente-family games are reimplemented on top of
  `engine.replay(_:until:)`.

**Scope guard — Go is out of scope.** A `Table` is either Go (`isGo()` true, `game` 19–24) or not,
for its whole lifetime. Go has its own group/liberty board logic (`addGoMove`, `captureGroup`,
`makeCaptures`, `setBoardValue`, …) that writes `abstractBoard`/`whiteCaptures`/`blackCaptures`
directly and is **not** part of the Pente engine. Every edit below keeps the `if isGo() { … }`
branch intact and only changes the Pente-family path.

**Opening-mask gating.** The forked `addMove` masked the centre 5×5 (and G-Pente arms) with `-1`
between move 2 and move 3 only when `rated || game == gPente` (and never for d/dk/swap2/gomoku/
connect6). That masking now lives entirely inside `PenteGame.play(_:)`, driven by
`ruleSet(for: variant).opening` (`OpeningMask.tournament` / `.gpente` / `.none`) — see Phases 0–2.
Phase 3 therefore **deletes** the inline mask block and does not reproduce it.

**Test target.** Phase 0 added the XCTest target **`PenteEngineTests`** (app module name `penteLive`,
workspace scheme `test1`). Every test file below is created under `PenteEngineTests/` and is a member
of that target; Phase 0 configured the target to compile every `.swift` under `PenteEngineTests/`.

**Frozen-contract dependencies consumed here (defined in Phases 0–2):**
`PenteGame(variant:)`, `PenteGame.play(_:) -> MoveResult`, `PenteGame.replay(_:until:) -> MoveResult`,
`PenteGame.reset()`, `PenteGame.stone(at:) -> Int`, `PenteGame.whiteCaptures`,
`PenteGame.blackCaptures`, `PenteVariant` (all cases), `MoveResult` (`.captured`, `.poofed`,
`.winner`, `.placed`), `Capture` (`.position`, `.color`, `init(position:color:)`).
Contract assumption relied upon: `replay(_:until:)` resets the engine and advances its internal move
index to `until`, so a subsequent `play(_:)` continues with the correct colour/cadence.

---

### Task 3.1: Give `Table` a `PenteGame` engine and route `addMove` through `engine.play`

Replace `addMove`'s hand-rolled placing + capture + poof + opening-mask with `engine.play(_:)`,
mirror the engine state back into `abstractBoard`/`whiteCaptures`/`blackCaptures`, and expose
`MoveResult.captured` through an `onCaptures` seam so the UI (and tests) can animate captures.

**Files**

- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/HelperClasses.swift`
  - `var game = 1` (line 89)
  - stored-property block after `blackCaptures = 0` (lines 97–99)
  - `addMove(move:)` (lines 248–323)
- Test (create): `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/TableEngineRoutingTests.swift`

- [ ] **Step 1: Write the failing headline test.** Create
  `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/TableEngineRoutingTests.swift`
  with the exact contents:

  ```swift
  //
  //  TableEngineRoutingTests.swift
  //  PenteEngineTests
  //

  import XCTest
  @testable import penteLive

  final class TableEngineRoutingTests: XCTestCase {

      // White plays both flanking stones of a 1-3-1 row; the two black stones between
      // them are captured. Move order alternates white, black, white, black, white.
      //   idx0 white (9,5)=176   idx1 black (9,6)=177   idx2 white (0,0)=0
      //   idx3 black (9,7)=178   idx4 white (9,8)=179  -> captures (9,6),(9,7)
      func testCaptureSequenceDelegatesToEngine() {
          let table = Table(table: 1)
          table.game = GameEnum.pente.rawValue

          var animated: [Capture] = []
          table.onCaptures = { captures in animated = captures }

          for move in [9 * 19 + 5, 9 * 19 + 6, 0, 9 * 19 + 7, 9 * 19 + 8] {
              table.addMove(move: move)
          }

          // Board is the engine's board, read via Table.stone(at:).
          XCTAssertEqual(table.stone(at: 9 * 19 + 5), 1)
          XCTAssertEqual(table.stone(at: 9 * 19 + 8), 1)
          XCTAssertEqual(table.stone(at: 9 * 19 + 6), 0)
          XCTAssertEqual(table.stone(at: 9 * 19 + 7), 0)

          // Counters are the engine's counters (whiteCaptures/blackCaptures count
          // captured stones of that colour: two black stones were captured).
          XCTAssertEqual(table.blackCaptures, 2)
          XCTAssertEqual(table.whiteCaptures, 0)

          // The capture animation seam received exactly the two captured cells.
          XCTAssertEqual(animated.count, 2)
          XCTAssertEqual(Set(animated.map { $0.position }), [9 * 19 + 6, 9 * 19 + 7])
          XCTAssertTrue(animated.allSatisfy { $0.color == 2 })
      }
  }
  ```

- [ ] **Step 2: Run the test, expect FAIL (does not compile).** Run:

  ```
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/TableEngineRoutingTests/testCaptureSequenceDelegatesToEngine
  ```

  Expected: build/compile failure ending in `** TEST FAILED **`, with errors such as
  `value of type 'Table' has no member 'onCaptures'` and `value of type 'Table' has no member 'stone'`.

- [ ] **Step 3: Add the engine field, variant mapping, and mirror accessors.** In
  `test1/HelperClasses.swift`, change `var game = 1` (line 89) to rebuild the engine when the
  game changes:

  ```swift
      var game = 1 {
          didSet {
              if game != oldValue {
                  engine = PenteGame(variant: penteVariant(for: game))
              }
          }
      }
  ```

  Then immediately after the three lines (97–99):

  ```swift
      var abstractBoard = Array(repeating: Array(repeating: 0, count: 19), count: 19)
      var whiteCaptures = 0
      var blackCaptures = 0
  ```

  insert the engine field and the move-result seam:

  ```swift
      private var engine = PenteGame(variant: .pente)
      private(set) var lastMoveResult: MoveResult?
      var onCaptures: (([Capture]) -> Void)?
  ```

- [ ] **Step 4: Add the variant mapping, `stone(at:)`, and `syncFromEngine()` helpers.** In
  `test1/HelperClasses.swift`, directly above `func addMove(move: Int) {` (currently line 248),
  insert:

  ```swift
      // Maps the live-room game id (GameEnum 1...30) to the engine variant.
      // Boat-Pente shares Pente rules; Go ids never reach the engine (isGo() short-circuits).
      private func penteVariant(for game: Int) -> PenteVariant {
          switch GameEnum(rawValue: game) {
          case .keryoPente, .speedKeryoPente: return .keryoPente
          case .oPente, .speedOPente: return .oPente
          case .poofPente, .speedPoofPente: return .poofPente
          case .dPente, .speedDPente: return .dPente
          case .dkPente, .speedDKPente: return .dkPente
          case .gPente, .speedGPente: return .gpente
          case .swap2Pente, .speedSwap2Pente: return .swap2Pente
          case .swap2Keryo, .speedSwap2Keryo: return .swap2Keryo
          case .gomoku, .speedGomoku: return .gomoku
          case .connect6, .speedConnect6: return .connect6
          default: return .pente
          }
      }

      // Read accessor used by tests and renderers: the engine is the source of truth
      // for Pente-family games; Go keeps its own board.
      func stone(at rowCol: Int) -> Int {
          if isGo() {
              return abstractBoard[rowCol / gridSize][rowCol % gridSize]
          }
          return engine.stone(at: rowCol)
      }

      // Mirror the engine board + counters into the stored arrays the renderers read.
      private func syncFromEngine() {
          for r in 0 ..< 19 {
              for c in 0 ..< 19 {
                  abstractBoard[r][c] = engine.stone(at: r * 19 + c)
              }
          }
          whiteCaptures = engine.whiteCaptures
          blackCaptures = engine.blackCaptures
      }
  ```

- [ ] **Step 5: Replace `addMove`'s Pente-family body with `engine.play`.** The current
  `addMove(move:)` (lines 248–323) reads, verbatim:

  ```swift
      func addMove(move: Int) {
          if isGo() {
              addGoMove(move: move)
              return
          }
          let color = currentPlayer()
          moves.append(move)
          let i = move / 19
          let j = move % 19
          abstractBoard[i][j] = color
          if game != GameEnum.gomoku.rawValue, game != GameEnum.speedGomoku.rawValue, game != GameEnum.connect6.rawValue, game != GameEnum.speedConnect6.rawValue {
              if game == GameEnum.poofPente.rawValue || game == GameEnum.speedPoofPente.rawValue || game == GameEnum.oPente.rawValue || game == GameEnum.speedOPente.rawValue {
                  detectPoof(move: move, color: color)
              }
              if game == GameEnum.oPente.rawValue || game == GameEnum.speedOPente.rawValue {
                  detectKeryoPoof(move: move, color: color)
              }
              detectCapture(move: move, color: color)
              if game == GameEnum.keryoPente.rawValue || game == GameEnum.speedKeryoPente.rawValue || game == GameEnum.dkPente.rawValue || game == GameEnum.speedDKPente.rawValue || game == GameEnum.oPente.rawValue || game == GameEnum.speedOPente.rawValue || game == GameEnum.swap2Keryo.rawValue || game == GameEnum.speedSwap2Keryo.rawValue {
                  detectKeryoCapture(move: move, color: color)
              }
          }
          if game != GameEnum.gomoku.rawValue, game != GameEnum.speedGomoku.rawValue, game != GameEnum.connect6.rawValue, game != GameEnum.speedConnect6.rawValue, game != GameEnum.dPente.rawValue, game != GameEnum.speedDPente.rawValue, game != GameEnum.dkPente.rawValue, game != GameEnum.speedDKPente.rawValue,
             game != GameEnum.swap2Pente.rawValue, game != GameEnum.speedSwap2Pente.rawValue, game != GameEnum.swap2Keryo.rawValue, game != GameEnum.speedSwap2Keryo.rawValue, rated || game == GameEnum.gPente.rawValue || game == GameEnum.speedGPente.rawValue
          {
             if moves.count == 2 {
                 for i in 7 ..< 12 {
                     for j in 7 ..< 12 {
                         if abstractBoard[i][j] == 0 {
                             abstractBoard[i][j] = -1
                         }
                     }
                 }
                 if game == GameEnum.gPente.rawValue || game == GameEnum.speedGPente.rawValue {
                     for i in 1 ..< 3 {
                         if abstractBoard[9][11 + i] == 0 {
                             abstractBoard[9][11 + i] = -1
                         }
                         if abstractBoard[9][7 - i] == 0 {
                             abstractBoard[9][7 - i] = -1
                         }
                         if abstractBoard[11 + i][9] == 0 {
                             abstractBoard[11 + i][9] = -1
                         }
                         if abstractBoard[7 - i][9] == 0 {
                             abstractBoard[7 - i][9] = -1
                         }
                     }
                 }
             } else if moves.count == 3 {
                 for i in 7 ..< 12 {
                     for j in 7 ..< 12 {
                         if abstractBoard[i][j] == -1 {
                             abstractBoard[i][j] = 0
                         }
                     }
                 }
                 if game == GameEnum.gPente.rawValue || game == GameEnum.speedGPente.rawValue {
                     for i in 1 ..< 3 {
                         if abstractBoard[9][11 + i] == -1 {
                             abstractBoard[9][11 + i] = 0
                         }
                         if abstractBoard[9][7 - i] == -1 {
                             abstractBoard[9][7 - i] = 0
                         }
                         if abstractBoard[11 + i][9] == -1 {
                             abstractBoard[11 + i][9] = 0
                         }
                         if abstractBoard[7 - i][9] == -1 {
                             abstractBoard[7 - i][9] = 0
                         }
                     }
                 }
             }
          }
      }
  ```

  Replace the **entire** method (lines 248–323) with:

  ```swift
      func addMove(move: Int) {
          if isGo() {
              addGoMove(move: move)
              return
          }
          let result = engine.play(move)
          moves.append(move)
          syncFromEngine()
          lastMoveResult = result
          if !result.captured.isEmpty {
              onCaptures?(result.captured)
          }
      }
  ```

  The colour is now derived by `engine.play` from its internal move index + cadence (alternating
  for Pente-family, Connect6 cadence for Connect6), exactly matching the old `currentPlayer()`
  pre-append value. Placement, captures, poof and the opening mask are all applied inside
  `engine.play`. `detectCapture`/`detectKeryoCapture`/`detectPoof`/`detectKeryoPoof` are now unused
  by `addMove` (they are deleted in Task 3.4).

- [ ] **Step 6: Run the test, expect PASS.** Run:

  ```
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/TableEngineRoutingTests/testCaptureSequenceDelegatesToEngine
  ```

  Expected: `Test Suite 'TableEngineRoutingTests' passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit.** Run:

  ```
  git add test1/HelperClasses.swift PenteEngineTests/TableEngineRoutingTests.swift
  git commit -m "feat(table): route Swift Table.addMove through PenteGame engine"
  ```

---

### Task 3.2: Reimplement `addMoves`, `reset`, and `undoLastMove` on the engine

Make bulk load (`addMoves`), `reset`, and single-move undo (`undoLastMove`) drive the engine via
`engine.replay(_:until:)` / `engine.reset()` for Pente-family games, leaving the Go branch intact.

**Files**

- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/HelperClasses.swift`
  - `addMoves(moves:)` (lines 201–216)
  - `reset()` (lines 375–388)
  - `undoLastMove()` (lines 445–461)
- Test (modify): `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/TableEngineRoutingTests.swift`

- [ ] **Step 1: Write the failing undo test.** Append this method inside
  `final class TableEngineRoutingTests` in
  `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/TableEngineRoutingTests.swift`
  (before the closing `}` of the class):

  ```swift
      func testUndoLastMoveReplaysThroughEngine() {
          let table = Table(table: 1)
          table.game = GameEnum.pente.rawValue

          // Capture sequence, then one extra (non-capturing) black move at idx5.
          for move in [9 * 19 + 5, 9 * 19 + 6, 0, 9 * 19 + 7, 9 * 19 + 8] {
              table.addMove(move: move)
          }
          XCTAssertEqual(table.blackCaptures, 2)

          table.addMove(move: 1) // black at (0,1), no capture
          XCTAssertEqual(table.moves.count, 6)

          table.undoLastMove()

          // Back to the post-capture position, rebuilt by engine.replay.
          XCTAssertEqual(table.moves, [9 * 19 + 5, 9 * 19 + 6, 0, 9 * 19 + 7, 9 * 19 + 8])
          XCTAssertEqual(table.blackCaptures, 2)
          XCTAssertEqual(table.whiteCaptures, 0)
          XCTAssertEqual(table.stone(at: 9 * 19 + 6), 0)
          XCTAssertEqual(table.stone(at: 9 * 19 + 7), 0)
          XCTAssertEqual(table.stone(at: 9 * 19 + 8), 1)
          XCTAssertEqual(table.stone(at: 0), 1)
      }
  ```

- [ ] **Step 2: Run the test, expect FAIL.** Run:

  ```
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/TableEngineRoutingTests/testUndoLastMoveReplaysThroughEngine
  ```

  Expected: `** TEST FAILED **`. `undoLastMove` still replays through the (now engine-backed)
  `addMove` loop and re-fires `onCaptures`, but more importantly the counters/board come from
  rebuilding via the old loop which no longer resets `engine` — the assertions on `blackCaptures`
  and `stone(at:)` fail with mismatched values.

- [ ] **Step 3: Reimplement `addMoves`.** The current `addMoves(moves:)` (lines 201–216) reads:

  ```swift
      func addMoves(moves: [Int]) {
          self.moves.removeAll()
          abstractBoard = Array(repeating: Array(repeating: 0, count: 19), count: 19)
          goStoneGroupIDsByPlayer.removeAll(); goStoneGroupIDsByPlayer[1] = [Int: Int](); goStoneGroupIDsByPlayer[2] = [Int: Int]()
          goStoneGroupsByPlayerAndID.removeAll(); goStoneGroupsByPlayerAndID[1] = [Int: [Int]](); goStoneGroupsByPlayerAndID[2] = [Int: [Int]]()
          goDeadStonesByPlayer.removeAll(); goDeadStonesByPlayer[1] = [Int](); goDeadStonesByPlayer[2] = [Int]()
          goTerritoryByPlayer.removeAll(); goTerritoryByPlayer[1] = [Int](); goTerritoryByPlayer[2] = [Int]()
          //        state.dPenteState = .noChoice
          //        state.swap2State = .noChoice
          state.goState = .play
          blackCaptures = 0
          whiteCaptures = 0
          for move in moves {
              addMove(move: move)
          }
      }
  ```

  Replace it with (Go branch keeps the per-move loop; Pente-family replays in one engine call and
  does **not** fire `onCaptures`, matching the old silent bulk load):

  ```swift
      func addMoves(moves: [Int]) {
          self.moves.removeAll()
          abstractBoard = Array(repeating: Array(repeating: 0, count: 19), count: 19)
          goStoneGroupIDsByPlayer.removeAll(); goStoneGroupIDsByPlayer[1] = [Int: Int](); goStoneGroupIDsByPlayer[2] = [Int: Int]()
          goStoneGroupsByPlayerAndID.removeAll(); goStoneGroupsByPlayerAndID[1] = [Int: [Int]](); goStoneGroupsByPlayerAndID[2] = [Int: [Int]]()
          goDeadStonesByPlayer.removeAll(); goDeadStonesByPlayer[1] = [Int](); goDeadStonesByPlayer[2] = [Int]()
          goTerritoryByPlayer.removeAll(); goTerritoryByPlayer[1] = [Int](); goTerritoryByPlayer[2] = [Int]()
          //        state.dPenteState = .noChoice
          //        state.swap2State = .noChoice
          state.goState = .play
          blackCaptures = 0
          whiteCaptures = 0
          if isGo() {
              for move in moves {
                  addMove(move: move)
              }
              return
          }
          lastMoveResult = engine.replay(moves, until: moves.count)
          self.moves = moves
          syncFromEngine()
      }
  ```

- [ ] **Step 4: Reset the engine in `reset()`.** The current `reset()` (lines 375–388) reads:

  ```swift
      func reset() {
          moves.removeAll()
          resetTimers()
          blackCaptures = 0
          whiteCaptures = 0
          abstractBoard = Array(repeating: Array(repeating: 0, count: 19), count: 19)
          goStoneGroupIDsByPlayer.removeAll(); goStoneGroupIDsByPlayer[1] = [Int: Int](); goStoneGroupIDsByPlayer[2] = [Int: Int]()
          goStoneGroupsByPlayerAndID.removeAll(); goStoneGroupsByPlayerAndID[1] = [Int: [Int]](); goStoneGroupsByPlayerAndID[2] = [Int: [Int]]()
          goDeadStonesByPlayer.removeAll(); goDeadStonesByPlayer[1] = [Int](); goDeadStonesByPlayer[2] = [Int]()
          goTerritoryByPlayer.removeAll(); goTerritoryByPlayer[1] = [Int](); goTerritoryByPlayer[2] = [Int]()
          state.dPenteState = .noChoice
          state.swap2State = .noChoice
          state.goState = .play
      }
  ```

  Add `engine.reset()` and `lastMoveResult = nil` by changing the line:

  ```swift
          abstractBoard = Array(repeating: Array(repeating: 0, count: 19), count: 19)
  ```

  (the one inside `reset()`, line 380) to:

  ```swift
          abstractBoard = Array(repeating: Array(repeating: 0, count: 19), count: 19)
          engine.reset()
          lastMoveResult = nil
  ```

- [ ] **Step 5: Reimplement `undoLastMove`.** The current `undoLastMove()` (lines 445–461) reads:

  ```swift
      func undoLastMove() {
          let newMoves = moves[0 ..< (moves.count - 1)]
          blackCaptures = 0
          whiteCaptures = 0
          abstractBoard = Array(repeating: Array(repeating: 0, count: 19), count: 19)
          moves.removeAll()
          goStoneGroupIDsByPlayer.removeAll(); goStoneGroupIDsByPlayer[1] = [Int: Int](); goStoneGroupIDsByPlayer[2] = [Int: Int]()
          goStoneGroupsByPlayerAndID.removeAll(); goStoneGroupsByPlayerAndID[1] = [Int: [Int]](); goStoneGroupsByPlayerAndID[2] = [Int: [Int]]()
          goDeadStonesByPlayer.removeAll(); goDeadStonesByPlayer[1] = [Int](); goDeadStonesByPlayer[2] = [Int]()
          goTerritoryByPlayer.removeAll(); goTerritoryByPlayer[1] = [Int](); goTerritoryByPlayer[2] = [Int]()
          koMove = -1
          state.dPenteState = .noChoice
          state.goState = .play
          for move in newMoves {
              addMove(move: move)
          }
      }
  ```

  Replace it with (Go branch keeps the per-move replay loop; Pente-family rebuilds in one
  `engine.replay` and does not animate):

  ```swift
      func undoLastMove() {
          let newMoves = Array(moves[0 ..< (moves.count - 1)])
          blackCaptures = 0
          whiteCaptures = 0
          abstractBoard = Array(repeating: Array(repeating: 0, count: 19), count: 19)
          moves.removeAll()
          goStoneGroupIDsByPlayer.removeAll(); goStoneGroupIDsByPlayer[1] = [Int: Int](); goStoneGroupIDsByPlayer[2] = [Int: Int]()
          goStoneGroupsByPlayerAndID.removeAll(); goStoneGroupsByPlayerAndID[1] = [Int: [Int]](); goStoneGroupsByPlayerAndID[2] = [Int: [Int]]()
          goDeadStonesByPlayer.removeAll(); goDeadStonesByPlayer[1] = [Int](); goDeadStonesByPlayer[2] = [Int]()
          goTerritoryByPlayer.removeAll(); goTerritoryByPlayer[1] = [Int](); goTerritoryByPlayer[2] = [Int]()
          koMove = -1
          state.dPenteState = .noChoice
          state.goState = .play
          if isGo() {
              for move in newMoves {
                  addMove(move: move)
              }
              return
          }
          lastMoveResult = engine.replay(newMoves, until: newMoves.count)
          moves = newMoves
          syncFromEngine()
      }
  ```

- [ ] **Step 6: Run both Table tests, expect PASS.** Run:

  ```
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/TableEngineRoutingTests
  ```

  Expected: `Test Suite 'TableEngineRoutingTests' passed` (2 tests) and `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit.** Run:

  ```
  git add test1/HelperClasses.swift PenteEngineTests/TableEngineRoutingTests.swift
  git commit -m "refactor(table): rebuild addMoves/reset/undo via PenteGame.replay"
  ```

---

### Task 3.3: Add capture animation to `LiveBoard` and wire it from `TableViewController`

The Swift Table UI never animated captures. Add `LiveBoard.animateCaptures(_:)` (a transient
overlay stone per captured cell that fades and shrinks), and feed it from
`Table.onCaptures` set in `TableViewController`.

**Files**

- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/LiveBoard.swift`
  - after `clearGoStructures()` (ends line 50)
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/TableViewController.swift`
  - designated `init` (after line 59)
- Test (create): `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/LiveBoardCaptureAnimationTests.swift`

- [ ] **Step 1: Write the failing animation test.** Create
  `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/LiveBoardCaptureAnimationTests.swift`:

  ```swift
  //
  //  LiveBoardCaptureAnimationTests.swift
  //  PenteEngineTests
  //

  import XCTest
  @testable import penteLive

  final class LiveBoardCaptureAnimationTests: XCTestCase {

      func testAnimateCapturesAddsOneTransientStonePerCapturedCell() {
          let table = Table(table: 1)
          table.game = GameEnum.pente.rawValue
          let board = LiveBoard(table: table)
          board.frame = CGRect(x: 0, y: 0, width: 380, height: 380)

          XCTAssertEqual(board.subviews.count, 0)

          board.animateCaptures([
              Capture(position: 9 * 19 + 6, color: 2),
              Capture(position: 9 * 19 + 7, color: 2),
          ])

          // The overlay stones are added synchronously, before the fade completes.
          XCTAssertEqual(board.subviews.count, 2)
      }

      func testAnimateCapturesIgnoresEmptyInput() {
          let table = Table(table: 1)
          table.game = GameEnum.pente.rawValue
          let board = LiveBoard(table: table)
          board.frame = CGRect(x: 0, y: 0, width: 380, height: 380)

          board.animateCaptures([])

          XCTAssertEqual(board.subviews.count, 0)
      }
  }
  ```

- [ ] **Step 2: Run the test, expect FAIL (does not compile).** Run:

  ```
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/LiveBoardCaptureAnimationTests
  ```

  Expected: `** TEST FAILED **` with `value of type 'LiveBoard' has no member 'animateCaptures'`.

- [ ] **Step 3: Implement `LiveBoard.animateCaptures(_:)`.** In `test1/LiveBoard.swift`, the
  method `clearGoStructures()` ends at line 50:

  ```swift
      func clearGoStructures() {
          goTerritory = nil
          goDeadStones = nil
      }
  ```

  Immediately after it, insert:

  ```swift
      // Briefly overlays each captured stone at its cell, then fades + shrinks it away.
      // Cell geometry matches draw(_:): a stone at (i, j) occupies a 2*margin square at
      // (j*2*margin, i*2*margin), with margin = bounds.width / (2 * gridSize).
      func animateCaptures(_ captures: [Capture]) {
          guard !captures.isEmpty, bounds.size.width > 0 else { return }
          let margin = bounds.size.width / (2 * CGFloat(gridSize))
          for capture in captures {
              let i = capture.position / 19
              let j = capture.position % 19
              let frame = CGRect(x: CGFloat(j) * 2 * margin,
                                 y: CGFloat(i) * 2 * margin,
                                 width: 2 * margin,
                                 height: 2 * margin)
              let overlay = UIView(frame: frame)
              overlay.layer.cornerRadius = margin
              overlay.backgroundColor = (capture.color == StoneColor.white.rawValue)
                  ? UIColor.white : UIColor.black
              overlay.isUserInteractionEnabled = false
              addSubview(overlay)
              UIView.animate(withDuration: 0.4, animations: {
                  overlay.alpha = 0
                  overlay.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
              }, completion: { _ in
                  overlay.removeFromSuperview()
              })
          }
      }
  ```

- [ ] **Step 4: Run the animation test, expect PASS.** Run:

  ```
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/LiveBoardCaptureAnimationTests
  ```

  Expected: `Test Suite 'LiveBoardCaptureAnimationTests' passed` (2 tests) and `** TEST SUCCEEDED **`.

- [ ] **Step 5: Wire `Table.onCaptures` to the boards in `TableViewController`.** In
  `test1/TableViewController.swift`, the designated `init` creates the boards at lines 58–59:

  ```swift
          board = LiveBoard(table: table)
          zoomedBoard = LiveBoard(table: table)
  ```

  Change that to also install the capture-animation hook:

  ```swift
          board = LiveBoard(table: table)
          zoomedBoard = LiveBoard(table: table)
          table.onCaptures = { [weak board, weak zoomedBoard] captures in
              board?.animateCaptures(captures)
              zoomedBoard?.animateCaptures(captures)
          }
  ```

  `board`/`zoomedBoard` are `let` instance properties already assigned on the lines above, so they
  can be captured weakly here; `addMove` (Task 3.1) calls `onCaptures` after each engine move with a
  non-empty capture set, and the synced `abstractBoard` no longer shows the captured stones, so the
  transient overlays provide the only visual of the capture.

- [ ] **Step 6: Run the full Phase-3 test set, expect PASS.** Run:

  ```
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/TableEngineRoutingTests \
    -only-testing:PenteEngineTests/LiveBoardCaptureAnimationTests
  ```

  Expected: both suites pass and `** TEST SUCCEEDED **`.

- [ ] **Step 7: Commit.** Run:

  ```
  git add test1/LiveBoard.swift test1/TableViewController.swift PenteEngineTests/LiveBoardCaptureAnimationTests.swift
  git commit -m "feat(table): animate engine captures in LiveBoard"
  ```

---

### Task 3.4: Delete `Table`'s forked rule methods

With `addMove`/`addMoves`/`undoLastMove` fully routed through the engine, the four detection
methods on `Table` are dead code. Delete them.

**Files**

- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/HelperClasses.swift`
  - delete `detectCapture(move:color:)` (lines 937–1046)
  - delete `detectKeryoCapture(move:color:)` (lines 1048–1165)
  - delete `detectPoof(move:color:)` (lines 1167–1293)
  - delete `detectKeryoPoof(move:color:)` (lines 1295–1491)

- [ ] **Step 1: Confirm there are no remaining callers.** Run:

  ```
  grep -rn "detectCapture\|detectKeryoCapture\|detectPoof\|detectKeryoPoof" test1/*.swift
  ```

  Expected output: only the four `func detect…` declaration lines in
  `test1/HelperClasses.swift` (no call sites). If anything else appears, stop — a caller was
  missed in Tasks 3.1–3.2.

- [ ] **Step 2: Delete the four methods.** In `test1/HelperClasses.swift`, delete the four
  contiguous method bodies:
  - `func detectCapture(move: Int, color: Int) { … }` (lines 937–1046)
  - `func detectKeryoCapture(move: Int, color: Int) { … }` (lines 1048–1165)
  - `func detectPoof(move: Int, color: Int) { … }` (lines 1167–1293)
  - `func detectKeryoPoof(move: Int, color: Int) { … }` (lines 1295–1491)

  These four methods are adjacent (separated only by blank lines) and end just before the class's
  closing brace at line 1492; delete from the start of `func detectCapture` through the end of
  `func detectKeryoPoof`, leaving the class's closing `}` intact.

- [ ] **Step 3: Verify the methods are gone.** Run:

  ```
  grep -rn "func detectCapture\|func detectKeryoCapture\|func detectPoof\|func detectKeryoPoof" test1/HelperClasses.swift
  ```

  Expected output: no matches (empty).

- [ ] **Step 4: Run the whole Phase-3 test set, expect PASS.** Run:

  ```
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/TableEngineRoutingTests \
    -only-testing:PenteEngineTests/LiveBoardCaptureAnimationTests
  ```

  Expected: both suites pass, `** TEST SUCCEEDED **` (proves the app target still compiles after the
  deletion and behaviour is unchanged).

- [ ] **Step 5: Commit.** Run:

  ```
  git add test1/HelperClasses.swift
  git commit -m "refactor(table): delete forked capture/poof detection from Table"
  ```
## Phase 4: Cut BoardViewController (ObjC) over; delete replay*Game + aliased global

Route the Objective-C `BoardViewController` through the stateful Swift engine via the
generated `penteLive-Swift.h`, collapse the twelve per-variant `replay*Game` methods into a
single `[engine replay:until:]` call, move the per-variant board colour into a data map,
render the board from `[engine stoneAt:]`, and drive the capture-count labels + win banner
from the engine / `MoveResult`. By the end of this phase the file-global
`int abstractBoard[19][19]` and the old-engine pointer aliasing are gone.

### Name-collision handling (READ THIS FIRST)

There are **two** classes spelled `PenteGame` in this codebase:

1. The legacy Objective-C class in `test1/PenteGame.h` / `PenteGame.m` (the `penteGame` global
   in `BoardViewController.m`, exposes `abstractBoard`, `replayMoves:variant:untilMove:`,
   `detectCaptureOfOpponent:atPosition:`, …). It is **retained in this phase** solely for the
   interactive tentative-placement capture preview (`detect*` seam at lines 3679-3707) and is
   slated for deletion in Phase 5.
2. The new Swift engine `@objc final class PenteGame` from the frozen contract. Because the
   legacy ObjC class already owns the Objective-C runtime name `PenteGame`, **Phase 2 exposed
   the Swift engine to Objective-C under the bridged name `SwiftPenteGame`** (i.e.
   `@objc(SwiftPenteGame) final class PenteGame`). Throughout this phase the Swift engine is
   referred to from Objective-C **only** as `SwiftPenteGame`, and the new instance ivar is
   named `engine`. The `@objc enum PenteVariant` surfaces in Objective-C as `PenteVariantPente`,
   `PenteVariantKeryoPente`, … `PenteVariantConnect6`. `MoveResult` and `Capture` are the
   `@objc` classes from the contract.

### Scope boundaries (non-goals for Phase 4)

- The interactive tentative-placement capture animation (`self.captures` array fed by the
  legacy `detect*` seam, lines 1158-1184 / 747-1056) keeps using the legacy ObjC `PenteGame`.
  `MoveResult.captured` is available for that migration but it is **deferred to Phase 5**, which
  also deletes `PenteGame.h/.m`, `syncCapturesToEngine`, `syncCapturesFromEngine`, and the
  `detect*` delegations.
- The Go path (`isGoGame`, `replayGoGame:`, `abstractGoBoard`) is **not** a `PenteVariant` and
  stays on its legacy implementation; only its board buffer migrates with the ivar change.
- Opening-mask *application* (tournament / G-Pente / swap2 restrictions, formerly the
  `maskTournamentOpening` / `maskGPenteOpening` calls inside the replay methods) is owned by the
  Swift engine per the frozen `RuleSet.opening` contract (Phases 1-2). This phase deletes those
  per-method calls and relies on the engine; legality of masked cells is read back through
  `[engine stoneAt:] == -1`. A manual verification item covers rated vs. unrated openings.

The XCTest target name frozen by Phase 0 and reused here is **`PenteEngineTests`**. The app
module is **`penteLive`** (`PRODUCT_NAME = penteLive`), so tests use `@testable import penteLive`.

---

### Task 4.1: Swift variant-from-gameType mapping (replaces the `replayGame:` if-chain)

Faithfully reproduce the precedence of the dispatch in `replayGame:` (`BoardViewController.m`
lines 2478-2519) as one pure, `@objc`-exposed function. The Go branch is excluded (callers test
`isGoGame` first).

**Files**
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/BoardVariantMapping.swift`
- Create (test): `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/BoardVariantMappingTests.swift`

- [ ] **Step 1: Write the failing test for variant derivation.**
  Create `BoardVariantMappingTests.swift`:
  ```swift
  import XCTest
  @testable import penteLive

  final class BoardVariantMappingTests: XCTestCase {
      func testVariantForGameType() {
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Pente"), .pente)
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Boat-Pente"), .pente)
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Speed Pente"), .pente)
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Speed Boat-Pente"), .pente)
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Keryo-Pente"), .keryoPente)
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Speed Keryo-Pente"), .keryoPente)
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "G-Pente"), .gpente)
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "D-Pente"), .dPente)
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "DK-Pente"), .dkPente)
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Speed DK-Pente"), .dkPente)
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Poof-Pente"), .poofPente)
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "O-Pente"), .oPente)
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Swap2-Pente"), .swap2Pente)
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Swap2-Keryo"), .swap2Keryo)
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Connect6"), .connect6)
          XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Gomoku"), .gomoku)
      }
  }
  ```
  Add `BoardVariantMapping.swift` to the **penteLive** app target and
  `BoardVariantMappingTests.swift` to the **PenteEngineTests** target in
  `penteLive.xcodeproj/project.pbxproj` (same membership pattern Phase 0/1 used for the engine
  files: a `PBXBuildFile` + `PBXFileReference` entry, the file added to the target's
  `PBXSourcesBuildPhase`).

- [ ] **Step 2: Run the test, expect a COMPILE failure (symbol not found).**
  ```
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/BoardVariantMappingTests/testVariantForGameType
  ```
  Expected: `** TEST FAILED **` with `cannot find 'BoardVariantMapping' in scope`.

- [ ] **Step 3: Implement `variant(forGameType:)`.**
  Create `BoardVariantMapping.swift`. The order below is the exact precedence of the legacy
  `replayGame:` chain (Pente exact-match first, then the `containsString` tests in source order;
  Go is handled by the caller). `"D-Pente"` is tested before `"DK-Pente"` exactly as in source —
  no game-type string matches both, so the early `return` is equivalent to the legacy
  non-`else` / last-write-wins behaviour.
  ```swift
  import Foundation
  import UIKit

  @objc final class BoardVariantMapping: NSObject {

      /// Mirrors the dispatch in BoardViewController `replayGame:` (lines 2478-2519).
      /// Callers must test `isGoGame` first; Go is not a PenteVariant.
      @objc(variantForGameType:)
      static func variant(forGameType gameType: String) -> PenteVariant {
          if gameType == "Pente" || gameType == "Boat-Pente" ||
             gameType == "Speed Pente" || gameType == "Speed Boat-Pente" {
              return .pente
          }
          if gameType.contains("Keryo-Pente") { return .keryoPente }
          if gameType.contains("G-Pente") { return .gpente }
          if gameType.contains("D-Pente") { return .dPente }
          if gameType.contains("DK-Pente") { return .dkPente }
          if gameType.contains("Poof-Pente") { return .poofPente }
          if gameType.contains("O-Pente") { return .oPente }
          if gameType.contains("Swap2-Pente") { return .swap2Pente }
          if gameType.contains("Swap2-Keryo") { return .swap2Keryo }
          if gameType.contains("Connect6") { return .connect6 }
          if gameType.contains("Gomoku") { return .gomoku }
          return .pente
      }
  }
  ```

- [ ] **Step 4: Run the test, expect PASS.**
  ```
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/BoardVariantMappingTests/testVariantForGameType
  ```
  Expected: `Test Suite 'BoardVariantMappingTests' passed` / `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit.**
  ```
  git add test1/BoardVariantMapping.swift PenteEngineTests/BoardVariantMappingTests.swift penteLive.xcodeproj/project.pbxproj
  git commit -m "feat(ios): add BoardVariantMapping.variant(forGameType:)"
  ```

---

### Task 4.2: Background-colour data map (replaces per-method `setBackgroundColor` literals)

Move every per-variant board colour literal out of the replay methods into one data map.
Values are copied verbatim from `BoardViewController.m`:
Pente `0.984,0.851,0.541` / Boat-Pente `0.145,0.729,1` (lines 2700-2716); Keryo `0.702,1,0.518`
(2768-2775); O-Pente `0.32,0.75,0.50` (2797-2804); DK-Pente `1,165/255,0` (2825-2832); Gomoku
`0.612,1,0.898` (2856-2863); Connect6 `0.929,0.639,0.992` (2882-2889); D-Pente `0.584,0.753,0.98`
(2926-2933); Swap2-Pente `0.90,0.67,0.44` (2963-2970); Swap2-Keryo `0.31,0.78,0.47` (3000-3007);
Poof-Pente `0.929,0.639,0.992` (3037-3044); G-Pente `0.616,0.545,0.965` (2738-2745).

**Files**
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/BoardVariantMapping.swift`
- Modify (test): `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/BoardVariantMappingTests.swift`

- [ ] **Step 1: Write the failing test.** Append to `BoardVariantMappingTests.swift`:
  ```swift
  extension BoardVariantMappingTests {
      private func rgba(_ c: UIColor) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
          var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
          c.getRed(&r, green: &g, blue: &b, alpha: &a)
          return (r, g, b, a)
      }
      private func assertColor(_ got: UIColor,
                               _ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat,
                               file: StaticString = #filePath, line: UInt = #line) {
          let c = rgba(got)
          XCTAssertEqual(c.0, r, accuracy: 0.001, file: file, line: line)
          XCTAssertEqual(c.1, g, accuracy: 0.001, file: file, line: line)
          XCTAssertEqual(c.2, b, accuracy: 0.001, file: file, line: line)
          XCTAssertEqual(c.3, a, accuracy: 0.001, file: file, line: line)
      }

      func testBackgroundColors() {
          assertColor(BoardVariantMapping.backgroundColor(for: .pente, boatPente: false),
                      0.984, 0.851, 0.541, 1)
          assertColor(BoardVariantMapping.backgroundColor(for: .pente, boatPente: true),
                      0.145, 0.729, 1, 1)
          assertColor(BoardVariantMapping.backgroundColor(for: .keryoPente, boatPente: false),
                      0.702, 1, 0.518, 1)
          assertColor(BoardVariantMapping.backgroundColor(for: .oPente, boatPente: false),
                      0.32, 0.75, 0.50, 1)
          assertColor(BoardVariantMapping.backgroundColor(for: .poofPente, boatPente: false),
                      0.929, 0.639, 0.992, 1)
          assertColor(BoardVariantMapping.backgroundColor(for: .dPente, boatPente: false),
                      0.584, 0.753, 0.98, 1)
          assertColor(BoardVariantMapping.backgroundColor(for: .dkPente, boatPente: false),
                      1, 165.0 / 255.0, 0, 1)
          assertColor(BoardVariantMapping.backgroundColor(for: .gpente, boatPente: false),
                      0.616, 0.545, 0.965, 1)
          assertColor(BoardVariantMapping.backgroundColor(for: .swap2Pente, boatPente: false),
                      0.90, 0.67, 0.44, 1)
          assertColor(BoardVariantMapping.backgroundColor(for: .swap2Keryo, boatPente: false),
                      0.31, 0.78, 0.47, 1)
          assertColor(BoardVariantMapping.backgroundColor(for: .gomoku, boatPente: false),
                      0.612, 1, 0.898, 1)
          assertColor(BoardVariantMapping.backgroundColor(for: .connect6, boatPente: false),
                      0.929, 0.639, 0.992, 1)
      }
  }
  ```

- [ ] **Step 2: Run, expect FAIL (no member `backgroundColor`).**
  ```
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/BoardVariantMappingTests/testBackgroundColors
  ```
  Expected: `** TEST FAILED **` (`type 'BoardVariantMapping' has no member 'backgroundColor'`).

- [ ] **Step 3: Implement the map.** Add inside `BoardVariantMapping`:
  ```swift
      /// One source of truth for the per-variant board colour; values copied verbatim
      /// from the former per-replay-method literals in BoardViewController.m.
      @objc(backgroundColorForVariant:boatPente:)
      static func backgroundColor(for variant: PenteVariant, boatPente: Bool) -> UIColor {
          switch variant {
          case .pente:
              return boatPente
                  ? UIColor(red: 0.145, green: 0.729, blue: 1, alpha: 1)
                  : UIColor(red: 0.984, green: 0.851, blue: 0.541, alpha: 1)
          case .keryoPente:
              return UIColor(red: 0.702, green: 1, blue: 0.518, alpha: 1)
          case .oPente:
              return UIColor(red: 0.32, green: 0.75, blue: 0.50, alpha: 1.0)
          case .poofPente:
              return UIColor(red: 0.929, green: 0.639, blue: 0.992, alpha: 1)
          case .dPente:
              return UIColor(red: 0.584, green: 0.753, blue: 0.98, alpha: 1)
          case .dkPente:
              return UIColor(red: 1, green: 165.0 / 255.0, blue: 0, alpha: 1)
          case .gpente:
              return UIColor(red: 0.616, green: 0.545, blue: 0.965, alpha: 1)
          case .swap2Pente:
              return UIColor(red: 0.90, green: 0.67, blue: 0.44, alpha: 1.00)
          case .swap2Keryo:
              return UIColor(red: 0.31, green: 0.78, blue: 0.47, alpha: 1.00)
          case .gomoku:
              return UIColor(red: 0.612, green: 1, blue: 0.898, alpha: 1)
          case .connect6:
              return UIColor(red: 0.929, green: 0.639, blue: 0.992, alpha: 1)
          }
      }
  ```

- [ ] **Step 4: Run, expect PASS.**
  ```
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/BoardVariantMappingTests/testBackgroundColors
  ```
  Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit.**
  ```
  git add test1/BoardVariantMapping.swift PenteEngineTests/BoardVariantMappingTests.swift
  git commit -m "feat(ios): add per-variant board background-colour map"
  ```

---

### Task 4.3: Capture-label visibility map (replaces scattered `setHidden:YES` blocks)

Gomoku and Connect6 always hide the capture labels (lines 2864-2867, 2890-2893). D-Pente,
DK-Pente, Swap2-Pente and Swap2-Keryo hide them only during the opening — and note that all four
test the **`dPenteOpening`** flag in source (lines 2935-2940, 2834-2839, 2972-2977, 3009-3014),
so the helper takes a single `opening` argument that the caller wires to `dPenteOpening`.

**Files**
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/BoardVariantMapping.swift`
- Modify (test): `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/BoardVariantMappingTests.swift`

- [ ] **Step 1: Write the failing test.** Append to `BoardVariantMappingTests.swift`:
  ```swift
  extension BoardVariantMappingTests {
      func testHidesCaptureLabels() {
          XCTAssertTrue(BoardVariantMapping.hidesCaptureLabels(for: .gomoku, opening: false))
          XCTAssertTrue(BoardVariantMapping.hidesCaptureLabels(for: .connect6, opening: false))
          XCTAssertFalse(BoardVariantMapping.hidesCaptureLabels(for: .pente, opening: false))
          XCTAssertFalse(BoardVariantMapping.hidesCaptureLabels(for: .keryoPente, opening: true))
          XCTAssertTrue(BoardVariantMapping.hidesCaptureLabels(for: .dPente, opening: true))
          XCTAssertFalse(BoardVariantMapping.hidesCaptureLabels(for: .dPente, opening: false))
          XCTAssertTrue(BoardVariantMapping.hidesCaptureLabels(for: .dkPente, opening: true))
          XCTAssertTrue(BoardVariantMapping.hidesCaptureLabels(for: .swap2Pente, opening: true))
          XCTAssertFalse(BoardVariantMapping.hidesCaptureLabels(for: .swap2Pente, opening: false))
          XCTAssertTrue(BoardVariantMapping.hidesCaptureLabels(for: .swap2Keryo, opening: true))
      }
  }
  ```

- [ ] **Step 2: Run, expect FAIL.**
  ```
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/BoardVariantMappingTests/testHidesCaptureLabels
  ```
  Expected: `** TEST FAILED **` (`no member 'hidesCaptureLabels'`).

- [ ] **Step 3: Implement.** Add inside `BoardVariantMapping`:
  ```swift
      /// Gomoku/Connect6 never show capture counts; D/DK/Swap2 hide them during the opening.
      /// The four opening-gated variants all keyed off the `dPenteOpening` flag in the
      /// legacy code, so the caller passes `dPenteOpening` for `opening`.
      @objc(hidesCaptureLabelsForVariant:opening:)
      static func hidesCaptureLabels(for variant: PenteVariant, opening: Bool) -> Bool {
          switch variant {
          case .gomoku, .connect6:
              return true
          case .dPente, .dkPente, .swap2Pente, .swap2Keryo:
              return opening
          default:
              return false
          }
      }
  ```

- [ ] **Step 4: Run, expect PASS.**
  ```
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/BoardVariantMappingTests/testHidesCaptureLabels
  ```
  Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit.**
  ```
  git add test1/BoardVariantMapping.swift PenteEngineTests/BoardVariantMappingTests.swift
  git commit -m "feat(ios): add per-variant capture-label visibility rule"
  ```

---

### Task 4.4: Wire the Swift engine in, demote the global to an ivar, drop the old-engine alias

Introduce the `SwiftPenteGame *engine` instance, move the file-global
`int abstractBoard[19][19]` into an instance ivar (every existing `abstractBoard[i][j]` access is
inside an instance method, so the references compile unchanged — verified: no access occurs
inside a block), delete the `penteGame.abstractBoard = abstractBoard` aliasing from
`viewDidLoad`, point `resetBoard` at the new engine, add the two render helpers, and re-establish
the legacy engine's board pointer inside the retained `syncCapturesToEngine` seam (used only by
the interactive `detect*` preview). No behaviour changes yet — this task only adds the engine and
relocates the buffer; `replayGame:` is rewritten in Task 4.5.

**Files**
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/BoardViewController.h` (ivar block, ~line 22)
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/BoardViewController.m` (lines 78, 114-115, 2453-2467, 3717-3720)

- [ ] **Step 1: Declare the new ivars in `BoardViewController.h`.**
  Inside the `@interface BoardViewController … { … }` ivar block (next to
  `NSMutableArray *movesList, *captures, *receivedMessages;` at line 22) add:
  ```objc
      SwiftPenteGame *engine;
      int abstractBoard[19][19];
      int lastReplayWinner;
  ```
  Ensure `BoardViewController.m` can see `SwiftPenteGame` — it already imports
  `"penteLive-Swift.h"` (line 29). If `BoardViewController.h` itself needs the type, forward
  declare with `@class SwiftPenteGame;` near the top.

- [ ] **Step 2: Delete the file-global declaration.**
  In `BoardViewController.m` delete the line (78):
  ```objc
  int abstractBoard[19][19];
  ```
  (`int abstractGoBoard[19][19];` on line 79 stays — Go is out of scope.)

- [ ] **Step 3: Build, expect a deliberate FAIL at line 115 (alias targets a now-typed ivar but old engine still owns it).**
  ```
  xcodebuild build -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16'
  ```
  This compiles (ivar `abstractBoard` resolves the 51 in-method references), but proceed to wire
  the engine before the first run. If the build fails on `SwiftPenteGame` being unknown, confirm
  Phase 2's `@objc(SwiftPenteGame)` annotation shipped in `penteLive-Swift.h`.

- [ ] **Step 4: Create the engine and remove the old-engine alias in `viewDidLoad`.**
  Replace (lines 114-115):
  ```objc
      penteGame = [[PenteGame alloc] init];
      penteGame.abstractBoard = abstractBoard;
  ```
  with:
  ```objc
      penteGame = [[PenteGame alloc] init];
      engine = [[SwiftPenteGame alloc] initWithVariant:PenteVariantPente];
      lastReplayWinner = 0;
  ```
  The legacy `penteGame` is kept for the interactive `detect*` preview only (Phase 5 removes it);
  its board pointer is now (re)set lazily in `syncCapturesToEngine` (Step 6) instead of being
  aliased here.

- [ ] **Step 5: Point `resetBoard` at the new engine.**
  Replace (lines 3717-3720):
  ```objc
  - (void)resetBoard {
      finalMove = -1;
      [penteGame resetBoard];
  }
  ```
  with:
  ```objc
  - (void)resetBoard {
      finalMove = -1;
      [engine reset];
  }
  ```

- [ ] **Step 6: Re-point the legacy engine inside `syncCapturesToEngine`; add render helpers.**
  Replace (lines 2453-2457):
  ```objc
  - (void)syncCapturesToEngine {
      penteGame.captures = captures;
      penteGame.whiteCaptures = whiteCaptures;
      penteGame.blackCaptures = blackCaptures;
  }
  ```
  with:
  ```objc
  - (void)syncCapturesToEngine {
      // Legacy ObjC PenteGame drives the interactive tentative-placement capture
      // preview only; point it at the controller's abstractBoard ivar here (the
      // viewDidLoad alias was removed in this phase). Removed entirely in Phase 5.
      penteGame.abstractBoard = abstractBoard;
      penteGame.captures = captures;
      penteGame.whiteCaptures = whiteCaptures;
      penteGame.blackCaptures = blackCaptures;
  }

  // Fills the abstractBoard ivar from the Swift engine (the render seam, scope (c)).
  - (void)loadEngineIntoAbstractBoard {
      for (int rc = 0; rc < gridSize * gridSize; ++rc) {
          abstractBoard[rc / gridSize][rc % gridSize] = (int)[engine stoneAt:rc];
      }
  }

  // Parses the full move list into rowCol ints for SwiftPenteGame replay:until:.
  - (NSArray<NSNumber *> *)parsedMoves {
      NSMutableArray<NSNumber *> *parsed =
          [NSMutableArray arrayWithCapacity:[movesList count]];
      for (NSString *m in movesList) {
          [parsed addObject:@([self parseMove:m])];
      }
      return parsed;
  }
  ```
  Delete the now-unused `replayWithEngine:untilMove:` (lines 2464-2468):
  ```objc
  - (void)replayWithEngine:(PenteGameVariant)variant untilMove:(int)untilMove {
      [self syncCapturesToEngine];
      [penteGame replayMoves:movesList variant:variant untilMove:untilMove];
      [self syncCapturesFromEngine];
  }
  ```

- [ ] **Step 7: Build, expect PASS (replay methods still reference `replayWithEngine`? — defer).**
  The twelve `replay*Game:` methods still call the deleted `replayWithEngine:`. To keep this
  commit compiling, delete those methods in the SAME commit only if Task 4.5 lands together;
  otherwise temporarily leave `replayWithEngine:` in place and delete it at the end of Task 4.5.
  Recommended: fold Steps 6-7 here into the start of Task 4.5 so the tree always builds. Run:
  ```
  xcodebuild build -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16'
  ```
  Expected once Task 4.5 deletions are in: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Commit (combined with 4.5 deletions).**
  ```
  git add test1/BoardViewController.h test1/BoardViewController.m
  git commit -m "refactor(ios): add SwiftPenteGame engine, demote abstractBoard to ivar, drop old-engine alias"
  ```

---

### Task 4.5: Collapse the twelve `replay*Game` methods into one engine-driven `replayGame:`

Rewrite the variant-dispatch body of `replayGame:` to call `[engine replay:until:]` once, set the
background colour from the data map, the capture counts from the engine, the capture-label
visibility from the rule, and the Connect6 penultimate highlight from the move list; delete all
twelve `replay*Game:` definitions; and convert both call sites — the `replayGame:` dispatcher
(lines 2477-2521) and the network-receive block (lines 1779-1917) — to the unified path.

**Files**
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/BoardViewController.m`
  (dispatch 2477-2521; receive block 1779-1917; method defs 2689-3054 except `replayGoGame:`)

- [ ] **Step 1: Replace the dispatch body of `replayGame:`.**
  BEFORE (lines 2477-2521):
  ```objc
      [self resetBoard];
      if ([[self.game gameType] isEqualToString:@"Pente"] ||
          [[self.game gameType] isEqualToString:@"Boat-Pente"] ||
          [[self.game gameType] isEqualToString:@"Speed Pente"] ||
          [[self.game gameType] isEqualToString:@"Speed Boat-Pente"]) {
          [self replayPenteGame:untilMove];
      }
      if ([[self.game gameType] containsString:@"Keryo-Pente"]) {
          [self replayKeryoPenteGame:untilMove];
      }
      if ([[self.game gameType] containsString:@"G-Pente"]) {
          [self replayGPenteGame:untilMove];
      }
      if ([[self.game gameType] containsString:@"D-Pente"]) {
          [self replayDPenteGame:untilMove];
      }
      if ([[self.game gameType] containsString:@"DK-Pente"]) {
          [self replayDKPenteGame:untilMove];
      }
      if ([[self.game gameType] containsString:@"Poof-Pente"]) {
          [self replayPoofPenteGame:untilMove];
      }
      if ([[self.game gameType] containsString:@"O-Pente"]) {
          [self replayOPenteGame:untilMove];
      }
      if ([[self.game gameType] containsString:@"Swap2-Pente"]) {
          [self replaySwap2PenteGame:untilMove];
      }
      if ([[self.game gameType] containsString:@"Swap2-Keryo"]) {
          [self replaySwap2KeryoGame:untilMove];
      }

      if (isGoGame) {
          [self replayGoGame:untilMove];
      }

      [self updateCaptures];

      if ([[self.game gameType] containsString:@"Connect6"]) {
          [self replayConnect6Game:untilMove];
      }
      if ([[self.game gameType] containsString:@"Gomoku"]) {
          [self replayGomokuGame:untilMove];
      }
  ```
  AFTER:
  ```objc
      [self resetBoard];

      if (isGoGame) {
          lastReplayWinner = 0;
          [self replayGoGame:untilMove];
          [self updateCaptures];
      } else {
          PenteVariant variant =
              [BoardVariantMapping variantForGameType:[self.game gameType]];

          // Opening flags — preserved verbatim from the deleted per-variant methods.
          if (variant == PenteVariantDPente || variant == PenteVariantDKPente) {
              dPenteOpening = ([movesList count] == 0);
          } else if (variant == PenteVariantSwap2Pente ||
                     variant == PenteVariantSwap2Keryo) {
              swap2Opening = ([movesList count] == 0 ||
                              ([movesList count] == 3 && swap2Pass));
          }

          MoveResult *result = [engine replay:[self parsedMoves] until:untilMove];
          lastReplayWinner = (int)result.winner;
          whiteCaptures = (int)engine.whiteCaptures;
          blackCaptures = (int)engine.blackCaptures;
          [captures removeAllObjects];

          BOOL boat = [[self.game gameType] isEqualToString:@"Boat-Pente"];
          UIColor *bg = [BoardVariantMapping backgroundColorForVariant:variant
                                                             boatPente:boat];
          [board setBackgroundColor:bg];
          [zoomedBoard setBackgroundColor:bg];

          [self loadEngineIntoAbstractBoard];
          [board setAbstractBoard:abstractBoard];

          [self updateCaptures];
          if ([BoardVariantMapping hidesCaptureLabelsForVariant:variant
                                                        opening:dPenteOpening]) {
              [whiteStoneCaptures setHidden:YES];
              [whiteCapturesCountLabel setHidden:YES];
              [blackStoneCaptures setHidden:YES];
              [blackCapturesCountLabel setHidden:YES];
          }

          BOOL atLatest = (lastMove == [movesList count]);
          BOOL syncZoom = (variant == PenteVariantConnect6) || atLatest;
          if (syncZoom) {
              [zoomedBoard setAbstractBoard:abstractBoard];
          }

          if (untilMove > 0) {
              int last = [self parseMove:[movesList objectAtIndex:untilMove - 1]];
              [board setLastMove:last];
              if (syncZoom) {
                  [zoomedBoard setLastMove:last];
              }
          }

          if (variant == PenteVariantConnect6) {
              if (untilMove > 1) {
                  int prev =
                      [self parseMove:[movesList objectAtIndex:untilMove - 2]];
                  [board setLastConnect6Move:prev];
                  [zoomedBoard setLastConnect6Move:prev];
              } else {
                  [board setLastConnect6Move:-1];
                  [zoomedBoard setLastConnect6Move:-1];
              }
          }
      }
  ```
  Notes on fidelity: the `syncZoom` gate reproduces the legacy behaviour where non-Connect6
  variants only refreshed `zoomedBoard` when viewing the latest position (`lastMove ==
  [movesList count]`, e.g. line 2721) whereas Connect6 refreshed it unconditionally (lines
  2904-2906). The Connect6 penultimate highlight is read straight from `movesList[untilMove-2]`
  (no `lastConnect6Move` global is consulted — scope (e)). The `maskTournamentOpening` /
  `maskGPenteOpening` calls are intentionally dropped (engine owns masks — see scope note).

- [ ] **Step 2: Delete the twelve per-variant replay methods.**
  Delete these whole method bodies from `BoardViewController.m` (keep `replayGoGame:` at
  3056-…): `replayPenteGame:` (2689-2727), `replayGPenteGame:` (2729-2755),
  `replayKeryoPenteGame:` (2757-2785), `replayOPenteGame:` (2786-2814),
  `replayDKPenteGame:` (2816-2851), `replayGomokuGame:` (2853-2877),
  `replayConnect6Game:` (2879-2915), `replayDPenteGame:` (2917-2952),
  `replaySwap2PenteGame:` (2954-2989), `replaySwap2KeryoGame:` (2991-3026),
  `replayPoofPenteGame:` (3028-3054). For reference, the representative BEFORE (the deleted
  `replayKeryoPenteGame:`, lines 2757-2785):
  ```objc
  - (void)replayKeryoPenteGame:(int)untilMove {
      [self replayWithEngine:PenteGameVariantKeryoPente untilMove:untilMove];
      if ([[self.game ratedNot] rangeOfString:@"Not Rated"].location ==
              NSNotFound &&
          ([movesList count] == 2)) {
          [penteGame maskTournamentOpening];
      }

      [captures removeAllObjects];

      // NSLog(@" kitty moves %i",abstractBoard[0][0]);
      [board setBackgroundColor:[UIColor colorWithRed:0.702
                                                green:1
                                                 blue:0.518
                                                alpha:1]];
      [zoomedBoard setBackgroundColor:[UIColor colorWithRed:0.702
                                                      green:1
                                                       blue:0.518
                                                      alpha:1]];
      [board setAbstractBoard:abstractBoard];
      [board
          setLastMove:[self parseMove:[movesList objectAtIndex:untilMove - 1]]];
      if (lastMove == [movesList count]) {
          [zoomedBoard setAbstractBoard:abstractBoard];
          [zoomedBoard
              setLastMove:[self
                              parseMove:[movesList objectAtIndex:untilMove - 1]]];
      }
  }
  ```
  AFTER: the method is gone; its Keryo colour `(0.702,1,0.518)` now lives in
  `BoardVariantMapping.backgroundColor(for: .keryoPente …)`, its board fill is handled by
  `loadEngineIntoAbstractBoard`, and its tournament mask is owned by the engine.

- [ ] **Step 3: Convert the network-receive block (lines 1779-1917) to the unified dispatcher.**
  This is a 1:1 substitution — every `[strongSelf replay<Variant>Game:lastMove]` call becomes
  `[strongSelf replayGame:lastMove]`. Exactly one variant `if` fires per receive (the tests are
  `isEqualToString` / variant-unique `containsString`), so `replayGame:` runs once. The
  surrounding D-Pente-choice (1815-1835), Swap2-choice (1837-1879) and Go (1883-1909) UI logic is
  left untouched; the redundant `dPenteOpening = NO;` (1772) and `swap2Opening = …` (1838)
  assignments are harmless because `replayGame:` recomputes them (matching the legacy
  last-write-wins behaviour of the old `replay*Game:` bodies). Apply:
  - 1784 `[strongSelf replayPenteGame:lastMove];` -> `[strongSelf replayGame:lastMove];`
  - 1789 `[strongSelf replayKeryoPenteGame:lastMove];` -> `[strongSelf replayGame:lastMove];`
  - 1794 `[strongSelf replayOPenteGame:lastMove];` -> `[strongSelf replayGame:lastMove];`
  - 1799 `[strongSelf replayGPenteGame:lastMove];` -> `[strongSelf replayGame:lastMove];`
  - 1810 `[strongSelf replayDKPenteGame:lastMove];` -> `[strongSelf replayGame:lastMove];`
  - 1812 `[strongSelf replayDPenteGame:lastMove];` -> `[strongSelf replayGame:lastMove];`
  - 1843 `[strongSelf replaySwap2PenteGame:lastMove];` -> `[strongSelf replayGame:lastMove];`
  - 1846 `[strongSelf replaySwap2KeryoGame:lastMove];` -> `[strongSelf replayGame:lastMove];`
  - 1881 `[strongSelf replayPoofPenteGame:lastMove];` -> `[strongSelf replayGame:lastMove];`
  - 1911 `[strongSelf replayConnect6Game:lastMove];` -> `[strongSelf replayGame:lastMove];`
  - 1916 `[strongSelf replayGomokuGame:lastMove];` -> `[strongSelf replayGame:lastMove];`
  Leave the Go path (1897 `[strongSelf replayGoGame:lastMove];`) unchanged — Go does not match
  any variant `if`, so `replayGame:` is not invoked for Go from this block.

- [ ] **Step 4: Build and run the helper tests (still green).**
  ```
  xcodebuild build -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16'
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/BoardVariantMappingTests
  ```
  Expected: `** BUILD SUCCEEDED **` and `** TEST SUCCEEDED **`. Confirm no stray references
  remain:
  ```
  grep -nE 'replay(Pente|KeryoPente|GPente|OPente|DKPente|DPente|Gomoku|Connect6|Swap2Pente|Swap2Keryo|PoofPente)Game|replayWithEngine' test1/BoardViewController.m
  ```
  Expected: only the (now deleted) names absent — zero matches.

- [ ] **Step 5: Manual verification (iPhone + iPad) — board state, colour, labels, highlight.**
  Run on `platform=iOS Simulator,name=iPhone 16` and `platform=iOS Simulator,name=iPad (10th generation)`.
  For Pente, Boat-Pente, Keryo-Pente, O-Pente, Poof-Pente, G-Pente, D-Pente, DK-Pente,
  Swap2-Pente, Swap2-Keryo, Gomoku and Connect6, open a game with history and step backward /
  forward:
  - stones render at the correct intersections on both form factors (no clipped board on iPad);
  - the board background colour matches the variant (e.g. Boat-Pente blue, Keryo green, DK-Pente
    orange);
  - capture-count labels are visible for the capturing variants and hidden for Gomoku, Connect6,
    and the D/DK/Swap2 openings;
  - Connect6 shows the red penultimate-move dot one ply behind the last move;
  - the zoom lens reflects the latest position during active play.

- [ ] **Step 6: Commit.**
  ```
  git add test1/BoardViewController.h test1/BoardViewController.m
  git commit -m "refactor(ios): route BoardViewController replay through SwiftPenteGame, delete per-variant replay methods"
  ```

---

### Task 4.6: Drive the win banner from `MoveResult.winner`

Replace the legacy `detectPenteOf:` line-win probe in the network-receive banner (lines
1998-2011) with the `MoveResult.winner` captured into `lastReplayWinner` during `replayGame:`.
The capture-threshold checks (`whiteCaptures == 10` / `blackCaptures == 10`) are preserved and now
read the engine-sourced counters.

**Files**
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/BoardViewController.m` (lines 1995-2011)

- [ ] **Step 1: Replace the banner's winner probe.**
  BEFORE (lines 1995-2011):
  ```objc
              if ([[strongSelf.game opponentName] isEqualToString:@"computer"]) {
                  NSString *message = nil;
                  BOOL iWin = YES;
                  if ([strongSelf
                          detectPenteOf:2 - ([strongSelf->movesList count] % 2)
                             atPosition:[[strongSelf->movesList lastObject]
                                            intValue]]) {
                      if (2 - ([strongSelf->movesList count] % 2) == 1) {
                          message = NSLocalizedString(@"White wins", nil);
                      } else {
                          message = NSLocalizedString(@"Black wins", nil);
                      }
                  } else if (whiteCaptures == 10) {
                      message = NSLocalizedString(@"Black wins", nil);
                  } else if (blackCaptures == 10) {
                      message = NSLocalizedString(@"White wins", nil);
                  }
  ```
  AFTER:
  ```objc
              if ([[strongSelf.game opponentName] isEqualToString:@"computer"]) {
                  NSString *message = nil;
                  BOOL iWin = YES;
                  if (strongSelf->lastReplayWinner == 1) {
                      message = NSLocalizedString(@"White wins", nil);
                  } else if (strongSelf->lastReplayWinner == 2) {
                      message = NSLocalizedString(@"Black wins", nil);
                  } else if (whiteCaptures == 10) {
                      message = NSLocalizedString(@"Black wins", nil);
                  } else if (blackCaptures == 10) {
                      message = NSLocalizedString(@"White wins", nil);
                  }
  ```
  Fidelity: `MoveResult.winner` (1 = white, 2 = black, 0 = none) is the engine's `winLine`
  result for the last applied move, replacing the per-move `detectPenteOf:` probe; the
  10-capture victory remains a separate check on the engine-sourced `whiteCaptures` /
  `blackCaptures` counters, exactly as before.

- [ ] **Step 2: Build, run helper tests.**
  ```
  xcodebuild build -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16'
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/BoardVariantMappingTests
  ```
  Expected: `** BUILD SUCCEEDED **`, `** TEST SUCCEEDED **`.

- [ ] **Step 3: Manual verification (iPhone + iPad) — win banner.**
  Versus the `computer` opponent, play out: (a) a five-in-a-row finish for white and for black —
  expect "White wins" / "Black wins"; (b) a Keryo-Pente / Pente game reaching 10 captures for
  each side — expect the captor's win banner; (c) a Connect6 six-in-a-row finish — expect the
  correct banner. Confirm the success/failure styling (`iWin`) is correct for the local colour on
  both form factors.

- [ ] **Step 4: Commit.**
  ```
  git add test1/BoardViewController.m
  git commit -m "refactor(ios): drive win banner from MoveResult.winner"
  ```

---

### Task 4.7: Full manual verification matrix and phase close-out

No code change — a final gate confirming the cut-over preserved behaviour on both form factors,
plus a grep gate proving the global and the old-engine alias are gone.

**Files**
- None (verification only).

- [ ] **Step 1: Static gates.**
  ```
  grep -nE 'penteGame\.abstractBoard *= *abstractBoard' test1/BoardViewController.m   # expect: only inside syncCapturesToEngine (Phase-5 seam)
  grep -nE '^int abstractBoard\[19\]\[19\];' test1/BoardViewController.m              # expect: zero matches (global gone)
  grep -nE 'replayWithEngine|replayPenteGame|replayKeryoPenteGame|replayConnect6Game' test1/BoardViewController.m  # expect: zero matches
  ```

- [ ] **Step 2: Full helper-test run.**
  ```
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 16' \
    -only-testing:PenteEngineTests/BoardVariantMappingTests
  ```
  Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 3: Device matrix (iPhone 16 + iPad 10th generation).** For each of the 11 engine
  variants confirm: correct stones, background colour, capture-label visibility, last-move dot,
  Connect6 penultimate dot, capture animation during interactive placement (still served by the
  retained legacy `detect*` seam), undo of an unsubmitted D-Pente / Swap2 opening stone (lines
  561-601, now mutating the `abstractBoard` ivar), and the win banner. Confirm rated Pente still
  forbids the centre 5x5 second move while unrated Pente allows it (engine-owned opening mask;
  legality read via `[engine stoneAt:] == -1`). Confirm Go (9x9 / 13x13 / 19x19) still renders,
  marks dead stones, and scores — Go was not migrated.

- [ ] **Step 4: Tag the phase complete.**
  ```
  git commit --allow-empty -m "chore(ios): Phase 4 complete — BoardViewController on SwiftPenteGame"
  ```

---

### Identifiers introduced by Phase 4

- Swift: `BoardVariantMapping` with `variant(forGameType:)` (`+variantForGameType:`),
  `backgroundColor(for:boatPente:)` (`+backgroundColorForVariant:boatPente:`),
  `hidesCaptureLabels(for:opening:)` (`+hidesCaptureLabelsForVariant:opening:`).
- ObjC `BoardViewController`: ivars `engine` (a `SwiftPenteGame *`), `abstractBoard` (relocated
  from file-global), `lastReplayWinner`; methods `-loadEngineIntoAbstractBoard`, `-parsedMoves`.

### Identifiers consumed from the contract / earlier phases

- `PenteVariant` (+ ObjC `PenteVariantPente`…`PenteVariantConnect6`), `MoveResult`
  (`.winner`, `.captured`), `Capture`, and the Swift engine `PenteGame` exposed to ObjC as
  `SwiftPenteGame` (`-initWithVariant:`, `-reset`, `-replay:until:`, `-stoneAt:`,
  `.whiteCaptures`, `.blackCaptures`). XCTest target `PenteEngineTests`; app module `penteLive`.
## Phase 5: Extract GoGame; delete dead Go properties

> **Separability note (read first).** This phase is the **most separable** in the
> consolidation. Go never flows through the Pente `PenteGame` engine today — it
> bypasses it entirely (`BoardViewController.replayGoGame` and `Table.addGoMove`
> own their own copies of the rules). Nothing in Phases 0–4 (`Scan`, `RuleSet`,
> `PenteVariant`, `MoveResult`, the stateful `PenteGame` Swift engine) depends on
> Go, and Go depends on none of them. **This phase is therefore safe to defer to a
> follow-up PR** without blocking the Pente consolidation. It is included here for
> completeness so the duplicated Go logic lands behind the same "one stateful
> engine" seam as the Pente variants.

The Go rules already exist **in Swift** inside `Table` (`HelperClasses.swift`,
`addGoMove` + helpers `makeCaptures`/`getCaptures`/`checkKo`/`captureGroup`/
`groupHasLiberties`/`stoneHasLiberties`/`settleGroups`/`mergeGroups`/`floodFill`/
`getTerritories`/`getGoScoreString`). `BoardViewController.m` holds a parallel
Objective-C copy used only for replay. We lift the **Swift** copy verbatim into a
standalone `@objc final class GoGame`, unit-test it, route both `Table` and
`BoardViewController` through it, then delete the dead `goStoneGroup*` properties
on the legacy ObjC `PenteGame`.

**Frozen test target (named by Phase 0, reused here):** `PenteEngineTests`.
**Canonical test command** (run from repo root
`/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS`):

```
xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:PenteEngineTests/GoGameTests/testCaptureSingleStoneByNoLiberties
```

### GoGame @objc surface (defined by this phase)

```swift
@objc enum GoPhase: Int { case play = 0, markStones = 1, evaluateStones = 2 }

@objc final class GoGame: NSObject {
    @objc init(gridSize: Int)                       // 9, 13, or 19
    @objc func reset()
    @objc func play(_ move: Int)                    // stone / pass / dead-mark per phase; rowCol = row*gridSize + col
    @objc func replay(_ moves: [Int], until: Int)
    @objc func stone(at rowCol: Int) -> Int         // 0 empty / 1 white / 2 black
    @objc func territory(forPlayer player: Int) -> [Int]   // player 1 = black, 2 = white
    @objc func scoreString() -> String
    @objc var gridSize: Int { get }
    @objc var passMove: Int { get }                 // == gridSize*gridSize
    @objc var phase: GoPhase { get }
    @objc var koMove: Int { get }
    @objc var whiteCaptures: Int { get }            // count of captured white (colour-1) stones
    @objc var blackCaptures: Int { get }            // count of captured black (colour-2) stones
    @objc var blackDeadStones: [Int] { get }
    @objc var whiteDeadStones: [Int] { get }
    @objc var moveCount: Int { get }
}
```

Source semantics preserved exactly: player 1 plays colour **2 (black)** and moves
first; player 2 plays colour **1 (white)**. Group dictionaries are keyed by
**player index** (1/2). `whiteCaptures`/`blackCaptures` count *captured stones of
that colour* (matching `captureGroup`). `koMove` is set only inside a capture and
otherwise persists, exactly as the `Table` source does (do **not** add a
per-move `koMove = -1` reset — that is the divergent ObjC behaviour we are
dropping in favour of the canonical Swift one).

---

### Task 5.1: Create `GoGame` core (board, groups, liberties, captures, dead-marking) with tests

**Files**
- Create: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/PenteEngine/GoGame.swift`
- Create (Test): `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/GoGameTests.swift`
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcodeproj/project.pbxproj` (target membership)

- [ ] **Step 1: Write the failing test file.** Create `GoGameTests.swift` with the
  capture, group-capture, and dead-stone cases. These are hand-verified on a 9×9
  board (passMove = 81; rowCol = row*9 + col):

```swift
import XCTest

final class GoGameTests: XCTestCase {

    // A single white stone at centre 40, surrounded by black on all four sides, is captured.
    func testCaptureSingleStoneByNoLiberties() {
        let go = GoGame(gridSize: 9)
        go.play(39)   // m0 black, 40-left   (player 1 = black, moves first)
        go.play(40)   // m1 white, target
        go.play(41)   // m2 black, 40-right
        go.play(0)    // m3 white filler (corner, has liberties)
        go.play(31)   // m4 black, 40-up
        go.play(80)   // m5 white filler (corner, has liberties)
        go.play(49)   // m6 black, 40-down -> white 40 has no liberties

        XCTAssertEqual(go.stone(at: 40), 0, "captured stone must be removed")
        XCTAssertEqual(go.whiteCaptures, 1, "one white stone captured")
        XCTAssertEqual(go.blackCaptures, 0)
        XCTAssertEqual(go.koMove, -1, "this capture is not a ko")
    }

    // A connected white group {40,41} (merged via flood-fill / settleGroups) is captured as one unit.
    func testCaptureConnectedGroupByNoLiberties() {
        let go = GoGame(gridSize: 9)
        go.play(39)   // m0 black, 40-left
        go.play(40)   // m1 white
        go.play(31)   // m2 black, 40-up
        go.play(41)   // m3 white -> merges with 40 into one group
        go.play(49)   // m4 black, 40-down
        go.play(0)    // m5 white filler
        go.play(42)   // m6 black, 41-right
        go.play(80)   // m7 white filler
        go.play(32)   // m8 black, 41-up
        go.play(8)    // m9 white filler
        go.play(50)   // m10 black, 41-down -> group {40,41} has no liberties

        XCTAssertEqual(go.stone(at: 40), 0)
        XCTAssertEqual(go.stone(at: 41), 0)
        XCTAssertEqual(go.whiteCaptures, 2, "both stones captured together")
    }

    // Two passes flip the game into markStones; a subsequent play marks a stone dead.
    func testDoublePassMarksDeadStone() {
        let go = GoGame(gridSize: 9)
        go.play(40)   // m0 black stone at centre
        go.play(81)   // m1 white pass (passMove == 81)
        go.play(81)   // m2 black pass -> double pass -> markStones
        XCTAssertEqual(go.phase, .markStones)
        go.play(40)   // m3 mark the black stone at 40 as dead
        XCTAssertEqual(go.stone(at: 40), 0, "dead stone removed from board")
        XCTAssertEqual(go.blackDeadStones, [40], "black stone recorded as dead")
    }
}
```

- [ ] **Step 2: Add `GoGameTests.swift` to the `PenteEngineTests` target, then run (expected FAIL).**
  In Xcode, select `GoGameTests.swift` → File inspector → Target Membership →
  check `PenteEngineTests` (the target Phase 0 created). Then:

```
xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:PenteEngineTests/GoGameTests/testCaptureSingleStoneByNoLiberties
```

  Expected FAIL — compilation error: `cannot find 'GoGame' in scope`.

- [ ] **Step 3: Create the engine core** `GoGame.swift` (ported verbatim from
  `Table` in `HelperClasses.swift`; territory/scoring is added in Task 5.2):

```swift
//
//  GoGame.swift
//  penteLive
//
//  Stateful Go engine extracted verbatim from Table (HelperClasses.swift) and
//  BoardViewController.replayGoGame. Single source of truth for Go rules:
//  board, stone groups, liberties, captures, ko and dead-stone marking.
//  Player 1 plays colour 2 (black) and moves first; player 2 plays colour 1 (white).
//

import Foundation

@objc enum GoPhase: Int {
    case play = 0
    case markStones = 1
    case evaluateStones = 2
}

@objc final class GoGame: NSObject {
    @objc let gridSize: Int
    @objc let passMove: Int

    private var board: [[Int]]
    private var groupsByPlayerAndID: [Int: [Int: [Int]]] = [:]
    private var groupIDsByPlayer: [Int: [Int: Int]] = [:]
    private var deadStonesByPlayer: [Int: [Int]] = [:]
    private var territoryByPlayer: [Int: [Int]] = [:]
    private var moves: [Int] = []

    private var hasPass = false
    private var doublePass = false

    @objc private(set) var phase: GoPhase = .play
    @objc private(set) var koMove: Int = -1
    @objc private(set) var whiteCaptures: Int = 0
    @objc private(set) var blackCaptures: Int = 0

    @objc var blackDeadStones: [Int] { return deadStonesByPlayer[1] ?? [] }
    @objc var whiteDeadStones: [Int] { return deadStonesByPlayer[2] ?? [] }
    @objc var moveCount: Int { return moves.count }

    @objc init(gridSize: Int) {
        self.gridSize = gridSize
        self.passMove = gridSize * gridSize
        self.board = Array(repeating: Array(repeating: 0, count: gridSize), count: gridSize)
        super.init()
        clearState()
    }

    private func clearState() {
        board = Array(repeating: Array(repeating: 0, count: gridSize), count: gridSize)
        groupsByPlayerAndID = [1: [Int: [Int]](), 2: [Int: [Int]]()]
        groupIDsByPlayer = [1: [Int: Int](), 2: [Int: Int]()]
        deadStonesByPlayer = [1: [Int](), 2: [Int]()]
        territoryByPlayer = [1: [Int](), 2: [Int]()]
        moves = []
        hasPass = false
        doublePass = false
        phase = .play
        koMove = -1
        whiteCaptures = 0
        blackCaptures = 0
    }

    @objc func reset() {
        clearState()
    }

    @objc func replay(_ moves: [Int], until: Int) {
        clearState()
        let count = min(until, moves.count)
        for k in 0 ..< count {
            play(moves[k])
        }
    }

    @objc func stone(at rowCol: Int) -> Int {
        return getBoardValue(move: rowCol)
    }

    // MARK: - move application (ported from Table.addGoMove)

    @objc func play(_ move: Int) {
        let player = currentPlayer(), color = 3 - player
        if move == passMove {
            if phase == .markStones {
                phase = .evaluateStones
            } else if hasPass {
                doublePass = true
                phase = .markStones
            } else {
                hasPass = true
            }
        } else {
            hasPass = false
        }
        moves.append(move)
        if phase == .markStones {
            if move != passMove {
                let p = 3 - getBoardValue(move: move)
                deadStonesByPlayer[p]?.append(move)
                setBoardValue(move: move, value: 0)
            }
        } else {
            if move < passMove {
                var groupsByID = groupsByPlayerAndID[player]!, stoneGroupIDs = groupIDsByPlayer[player]!
                setBoardValue(move: move, value: color)
                settleGroups(groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs, move: move)
                groupsByPlayerAndID[player] = groupsByID; groupIDsByPlayer[player] = stoneGroupIDs

                groupsByID = groupsByPlayerAndID[color]!; stoneGroupIDs = groupIDsByPlayer[color]!
                makeCaptures(move: move, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs)
                groupsByPlayerAndID[color] = groupsByID; groupIDsByPlayer[color] = stoneGroupIDs
            }
        }
    }

    // MARK: - turn order (ported from Table.currentPlayer / doublePassMove)

    private func currentPlayer() -> Int {
        let d = doublePassMove()
        if phase == .evaluateStones {
            return 1 + d % 2
        } else if phase == .markStones {
            return 2 - d % 2
        } else {
            return 1 + (moves.count % 2)
        }
    }

    private func doublePassMove() -> Int {
        var pass = false, i = 0
        for move in moves {
            if move == passMove {
                if pass {
                    return i
                } else {
                    pass = true
                }
            } else {
                pass = false
            }
            i += 1
        }
        return -1
    }

    // MARK: - captures (ported from Table.makeCaptures / getCaptures / checkKo / captureGroup)

    private func makeCaptures(move: Int, groupsByID: inout [Int: [Int]], stoneGroupIDs: inout [Int: Int]) {
        var captures = 0
        if move % gridSize != 0 {
            let neighborStone = move - 1
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                captures = getCaptures(move: move, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs, captures: captures, neighborStone: neighborStone, neighborStoneID: neighborStoneID)
            }
        }
        if move % gridSize != gridSize - 1 {
            let neighborStone = move + 1
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                captures = getCaptures(move: move, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs, captures: captures, neighborStone: neighborStone, neighborStoneID: neighborStoneID)
            }
        }
        if move / gridSize != 0 {
            let neighborStone = move - gridSize
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                captures = getCaptures(move: move, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs, captures: captures, neighborStone: neighborStone, neighborStoneID: neighborStoneID)
            }
        }
        if move / gridSize != gridSize - 1 {
            let neighborStone = move + gridSize
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                captures = getCaptures(move: move, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs, captures: captures, neighborStone: neighborStone, neighborStoneID: neighborStoneID)
            }
        }
        _ = captures
    }

    private func getCaptures(move: Int, groupsByID: inout [Int: [Int]], stoneGroupIDs: inout [Int: Int], captures: Int, neighborStone: Int, neighborStoneID: Int) -> Int {
        var newCaptures = captures
        if let neighborStoneGroup = groupsByID[neighborStoneID] {
            if !groupHasLiberties(group: neighborStoneGroup) {
                if koMove < 0 && neighborStoneGroup.count == 1 && checkKo(move: move) {
                    koMove = neighborStone
                } else {
                    koMove = -1
                }
                newCaptures += neighborStoneGroup.count
                captureGroup(groupID: neighborStoneID, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs)
            }
        }
        return newCaptures
    }

    private func checkKo(move: Int) -> Bool {
        let position = getBoardValue(move: move)
        if move % gridSize != 0 {
            let neighborStone = move - 1
            let neighborPosition = getBoardValue(move: neighborStone)
            if position != 3 - neighborPosition {
                return false
            }
        }
        if move % gridSize != gridSize - 1 {
            let neighborStone = move + 1
            let neighborPosition = getBoardValue(move: neighborStone)
            if position != 3 - neighborPosition {
                return false
            }
        }
        if move / gridSize != 0 {
            let neighborStone = move - gridSize
            let neighborPosition = getBoardValue(move: neighborStone)
            if position != 3 - neighborPosition {
                return false
            }
        }
        if move / gridSize != gridSize - 1 {
            let neighborStone = move + gridSize
            let neighborPosition = getBoardValue(move: neighborStone)
            if position != 3 - neighborPosition {
                return false
            }
        }
        return true
    }

    private func captureGroup(groupID: Int, groupsByID: inout [Int: [Int]], stoneGroupIDs: inout [Int: Int]) {
        let group = groupsByID[groupID]!
        let color = getBoardValue(move: group[0])
        for stone in group {
            setBoardValue(move: stone, value: 0)
            stoneGroupIDs.removeValue(forKey: stone)
        }
        groupsByID.removeValue(forKey: groupID)
        if color == 2 {
            blackCaptures += group.count
        } else if color == 1 {
            whiteCaptures += group.count
        }
    }

    // MARK: - liberties (ported from Table.groupHasLiberties / stoneHasLiberties)

    private func groupHasLiberties(group: [Int]) -> Bool {
        for stone in group {
            if stoneHasLiberties(move: stone) {
                return true
            }
        }
        return false
    }

    private func stoneHasLiberties(move: Int) -> Bool {
        if move % gridSize != 0 {
            let neighborStone = move - 1
            let pos = getBoardValue(move: neighborStone)
            if pos != 1 && pos != 2 {
                return true
            }
        }
        if move % gridSize != gridSize - 1 {
            let neighborStone = move + 1
            let pos = getBoardValue(move: neighborStone)
            if pos != 1 && pos != 2 {
                return true
            }
        }
        if move / gridSize != 0 {
            let neighborStone = move - gridSize
            let pos = getBoardValue(move: neighborStone)
            if pos != 1 && pos != 2 {
                return true
            }
        }
        if move / gridSize != gridSize - 1 {
            let neighborStone = move + gridSize
            let pos = getBoardValue(move: neighborStone)
            if pos != 1 && pos != 2 {
                return true
            }
        }
        return false
    }

    // MARK: - board accessors (ported from Table.getBoardValue / setBoardValue)

    private func getBoardValue(move: Int) -> Int {
        let i = move / gridSize
        let j = move % gridSize
        return board[i][j]
    }

    private func setBoardValue(move: Int, value: Int) {
        let i = move / gridSize
        let j = move % gridSize
        board[i][j] = value
    }

    // MARK: - groups (ported from Table.settleGroups / mergeGroups)

    private func settleGroups(groupsByID: inout [Int: [Int]], stoneGroupIDs: inout [Int: Int], move: Int) {
        let newGroup = [move]
        groupsByID[move] = newGroup
        stoneGroupIDs[move] = move
        if move % gridSize != 0 {
            let neighborStone = move - 1
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                mergeGroups(group1: move, group2: neighborStoneID, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs)
            }
        }
        if move % gridSize != gridSize - 1 {
            let neighborStone = move + 1
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                mergeGroups(group1: stoneGroupIDs[move]!, group2: neighborStoneID, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs)
            }
        }
        if move / gridSize != 0 {
            let neighborStone = move - gridSize
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                mergeGroups(group1: stoneGroupIDs[move]!, group2: neighborStoneID, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs)
            }
        }
        if move / gridSize != gridSize - 1 {
            let neighborStone = move + gridSize
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                mergeGroups(group1: stoneGroupIDs[move]!, group2: neighborStoneID, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs)
            }
        }
    }

    private func mergeGroups(group1: Int, group2: Int, groupsByID: inout [Int: [Int]], stoneGroupIDs: inout [Int: Int]) {
        var oldGroup, newGroup: [Int]
        var oldGroupID, newGroupID: Int
        if group1 < group2 {
            oldGroup = groupsByID[group1]!
            newGroup = groupsByID[group2]!
            oldGroupID = group1
            newGroupID = group2
        } else {
            newGroup = groupsByID[group1]!
            oldGroup = groupsByID[group2]!
            oldGroupID = group2
            newGroupID = group1
        }
        groupsByID.removeValue(forKey: oldGroupID)
        newGroup.append(contentsOf: oldGroup)
        groupsByID[newGroupID] = newGroup
        for stone in oldGroup {
            stoneGroupIDs[stone] = newGroupID
        }
    }
}
```

- [ ] **Step 4: Add `GoGame.swift` to both targets.** In Xcode, select
  `GoGame.swift` → File inspector → Target Membership → check **`test1`** (the app)
  **and `PenteEngineTests`** (so the test bundle compiles the engine directly — no
  `@testable import` is needed; this matches the repo's existing standalone-engine
  test convention).

- [ ] **Step 5: Run the three tests (expected PASS).**

```
xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:PenteEngineTests/GoGameTests/testCaptureSingleStoneByNoLiberties \
  -only-testing:PenteEngineTests/GoGameTests/testCaptureConnectedGroupByNoLiberties \
  -only-testing:PenteEngineTests/GoGameTests/testDoublePassMarksDeadStone
```

  Expected: `Test Suite 'GoGameTests' passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit.**

```
git add test1/PenteEngine/GoGame.swift PenteEngineTests/GoGameTests.swift penteLive.xcodeproj/project.pbxproj
git commit -m "feat(engine): add stateful GoGame engine with capture and dead-stone rules"
```

---

### Task 5.2: Add Go territory scoring + dead-stone accessors to `GoGame`

**Files**
- Modify (Test): `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/PenteEngineTests/GoGameTests.swift` (append one test)
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/PenteEngine/GoGame.swift` (append territory section before final `}`)

- [ ] **Step 1: Add the failing territory test.** Append this method inside the
  `GoGameTests` class (before the closing brace). Hand-verified on 9×9: black
  stones at 1 and 9 enclose the corner point 0 (a corner has only neighbours 1 and
  9); the rest of the empty board is reachable from both colours and is neutral:

```swift
    // Black stones at 1 and 9 enclose the corner point 0, which only black can reach.
    func testTerritoryEnclosedCorner() {
        let go = GoGame(gridSize: 9)
        go.play(1)    // m0 black at (0,1)
        go.play(80)   // m1 white far corner
        go.play(9)    // m2 black at (1,0)
        XCTAssertEqual(go.territory(forPlayer: 1), [0], "corner is black-exclusive territory")
        XCTAssertEqual(go.territory(forPlayer: 2), [], "white has no exclusive territory")
    }
```

- [ ] **Step 2: Run it (expected FAIL).**

```
xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:PenteEngineTests/GoGameTests/testTerritoryEnclosedCorner
```

  Expected FAIL — compilation error: `value of type 'GoGame' has no member 'territory'`.

- [ ] **Step 3: Add the territory/scoring section** to `GoGame.swift`. Locate the
  end of `mergeGroups(group1:group2:groupsByID:stoneGroupIDs:)` and the class's closing brace:

```swift
        for stone in oldGroup {
            stoneGroupIDs[stone] = newGroupID
        }
    }
}
```

  Replace those lines with the same `mergeGroups` ending followed by the territory
  methods (ported verbatim from `Table.getGoScoreString` / `getTerritories` /
  `floodFill` / `floodFillWorker` / `getEmptyNeighbor` / `getMoves` /
  `resetGoBeforeFlood`) and the class close:

```swift
        for stone in oldGroup {
            stoneGroupIDs[stone] = newGroupID
        }
    }

    // MARK: - territory (ported from Table.getTerritories / floodFill / floodFillWorker / getEmptyNeighbor / getMoves / resetGoBeforeFlood / getGoScoreString)

    @objc func territory(forPlayer player: Int) -> [Int] {
        getTerritories()
        return territoryByPlayer[player] ?? []
    }

    @objc func scoreString() -> String {
        getTerritories()
        let p1Stones = getMoves(value: 2).count, p2Stones = getMoves(value: 1).count, p1Territory = territoryByPlayer[1]!.count, p2Territory = territoryByPlayer[2]!.count
        return "black score is \(p1Territory) + \(p1Stones) = \(p1Stones + p1Territory)\nwhite score is \(p2Territory) + \(p2Stones) + 7.5 = \(p2Stones + p2Territory + 7).5"
    }

    private func getTerritories() {
        floodFill(player: 1)
        var p1Territory = getMoves(value: 3)
        resetGoBeforeFlood()
        floodFill(player: 2)
        var p2Territory = getMoves(value: 4)
        resetGoBeforeFlood()
        var i1 = p1Territory.count - 1, i2 = p2Territory.count - 1
        while i1 > -1, i2 > -1 {
            let p1 = p1Territory[i1], p2 = p2Territory[i2]
            if p1 == p2 {
                p1Territory.remove(at: i1); p2Territory.remove(at: i2)
                i1 -= 1; i2 -= 1
            } else if p1 < p2 {
                i2 -= 1
            } else {
                i1 -= 1
            }
        }
        territoryByPlayer[1] = p1Territory; territoryByPlayer[2] = p2Territory
    }

    private func resetGoBeforeFlood() {
        for i in 0 ..< gridSize {
            for j in 0 ..< gridSize {
                let pos = board[i][j]
                if pos != 1, pos != 2 {
                    board[i][j] = 0
                }
            }
        }
    }

    private func getEmptyNeighbor(move: Int) -> Int {
        if move % gridSize != 0 {
            let neighborStone = move - 1
            if getBoardValue(move: neighborStone) == 0 {
                return neighborStone
            }
        }
        if move % gridSize != gridSize - 1 {
            let neighborStone = move + 1
            if getBoardValue(move: neighborStone) == 0 {
                return neighborStone
            }
        }
        if move / gridSize != 0 {
            let neighborStone = move - gridSize
            if getBoardValue(move: neighborStone) == 0 {
                return neighborStone
            }
        }
        if move / gridSize != gridSize - 1 {
            let neighborStone = move + gridSize
            if getBoardValue(move: neighborStone) == 0 {
                return neighborStone
            }
        }
        return -1
    }

    private func getMoves(value: Int) -> [Int] {
        var result = [Int]()
        for i in 0 ..< gridSize {
            for j in 0 ..< gridSize {
                let pos = board[i][j]
                if pos == value {
                    result.append(i * gridSize + j)
                }
            }
        }
        return result
    }

    private func floodFillWorker(move: Int, value: Int) {
        setBoardValue(move: move, value: value)
        var neighbor = getEmptyNeighbor(move: move)
        while neighbor > -1 {
            floodFillWorker(move: neighbor, value: value)
            neighbor = getEmptyNeighbor(move: move)
        }
    }

    private func floodFill(player: Int) {
        for i in 0 ..< gridSize {
            for j in 0 ..< gridSize {
                let pos = board[i][j]
                if pos == 3 - player {
                    let move = i * gridSize + j
                    var neighbor = getEmptyNeighbor(move: move)
                    while neighbor > -1 {
                        floodFillWorker(move: neighbor, value: player + 2)
                        neighbor = getEmptyNeighbor(move: move)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 4: Run the territory test plus the full suite (expected PASS).**

```
xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:PenteEngineTests/GoGameTests
```

  Expected: `Test Suite 'GoGameTests' passed` (4 tests), `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit.**

```
git add test1/PenteEngine/GoGame.swift PenteEngineTests/GoGameTests.swift
git commit -m "feat(engine): add Go territory scoring and dead-stone accessors to GoGame"
```

---

### Task 5.3: Route `Table` (HelperClasses.swift) Go moves through `GoGame`

`Table` keeps `abstractBoard` (for rendering), `moves`, `koMove`,
`goDeadStonesByPlayer`, `goTerritoryByPlayer`, `currentPlayer()`, `doublePassMove()`
and the `state.goState`-based show* helpers. We delete its private Go rule helpers
and the two now-unused group dictionaries, and delegate to a `GoGame` instance.

**Files**
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/HelperClasses.swift`
  - line 100–101 (delete group-dictionary properties)
  - line 105 (add `goGame` property)
  - line 328–369 (`addGoMove` → delegating body + `syncFromGoGame`)
  - line 557–857 (delete the Go-rule helper block; replace with delegating `getGoScoreString`)
  - the three identical 4-line Go-reset blocks at 204–207, 381–384, 451–454

- [ ] **Step 1: Add the `goGame` property.** After line 105
  (`var koMove = -1`), insert:

```swift
    var goGame = GoGame(gridSize: 19)
```

- [ ] **Step 2: Delete the two unused group-dictionary properties.** Remove lines
  100–101:

```swift
    var goStoneGroupIDsByPlayer = [Int: [Int: Int]]()
    var goStoneGroupsByPlayerAndID = [Int: [Int: [Int]]]()
```

  (Keep `goDeadStonesByPlayer` and `goTerritoryByPlayer` on lines 102–103 — they
  stay, synced from `GoGame`.)

- [ ] **Step 3: Replace `addGoMove` (lines 328–369)** with a delegating version
  plus a `syncFromGoGame` helper:

```swift
    func addGoMove(move: Int) {
        if game == GameEnum.speedGo9x9.rawValue || game == GameEnum.go9x9.rawValue {
            gridSize = 9
        } else if game == GameEnum.go13x13.rawValue || game == GameEnum.speedGo13x13.rawValue {
            gridSize = 13
        } else {
            gridSize = 19
        }
        passMove = gridSize * gridSize
        if goGame.gridSize != gridSize {
            goGame = GoGame(gridSize: gridSize)
            goGame.replay(moves, until: moves.count)
        }
        goGame.play(move)
        moves.append(move)
        syncFromGoGame()
    }

    func syncFromGoGame() {
        for pos in 0 ..< (gridSize * gridSize) {
            let i = pos / gridSize, j = pos % gridSize
            abstractBoard[i][j] = goGame.stone(at: pos)
        }
        whiteCaptures = goGame.whiteCaptures
        blackCaptures = goGame.blackCaptures
        koMove = goGame.koMove
        goDeadStonesByPlayer[1] = goGame.blackDeadStones
        goDeadStonesByPlayer[2] = goGame.whiteDeadStones
        switch goGame.phase {
        case .play: state.goState = .play
        case .markStones: state.goState = .markStones
        case .evaluateStones: state.goState = .evaluateStones
        }
    }
```

- [ ] **Step 4: Delete the Go-rule helper block (lines 557–857) and replace with a
  delegating `getGoScoreString`.** Select the contiguous block from
  `func makeCaptures(move:` (line 557) through the closing brace of
  `getTerritories()` (line 857) — this block contains `makeCaptures`,
  `getCaptures`, `checkKo`, `captureGroup`, `groupHasLiberties`,
  `stoneHasLiberties`, `getBoardValue`, `setBoardValue`, `settleGroups`,
  `mergeGroups`, `getGoScoreString`, `resetGoBeforeFlood`, `getEmptyNeighbor`,
  `getMoves`, `floodFillWorker`, `floodFill`, `getTerritories` — and replace the
  **entire** block with only:

```swift
    func getGoScoreString() -> String {
        goTerritoryByPlayer[1] = goGame.territory(forPlayer: 1)
        goTerritoryByPlayer[2] = goGame.territory(forPlayer: 2)
        return goGame.scoreString()
    }
```

  (`isGo()` on lines 553–555, immediately above the block, is unaffected.
  `currentPlayer()` and `doublePassMove()` on lines 463–498 are above the block and
  remain — they read `moves` and `state.goState`, both kept in sync.)

- [ ] **Step 5: Reset `goGame` at every full-reset site.** The four-line Go-reset
  block appears identically at lines 204–207 (`addMoves`), 381–384 (`reset`) and
  451–454 (`undoLastMove`):

```swift
        goStoneGroupIDsByPlayer.removeAll(); goStoneGroupIDsByPlayer[1] = [Int: Int](); goStoneGroupIDsByPlayer[2] = [Int: Int]()
        goStoneGroupsByPlayerAndID.removeAll(); goStoneGroupsByPlayerAndID[1] = [Int: [Int]](); goStoneGroupsByPlayerAndID[2] = [Int: [Int]]()
        goDeadStonesByPlayer.removeAll(); goDeadStonesByPlayer[1] = [Int](); goDeadStonesByPlayer[2] = [Int]()
        goTerritoryByPlayer.removeAll(); goTerritoryByPlayer[1] = [Int](); goTerritoryByPlayer[2] = [Int]()
```

  Replace all three occurrences (use Edit with `replace_all: true`) with:

```swift
        goDeadStonesByPlayer.removeAll(); goDeadStonesByPlayer[1] = [Int](); goDeadStonesByPlayer[2] = [Int]()
        goTerritoryByPlayer.removeAll(); goTerritoryByPlayer[1] = [Int](); goTerritoryByPlayer[2] = [Int]()
        goGame = GoGame(gridSize: 19)
```

- [ ] **Step 6: Build the app target (expected PASS).** This proves the `Table`
  refactor removed all references to the deleted helpers/properties:

```
xcodebuild build -workspace penteLive.xcworkspace -scheme test1 \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

  Expected: `** BUILD SUCCEEDED **` (no `cannot find` / `has no member` errors for
  `goStoneGroupIDsByPlayer`, `goStoneGroupsByPlayerAndID`, `getBoardValue`,
  `setBoardValue`, `makeCaptures`, etc.).

- [ ] **Step 7: Re-run the engine tests (still green).**

```
xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:PenteEngineTests/GoGameTests
```

  Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 8: Commit.**

```
git add test1/HelperClasses.swift
git commit -m "refactor(live): route Table Go moves through GoGame engine"
```

---

### Task 5.4: Route `BoardViewController.replayGoGame` through `GoGame`

**Files**
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/BoardViewController.m`
  - top imports (ensure `#import "penteLive-Swift.h"`)
  - line 3056–3133 (`replayGoGame:`)

- [ ] **Step 1: Ensure the Swift bridging header is imported.** Near the other
  `#import` lines at the top of `BoardViewController.m`, confirm
  `#import "penteLive-Swift.h"` is present; add it if missing (earlier phases that
  surfaced `PenteGame`/`Scan` to ObjC will normally have added it already).

- [ ] **Step 2: Replace `replayGoGame:` (lines 3056–3133)** with a version that
  delegates to `GoGame`, then copies the engine board into the C `abstractBoard`
  and reapplies the existing display behaviour (dead stones, ko mask, background
  colours, last-move). `gridSize`, `koMove`, `deadBlackStones`, `deadWhiteStones`,
  `movesList`, `lastMove`, `board`, `zoomedBoard`, `parseMove:`,
  `setValue:forPosition:`, `setAbstractBoard:` already exist in this file:

```objc
- (void)replayGoGame:(int)untilMove {
    GoGame *goGame = [[GoGame alloc] initWithGridSize:gridSize];
    NSMutableArray<NSNumber *> *moveInts = [NSMutableArray array];
    for (int i = 0; i < [movesList count]; ++i) {
        [moveInts addObject:@([self parseMove:[movesList objectAtIndex:i]])];
    }
    [goGame replay:moveInts until:untilMove];

    deadBlackStones = [[goGame blackDeadStones] mutableCopy];
    deadWhiteStones = [[goGame whiteDeadStones] mutableCopy];

    for (int pos = 0; pos < gridSize * gridSize; ++pos) {
        [self setValue:(int)[goGame stoneAt:pos] forPosition:pos];
    }
    koMove = (int)[goGame koMove];

    [board setBlackDeadStones:deadBlackStones];
    [board setWhiteDeadStones:deadWhiteStones];
    [zoomedBoard setBlackDeadStones:deadBlackStones];
    [zoomedBoard setWhiteDeadStones:deadWhiteStones];
    [board setBackgroundColor:[UIColor colorWithRed:250.0 / 255
                                              green:200.0 / 255
                                               blue:50.0 / 255
                                              alpha:1]];
    [zoomedBoard setBackgroundColor:[UIColor colorWithRed:250.0 / 255
                                                    green:200.0 / 255
                                                     blue:50.0 / 255
                                                    alpha:1]];
    [board setAbstractBoard:abstractBoard];
    if (untilMove > 0) {
        [board setLastMove:[self parseMove:[movesList
                                               objectAtIndex:untilMove - 1]]];
    }
    if (lastMove == [movesList count]) {
        [zoomedBoard setAbstractBoard:abstractBoard];
        if (untilMove > 0) {
            [zoomedBoard
                setLastMove:[self parseMove:[movesList
                                                objectAtIndex:untilMove - 1]]];
        }
    }
    if (koMove > -1) {
        [self setValue:-1 forPosition:koMove];
    }
}
```

  > The dead-stone phase now follows the canonical `Table`/`GoGame` phase machine
  > (double-pass → `markStones`) rather than the old inline "after double-pass,
  > every non-pass move is a dead mark forever" behaviour. This is the intended
  > consolidation; the displayed board state for completed replays is unchanged.
  >
  > After this routing the file-scope ObjC Go globals/ivars
  > (`goStoneGroupIDsByPlayer`, `goStoneGroupsByPlayerAndID`, `goStoneGroups`,
  > `goStoneGroupIDs`) and the now-unreferenced ObjC Go methods (`initGoStructures`,
  > `makeCapturesWithMove:`, `getCapturesOfMove:`, `settleGroups:andIDs:forMove:`,
  > `floodFill`, `floodFillWorker`, `getTerritories`) are dead. **Deleting them is a low-risk
  > follow-up** — leave them for now since `setValue:forPosition:` / `getBoardValue:`
  > are shared with non-Go code paths and removing the cluster needs its own
  > verification pass.

- [ ] **Step 3: Build the app target (expected PASS).**

```
xcodebuild build -workspace penteLive.xcworkspace -scheme test1 \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

  Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit.**

```
git add test1/BoardViewController.m
git commit -m "refactor(board): route BoardViewController Go replay through GoGame"
```

---

### Task 5.5: Delete the dead `goStoneGroup*` properties from legacy ObjC `PenteGame`

These two properties are declared in `PenteGame.h` and only `@synthesize`d in
`PenteGame.m` — they are never populated or read (verified: no `penteGame.goStoneGroup*`
access exists anywhere in the codebase; `BoardViewController` uses its own separate
file-scope ivars of the same name).

**Files**
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/PenteGame.h`
  - line 41–46 (ivar declarations)
  - line 53–58 (`@property` declarations)
- Modify: `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/PenteGame.m`
  - line 16–17 (`@synthesize`)

- [ ] **Step 1: Delete the ivar declarations in `PenteGame.h` (lines 41–46).**
  Remove:

```objc
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSNumber *, NSNumber *>
                                        *> *goStoneGroupIDsByPlayer;
    NSMutableDictionary<
        NSNumber *,
        NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *>
        *goStoneGroupsByPlayerAndID;
```

  The ivar block becomes:

```objc
@interface PenteGame : NSObject {

    AbstractBoard *abstractBoard;

    int whiteCaptures, blackCaptures;
}
```

- [ ] **Step 2: Delete the `@property` declarations in `PenteGame.h` (lines 53–58).**
  Remove:

```objc
@property(nonatomic, retain)
    NSMutableDictionary<NSNumber *, NSMutableDictionary<NSNumber *, NSNumber *>
                                        *> *goStoneGroupIDsByPlayer;
@property(nonatomic, retain) NSMutableDictionary<
    NSNumber *, NSMutableDictionary<NSNumber *, NSMutableArray<NSNumber *> *> *>
    *goStoneGroupsByPlayerAndID;
```

  (The `abstractBoard`, `whiteCaptures`/`blackCaptures`, and `captures` properties
  on lines 48–52 remain unchanged.)

- [ ] **Step 3: Delete the `@synthesize` lines in `PenteGame.m` (lines 16–17).**
  Remove:

```objc
@synthesize goStoneGroupsByPlayerAndID;
@synthesize goStoneGroupIDsByPlayer;
```

- [ ] **Step 4: Build the app target (expected PASS).** Confirms nothing referenced
  the deleted properties:

```
xcodebuild build -workspace penteLive.xcworkspace -scheme test1 \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

  Expected: `** BUILD SUCCEEDED **` (no `property 'goStoneGroupIDsByPlayer' not found`
  or `use of undeclared identifier` errors).

- [ ] **Step 5: Run the full engine test suite once more (regression guard).**

```
xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:PenteEngineTests/GoGameTests
```

  Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit.**

```
git add test1/PenteGame.h test1/PenteGame.m
git commit -m "chore(engine): delete dead goStoneGroup properties from legacy PenteGame"
```

---

**Phase 5 done.** `GoGame` is the single, tested source of truth for Go; `Table`
and `BoardViewController` route through it; the dead ObjC `PenteGame` Go properties
are gone. Because Go is fully decoupled from the Pente seam, this whole phase can
ship as an independent follow-up PR if the Pente consolidation (Phases 0–4) needs
to merge first.
