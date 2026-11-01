<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# slack cheatsheet

Every export of `@jennifer/slack`. Background is in
[the introduction](index.md).

```jennifer
import "@jennifer/slack/" as slack;
import "http.j" as http;
```

Every post is a JSON POST to the webhook URL and returns the `http.Response`
unchecked: `200` with body `ok` on success, `4xx` for a bad webhook. A URL
that is not `https://` (or `http://` to a loopback host) throws `slack`;
transport failures throw from `http`.

## Types

### `Message`

| Field | Meaning |
|---|---|
| `text as string` | fallback text, `""` to omit |
| `blocks as list of string` | rendered block JSON fragments |

## Posting

| Function | Returns | Posts |
|---|---|---|
| `slack.send(webhookUrl, text)` | `http.Response` | `{"text": text}` |
| `slack.sendMessage(webhookUrl, m)` | `http.Response` | `render(m)` |

## Escaping

| Function | Returns | Does |
|---|---|---|
| `slack.escape(text)` | `string` | `&`, `<`, `>` as `&amp;`, `&lt;`, `&gt;`, for untrusted text |

## Building

Each builder returns a new `Message` with one block appended.

| Function | Returns | Adds |
|---|---|---|
| `slack.message()` | `Message` | an empty message |
| `slack.text(m, text)` | `Message` | the fallback text |
| `slack.header(m, heading)` | `Message` | a plain-text header |
| `slack.section(m, markdown)` | `Message` | a mrkdwn section |
| `slack.fieldsSection(m, fields)` | `Message` | a section of mrkdwn fields |
| `slack.contextBlock(m, text)` | `Message` | a small mrkdwn context line |
| `slack.actionsBlock(m, buttons)` | `Message` | URL buttons from `button` |
| `slack.divider(m)` | `Message` | a horizontal rule |
| `slack.button(text, url)` | `string` | a button fragment for `actionsBlock` |
| `slack.render(m)` | `string` | the JSON payload, without posting |
