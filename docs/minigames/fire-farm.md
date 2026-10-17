# Spec: Fire minigame, kangaroo farm (DRAFT)

Issue #125. Design by burcubaran22 (with sudeimete), built by memoksin after the spec.
Event: Black Saturday, Victoria, Australia, 7 Feb 2009 (place and tone to confirm). Role: Citizen.
Score, timer (90 s) and lose rule are decided. Items marked `OPEN` are not decided yet. Do not state anything in a result card text as a real fact until it is checked (`VERIFY`).

## Idea in one line

First person. You are on a fenced farm with a kangaroo pen while a bushfire comes. You go through a few marked tasks (exclamation marks), each one prepares the farm or opens an escape for the kangaroos, then you leave through the broken gate. Every task is a simple hands-on action.

## What the player sees and does, in order

1. **Overview (a few seconds):** the farm from above, fenced on all four sides, with the kangaroo pen. Simple, like the earlier minigames' intro. Then the game starts.
2. **First person.** The player looks around. Two **exclamation marks** show the tasks.
3. **Task A, the fence:**
   - Run to the first exclamation mark. There is a **knife** on the ground: pick it up.
   - A **fence** stands at the side: cut it. A gap opens, so the kangaroos have a way out.
   - Success sound (the player did it).
4. **Look around again.** Another exclamation mark.
5. **Task B, the hose and the fire:**
   - Run to it. A **hose** lies free on the ground, a **valve** is on the wall.
   - Attach the hose to the valve, turn the valve: water flows.
   - Look to the other side: a **small flame** has started **on the path to the exit**. Put it out with the hose so the way out stays open.
   - Success sound when it is out.
6. **Exit.** When all exclamation marks are done, the **exit gate** shows. The gate is broken, with a **pile of debris** in front. The player **jumps over the pile** (jump key) and leaves. End of the minigame.

## Lesson link (decided with memoksin, from sudeimete's note)

Black Saturday's main lesson is "leave early", not "stay and defend". So the tasks are about **opening ways out**, not about defending the farm: the fence opens a way out for the kangaroos, and the flame is put out only because it blocks the player's own way out. The card says: leave early, do not fight a fire you can leave.

## Controls (first person)

Move, look with the mouse, an **interact** key (pick up, cut, attach, turn), a **jump** key. Mouse and keyboard.

## Props (3D, simple)

Farm yard, fences on four sides, kangaroo pen with kangaroos, 2 exclamation markers, knife, cuttable fence section, hose, wall with a valve, a small flame (and no flame afterwards), broken gate with a debris pile, sky and smoke.

## Score and ending (decided by burcubaran22)

- **Score = the tasks completed, plus leaving successfully.** Shown as "X/3 done": the fence cut, the flame put out, and the player got out through the gate (the third counts only if the player leaves in time). `OPEN`: exact wording on the card.
- **Time pressure = the view gets worse.** The total time is **90 s** (decided; the minigame budget is 60 to 90 s, and a first-time player in first person needs time to find the tasks). The smoke follows the clock: the first **10 s are clear**, then the smoke **thickens gradually**, and in the **last 10 s it is very dense**. The debris pile at the gate does **not** get worse. The pressure is that you see less and less, so leaving late is hard. This carries the "leave early" lesson of Black Saturday.
- **Lose:** the time runs out before the player has left (the view is almost gone). The tasks done before that still count in the score. Timer: 90 s total, decided.
- **Kangaroos:** after the player cuts the fence, **two or three kangaroos run out through the gap** (a visible payoff).
- **Result card:** the real event, numbers and the "leave early" lesson, with sources (`VERIFY`).

## Sounds this game needs (to add to `docs/audio.md`)

Footsteps, picking up the knife, cutting the fence, kangaroos hopping out, **success sound** for the fence, hose attach and valve turn, water flow, the flame, putting it out, **success sound** for the fire, fire and wind ambience, jump and landing on debris, the exit. Voice: none.

## Art and build notes

- First person 3D scene, small: one yard, a few props. The 2.5D style guide (#121) applies to the look.
- Mechanics are few: move, look, interact, jump. No steering of animals.
- Memoksin (#125): a small first-person 3D scene is feasible and will not take long; built in parallel with the 2.5D reform (done around 16:00 on Sat), then polish until Sun 18:00.

## Open questions

- The exact wording of the score on the card.
- Real event details and what the card says (Black Saturday facts to verify).
