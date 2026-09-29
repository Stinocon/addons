# Changelog

## 0.2.4

- Builds the fork's `v0.1.0-d0211.4` tag: `extra_dry`, `high_temp` and `half_load` become
  entities. The three options were measured on the idle panel first, and the option entities
  report only while a cycle runs, so each waited for a running cycle to show its bit — extra
  dry through a whole Eco wash, high temp + half load on a short Auto run later cancelled.
  The published set is 18 components.

## 0.2.3

- Builds the fork's `v0.1.0-d0211.3` tag: the delay-start countdown runs at state `0x02` with
  process `0x01`, so it no longer raises `running` and its phase is published as `Delay` instead
  of firing the live-activity automation an hour before the wash.
- `delay_start`, `child_lock` and `rinse_refill` become entities, and the published option and
  status bits are the ones measured on the appliance rather than positions predicted from a
  sibling model.

## 0.2.2

- Builds the fork's `v0.1.0-d0211.2` tag: it drops the comments that pointed at a non-public
  repository. Nothing about the dishwasher decode changes.

## 0.2.1

- Builds the fork's `v0.1.0-d0211.1` tag: the dishwasher handler no longer treats record state
  `0x01` as a running cycle. Live traffic from the appliance showed `0x01` with the machine idle
  and its door open, so `running` rose on an idle machine and the course and option entities
  reported a cycle that was not there. Only `0x02` now counts as a cycle.

## 0.2.0

- Builds the fork's `v0.1.0-d0211` tag instead of its `master` branch. The dishwasher work lives
  on the branch rebased onto rethink `v0.1.0`; the fork's `master` is an older development line
  whose handler predates the adopted option mapping.
- The dishwasher decode now covers the whole published entity set rather than a scaffold: run
  state, process phase, initial and remaining time, the course byte, the cycle counter, and the
  option and status bits. State labels are English, and the time sensors publish whole minutes,
  which is what Home Assistant's `duration` device class requires.
- Six option/status bit positions are transferred from an independent handler for the same record
  layout and are flagged in the source as predictions until a wash confirms each.

## 0.1.0

- Initial release.
- Builds the [rethink](https://github.com/anszom/rethink) fork
  [Stinocon/rethink-dishwasher](https://github.com/Stinocon/rethink-dishwasher), which adds the
  LG ThinQ dishwasher definition (`D0211`, deviceType 204).
- Dishwasher support is a beta: the TLV field decoding is written against live captures of a
  real unit.
