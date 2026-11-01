<!-- SPDX-License-Identifier: LGPL-3.0-only -->
<!-- SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev> -->

# @jennifer/slack

Posts messages to a Slack channel through an
[Incoming Webhook](https://api.slack.com/messaging/webhooks), using Jennifer's
`http` module. The full API is on the [cheatsheet](cheatsheet.md).

## Conventions

Snippets assume these imports:

```jennifer
import "@jennifer/slack/" as slack;
import "http.j" as http;
```

The trailing slash resolves to the entry module.

## Posting

```jennifer
def url as string init os.getEnv("SLACK_WEBHOOK_URL");
def r as http.Response init slack.send($url, "deploy *1234* finished");
if ($r.status != 200) {
    io.printf("slack: %d %s\n", $r.status, $r.body);
}
```

`send` POSTs `{"text": ...}` as JSON to the webhook URL. The text is Slack
[mrkdwn](https://api.slack.com/reference/surfaces/formatting). The webhook URL
is a secret that grants posting to one channel: read it from the environment
or a config file, never from source. A URL that does not start with `https://`
throws an error of kind `slack` before anything is sent, so a missing or
mistyped scheme cannot send the secret in the clear; `http://` is allowed only
to `127.0.0.1`, `localhost` and `[::1]`, for a local test server.

Text from elsewhere (a commit message, a user name) can carry mrkdwn control
sequences: `<!channel>` notifies the whole channel and `<url|label>` makes a
link. Pass it through `escape` first, which turns `&`, `<` and `>` into
`&amp;`, `&lt;` and `&gt;`:

```jennifer
slack.send($url, "deployed: " + slack.escape($commitMessage));
```

## Block Kit messages

`message()` starts an empty `Message`; each builder returns a new one with a
[block](https://api.slack.com/reference/block-kit/blocks) appended, and
`sendMessage` posts it:

```jennifer
def m as slack.Message init slack.message();
$m = slack.text($m, "Deploy finished");
$m = slack.header($m, "Deploy");
$m = slack.section($m, "*build 1234* is live");
$m = slack.fieldsSection($m, ["*Env:*\nprod", "*Build:*\n1234"]);
$m = slack.actionsBlock($m, [slack.button("Logs", "https://ci.example.com/1234")]);
def r as http.Response init slack.sendMessage($url, $m);
```

| Builder | Block |
|---|---|
| `text(m, text)` | top-level fallback text, shown in notifications |
| `header(m, heading)` | `header`, plain text |
| `section(m, markdown)` | `section` with mrkdwn text |
| `fieldsSection(m, fields)` | `section` with mrkdwn fields in two columns |
| `contextBlock(m, text)` | `context`, small muted mrkdwn |
| `actionsBlock(m, buttons)` | `actions` with URL buttons made by `button(text, url)` |
| `divider(m)` | `divider` |

`render(m)` returns the JSON payload without posting it. Text and blocks are
left out when empty, so `render(message())` is `{}`.

## Errors

`send` and `sendMessage` return the `http.Response` and do not inspect it.
Slack answers `200` with the body `ok`; a revoked or unknown webhook is a
`4xx` response (body such as `no_service`), not an error. A webhook URL that
is not `https://` throws an error of kind `slack`; a transport failure (no
network, refused connection, TLS) throws from `http`.

## Runtime

Needs `net`, so it runs on the default `jennifer` binary. The stock
`jennifer-tiny` has no network driver and every post throws; building and
rendering messages works on both.

## Moving from the standard library module

Jennifer has shipped `slack` as a standard library module (`modules/slack.j`)
since 0.18.0; `contextBlock`, `fieldsSection`, `button` and `actionsBlock`
came in 0.23.0. The module is deprecated from Jennifer 0.26.0 and removed in
0.28.0. This deck replaces it with the same types and functions; only the
import changes:

```jennifer
import "slack.j" as slack;            # before
import "@jennifer/slack/" as slack;   # after: jvc add @jennifer/slack
```

Two things differ from the module: the deck adds `escape`, and it refuses a
webhook URL that is not `https://`, which the module would have sent.
