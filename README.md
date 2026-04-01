![Openbird Today view showing a generated daily review on macOS](./apps/landing/public/openbird-screenshot.png)

# Openbird

Openbird is a local-first macOS app that keeps a private record of your workday, turns it into a daily review, and lets you ask questions about what you were doing.

It is built for people who want help remembering their day without sending their activity history to someone else's server.

No account. No backend. Your data stays on your Mac by default.

## What You Can Do With It

Openbird builds a timeline from the app, window, tab, and on-screen context you are actively using, then uses that history to help you:

- generate a daily review with time blocks, highlights, and a short narrative
- ask follow-up questions about your day in chat
- jump back to the apps, windows, URLs, and timestamps behind each summary

It is useful for questions like:

- What did I actually spend time on today?
- What was I working on around 3 PM?
- Which project got most of my attention?
- Which apps, tabs, or docs was I using during that stretch?

## Privacy, In Plain Terms

Openbird is designed so you can see what it knows, control what it captures, and remove data whenever you want.

Openbird captures:

- the frontmost app
- app name and bundle ID
- window title
- browser tab URL when available
- visible text from the active window's accessibility tree
- start and end timestamps

Openbird does not capture:

- raw key events
- clipboard contents
- passwords
- secure text fields
- hidden or minimized windows
- automatic screenshots

You can also:

- pause capture at any time
- exclude apps
- exclude domains
- inspect the raw log behind each summary
- delete the last hour, the last day, or everything

All captured data is stored locally in:

`~/Library/Application Support/Openbird/openbird.sqlite`

## Use Your Own Model

Openbird works with local and self-hosted model providers, including:

- Ollama
- LM Studio
- other OpenAI-compatible endpoints

If your model runs locally, Openbird can stay fully offline.

Default local endpoints:

- Ollama: `http://127.0.0.1:11434/v1`
- LM Studio: `http://127.0.0.1:1234/v1`

The app includes presets for both and lets you configure separate generation and embedding models.

## Install

Current release target:

- macOS 14+
- Apple Silicon

Download the latest release here:

[Latest Release](https://github.com/ComputelessComputer/openbird/releases/latest)

Open the DMG, drag `Openbird.app` into `Applications`, then launch it.

## Quick Start

1. Download the latest release.
2. Launch `Openbird.app`.
3. Grant Accessibility permission when prompted.
4. In Settings, choose an Ollama or LM Studio preset, or add your own compatible endpoint.
5. Click `Check Connection`, then save the provider.
6. Open `Today` and generate your first review.
7. Use `Chat` to ask questions about your day.

## Inside The App

Openbird has four main areas:

- Onboarding for permissions and privacy
- Today for generating your daily review
- Chat for asking questions about your activity history
- Settings for model setup, exclusions, retention, pause, and delete controls

## Project Status

Openbird is still early and should be treated as experimental software, but the main flow already works:

- local capture
- local storage
- exclusions
- raw-log inspection
- daily journal generation
- date-scoped chat over your activity history

The current focus is a trustworthy personal activity journal first. Parts of this work may later feed into [Char](https://char.com), but the goal here is to keep the local-first, inspectable privacy model intact.

## Open Source

Open source is part of the product.

When an app can observe your work, you should be able to inspect how it works, where it stores data, what it excludes, and which model receives your prompts.

The code is public because trust is stronger when it can be verified.
