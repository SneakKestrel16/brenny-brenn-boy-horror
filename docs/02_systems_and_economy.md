# Doc 02: Systems & Economy

Owner: Game Designer. Task: PP-04. Status: done (QA passed on re-review, Director checked against doc 01,
2026-10-07).

Doc 01's numbers turned into tables the game and the season simulator can read, plus the rules
that connect them. Doc 01 is the source of truth; this doc never overrides it. A conflict or gap is
flagged in [Questions raised](#questions-raised), not resolved here.

## Contents

1. [Scope and conventions](#1-scope-and-conventions)
2. [Labor: hold seconds and plots per player (for doc 04)](#2-labor-hold-seconds-and-plots-per-player-for-doc-04)
3. [Season clock](#3-season-clock)
4. [Player-count scaling](#4-player-count-scaling)
5. [Crops](#5-crops)
6. [The Prize Pumpkin](#6-the-prize-pumpkin)
7. [Debt, payments and Foreclosure](#7-debt-payments-and-foreclosure)
8. [Medical bill](#8-medical-bill)
9. [Dawn, in order](#9-dawn-in-order)
10. [Store and items](#10-store-and-items)
11. [Ramp-up by player count](#11-ramp-up-by-player-count)
12. [Traps (economy and labor side)](#12-traps-economy-and-labor-side)
13. [Taint and Shaken](#13-taint-and-shaken)
14. [Generator and farm damage](#14-generator-and-farm-damage)
15. [Roles](#15-roles)
16. [Difficulty and the short season](#16-difficulty-and-the-short-season)
17. [Economy checks](#17-economy-checks)
18. [Season simulator design](#18-season-simulator-design)
19. [Gotchas](#19-gotchas)
20. [Questions raised](#questions-raised)
21. [Appendix A: proposed JSON schemas (CONTRACTS section 6)](#appendix-a-proposed-json-schemas-contracts-section-6)

---

## 1. Scope and conventions

Covers doc 01 "Core Loop" (timings and the dawn order), "Night Traps" (counts, clearing, the tool
shed), "Nights" (generator), "The Taint" and "Shaken", "Death and Respawning > Medical bill",
"Daytime Threats" (the trample rule), "Crops", "The Prize Pumpkin", "Season and Numbers" (all of
it except Next season, which is DD Phase 5), "Store", "Roles" and "Difficulty and group settings".

Not covered here, and owned elsewhere: what the creature senses, how it picks trap spots, the trap
race distance, the disturbance pool and the AI Director (doc 03, PP-06); where things are on the
farm (doc 04, PP-05); the interaction-hold framework, saves and log events (doc 05, PP-07).

**Source tags.** Every number carries one:

| Tag | Meaning |
|---|---|
| `01 <Heading>` | Copied from that doc 01 section |
| `01 <Heading>, scaled` | Doc 01's 4-player value scaled by section 4's rule; the arithmetic is shown |
| `sim` | Doc 01 says the simulator sets it; the value shown is the simulator's starting point |
| `placeholder` | Doc 01 gives no number; a starting value for DD Phase 1 to 4 playtests to tune |

**Inference** is marked as such, with what would settle it. "Day N" is the day after dawn N;
dawn 1 starts the season, the first payment falls at dawn 4 (after night 3) and the final at dawn 8
(after the Harvest Moon) (`01 Debt and payments`).

## 2. Labor: hold seconds and plots per player (for doc 04)

Doc 01 "Crops": "planting, watering and harvesting are each a hold of a few seconds, plus walking.
Labor is measured in seconds, and plots per player are derived from that (starting estimate about
6)." Doc 01 "Economy check": planting 16 of 24 tendable plots (8 of 12 at 2p) leaves about a third
of everyone's time for chores. So **one player tending 6 plots uses a whole day**, and the median
team plants 4 per player.

### 2.1 Hold seconds per verb

A hold is a timed interaction the player keeps a button down for; letting go cancels it. All
values are `placeholder` unless tagged; the DD Phase 1 `hold_completed` log (CONTRACTS section 10)
measures them.

| Verb | Hold (s) | Source | Notes |
|---|---|---|---|
| Plant | 3 | placeholder | "a few seconds" (`01 Crops`) |
| Water (noisy can) | 3 | placeholder | "a few seconds"; loud (`01 Farming Meets Horror`) |
| Water (quiet can) | 5 | placeholder | store item "slower, heard less far" (`01 Store`) |
| Harvest (incl. moonflowers at night) | 2 | placeholder | "a few seconds" |
| Fill watering can at the well | 4 | placeholder | well pump is a heard sound (`01 Senses`) |
| Wash off Taint at the well | 10 | 01 The Taint | "about 10 seconds of noisy pumping" |
| Water the Prize Pumpkin | 3 | placeholder | same as Water |
| Sell at the town stand (per trip) | 2 | placeholder | |
| Buy at the shipping crate (per trip) | 2 | placeholder | |
| Disarm a bear trap (kneeling still) | 5 | placeholder | "a few seconds" (`01 Night Traps`) |
| Pry free of a bear trap, solo, untainted | 4 | placeholder | doc 03 sets the race distance against this |
| Fill a pit with a shovel | 4 | placeholder | |
| Cut tripwire bells | 1 | placeholder | "cheap" (`01 Night Traps`) |
| Hang a trap on the pegboard | 1 | placeholder | |
| Place a flag | 1 | placeholder | flags are free and unlimited (`01 Night Traps`) |
| Fill a fuel can at the drum | 3 | placeholder | drum is free and infinite (`01 Nights`) |
| Refuel the generator | 4 | placeholder | |
| Repair the generator (uses 1 scrap) | 6 | placeholder | |
| Repair a fence | 5 | placeholder | |
| Clear a dead moonflower plot | 3 | placeholder | touching it Taints (`01 The Taint`) |
| Place a scarecrow | 3 | placeholder | |

**Multipliers on hold time** (all `placeholder`), each stored in one file: a teammate helping a
pry ×0.6 ("shortens the pry", `01 Day deaths`) in `labor.json` (`pry.helped_mult`); Tainted pry
×1.5 ("prying is slower", `01 The Taint`) in `taint.json` only (section 13); Mechanic repair and
refuel ×0.6 and Tracker disarm ×0.6 (`01 Roles`, "faster") in `roles.json` only (section 15).
Multipliers multiply.

### 2.2 Movement and capacities

Doc 01 gives no speeds or capacities; all `placeholder`. Movement speed belongs to the player code
(Gameplay Programmer, doc 05); these are the values the labor model and simulator assume until doc
05 settles them (Q-016).

| Value | Number | Source |
|---|---|---|
| Walk | 3.0 m/s | placeholder (doc 04 section 8.7 timed walks at 4 m/s, also placeholder) |
| Crouch-walk ("silent and slow") | 1.2 m/s | placeholder |
| Sprint | 5.0 m/s for up to 6 s, refills over 10 s | placeholder |
| After a bear trap: "40% slower for 60 s" | walk ×0.6 for 60 s | 01 Night Traps |
| Watering can capacity | 2 plots per fill | placeholder |
| Carry capacity | 4 crops | placeholder |

### 2.3 Plots per player: the derivation

Seconds of farming labor one field plot costs one player per day (turnips, the daily
harvest-replant-water cycle):

```
t_plot = h_harvest + h_plant + h_water            (holds)
       + d_step / v                               (walk to the next plot)
       + (h_fill + 2 * d_well / v) / c_can        (well trips, shared by c_can plots)
       + (L_trade / v + h_sell + h_buy) / c_carry (trade loop, shared by c_carry crops)

P = T_day / t_plot                                (plots one player can tend with no chores)
```

- `d_well`: field to well, one way. `L_trade`: field → town stand (sell) → shipping crate (seeds)
  → field. `d_step`: plot spacing, 3 m (placeholder).
- `T_day` = 540 s (section 3).
- Doc 01's target, P ≈ 6, means **t_plot ≈ 90 s**.

With the holds and capacities above (holds 8 s, `v` 3.0, can 2, carry 4), P for a range of
layouts, computed with the formula:

| `d_well` (m) | `L_trade` 200 m | 400 m | 600 m |
|---|---|---|---|
| 30 | 14.0 | 9.8 | 7.5 |
| 50 | 11.9 | 8.7 | 6.9 |
| 80 | 9.8 | 7.5 | 6.1 |

**What doc 04 needs from this:** with "few-second" holds, P ≈ 6 needs about 80 s of walking per
plot per day, roughly `d_well` 60 to 80 m and a 600 m trade loop. A compact farm (trade loop near
200 m) gives P ≈ 12 to 14 with `d_well` 30 to 50 m, and 9.8 at 80 m. The labor numbers get
tuned to doc 04's layout, not the other way round; section 2.4 checks the layout doc 04 drew.

### 2.4 Against doc 04's layout

Doc 04 section 8.7 (PP-05, after its QA fixes) gives walks as shortest paths with 1 m clearance,
timed at 3.0 m/s. With cans filled **at the well only** (inference: doc 01 names no other water; a
pump per field would be a doc 01 change, as doc 04 says):

| Field | `d_well` | `L_trade` | t_plot at 3.0 m/s | P | at 4 m/s | P |
|---|---|---|---|---|---|---|
| A (by the barn) | 58.5 m | 197.8 m | 48.0 s | 11.3 | 38.7 s | 13.9 |
| B (by the crate) | 106.5 m | 107.5 m | 56.5 s | 9.6 | 45.1 s | 12.0 |

From doc 04's walk table: `d_well` is "Well to field A centre" and "Well to field B centre".
`L_trade` for A is A → stand → crate → A (94.2 + 49.0 + 54.6); for B, B → stand → crate → B
(48.0 + 49.0 + 10.5). The 4 m/s column is for comparison only.

So **doc 04's farm gives P ≈ 10 to 11, not 6.** The walks are not too long for labor, as doc 04
feared; they are too short for doc 01's estimate with few-second holds. Q-015 item 4 asks which
knob moves.

**Why P matters (inference):** labor, not the field, is what holds the 2-player economy to doc
01's "8 of 12 at 2p". The field has 16 plots at every player count (`01 Crops`). If P ≈ 12, a
2-player team tends all 16 and earns what a 4-player team earns from the field, against 60% of the
debt. Settled by the DD Phase 1 hold and walk logs feeding the simulator.

**Until settled,** the simulator takes P = 6 from doc 01 as an input, and the median team plants
`ceil(2/3 × 6) = 4` plots per player, capped by the plots the farm has (`01 Economy check`).

## 3. Season clock

| Value | Number | Source |
|---|---|---|
| Season length | 7 days; night 7 is the Harvest Moon | 01 Season and Numbers |
| Day | 540 s (9 min) | placeholder, inside doc 01's "about 8 to 10 minutes" (`01 Core Loop`) |
| Day thirds (calm, low presence, build) | 180 s each | 01 The AI Director (thirds); seconds follow from 540 |
| Dusk | 60 s | 01 Core Loop ("about 1 minute") |
| Night, nights 1 to 6 | 300 s | 01 Nights ("about 5 minutes") |
| Harvest Moon | no timer; hard cap 900 s | 01 Nights |
| Starting bank | 60 coins | 01 Season and Numbers |

Phase IDs are CONTRACTS section 8's: `day`, `dusk`, `night`, `dawn`, `harvest_moon`.

## 4. Player-count scaling

**Rule** (`01 Ramp-up`): payments, medical bills, trap counts and the disturbance budget scale to
80% at 3 players and 60% at 2, rounded up. `01 Joining and leaving` adds the moonflower bed (1 plot
per player, `01 Crops`) and the Prize Pumpkin payout table is scaled the same way.

```
scaled(v, headcount) = ceil(v * pct / 100)      pct = 100, 80, 60 for 4, 3, 2 players
```

Computed in integers (`(v * pct + 99) // 100`), never with `0.8` or `0.6` as floats. Checked:
float `ceil(n * 0.6)` and `ceil(n * 0.8)` agree with the integer form for every n up to 2,000, so
this is a precaution, not a known bug.

**Exception: the debt.** Its total and the first-payment split round to the **nearest** coin
(section 7). Rounding up there breaks doc 01's worked example.

**Headcount** is the number of players with a body at that dawn: a late joiner counts from the
dawn they get a body, a leaver stops counting from the next dawn (`01 Joining and leaving`). One
player left pauses the season (`01 Joining and leaving`), so headcount is always 2 to 4.

Every scaled doc 01 table already lands on whole numbers (sections 7, 8 and 6); the rounding only
matters for trap and disturbance counts (section 11).

## 5. Crops

"Grows in N days" means ready on the Nth dawn after planting (`01 Crops`).

| Crop | Grows in | Seed | Sells | Profit | Profit per plot-day | Unlock | Source |
|---|---|---|---|---|---|---|---|
| `turnip` | 1 day | 4 | 10 | 6 | 6 | day 1 | 01 Crops |
| `pumpkin` | 2 days | 10 | 28 | 18 | 9 | dawn 4, only if the first payment was made | 01 Crops; D-017 |
| `moonflower` | same night | 25 | 60 | 35 | 35 (one night) | day 3 | 01 Crops |

- **Pumpkins are the first-payment reward** (`01 Crops`): they unlock at dawn 4 only if the first
  payment was made, and stay locked for the season after a missed one (D-017). This is a data
  switch, `crops.json` `unlock_rule`: `first_payment_made` (the default) or `day` (unlock at dawn
  4 regardless). The simulator runs both (section 18.2).
- **Plots:** 16 field plots at the start, up to 24 with bought plots, in two fields (`01 Crops`).
  The moonflower bed is separate: 1 plot per player (`01 Crops`).
- **Seed pack:** one seed per plot; doc 01 "Medical bill" calls 4 coins "a turnip seed pack".
- **Watering rule** (placeholder; inference from `01 The Prize Pumpkin` and "Labor"): a crop
  advances one growth day at a dawn only if it was watered the day before. Turnips and pumpkins are
  watered on the day they're planted; pumpkins again the next day. Moonflowers are watered when
  planted and harvested that night.
- **Ripe crops** stay harvestable until picked (placeholder; doc 01 is silent). Moonflowers are the
  exception: wilted by dawn, and an unpicked one becomes a Taint object whose plot can't be
  replanted until cleared (`01 Crops`).
- **End of season:** any crop still in the ground at the final dawn sells at 50% (`01 Crops`):
  turnip 5, pumpkin 14 (exact halves). Inference: ripe or not, since doc 01 says "still in the
  ground".
- **Corn** can't be planted, cut or sold (`01 Crops`).
- **Sale price** is the same at the town stand and at dawn cash-in (inference; doc 01 gives one
  price).

## 6. The Prize Pumpkin

| Size | Requirement | 4p | 3p | 2p | Source |
|---|---|---|---|---|---|
| `giant` | watered all 7 days and guarded 2 nights | 250 | 200 | 150 | 01 Prize Pumpkin payout |
| `large` | watered 5 to 7 days | 150 | 120 | 90 | 01 Prize Pumpkin payout |
| `medium` | watered 3 to 4 days | 75 | 60 | 45 | 01 Prize Pumpkin payout |
| `sad` | watered 0 to 2 days | 20 | 16 | 12 | 01 Prize Pumpkin payout |

Doc 01's 3p and 2p columns equal `scaled()` of the 4p column exactly (250 × 80 / 100 = 200,
250 × 60 / 100 = 150, and so on), so the data stores the 4p column only.

- **Seed:** free, planted on day 1 (D-017; the perfect-start check in section 17 reproduces doc
  01's 322 and 194 only if it costs nothing).
- **Placement:** at least 30 m from any building's door, between the farmhouse and the first corn
  strip (`01 The Prize Pumpkin`). Doc 04's concern.
- **Guarded night:** a living player outdoors within 20 m of it for at least 60 s of that night,
  not counting time inside a lit doorway's light; needed on at least 2 of nights 1 to 6 for Giant
  (`01 The Prize Pumpkin`).
- **Size** comes from the count of watered days (D-017): the table is count-based, so "shrinks or
  rots on days it isn't" is what the player *sees* on an unwatered day, not a second rule.
- **Drops one size** per gnawed night (from night 3, any night nobody is within 20 m) and per
  escort bite (at most 2) (`01 The Prize Pumpkin`, `01 The Harvest Moon`). Sad is the floor.
  The simulator reads "nobody within 20 m" as "not guarded that night" (D-017, until doc 03 sets
  the creature's gnawing rule).
- **Payout** counts toward the final payment (`01 Debt and payments`).

## 7. Debt, payments and Foreclosure

### 7.1 Doc 01's table

| Players | Total debt | First payment (dawn 4) | Final payment (dawn 8) | Source |
|---|---|---|---|---|
| 4 | 1,300 | 255 | 1,045 | 01 Debt and payments |
| 3 | 1,040 | 204 | 836 | 01 Debt and payments |
| 2 | 780 | 153 | 627 | 01 Debt and payments |

The data stores only 1,300 and 255; the formula below produces the whole table.

### 7.2 The formula

From `01 Joining and leaving`, in integer form. `pct_d` is the headcount percentage fixed when
dawn `d` begins (100, 80, 60), for d = 1 to 7. Past days use the recorded value, future days the
current headcount.

```
total      = round_half_up(1300 * sum(pct_d) / 700)       # each day carries 1/7 of 1,300
first      = round_half_up(255 * total / 1300)            # only while dawn 4 is still ahead
final      = total - first
still_owed = total - payments_made + foreclosure_penalty + deferred_bills
```

Foreclosure penalties and deferred bills never rescale (`01 Joining and leaving`). Once dawn 4 has
begun the first payment is locked (`01 Joining and leaving` "Payments lock"), and the final is
`still_owed`.

**Rounding is to the nearest coin, not up.** Doc 01 says the split is "rounded"; the total's
rounding isn't stated. Only nearest (or down) reproduces doc 01's example; rounding up gives 1,078
and 212.

### 7.3 Doc 01's example, reproduced

4 players, one drops before dawn 2 (`01 Joining and leaving`):

```
pct = 100, 80, 80, 80, 80, 80, 80          sum = 580
total = 1300 * 580 / 700 = 754000 / 700 = 1077.142857...  -> 1,077
        (doc 01's form: 185.714 + 6 * 148.571 = 185.714 + 891.429 = 1077.143)
first = 255 * 1077 / 1300 = 274635 / 1300 = 211.257...   -> 211
final = 1077 - 211 = 866
```

1,077 total and 211 first payment, exactly as doc 01. Splitting the unrounded total gives
255 × 580 / 700 = 211.29, also 211.

**The table, from the formula:** 3 players all season, sum 560: 1300 × 560 / 700 = 1,040; first
255 × 1040 / 1300 = 204; final 836. 2 players, sum 420: 780; first 153; final 627. All match 7.1.

**Two more cases** (my arithmetic, for tests):
- 2 players, a third gets a body at dawn 3: sum 60 + 60 + 5 × 80 = 520; total 1300 × 520 / 700 =
  965.71 → 966; first 255 × 966 / 1300 = 189.48 → 189; final 777.
- 4 players pay 255 at dawn 4, one leaves before dawn 6: sum 5 × 100 + 2 × 80 = 660; total
  1225.71 → 1,226; still owed 1226 − 255 = 971.

### 7.4 Payments

- **Early payment** is allowed at any dawn (`01 Debt and payments`). It goes to the first payment
  until that is covered, then to the final (inference).
- **Missed first payment (Foreclosure Notice):** not a loss. `penalty = ceil(1.5 × shortfall)` is
  added to the final payment, and the bank seizes one upgrade or 2 plots, its choice
  (`01 Debt and payments`). Rounding up on a .5 is placeholder (`season.json`
  `foreclosure_penalty_rounding`).
  - **Partial payment** (D-017): at dawn 4 the bank takes every coin down to the 4-coin floor the
    medical bill uses, and the shortfall is what remains.
  - **Pumpkins stay locked** for the rest of the season after a missed first payment (D-017;
    section 5).
  - **Bank's choice** (placeholder, `season.json` `foreclosure_seizure_order`): it seizes the most
    expensive upgrade the team owns if that cost more than 2 plots did; otherwise 2 bought plots,
    otherwise 2 starting plots.
- **Final payment, dawn 8:** cash-in, end-of-season sale, festival payout, then the bill, then the
  payment (section 9). Short of `still_owed` is a loss (`01 Debt and payments`).
- **Win:** final payment made and the cart out the gate with at least one player alive
  (`01 Debt and payments`).

## 8. Medical bill

| Players | First death a night | Each later death | Nightly cap | Source |
|---|---|---|---|---|
| 4 | 25 | 50 | 120 | 01 Death and Respawning |
| 3 | 20 | 40 | 96 | 01 Death and Respawning (= scaled 4p values) |
| 2 | 15 | 30 | 72 | 01 Death and Respawning (= scaled 4p values) |

- "A night" is a day-night cycle: day deaths count (`01 Day deaths`), billed at the next dawn.
- **Floor:** the bill never takes the bank below 4 coins; what it can't cover is added to the final
  payment (`01 Death and Respawning`).
- **Headcount** is the one at the dawn that bills (inference).
- **The cap only bites with 3+ deaths:** 4p 25 + 50 + 50 = 125 → 120; 3p 20 + 40 + 40 = 100 → 96.
  At 2p the most is 15 + 30 = 45, so the 72 cap is never reached (each player dies at most once a
  cycle, since the dead are out until dawn).

## 9. Dawn, in order

From `01 Core Loop` "Dawn, in this order", with the steps doc 01 places elsewhere:

1. **Cash-in:** survivors sell what they carry at full price; the dead lose what they carried.
2. **Final dawn only:** crops in the ground sell at 50%; the festival payout is added.
3. **Medical bill** (section 8).
4. **Payment due** (section 7), and any early payment.
5. **Farm damage** (section 14). After a full wipe, damage doubles and extra traps appear.
6. **Save** (`01 Saving`).
7. **Free scrap** (1, section 10) and the flare gun refill.

Steps 6 and 7's position is inference; they don't affect money.

## 10. Store and items

Bought at the shipping crate (`01 Store`), which is the store only; crops are sold at the town
stand and at the dawn cash-in (D-017). `sim` prices are the simulator's starting points.

| Item | Price | Source | Rule |
|---|---|---|---|
| `turnip_seed` | 4 | 01 Crops | per plot |
| `pumpkin_seed` | 10 | 01 Crops | from dawn 4 |
| `moonflower_seed` | 25 | 01 Crops | from day 3 |
| `shed_lock` | 40 | 01 Store | caps theft at one trap a night; no effect from night 5 (`01 The tool shed`) |
| `scrap` | 15 | 01 Store | one free each dawn; the free one doesn't stack (placeholder, `season.json` `free_scrap_stacks`) |
| `quiet_watering_can` | 30 | sim | hold 5 s, heard less far (radius in doc 03) |
| `walkie_talkie` | 30 each | sim | one per player; 1 battery included |
| `walkie_battery` | 10 | sim | 180 s of transmitting (placeholder) |
| `brighter_lantern` | 25 | sim | light radius in doc 03 |
| `scarecrow` | 20 | sim | effect in doc 03 |
| `plot_pair` | 40 | sim | 2 field plots, 16 to 24 |
| `flare_gun` | 50 | sim | one shot, refilled each dawn; scares the creature off for 30 s (`01 Store`) |

- Cosmetics are DD Phase 5 and out of scope.
- **Walkies:** doc 01 calls them "craftable" (`01 How players fight back`) and lists them in the
  store. They are bought; no crafting system exists (D-017).
- **Plots sold in pairs** because Foreclosure seizes 2 (placeholder).
- **Upgrades** (what Foreclosure can seize): every bought item except seeds and scrap.

## 11. Ramp-up by player count

`01 Ramp-up (4 players)` scaled with section 4's rule. Bear / pits / bells; night 7 "hunts all
night" sets no trap count.

| Day | Disturbances 4p | 3p | 2p | Traps 4p | 3p | 2p |
|---|---|---|---|---|---|---|
| 1 | 1 | 1 | 1 | 2 / 1 / 0 | 2 / 1 / 0 | 2 / 1 / 0 |
| 2 | 1 | 1 | 1 | 2 / 2 / 0 | 2 / 2 / 0 | 2 / 2 / 0 |
| 3 | 2 | 2 | 2 | 3 / 2 / 0 | 3 / 2 / 0 | 2 / 2 / 0 |
| 4 | 2 | 2 | 2 | 3 / 2 / 1 | 3 / 2 / 1 | 2 / 2 / 1 |
| 5 | 3 | 3 | 2 | 4 / 3 / 1 | 4 / 3 / 1 | 3 / 2 / 1 |
| 6 | 3 | 3 | 2 | 5 / 3 / 2 | 4 / 3 / 2 | 3 / 2 / 2 |
| 7 | 4 | 4 | 3 | hunts all night | | |

Worked: 3p bear day 5 = ceil(4 × 0.8) = ceil(3.2) = 4; 2p bells day 6 = ceil(2 × 0.6) = ceil(1.2)
= 2; 2p disturbances day 5 = ceil(3 × 0.6) = ceil(1.8) = 2.

Voice (exact through day 3, spliced from day 4) and the "New" column belong to doc 03 and are not
scaled. Unlock days used here: moonflowers, Taint sources and pumpkin gnawing day 3; pumpkins and
bells day 4; lock-breaking and flag-moving day 5 (`01 Ramp-up`).

**Rounding up favours the creature at 3p and 2p** (inference from the table): 3p gets 4p's
disturbances every day and 4p's traps on 5 of 6 nights; 2p faces 1.5 to 3.5 traps per player a
night against 4p's 0.75 to 2.5. Doc 01 asks for it; the simulator measures what it costs in chore
time.

## 12. Traps (economy and labor side)

How traps are placed, sprung and raced is doc 03. What they cost the economy:

| Trap | Clear by | Hold | Cost to the team | Source |
|---|---|---|---|---|
| `bear_trap` | disarm with a tool, kneeling still | 5 s | caught: pinned until pried (4 s solo), then walk ×0.6 for 60 s, Shaken if it was a day race | 01 Night Traps; holds placeholder |
| `pit` | fill with a shovel | 4 s | stumble, drop what you carry | 01 Night Traps; hold placeholder |
| `tripwire_bells` | cut | 1 s | loud; tells the creature where you are | 01 Night Traps; hold placeholder |

- **Pegboard:** each bear trap not on the pegboard at nightfall is the creature's to take; the
  starting pegboard holds the 4p maximum, 5 bear traps (placeholder, `season.json`
  `pegboard_bear_slots`; inferred from the day 6 count; doc 03 settles theft).
- **Flags** are free (`01 Night Traps`).

## 13. Taint and Shaken

| State | Effect | Number | Source |
|---|---|---|---|
| Taint | sprint runs out 40% sooner | sprint time ×0.6 | 01 The Taint |
| Taint | prying slower | pry ×1.5 | placeholder |
| Taint | footsteps heard 50% further | footstep radius ×1.5 | 01 The Taint |
| Taint | night trail; more hallucinations | doc 03 | 01 The Taint |
| Taint | cure | 10 s pumping at the well | 01 The Taint |
| Shaken | shortens sprint for 60 s | sprint time ×0.6 for 60 s | 01 The Taint (60 s); ×0.6 placeholder |
| Bear trap | slow after escaping | walk ×0.6 for 60 s | 01 Night Traps |

- **Taint causes** (`01 The Taint`): creature leavings, a stolen tool, an item left in the field
  at dusk (the item stays Tainted until picked up), an unpicked moonflower. Taint lasts until
  washed or dawn; Tainted twice changes nothing.
- **Shaken causes:** jumpscares and surviving a trap race; never Taints; a new cause restarts the
  60 s (placeholder).
- **Stacking:** Taint and Shaken multiply (sprint ×0.36) (placeholder).

## 14. Generator and farm damage

| Value | Number | Source |
|---|---|---|
| Fuel burn | burns only at dusk and night; a full tank lasts 210 s | placeholder: "runs low mid-night" (`01 Nights`) after a top-up at dusk |
| Dimming | dims steadily below 25% fuel, never flickers | 01 Nights (rule); 25% placeholder |
| Fuel can | refills 50% of the tank | placeholder |
| Repair | 1 scrap, 6 s hold | 01 Nights (scrap); hold placeholder |
| Nightmare fuel | tank ×0.75 | placeholder ("less fuel", `01 Difficulty and group settings`); section 16 |

**Trampled plots at dawn** (`01 Daytime Threats`): 1 plot a night; 2 if nobody was outside; +1 if
the generator was left dead at dawn (`season.json` `trample_*`). After a full wipe the damage
doubles (`01 Core Loop`; `full_wipe_damage_mult` 2) and extra traps appear (`01 Core Loop`; 2 more
traps, placeholder, `full_wipe_extra_traps`, until doc 03 sets the mix). "Nobody outside"
means no living player spent 30 s outdoors that night (placeholder). Trampled crops are lost; the
plot can be replanted. The "unattended farm" scaling beyond this and the disturbance pool are doc
03's.

## 15. Roles

Optional, best at 4 players; none required to win (`01 Roles`).

| Role | Perk | Number | Source |
|---|---|---|---|
| `farmer` | +1 crop every 5th harvest | counter per Farmer | 01 Roles |
| `rancher` | handles animals | round-up time ×0.6 (placeholder) | 01 Roles |
| `mechanic` | repairs and refuels faster | hold ×0.6 | placeholder |
| `tracker` | spots trap clues more easily, disarms faster | disarm ×0.6; clue range in doc 03 | placeholder |

## 16. Difficulty and the short season

Stored in `difficulty.json`, one record per setting, applied after headcount scaling and rounded
up (placeholder):

| Setting | Traps | Bills | Generator tank | Source |
|---|---|---|---|---|
| `easy` | ×0.75 | ×0.5 | ×1 | "fewer traps, gentler bills" (`01 Difficulty and group settings`); numbers placeholder |
| `normal` | ×1 | ×1 | ×1 | 01 Difficulty and group settings |
| `nightmare` | ×1 | ×1 | ×0.75 | "less fuel" (`01 Difficulty and group settings`); 0.75 placeholder |

Nightmare's other changes (wider distance bends, no voice tells) are doc 03's.

**Short season:** 3 days with a faster-growing Prize Pumpkin; "its numbers are set with the
simulator" (`01 Saving`). All `sim`, not set here: debt, payment dawns, pumpkin size thresholds.

## 17. Economy checks

### 17.1 The perfect start reproduces doc 01

Doc 01 "Economy check": no deaths, turnips on every tendable plot, moonflowers from day 3 → 322
coins at 4p and 194 at 2p at the first payment. Reproduced with 4 planted plots per player,
1 moonflower plot per player, seeds bought on the day, no store purchases, a free Prize Pumpkin.

"Every tendable plot" is read as the 4 plots per player doc 01's "Economy check" plants ("16 of 24
tendable", "8 of 12 at 2p"), not all 6 tendable (inference: 6 per player gives 226 at 2p, not 194).
The free seed is D-017's ruling, made because only it reproduces these numbers.

**4 players** (16 plots, 4 moonflowers):
```
day 1: 60 coins buys 15 turnips (60/4)              -> 0
day 2: sell 15 (+150), plant 16 (-64)               -> 86
day 3: sell 16 (+160), plant 16 (-64), 4 moon (-100) -> 82
night 3: harvest 4 moonflowers, sold at cash-in (+240) -> 322 at dawn 4
```
**2 players** (8 plots, 2 moonflowers): 60 − 32 = 28; +80 − 32 = 76; +80 − 32 − 50 = 74; +120 =
**194**. **3 players** (12 plots, 3 moonflowers), same method: **261**.

Over the first payment: 322 / 255 = 1.26, 261 / 204 = 1.28, 194 / 153 = 1.27, doc 01's "about 25%".
Two details only show up because the numbers match exactly: the 4p team can afford 15 turnips on
day 1, not 16, and the Prize Pumpkin seed costs nothing.

### 17.2 A full-season projection (a sanity check, not the simulator)

Deterministic, computed by `tools/sim/projection.py` (`uv run --no-project python -I
tools/sim/projection.py`), which copies doc 01's numbers because `data/` doesn't exist yet. Its
rules, in order each day and dawn:

- **Day d (1 to 7):** harvest and sell every ripe field crop at the town stand. From day 3, buy and
  plant 1 moonflower per player first. Then fill free field plots (4 per player, at most 16): a
  pumpkin on days 4 and 5 if pumpkins are unlocked, otherwise a turnip; a plot the team can't
  afford a pumpkin for gets a turnip; planting stops when the team can't afford a turnip.
- **Dawn d + 1, in order:** cash-in of that night's moonflowers; at dawn 8, every crop in the
  ground at 50% plus a Large payout; the medical bill; one trample; the payment at dawn 4 (paid in
  full, or Foreclosure as section 7.4, which locks pumpkins) and the check against `still_owed` at
  dawn 8.
- **Perfect:** no deaths, no trampling.
- **Rough median:** one death on each of nights 2, 4 and 6, billed at the first-death rate at the
  next dawn (floor 4, the rest deferred to the final), and the dead player's moonflower that night
  lost (night 2 has none); one crop trampled every dawn from 2 to 8, always the dearest growing one
  (a pumpkin if any). No purchases besides seeds.

| Players | Final owed | Perfect: coins at dawn 8 | margin | Rough median: coins | owed | margin |
|---|---|---|---|---|---|---|
| 4 | 1,045 | 1,319 | +274 | 938 | 1,045 | −107 |
| 3 | 836 | 1,005 | +169 | 633 | 836 | −203 |
| 2 | 627 | 685 | +58 | 334 | 627 | −293 |

QA's reproduction of the first version got 1,043 to 1,130, 738 to 837 and 398 to 532 for the rough
median across its readings; the first version's rules were not written down, and this table
replaces it. Trampling the cheapest growing crop instead of the dearest adds only 12 to 30 coins
(968, 663, 346), so the trample target is not what separates these numbers from QA's.

With pumpkins never unlocked (the `unlock_rule` default after a missed first payment), the rough
median ends at 986, 705 and 406 (margins −59, −131, −221). In the perfect season pumpkins add 42
to 78 coins (locked: 1,241, 945, 643); in the rough median, where the trample takes a pumpkin
whenever one is growing, they cost 48 to 72. So the first-payment reward is only worth having if
the team can protect it, which the simulator should report.

Findings, inference until the simulator runs:
- **2 players are structurally poorer.** Income scales with headcount (4 plots and 1 moonflower per
  player: 50% at 2p) while the debt scales to 60%. The unscaled 60 starting coins hide it at dawn 4.
  At dawn 8 the 2p rough median falls short by 47% of its final payment, the 4p one by 10%. This
  likely breaks the "at most 10 points" spread target. Levers: plots per player at 2p (labor,
  section 2), or doc 01's scaling (a CEO change).
- **The final payment looks hard** even at 4p with a Large pumpkin. Bought plots are **not** a
  lever for the median team at P = 6: it plants 4 plots per player, which is all 16 starting plots
  at 4p and fewer than 16 at 3p and 2p, so an extra plot never gets planted (section 18.2). The
  levers left are P itself (if labor allows more than 4 plots a player, bought plots start to pay
  at 4p) and doc 01's numbers.

## 18. Season simulator design

Building it is a later task; this is the design. The simulator gates DD Phase 4 (`01 Season
simulator`).

### 18.1 Shape

- `tools/sim/`, Python 3.13 run with `uv`, standard library only. It reads the same `data/*.json`
  as the game (D-002) and copies no number into code.
- **Granularity:** one step per phase (day, dusk, night, dawn) per day. Not spatial: actions cost
  seconds from `labor.json` and layout distances from `tools/sim/layout.json`, a copy of doc 04's
  distances that cites doc 04.
- **Command:** `uv run tools/sim/sim.py --players 2,3,4 --runs 10000 --seed 1 [--policy median]
  [--scenario <file>]`. A fixed seed gives identical output.

### 18.2 Inputs

- All of `data/` (Appendix A).
- **Policy** (`tools/sim/policies/median.json`), doc 01's median team:
  - plays greedily: each plot gets the crop with the best profit per plot-day that ripens before
    dawn 8, or sells at 50% in the ground if better; moonflowers on every bed plot from day 3;
  - keeps a third of its time for chores: plants `ceil(2/3 × P)` plots per player, P from section 2;
  - takes scheduled sabotage (doc 03's `sabotage.json`) plus the trample rule;
  - one death on each of 3 nights, the nights drawn at random from 1 to 7 (placeholder);
  - delivers a Large pumpkin;
  - buys by a rule (placeholder): scrap when the generator is damaged, a `plot_pair` only when its
    planting cap (`ceil(2/3 × P)` × headcount) exceeds the plots it owns and the pair pays back
    before dawn 8, nothing else unless a scenario says so; pays only what is due. At P = 6 the cap
    never exceeds 16, so the median team never buys plots; a P above 6 (section 2.4) makes plots
    matter at 4p first.
- **Variance sources** (all placeholder distributions, logged per run). Without them the median
  team is deterministic and every target reads 0% or 100%, so these shape the result as much as
  any price:
  - hold-time and walk-time jitter (±20%, uniform);
  - which nights the deaths fall on, and what the dead were carrying (0 to carry capacity);
  - sabotage draws from doc 03's pool and their time cost;
  - trap clearing time (each trap's clear hold plus a walk drawn from layout distances);
  - which crops are trampled.
- **Scenarios:** headcount changes (join or leave before dawn N), short season, Easy and Nightmare,
  and **`unlock_rule` both ways**: the default `first_payment_made` (D-017) and `day` (pumpkins
  unlock at dawn 4 even after a missed first payment). Every summary reports both.

### 18.3 Outputs

Per player count: share of runs clearing the first payment, the final payment, and winning;
Foreclosure rate; median and quartile margin at dawns 4 and 8; bank by dawn; spread across player
counts. Written as `tools/sim/out/<seed>/summary.json` and `runs.csv`, plus a pass/fail line per
target. Exit code 1 if a target fails.

| Target | Value | Source |
|---|---|---|
| Median team clears the first payment | about 85% (pass band 80 to 90%, placeholder) | 01 Season simulator |
| Median team clears the final payment | 55 to 70% | 01 Season simulator |
| Spread across player counts | at most 10 points, for the first and the final clear rate each | 01 Season simulator |
| Median team needs a Large pumpkin | with a Medium pumpkin instead, the final clear rate is at least 30 points lower than with Large (placeholder) | 01 Debt and payments |

**Spread** is max minus min of a rate across the 2p, 3p and 4p runs, in percentage points,
checked separately for the first-payment and the final-payment clear rates (inference: doc 01 says
only "spread across player counts"; checking both is the stricter reading).

### 18.4 Tests that must pass before tuning

- Section 17.1: 322, 261 and 194 under the perfect-start policy.
- Section 7.3: 1,077 and 211; the 7.1 table from the formula; the two extra cases.
- Every per-count table in sections 6, 8 and 11 from `scaled()`.

### 18.5 Checking it against playtests

A `compare` command reads the host's `money_changed` events (CONTRACTS section 10) by dawn and
places each live season inside the simulated distribution. Doc 01: logs must land within 15 points
of the sim before the numbers freeze (`01 Season simulator`).

**Metric (Q-038; inference, doc 01 gives only "within 15 points"):** per dawn, the live median of
money (coins) as a percentage of the next payment due, against the simulated median for the same
player count; every dawn from 2 to 8 must be within 15 points. First and final clear rates are
reported beside it but do not gate: with 6 seasons one rate has a confidence band far wider than 15
points. **Seasons:** at least 6 full live seasons, 2 per player count (placeholder, QA's proposal
accepted); the simulator side runs 1,000 or more seasons per count. Settle with the first real logs:
if live spread exceeds 15 points, widen the sample before touching numbers.

### 18.6 Tuning

Only `sim` and `placeholder` values move. One knob per change, the seed fixed, before and after
summaries kept, and each accepted change recorded in this doc with its result.

## 19. Gotchas

- **The debt rounds to nearest; everything else scaled rounds up.** Rounding the debt up gives
  1,078 and 212 instead of doc 01's 1,077 and 211.
- **Doc 01's per-count tables are already scaled 4p tables.** Store the 4p column only, or the two
  copies drift.
- **The 2p medical cap of 72 is unreachable** (most is 45). The cap only matters with 3+ deaths.
- **Ceil makes 3p look like 4p:** disturbances identical every day, traps on 5 of 6 nights.
- **Perfect start:** 60 coins buys 15 turnips, not 16; the Prize Pumpkin seed must be free.
- **Dawn-4 money hides the 2p gap**: 60 unscaled starting coins are a bigger share at 2p. Look at
  dawn 8.
- **Labor is the 2p balance lever,** not the field: 16 plots at every headcount.
- **Bought plots do nothing for a team that plants 4 a player** at P = 6; only a higher P makes
  them pay.
- **A projection without written rules can't be checked.** 17.2's first version wasn't
  reproducible; its rules now sit beside the numbers and the script is kept.
- **Each multiplier lives in one file** (taint pry in `taint.json`, role perks in `roles.json`);
  a copy in `labor.json` would drift.

## Questions raised

- **Q-015** (to the Director): answered by D-017 for the doc 01 readings (partial payment,
  pumpkins locked after a missed first payment, the crate as store only, the free Prize Pumpkin
  seed, debt rounding, walkies bought, gnawing, size by count). Items 4 (labor vs P ≈ 6) and 5 (the
  2p gap) wait for the simulator and may go to the CEO at PP-12; item 5's numbers were corrected
  on 2026-10-07 (section 17.2).
- **Reply on Q-014 item 2** (to the Level Designer): walk speed, refill point and plots per can
  for doc 04, and section 2.4's check of doc 04's walks.
- **Q-016** (to the Gameplay Programmer): movement speeds and sprint numbers.

---

## Appendix A: proposed JSON schemas (CONTRACTS section 6)

Proposed, not approved: CONTRACTS section 6 changes only with the Director's approval and a
DECISIONS entry. One JSON Schema (draft 2020-12) per data file, so QA can validate `data/*.json`
against them. Each was checked with `jsonschema` 4 (`Draft202012Validator.check_schema`), and an
example file built from this doc's tables validated against each, while three broken copies of
each example (a required record missing, a stray field, a bad source tag) were rejected.

### A.1 Shared rules

- **Envelope:** every file is `{"table": "<file name>", "schema_version": 1, "records": [...]}`.
- **`id`:** `snake_case` (CONTRACTS section 3). Each schema lists the ids its file must contain
  (`allOf` / `contains`); a file may add records. **Ids are unique per file**, which JSON Schema
  can't check; the `Data` loader and `tools/sim/` reject duplicates.
- **`source`:** `doc01`, `sim` or `placeholder` for every number in the record. `sources` overrides
  it per field, for example `{"pry_mult": "placeholder"}`. `cite` names the doc 01 heading.
- **Field suffixes:** `_s` seconds, `_m` metres, `_mps` metres per second, `_pct` an integer
  percent, `_mult` a multiplier. **`_4p`** is a 4-player value the reader scales with
  `player_scaling.json` (round up), except in `debt.json` (nearest). Coins are integers.
- **One home per value.** A multiplier or rule appears in one file only (section 19).
- **Files:** the 13 below. `season.json`, `labor.json` and `difficulty.json` are new beyond
  CONTRACTS' list. `sabotage.json`, `ai_director.json`, `voice_lines.json` and
  `dawn_report_templates.json` are PP-06's.

`season.json` ids, for reference:

| id | value | source |
|---|---|---|
| `start_coins` | 60 | doc01 Season and Numbers |
| `season_days` | 7 | doc01 Season and Numbers |
| `day_s` | 540 | placeholder |
| `dusk_s` | 60 | doc01 Core Loop |
| `night_s` | 300 | doc01 Nights |
| `harvest_moon_cap_s` | 900 | doc01 Nights |
| `first_payment_dawn` | 4 | doc01 Debt and payments |
| `final_payment_dawn` | 8 | doc01 Debt and payments |
| `field_plots_start` | 16 | doc01 Crops |
| `field_plots_max` | 24 | doc01 Crops |
| `moonflower_plots_per_player` | 1 | doc01 Crops |
| `end_season_sale_pct` | 50 | doc01 Crops |
| `bank_floor` | 4 | doc01 Death and Respawning |
| `foreclosure_penalty_pct` | 150 | doc01 Debt and payments |
| `foreclosure_penalty_rounding` | "ceil" | placeholder |
| `foreclosure_seized_plots` | 2 | doc01 Debt and payments |
| `foreclosure_seizure_order` | ["dearest_upgrade_over_2_plots", "bought_plots", "starting_plots"] | placeholder |
| `sanctuary_m` | 10 | doc01 The AI Director |
| `plots_per_player` | 6 | doc01 Crops |
| `chore_share_pct` | 33 | doc01 Season simulator |
| `pegboard_bear_slots` | 5 | placeholder |
| `generator_tank_s` | 210 | placeholder |
| `generator_dim_pct` | 25 | placeholder |
| `fuel_can_pct` | 50 | placeholder |
| `trample_base` | 1 | doc01 Daytime Threats |
| `trample_nobody_outside` | 2 | doc01 Daytime Threats |
| `trample_dead_generator` | 1 | doc01 Daytime Threats |
| `nobody_outside_s` | 30 | placeholder |
| `full_wipe_damage_mult` | 2 | doc01 Core Loop |
| `full_wipe_extra_traps` | 2 | placeholder |
| `free_scrap_per_dawn` | 1 | doc01 Nights |
| `free_scrap_stacks` | false | placeholder |

### A.2 `season.json`

Named constants: one record per value, each `{id, value, unit, source, cite}`. The schema requires
every id below; values are set in the sections cited.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "data/season.schema.json",
  "title": "Named season constants (doc 02 A.2)",
  "type": "object",
  "additionalProperties": false,
  "required": ["table", "schema_version", "records"],
  "properties": {
    "table": {"const": "season"},
    "schema_version": {"const": 1},
    "records": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "id": {"$ref": "#/$defs/id"},
          "source": {"$ref": "#/$defs/source"},
          "cite": {"type": "string"},
          "sources": {"$ref": "#/$defs/sources"},
          "value": {"type": ["number", "string", "boolean", "array"], "items": {"type": "string"}},
          "unit": {"enum": ["s", "m", "coins", "pct", "count", "mult", "dawn"]}
        },
        "required": ["id", "source", "value"]
      },
      "allOf": [
        {"contains": {"properties": {"id": {"const": "start_coins"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "season_days"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "day_s"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "dusk_s"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "night_s"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "harvest_moon_cap_s"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "first_payment_dawn"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "final_payment_dawn"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "field_plots_start"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "field_plots_max"}}, "required": ["id"]}},
        {
          "contains": {
            "properties": {"id": {"const": "moonflower_plots_per_player"}},
            "required": ["id"]
          }
        },
        {"contains": {"properties": {"id": {"const": "end_season_sale_pct"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "bank_floor"}}, "required": ["id"]}},
        {
          "contains": {
            "properties": {"id": {"const": "foreclosure_penalty_pct"}},
            "required": ["id"]
          }
        },
        {
          "contains": {
            "properties": {"id": {"const": "foreclosure_penalty_rounding"}},
            "required": ["id"]
          }
        },
        {
          "contains": {
            "properties": {"id": {"const": "foreclosure_seized_plots"}},
            "required": ["id"]
          }
        },
        {
          "contains": {
            "properties": {"id": {"const": "foreclosure_seizure_order"}},
            "required": ["id"]
          }
        },
        {"contains": {"properties": {"id": {"const": "sanctuary_m"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "plots_per_player"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "chore_share_pct"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "pegboard_bear_slots"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "generator_tank_s"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "generator_dim_pct"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "fuel_can_pct"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "trample_base"}}, "required": ["id"]}},
        {
          "contains": {
            "properties": {"id": {"const": "trample_nobody_outside"}},
            "required": ["id"]
          }
        },
        {
          "contains": {
            "properties": {"id": {"const": "trample_dead_generator"}},
            "required": ["id"]
          }
        },
        {"contains": {"properties": {"id": {"const": "nobody_outside_s"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "full_wipe_damage_mult"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "full_wipe_extra_traps"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "free_scrap_per_dawn"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "free_scrap_stacks"}}, "required": ["id"]}}
      ]
    }
  },
  "$defs": {
    "id": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
    "source": {"enum": ["doc01", "sim", "placeholder"]},
    "sources": {"type": "object", "additionalProperties": {"enum": ["doc01", "sim", "placeholder"]}}
  }
}
```

### A.3 `labor.json`

Section 2. Three record kinds: `hold` (a verb's hold), `move` (a speed) and `capacity`. Role and
Taint multipliers are not here (sections 13 and 15).

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "data/labor.schema.json",
  "title": "Hold seconds, movement speeds and capacities (doc 02 section 2)",
  "type": "object",
  "additionalProperties": false,
  "required": ["table", "schema_version", "records"],
  "properties": {
    "table": {"const": "labor"},
    "schema_version": {"const": 1},
    "records": {
      "type": "array",
      "minItems": 1,
      "items": {
        "oneOf": [
          {
            "type": "object",
            "additionalProperties": false,
            "properties": {
              "id": {"$ref": "#/$defs/id"},
              "source": {"$ref": "#/$defs/source"},
              "cite": {"type": "string"},
              "sources": {"$ref": "#/$defs/sources"},
              "kind": {"const": "hold"},
              "hold_s": {"type": "number", "exclusiveMinimum": 0},
              "helped_mult": {"type": "number", "exclusiveMinimum": 0}
            },
            "required": ["id", "source", "kind", "hold_s"]
          },
          {
            "type": "object",
            "additionalProperties": false,
            "properties": {
              "id": {"$ref": "#/$defs/id"},
              "source": {"$ref": "#/$defs/source"},
              "cite": {"type": "string"},
              "sources": {"$ref": "#/$defs/sources"},
              "kind": {"const": "move"},
              "speed_mps": {"type": "number", "exclusiveMinimum": 0},
              "max_s": {"type": "number", "exclusiveMinimum": 0},
              "refill_s": {"type": "number", "exclusiveMinimum": 0}
            },
            "required": ["id", "source", "kind", "speed_mps"]
          },
          {
            "type": "object",
            "additionalProperties": false,
            "properties": {
              "id": {"$ref": "#/$defs/id"},
              "source": {"$ref": "#/$defs/source"},
              "cite": {"type": "string"},
              "sources": {"$ref": "#/$defs/sources"},
              "kind": {"const": "capacity"},
              "capacity": {"type": "integer", "minimum": 1}
            },
            "required": ["id", "source", "kind", "capacity"]
          }
        ]
      },
      "allOf": [
        {"contains": {"properties": {"id": {"const": "plant"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "water"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "water_quiet"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "harvest"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "fill_can"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "wash"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "water_prize_pumpkin"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "sell"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "buy"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "disarm_bear"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "pry"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "fill_pit"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "cut_bells"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "hang_trap"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "place_flag"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "fill_fuel"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "refuel"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "repair_generator"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "repair_fence"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "clear_plot"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "place_scarecrow"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "walk"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "crouch"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "sprint"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "can"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "carry"}}, "required": ["id"]}}
      ]
    }
  },
  "$defs": {
    "id": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
    "source": {"enum": ["doc01", "sim", "placeholder"]},
    "sources": {"type": "object", "additionalProperties": {"enum": ["doc01", "sim", "placeholder"]}}
  }
}
```

### A.4 `crops.json`

Section 5. Profit is derived, not stored. `unlock_rule` defaults to `first_payment_made` for
pumpkins (D-017).

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "data/crops.schema.json",
  "title": "Crops (doc 02 section 5)",
  "type": "object",
  "additionalProperties": false,
  "required": ["table", "schema_version", "records"],
  "properties": {
    "table": {"const": "crops"},
    "schema_version": {"const": 1},
    "records": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "id": {"$ref": "#/$defs/id"},
          "source": {"$ref": "#/$defs/source"},
          "cite": {"type": "string"},
          "sources": {"$ref": "#/$defs/sources"},
          "name": {"type": "string"},
          "grow_days": {"type": "integer", "minimum": 0},
          "seed": {"type": "integer", "minimum": 0},
          "sell": {"type": "integer", "minimum": 0},
          "unlock_day": {"type": "integer", "minimum": 1, "maximum": 7},
          "unlock_rule": {"enum": ["day", "first_payment_made"]},
          "harvest_phase": {"enum": ["day", "night"]},
          "wilts_at_dawn": {"type": "boolean"},
          "dead_plot_taints": {"type": "boolean"}
        },
        "required": [
          "id", "source", "name", "grow_days", "seed", "sell", "unlock_day", "unlock_rule",
          "harvest_phase", "wilts_at_dawn", "dead_plot_taints"
        ]
      },
      "allOf": [
        {"contains": {"properties": {"id": {"const": "turnip"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "pumpkin"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "moonflower"}}, "required": ["id"]}}
      ]
    }
  },
  "$defs": {
    "id": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
    "source": {"enum": ["doc01", "sim", "placeholder"]},
    "sources": {"type": "object", "additionalProperties": {"enum": ["doc01", "sim", "placeholder"]}}
  }
}
```

### A.5 `pumpkin.json`

Section 6. Four size records and one `rules` record.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "data/pumpkin.schema.json",
  "title": "Prize Pumpkin sizes and rules (doc 02 section 6)",
  "type": "object",
  "additionalProperties": false,
  "required": ["table", "schema_version", "records"],
  "properties": {
    "table": {"const": "pumpkin"},
    "schema_version": {"const": 1},
    "records": {
      "type": "array",
      "minItems": 5,
      "items": {
        "oneOf": [
          {
            "type": "object",
            "additionalProperties": false,
            "properties": {
              "id": {"enum": ["giant", "large", "medium", "sad"]},
              "source": {"$ref": "#/$defs/source"},
              "cite": {"type": "string"},
              "sources": {"$ref": "#/$defs/sources"},
              "rank": {"type": "integer", "minimum": 0, "maximum": 3},
              "min_watered_days": {"type": "integer", "minimum": 0, "maximum": 7},
              "max_watered_days": {"type": "integer", "minimum": 0, "maximum": 7},
              "guarded_nights_min": {"type": "integer", "minimum": 0, "maximum": 6},
              "payout_4p": {"type": "integer", "minimum": 0}
            },
            "required": [
              "id", "source", "rank", "min_watered_days", "max_watered_days", "guarded_nights_min",
              "payout_4p"
            ]
          },
          {
            "type": "object",
            "additionalProperties": false,
            "properties": {
              "id": {"const": "rules"},
              "source": {"$ref": "#/$defs/source"},
              "cite": {"type": "string"},
              "sources": {"$ref": "#/$defs/sources"},
              "guard_radius_m": {"type": "number", "exclusiveMinimum": 0},
              "guard_s": {"type": "number", "exclusiveMinimum": 0},
              "guard_first_night": {"type": "integer", "minimum": 1, "maximum": 7},
              "guard_last_night": {"type": "integer", "minimum": 1, "maximum": 7},
              "gnaw_from_night": {"type": "integer", "minimum": 1, "maximum": 7},
              "max_escort_bites": {"type": "integer", "minimum": 0},
              "min_door_distance_m": {"type": "number", "exclusiveMinimum": 0},
              "seed": {"type": "integer", "minimum": 0}
            },
            "required": [
              "id", "source", "guard_radius_m", "guard_s", "guard_first_night", "guard_last_night",
              "gnaw_from_night", "max_escort_bites", "min_door_distance_m", "seed"
            ]
          }
        ]
      },
      "maxItems": 5,
      "allOf": [
        {"contains": {"properties": {"id": {"const": "giant"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "large"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "medium"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "sad"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "rules"}}, "required": ["id"]}}
      ]
    }
  },
  "$defs": {
    "id": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
    "source": {"enum": ["doc01", "sim", "placeholder"]},
    "sources": {"type": "object", "additionalProperties": {"enum": ["doc01", "sim", "placeholder"]}}
  }
}
```

### A.6 `debt.json`

Section 7. `rounding` is fixed at `nearest`, the one exception to `player_scaling.json` (D-017).

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "data/debt.schema.json",
  "title": "Season debt (doc 02 section 7)",
  "type": "object",
  "additionalProperties": false,
  "required": ["table", "schema_version", "records"],
  "properties": {
    "table": {"const": "debt"},
    "schema_version": {"const": 1},
    "records": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "id": {"const": "season"},
          "source": {"$ref": "#/$defs/source"},
          "cite": {"type": "string"},
          "sources": {"$ref": "#/$defs/sources"},
          "total_4p": {"type": "integer", "minimum": 0},
          "first_payment_4p": {"type": "integer", "minimum": 0},
          "days": {"type": "integer", "minimum": 1},
          "rounding": {"const": "nearest"}
        },
        "required": ["id", "source", "total_4p", "first_payment_4p", "days", "rounding"]
      },
      "maxItems": 1
    }
  },
  "$defs": {
    "id": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
    "source": {"enum": ["doc01", "sim", "placeholder"]},
    "sources": {"type": "object", "additionalProperties": {"enum": ["doc01", "sim", "placeholder"]}}
  }
}
```

### A.7 `medical_bill.json`

Section 8.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "data/medical_bill.schema.json",
  "title": "Medical bill (doc 02 section 8)",
  "type": "object",
  "additionalProperties": false,
  "required": ["table", "schema_version", "records"],
  "properties": {
    "table": {"const": "medical_bill"},
    "schema_version": {"const": 1},
    "records": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "id": {"const": "bill"},
          "source": {"$ref": "#/$defs/source"},
          "cite": {"type": "string"},
          "sources": {"$ref": "#/$defs/sources"},
          "first_4p": {"type": "integer", "minimum": 0},
          "later_4p": {"type": "integer", "minimum": 0},
          "cap_4p": {"type": "integer", "minimum": 0}
        },
        "required": ["id", "source", "first_4p", "later_4p", "cap_4p"]
      },
      "maxItems": 1
    }
  },
  "$defs": {
    "id": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
    "source": {"enum": ["doc01", "sim", "placeholder"]},
    "sources": {"type": "object", "additionalProperties": {"enum": ["doc01", "sim", "placeholder"]}}
  }
}
```

### A.8 `player_scaling.json`

Section 4.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "data/player_scaling.schema.json",
  "title": "Headcount scaling (doc 02 section 4)",
  "type": "object",
  "additionalProperties": false,
  "required": ["table", "schema_version", "records"],
  "properties": {
    "table": {"const": "player_scaling"},
    "schema_version": {"const": 1},
    "records": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "id": {"const": "headcount"},
          "source": {"$ref": "#/$defs/source"},
          "cite": {"type": "string"},
          "sources": {"$ref": "#/$defs/sources"},
          "pct_by_players": {
            "type": "object",
            "additionalProperties": false,
            "required": ["2", "3", "4"],
            "properties": {
              "2": {"type": "integer", "minimum": 0, "maximum": 1000},
              "3": {"type": "integer", "minimum": 0, "maximum": 1000},
              "4": {"type": "integer", "minimum": 0, "maximum": 1000}
            }
          },
          "rounding": {"const": "ceil"},
          "min_players": {"const": 2},
          "max_players": {"const": 4}
        },
        "required": ["id", "source", "pct_by_players", "rounding", "min_players", "max_players"]
      },
      "maxItems": 1
    }
  },
  "$defs": {
    "id": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
    "source": {"enum": ["doc01", "sim", "placeholder"]},
    "sources": {"type": "object", "additionalProperties": {"enum": ["doc01", "sim", "placeholder"]}}
  }
}
```

### A.9 `difficulty.json`

Section 16.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "data/difficulty.schema.json",
  "title": "Difficulty multipliers (doc 02 section 16)",
  "type": "object",
  "additionalProperties": false,
  "required": ["table", "schema_version", "records"],
  "properties": {
    "table": {"const": "difficulty"},
    "schema_version": {"const": 1},
    "records": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "id": {"enum": ["easy", "normal", "nightmare"]},
          "source": {"$ref": "#/$defs/source"},
          "cite": {"type": "string"},
          "sources": {"$ref": "#/$defs/sources"},
          "trap_pct": {"type": "integer", "minimum": 0, "maximum": 1000},
          "bill_pct": {"type": "integer", "minimum": 0, "maximum": 1000},
          "generator_tank_pct": {"type": "integer", "minimum": 0, "maximum": 1000},
          "rounding": {"const": "ceil"}
        },
        "required": ["id", "source", "trap_pct", "bill_pct", "generator_tank_pct", "rounding"]
      },
      "maxItems": 3,
      "allOf": [
        {"contains": {"properties": {"id": {"const": "easy"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "normal"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "nightmare"}}, "required": ["id"]}}
      ]
    }
  },
  "$defs": {
    "id": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
    "source": {"enum": ["doc01", "sim", "placeholder"]},
    "sources": {"type": "object", "additionalProperties": {"enum": ["doc01", "sim", "placeholder"]}}
  }
}
```

### A.10 `store.json`

Section 10. Seeds live in `crops.json`. `effect` holds the item's own numbers.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "data/store.schema.json",
  "title": "Store items (doc 02 section 10)",
  "type": "object",
  "additionalProperties": false,
  "required": ["table", "schema_version", "records"],
  "properties": {
    "table": {"const": "store"},
    "schema_version": {"const": 1},
    "records": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "id": {"$ref": "#/$defs/id"},
          "source": {"$ref": "#/$defs/source"},
          "cite": {"type": "string"},
          "sources": {"$ref": "#/$defs/sources"},
          "name": {"type": "string"},
          "price": {"type": "integer", "minimum": 0},
          "unlock_day": {"type": "integer", "minimum": 1, "maximum": 7},
          "upgrade": {"type": "boolean"},
          "consumable": {"type": "boolean"},
          "per_player": {"type": "boolean"},
          "effect": {
            "type": "object",
            "additionalProperties": {"type": ["number", "boolean", "string"]}
          }
        },
        "required": [
          "id", "source", "name", "price", "unlock_day", "upgrade", "consumable", "per_player",
          "effect"
        ]
      },
      "allOf": [
        {"contains": {"properties": {"id": {"const": "shed_lock"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "scrap"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "quiet_watering_can"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "walkie_talkie"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "walkie_battery"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "brighter_lantern"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "scarecrow"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "plot_pair"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "flare_gun"}}, "required": ["id"]}}
      ]
    }
  },
  "$defs": {
    "id": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
    "source": {"enum": ["doc01", "sim", "placeholder"]},
    "sources": {"type": "object", "additionalProperties": {"enum": ["doc01", "sim", "placeholder"]}}
  }
}
```

### A.11 `ramp_up.json`

Section 11. Exactly 7 records; day 7's trap counts are `null` (hunts all night).

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "data/ramp_up.schema.json",
  "title": "Ramp-up per day at 4 players (doc 02 section 11)",
  "type": "object",
  "additionalProperties": false,
  "required": ["table", "schema_version", "records"],
  "properties": {
    "table": {"const": "ramp_up"},
    "schema_version": {"const": 1},
    "records": {
      "type": "array",
      "minItems": 7,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "id": {"enum": ["day_1", "day_2", "day_3", "day_4", "day_5", "day_6", "day_7"]},
          "source": {"$ref": "#/$defs/source"},
          "cite": {"type": "string"},
          "sources": {"$ref": "#/$defs/sources"},
          "day": {"type": "integer", "minimum": 1, "maximum": 7},
          "disturbances_4p": {"type": "integer", "minimum": 0},
          "bear_4p": {"type": ["integer", "null"], "minimum": 0},
          "pit_4p": {"type": ["integer", "null"], "minimum": 0},
          "bells_4p": {"type": ["integer", "null"], "minimum": 0},
          "hunts_all_night": {"type": "boolean"},
          "voice": {"enum": ["exact", "spliced"]},
          "new": {"type": "array", "items": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"}}
        },
        "required": [
          "id", "source", "day", "disturbances_4p", "bear_4p", "pit_4p", "bells_4p",
          "hunts_all_night", "voice", "new"
        ]
      },
      "maxItems": 7,
      "allOf": [
        {"contains": {"properties": {"id": {"const": "day_1"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "day_2"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "day_3"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "day_4"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "day_5"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "day_6"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "day_7"}}, "required": ["id"]}}
      ]
    }
  },
  "$defs": {
    "id": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
    "source": {"enum": ["doc01", "sim", "placeholder"]},
    "sources": {"type": "object", "additionalProperties": {"enum": ["doc01", "sim", "placeholder"]}}
  }
}
```

### A.12 `traps.json`

Section 12. Doc 03 (PP-06) adds its fields by amending this schema.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "data/traps.schema.json",
  "title": "Traps: economy and labor fields (doc 02 section 12)",
  "type": "object",
  "additionalProperties": false,
  "required": ["table", "schema_version", "records"],
  "properties": {
    "table": {"const": "traps"},
    "schema_version": {"const": 1},
    "records": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "id": {"enum": ["bear_trap", "pit", "tripwire_bells"]},
          "source": {"$ref": "#/$defs/source"},
          "cite": {"type": "string"},
          "sources": {"$ref": "#/$defs/sources"},
          "clear_verb": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
          "pinned": {"type": "boolean"},
          "drops_carried": {"type": "boolean"},
          "slow_mult": {"type": "number", "exclusiveMinimum": 0},
          "slow_s": {"type": "number", "minimum": 0},
          "starts_race_by_day": {"type": "boolean"},
          "unlock_day": {"type": "integer", "minimum": 1, "maximum": 7}
        },
        "required": [
          "id", "source", "clear_verb", "pinned", "drops_carried", "slow_mult", "slow_s",
          "starts_race_by_day", "unlock_day"
        ]
      },
      "allOf": [
        {"contains": {"properties": {"id": {"const": "bear_trap"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "pit"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "tripwire_bells"}}, "required": ["id"]}}
      ]
    }
  },
  "$defs": {
    "id": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
    "source": {"enum": ["doc01", "sim", "placeholder"]},
    "sources": {"type": "object", "additionalProperties": {"enum": ["doc01", "sim", "placeholder"]}}
  }
}
```

### A.13 `taint.json`

Section 13. Records `taint`, `shaken` and `stacking`; doc 03 adds causes.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "data/taint.schema.json",
  "title": "Taint and Shaken effects (doc 02 section 13)",
  "type": "object",
  "additionalProperties": false,
  "required": ["table", "schema_version", "records"],
  "properties": {
    "table": {"const": "taint"},
    "schema_version": {"const": 1},
    "records": {
      "type": "array",
      "minItems": 1,
      "items": {
        "oneOf": [
          {
            "type": "object",
            "additionalProperties": false,
            "properties": {
              "id": {"const": "taint"},
              "source": {"$ref": "#/$defs/source"},
              "cite": {"type": "string"},
              "sources": {"$ref": "#/$defs/sources"},
              "sprint_mult": {"type": "number", "exclusiveMinimum": 0},
              "pry_mult": {"type": "number", "exclusiveMinimum": 0},
              "footstep_radius_mult": {"type": "number", "exclusiveMinimum": 0},
              "cure_verb": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
              "lasts": {"const": "wash_or_dawn"}
            },
            "required": [
              "id", "source", "sprint_mult", "pry_mult", "footstep_radius_mult", "cure_verb",
              "lasts"
            ]
          },
          {
            "type": "object",
            "additionalProperties": false,
            "properties": {
              "id": {"const": "shaken"},
              "source": {"$ref": "#/$defs/source"},
              "cite": {"type": "string"},
              "sources": {"$ref": "#/$defs/sources"},
              "sprint_mult": {"type": "number", "exclusiveMinimum": 0},
              "duration_s": {"type": "number", "exclusiveMinimum": 0},
              "restarts_on_new_cause": {"type": "boolean"}
            },
            "required": ["id", "source", "sprint_mult", "duration_s", "restarts_on_new_cause"]
          },
          {
            "type": "object",
            "additionalProperties": false,
            "properties": {
              "id": {"const": "stacking"},
              "source": {"$ref": "#/$defs/source"},
              "cite": {"type": "string"},
              "sources": {"$ref": "#/$defs/sources"},
              "rule": {"const": "multiply"}
            },
            "required": ["id", "source", "rule"]
          }
        ]
      },
      "maxItems": 3,
      "allOf": [
        {"contains": {"properties": {"id": {"const": "taint"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "shaken"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "stacking"}}, "required": ["id"]}}
      ]
    }
  },
  "$defs": {
    "id": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
    "source": {"enum": ["doc01", "sim", "placeholder"]},
    "sources": {"type": "object", "additionalProperties": {"enum": ["doc01", "sim", "placeholder"]}}
  }
}
```

### A.14 `roles.json`

Section 15. `perks` maps a perk to its number.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "data/roles.schema.json",
  "title": "Roles (doc 02 section 15)",
  "type": "object",
  "additionalProperties": false,
  "required": ["table", "schema_version", "records"],
  "properties": {
    "table": {"const": "roles"},
    "schema_version": {"const": 1},
    "records": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "additionalProperties": false,
        "properties": {
          "id": {"enum": ["farmer", "rancher", "mechanic", "tracker"]},
          "source": {"$ref": "#/$defs/source"},
          "cite": {"type": "string"},
          "sources": {"$ref": "#/$defs/sources"},
          "name": {"type": "string"},
          "perks": {
            "type": "object",
            "minProperties": 1,
            "additionalProperties": {"type": "number", "exclusiveMinimum": 0}
          }
        },
        "required": ["id", "source", "name", "perks"]
      },
      "maxItems": 4,
      "allOf": [
        {"contains": {"properties": {"id": {"const": "farmer"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "rancher"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "mechanic"}}, "required": ["id"]}},
        {"contains": {"properties": {"id": {"const": "tracker"}}, "required": ["id"]}}
      ]
    }
  },
  "$defs": {
    "id": {"type": "string", "pattern": "^[a-z][a-z0-9_]*$"},
    "source": {"enum": ["doc01", "sim", "placeholder"]},
    "sources": {"type": "object", "additionalProperties": {"enum": ["doc01", "sim", "placeholder"]}}
  }
}
```
