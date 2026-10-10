# WorkLog — Codex Instructions

## Project

WorkLog is a Flutter productivity/freelance app using Supabase as the backend.

* Flutter + Dart
* Supabase
* Mobile + Desktop responsive
* Do NOT use Firebase

## Core Rules

* Make the smallest change necessary for the requested task.
* Do not modify unrelated features or files.
* Do not rewrite entire files when a focused edit is possible.
* Reuse existing components, services, models, utilities, and styles.
* Before creating anything new, check whether an existing implementation can be reused.
* Do not refactor working code unless explicitly requested.
* Preserve existing functionality and user changes.

## Token Efficiency

IMPORTANT: Keep Codex usage efficient.

* Do NOT scan the entire repository for small tasks.
* First identify the feature and inspect only relevant files.
* Avoid reading unrelated files.
* Avoid repeating analysis of the same files.
* Prefer targeted searches and targeted tests.
* If a task is isolated, keep the investigation isolated.
* Do not repeatedly explain or re-analyze the whole project.

## UI / Design

Preserve the existing WorkLog:

* colors
* fonts
* spacing
* components
* icons
* navigation
* responsive behavior

Only change UI/design when explicitly requested.

Keep the interface minimal, modern, professional, and responsive.

## Supabase

* Use Supabase for backend/database functionality.
* Never introduce Firebase.
* Reuse existing Supabase configuration and services.
* Avoid unnecessary database/API calls.
* Fetch only the data required.
* Do not change database schema unless necessary.
* Never expose secrets or service-role keys in client code.

## Code

Follow normal Flutter/Dart best practices:

* null safety
* readable code
* reusable components
* proper async/error handling
* avoid duplicated code
* avoid unnecessary dependencies
* avoid unnecessary abstractions

## Feature Isolation

When fixing a feature, only inspect and modify code related to that feature.

Examples:

* Reminder bug → reminder/notification code
* Finance bug → finance code
* Invoice bug → invoice/PDF code
* UI bug → affected screen/components

Do not change unrelated functionality.

## Validation

After changes:

1. Run the relevant analyzer/tests.
2. Fix errors caused by your changes.
3. Do not spend excessive time fixing unrelated pre-existing errors.
4. Verify the requested functionality.

Prefer targeted validation instead of running the entire project unnecessarily.

## Git Safety

Never:

* delete user work
* reset commits
* force push
* overwrite unrelated changes

Preserve existing uncommitted changes.

## Final Response

Keep the final response concise:

### Changed

* What was changed.

### Files

* Files modified.

### Validation

* Tests/analyzer/checks performed.

### Notes

* Important remaining issue or limitation, if any.

## Most Important Rule

**Understand the requested task → inspect only relevant code → make the smallest reliable change → validate it → stop.**

Do not expand the scope without the user's permission.
