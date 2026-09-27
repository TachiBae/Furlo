# Flutter Learning Reflection

---

## A. Module 4: Making a Screen

A widget is a description of what the screen should look like given the current data, rather than a fixed element. The `build` method turns this description into pixels and reruns whenever Flutter detects data changes. This clicked for me when watching `build` fire after a `setState` call; I realized I am not editing the screen directly but rewriting the "recipe" while Flutter calculates the smallest diff to redraw.

Layout challenges arose with `Row` and `Expanded`. In m4a4, I initially used fixed `SizedBox` gaps for monster stats, which broke on narrower devices. It became clear that `Expanded` is functional, not decorative — it tells children to claim remaining space.

Theming in m4a3 taught me to define a look once; I'm applying this in my capstone with a dark theme (**Wondrous Wisteria** primary, **Succulent Lime** accent) that all components inherit.

For m4a4, I successfully implemented the required keyed widgets (`type`, `hp`, `hpBar`).

**To improve:** derive type colors dynamically and replace hardcoded spacing with `Expanded` for better responsiveness.

---

## B. Module 5: Making It Move

`setState` is crucial because Flutter does not automatically monitor variables; it only rebuilds when explicitly signaled. Changing `_currentHp` in memory without `setState` leaves the UI stale.

Working with `TextField` controllers highlighted the importance of lifecycle management; forgetting to call `dispose()` often leads to errors if the controller is accessed after the screen is removed.

I also learned that `ListView.builder` is superior to a standard `Column` for long lists because it lazily builds only visible items, saving resources.

My first experience with `Navigator.push` was a lesson in data passing — I initially reached the new screen but failed to pass the required monster object through the constructor.

Developing **HAUDEX** took several days, with most effort focused on the add-monster dialog flow and ensuring `setState` triggered correctly across the navigation stack.

---

## C. What Clicked, and What Is Still Shaky

### ✅ What clicked
Polymorphism became concrete in `m3a6_battler`. Seeing the base `Monster` class call `bonusVs()` and watching it resolve to specific subclass implementations (`FireMon`, `WaterMon`) illustrated how subclass logic takes precedence.

I am proud of debugging m4a4's layout overflow. When the name, type, and HP clipped on smaller screens, I identified that fixed `SizedBox` spacing was the culprit. I now recognize the `RenderFlex overflowed` warning immediately as a sign that a `Row` or `Column` lacks flexible children to manage its content within the available space.

### ⚠️ What's still shaky
Some logic remains shaky, such as my `winner` getter in `Battle`. It currently returns a value based on `!isFainted`, which is technically true mid-fight; the logic only works because I manually check `isOver` first. I need to make the getter more robust.

---

## D. How I Work

When I encounter obstacles, I now prioritize researching the underlying logic rather than seeking immediate fixes. I use Claude as a tutor to walk through problem-reasoning instead of generating raw code.

I maintained consistency by completing Module 5 activities ahead of time, a habit I intend to carry into the final project.

**Goal:** shift from purely conceptual understanding to consistent, practical implementation in every stage of development.

---

## E. Looking Forward

My final project relies heavily on Module 5's state management and lists. The pet list and care-log screens utilize the HAUDEX pattern: a `ListView.builder` over a mutable list driven by `setState`.

**Current gap:** persistence — my previous lists exist only in memory.

**Plan:** bridge this using `sqflite`, implementing a join-table schema for the many-to-many vet–pet relationship.

**Objective (next 2 weeks):** transition from in-memory placeholders to a functional database, mastering the full CRUD flow for a production-ready application.
