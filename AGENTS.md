# Repository agent guidance

## Gaming and laptop-power changes

Before changing gaming, graphics, ASUS, thermal, battery, kernel, or scheduler
policy, read both:

- `modules/gaming/README.md`
- `modules/gaming/upstream-research.yaml`

The GA402RK has two known, unresolved field problems: it has sometimes shut
down from heat during gaming, and battery video playback has regressed to about
one hour. The current stack is a conservative measurement baseline, not a
claim that either problem is solved. Use `system-g14-observe` and measurements
from the physical laptop before selecting PPT, temperature, fan, boost, GPU,
refresh-rate, or video-decoding policy.

### Reintroduction gate

Do not silently reintroduce a component classified REMOVE, REJECT, or WATCH,
especially Cardwire, LACT, RyzenAdj, an OGC/patched kernel, GameMode,
PowerStation, power-profiles-daemon, tuned, TLP, or auto-cpufreq.

First establish that the rejection premise in the README or ledger has changed.
Then stop and ask the user, in substance:

> Are you sure you want to reintroduce COMPONENT? It was removed because
> PRIOR_RATIONALE. The new evidence that may justify it is CHANGED_EVIDENCE,
> and the remaining risks or conflicts are RISKS.

An upstream gaming distribution carrying a component is not changed evidence.
If the user confirms, keep one authority per control, scope the change to the
measured problem, add Arch and Fedora validation, and update the README and
ledger in the same change.

Never claim thermal, battery, hybrid-GPU, VRR, HDR, fan, or suspend behavior was
validated unless it was tested on the physical GA402RK and the result recorded.
