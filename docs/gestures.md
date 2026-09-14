# Gestures and motion

What makes this feel like an app rather than a website in a phone-shaped
window. All of it collapses under `prefers-reduced-motion`, and none of it is
the only way to do anything — every gesture has a tap that does the same.

## Navigation

Turbo Drive swaps the body in place. No white flash, no lost scroll position,
no re-fetching avatars that were already on screen. Pages cross-fade through
the View Transitions API while the top bar and tab bar stay put.

## Swipe on a row

| Direction | Action |
| --- | --- |
| Left | Edit |
| Right | Void, or Restore if it is already voided |

A short swipe rests the row open so you can read the action and tap it. A long
one past the commit point fires as you let go, which is what separates a
gesture from a menu. Swiping toward an action that isn't there still moves,
with resistance, rather than refusing — a dead surface feels broken.

Holding a row does the same thing without swiping, which also covers pointer
devices, since they cannot swipe at all.

## The add button

Pull it upward to open the composer. It follows your thumb, grows slightly,
rotates its cross, and springs back past its resting size if you let go early.
A grab handle appears only while it is being pulled.

## Sheets

Everything that would be a page on a desktop is a bottom sheet on a phone:
adding an expense, settling up, filtering, confirming something destructive.
They spring up, can be flicked down to dismiss, and become centred dialogs
from `md` up.

Their footers are the action bar rather than a tray holding buttons: full
bleed, split by a hairline when there are two.

## Haptics

A short buzz when a row snaps open, a longer pattern when a destructive action
fires, a tap when the add button passes its commit point. Wrapped in try/catch
because most desktop browsers do not implement it and one that throws should
not take a gesture down with it.

## What is deliberately still

Money figures count up once when they arrive and then hold. Lists stagger in
on first sight and never again. Nothing loops, nothing pulses, and nothing
moves while you are trying to read it.
