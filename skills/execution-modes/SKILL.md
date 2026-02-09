---
name: execution-mode-routing
description: Taxonomy of 5 execution modes for AI-assisted development. Provides a decision heuristic for selecting the right mode based on scope clarity, risk level, parallelizability, and testability. Covers model routing for subagent delegation.
---

# Execution Mode Routing

Every task entering implementation should be tagged with exactly one execution mode. The mode determines ceremony level, review cadence, agent autonomy, and model routing. Apply the `exec:*` label to the issue in `~~project-tracker~~` before starting work.

## The 5 Modes

### `exec:quick` -- Direct Implementation

**When:** Small, well-understood changes with obvious implementation paths. No ambiguity in requirements, no risk of breaking adjacent systems.

**Behavior:** Implement directly with minimal ceremony. No explicit test-first step (though existing tests must still pass). Commit and move on.

**Examples:** Fix a typo, update a dependency version, add a config flag, adjust a UI string, rename a variable across files.

**Guard rail:** If implementation takes longer than 30 minutes or reveals unexpected complexity, upgrade to `exec:tdd` or `exec:pair`.

---

### `exec:tdd` -- Test-Driven Development

**When:** Well-defined acceptance criteria that can be expressed as automated tests. The requirements are clear enough to write a failing test before writing implementation code.

**Behavior:** Strict red-green-refactor cycle:
1. Write a failing test that captures the acceptance criterion
2. Write the minimum code to make it pass
3. Refactor while keeping tests green
4. Repeat for each criterion

**Examples:** API endpoint with defined request/response contract, business logic with edge cases, data transformation pipeline, utility function with known inputs/outputs.

**Guard rail:** If you cannot express the requirement as a test, the scope is not well-defined enough for TDD. Drop to `exec:pair` to clarify requirements first.

---

### `exec:pair` -- Human-in-the-Loop Pairing

**When:** Complex logic where the scope is uncertain, requirements need exploration, or the task involves a learning opportunity. The agent acts as navigator; the human acts as driver (or vice versa).

**Behavior:** Iterative exploration with frequent check-ins. The agent proposes approaches, the human validates direction. Use Plan Mode or equivalent to establish shared understanding before committing to implementation.

**Examples:** Architectural decisions, novel integrations, unfamiliar APIs, research-heavy features, first implementation of a new pattern.

**Guard rail:** Define exit criteria up front. Pair sessions without clear goals degenerate into exploration without convergence. If the task becomes well-defined during pairing, upgrade to `exec:tdd`.

---

### `exec:checkpoint` -- Milestone-Gated Implementation

**When:** High-risk changes where mistakes are expensive or irreversible. Security-sensitive code, data migrations, breaking API changes, infrastructure modifications.

**Behavior:** Implementation proceeds in defined phases. At each milestone, the agent pauses for explicit human review and approval before continuing. No "I'll just finish this part" -- the checkpoint is a hard stop.

**Checkpoints to define up front:**
- After schema/migration design, before execution
- After security-sensitive logic, before deployment
- After breaking change implementation, before merge
- After data transformation logic, before running on production data

**Examples:** Database migration, auth system changes, payment integration, API versioning, infrastructure provisioning, data backfill scripts.

**Guard rail:** If a checkpoint reveals the approach is wrong, do not proceed. Revert to planning. Sunk cost is not a reason to continue a flawed approach.

---

### `exec:swarm` -- Multi-Agent Orchestration

**When:** 5 or more independent tasks that can be executed in parallel with no dependencies between them. The overhead of coordination is justified by the parallelism gain.

**Behavior:** Decompose the work into independent units. Dispatch each to a subagent. Collect results. Reconcile any conflicts. The orchestrating agent manages the fan-out/fan-in lifecycle.

**Examples:** Updating 10 configuration files with a consistent change, implementing 6 independent API endpoints, applying a code pattern across 8 modules, bulk research across multiple sources.

**Guard rail:** If tasks have dependencies, they are not suitable for swarm. Sequence dependent tasks; only parallelize truly independent work. If fewer than 5 tasks, the coordination overhead of swarm mode exceeds its benefit -- use a simpler mode.

---

## Decision Heuristic

Use this tree to select the appropriate mode. Start at the root and follow the branches:

```
Is the scope well-defined with clear acceptance criteria?
|
+-- YES --> Are there 5+ independent tasks?
|           |
|           +-- YES --> exec:swarm
|           |
|           +-- NO --> Is it testable (can you write a failing test)?
|                      |
|                      +-- YES --> exec:tdd
|                      |
|                      +-- NO --> exec:quick
|
+-- NO --> Is it high-risk (security, data, breaking changes)?
           |
           +-- YES --> exec:checkpoint
           |
           +-- NO --> exec:pair
```

When in doubt, prefer `exec:pair`. It is the safest default because it keeps a human in the loop while the scope crystallizes. Modes can be upgraded mid-task (pair to tdd, quick to checkpoint) but should not be downgraded without justification.

## Model Routing for Subagents

When delegating subtasks to subagents, match the model tier to the cognitive demand:

| Model Tier | Use For | Characteristics |
|------------|---------|-----------------|
| **Fast/cheap** (e.g., haiku) | File scanning, data retrieval, simple search, bulk reads | Lowest cost, highest throughput. Use for Tier 1 delegation. |
| **Balanced** (e.g., sonnet) | Code review synthesis, PR summaries, test analysis | Good quality-to-cost ratio. Use for review and analysis tasks. |
| **Highest quality** (e.g., opus) | Critical implementation, complex reasoning, architectural decisions | Highest quality, highest cost. Reserve for tasks where correctness matters most. |

**Routing by execution mode:**

- `exec:quick` -- Direct execution, no subagent needed
- `exec:tdd` -- Fast model for test scaffolding, highest quality for implementation logic
- `exec:pair` -- Highest quality for all interactions (human is watching)
- `exec:checkpoint` -- Highest quality for implementation, balanced for review summaries
- `exec:swarm` -- Fast model for independent leaf tasks, balanced for reconciliation

## Integration with Issue Labels

Apply the execution mode label when transitioning an issue from spec-ready to implementation:

1. During planning or triage, evaluate the task against the decision heuristic
2. Apply the appropriate `exec:*` label in `~~project-tracker~~`
3. The label informs session planning: `exec:swarm` tasks need longer sessions; `exec:quick` tasks can be batched; `exec:checkpoint` tasks need human availability windows
4. If the mode changes mid-implementation, update the label and document why

The execution mode also informs estimation. Quick tasks are typically under 1 hour. TDD tasks are 1-4 hours. Pair sessions are 1-2 hours per sitting. Checkpoint tasks span multiple sessions. Swarm tasks vary by fan-out count but each leaf should be quick or tdd-sized.
