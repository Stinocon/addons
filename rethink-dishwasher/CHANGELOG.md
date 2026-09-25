# Changelog

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
