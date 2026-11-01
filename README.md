# @jennifer/slack

[![test](https://github.com/jennifer-language/deck-slack/actions/workflows/test.yml/badge.svg)](https://github.com/jennifer-language/deck-slack/actions/workflows/test.yml)
[![Documentation](https://img.shields.io/badge/docs-github%20pages-blue)](https://jennifer-language.github.io/deck-slack/)
[![release](https://img.shields.io/github/v/release/jennifer-language/deck-slack)](https://github.com/jennifer-language/deck-slack/releases/latest)

Posts messages to a Slack channel through an Incoming Webhook from a
[Jennifer](https://jennifer-lang.dev/) program, as plain text or as Block Kit
blocks. Replaces the `slack` module of Jennifer's standard library (shipped
since 0.18.0, deprecated from 0.26.0, removed in 0.28.0); the API is
unchanged, only the import differs.

**[Documentation](https://jennifer-language.github.io/deck-slack/)**

## Install

```sh
jvc add @jennifer/slack
```

This vendors the deck to `vendor/jennifer/slack/`. Without `jvc`, unpack the
`src/` subtree of a release archive (`jennifer-slack-<version>.tar.gz`) there.

## Usage

```jennifer
import "@jennifer/slack/" as slack;
import "http.j" as http;

def url as string init os.getEnv("SLACK_WEBHOOK_URL");
def r as http.Response init slack.send($url, "deploy finished");
io.printf("%d\n", $r.status);   # 200 with body "ok"; a bad webhook is 4xx, not an error
```

`examples/post.j` posts a plain and a Block Kit message.

## Requirements

Jennifer 0.25.0 or newer and network access to `hooks.slack.com`. Posts need
the default `jennifer` binary; the stock `jennifer-tiny` has no network driver.

## Development

```sh
tools/check-all.sh                   # the full gate, as CI runs it
jennifer test src/slack_test.j       # the test overlay
tools/check-docs.sh                  # docs against the code
tools/pack.sh dist                   # build the release archive
```

## Licence

LGPL-3.0-only, see [LICENSE](LICENSE). Copyright (C) 2026 mplx &lt;mplx@jennifer-lang.dev&gt;.

`tools/check-headers.sh` checks every source file's SPDX header against
`deck.toml`.
