# Today Visual Upgrade Design

## Goal

Raise the Today screen's visual hierarchy while keeping its existing companion, six-dimension life field, task actions, journal entry, growth feedback, persistence, accessibility, and Reduce Motion behavior.

## Approved Direction

- Keep the quiet monochrome LIVELVL identity and existing point-cloud companion artwork.
- Add the LIVELVL eyebrow and a localized current-date line to the Today header.
- Reduce the regular-size life field so task content begins within the first viewport. Accessibility Dynamic Type retains the taller field and scrolls naturally.
- Arrange the six dimension vertices as a true regular hexagon in display coordinates, including on non-square Today fields.
- Keep all six dimension labels, official values, projected markers, detail interactions, growth animations, and fold/expand behavior.
- Present the journal entry before the task section; keep a visible task title and completed/total count.
- Keep the task completion control and edit action separate, each with at least a 44-point target.
- Show each task's dimension and base XP at rest; completed-task reward feedback temporarily replaces the base XP with the earned `+XP` value.
- Keep `THE NOTE` and its existing open action as the first callout below the life field.
- Use solid, readable surfaces and restrained shadows. Do not introduce new product features, 3D rendering, network dependencies, or new persistence state.

## Layout Contract

- Regular Today header: eyebrow, 38-point title, localized date metadata, 44-point add button.
- Regular life field: approximately 360 points tall; central card approximately 124 by 210 points.
- Accessibility sizes: preserve a 590-point field and a larger central card.
- Journal entry follows the life field.
- Task section follows the journal: title, completed/total count, then the current task rows.
- Existing tab bar, sheets, alerts, reward overlays, and scroll container remain in place.

## Verification

- Presentation tests cover localized date copy, task summary clamping, and resting/reward XP text.
- Existing life-field, growth, journal, and task tests continue to pass.
- Debug build succeeds.
- iPhone 17 Pro simulator checks expanded and compact growth states, task completion/edit controls, journal opening, scrolling, and visible hierarchy.
