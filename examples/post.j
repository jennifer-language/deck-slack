#!/usr/bin/env -S jennifer run
# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * Post to Slack: SLACK_WEBHOOK_URL=... jennifer run examples/post.j
 *
 * Prints the payloads it builds. Without SLACK_WEBHOOK_URL it posts nothing;
 * when the webhook cannot be reached it prints the error.
 */

use io;
use os;

import "http.j" as http;
import "../src/slack.j" as slack;

def url as string init os.getEnv("SLACK_WEBHOOK_URL");

def m as slack.Message init slack.message();
$m = slack.text($m, "Deploy finished");
$m = slack.header($m, "Deploy");
$m = slack.section($m, "*build 1234* is live in _production_");
$m = slack.fieldsSection($m, ["*Env:*\nprod", "*Build:*\n1234"]);
$m = slack.divider($m);
$m = slack.actionsBlock(
    $m,
    [slack.button("Docs", "https://jennifer-language.github.io/deck-slack/")]);

io.printf("plain:  %s\n", slack.render(slack.text(slack.message(), "hello")));
io.printf("blocks: %s\n", slack.render($m));

if (len($url) == 0) {
    io.printf("set SLACK_WEBHOOK_URL to post the messages\n");
} else {
    try {
        def r as http.Response init slack.send($url, "Hello from @jennifer/slack");
        io.printf("send -> %d %s\n", $r.status, $r.body);
        def b as http.Response init slack.sendMessage($url, $m);
        io.printf("sendMessage -> %d %s\n", $b.status, $b.body);
    } catch (e) {
        io.printf("could not post to the webhook (%s)\n", $e.message);
    }
}
