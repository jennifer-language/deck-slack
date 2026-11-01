# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * Post messages to a Slack channel through an Incoming Webhook, on top of the
 * `http` module. `send(webhookUrl, text)` posts a plain message; the `message`
 * builder assembles a richer payload from Slack Block Kit blocks (`header`,
 * `section`, `fieldsSection`, `contextBlock`, `actionsBlock`, `divider`) and
 * `sendMessage` posts it. Needs the default `jennifer` binary, since `http`
 * uses `net`. The webhook URL is a secret: read it from the environment or a
 * config file. A URL other than `https://` (or `http://` to a loopback host)
 * throws `Error{kind: "slack"}` before anything is sent.
 *
 * Replaces the `slack` module of the Jennifer standard library (since 0.18.0,
 * deprecated from 0.26.0, removed in 0.28.0) with the same surface.
 *
 * @module slack
 * @example
 *   slack.send("https://hooks.slack.com/services/T/B/xxx", "deploy finished");
 *   def m as slack.Message init slack.section(
 *       slack.header(slack.message(), "Deploy"), "*build 1234* is live");
 *   slack.sendMessage("https://hooks.slack.com/services/T/B/xxx", $m);
 */
use json;
use strings;
import "http.j" as http;

/**
 * A rich message under construction: a fallback text (shown in notifications)
 * plus a list of pre-rendered Block Kit block JSON fragments.
 * @field text {string} the top-level fallback / notification text ("" to omit)
 * @field blocks {list of string} pre-rendered block JSON fragments
 */
export def struct Message {
    text as string,
    blocks as list of string
};

# isLoopback reports whether an http:// URL (scheme already stripped) names a
# loopback host, so a local test server can stand in for Slack.
func isLoopback(rest as string) {
    def authority as string init $rest;
    for (def stop in ["/", "?", "#"]) {
        def i as int init strings.indexOf($authority, $stop);
        if ($i >= 0) {
            $authority = $authority[..$i];
        }
    }
    def at as int init strings.lastIndexOf($authority, "@");
    if ($at >= 0) {
        $authority = $authority[$at + 1..];
    }
    def host as string init $authority;
    if (strings.startsWith($host, "[")) {
        def rb as int init strings.indexOf($host, "]");
        if ($rb >= 0) {
            $host = $host[..$rb + 1];
        }
    } else {
        def colon as int init strings.indexOf($host, ":");
        if ($colon >= 0) {
            $host = $host[..$colon];
        }
    }
    $host = strings.lower($host);
    return $host == "127.0.0.1" or $host == "localhost" or $host == "[::1]";
}

# checkWebhook throws unless the URL is https://, or http:// to a loopback host.
# `http` sends anything else, a missing or mistyped scheme included, in the
# clear, and the URL is the secret. The message leaves the URL out.
func checkWebhook(webhookUrl as string) {
    def lower as string init strings.lower($webhookUrl);
    if (strings.startsWith($lower, "https://")) {
        return;
    }
    if (strings.startsWith($lower, "http://") and isLoopback($webhookUrl[7..])) {
        return;
    }
    throw Error{kind: "slack", message: "slack: the webhook URL must start with https://"};
}

# post sends a JSON payload to a Slack webhook URL.
func post(webhookUrl as string, payload as string) {
    checkWebhook($webhookUrl);
    def headers as map of string to string init {};
    return http.post($webhookUrl, "application/json", $payload, $headers);
}

/**
 * Post a plain-text message to a Slack Incoming Webhook.
 * @param webhookUrl {string} the Incoming Webhook URL
 * @param text {string} the message text (Slack mrkdwn)
 * @return {http.Response} Slack answers 200 with body "ok" on success
 */
export func send(webhookUrl as string, text as string) {
    def payload as map of string to string init {"text": $text};
    return post($webhookUrl, json.encode($payload));
}

/**
 * Escape `&`, `<` and `>` so text from elsewhere (a commit message, a user
 * name) shows literally in mrkdwn instead of becoming a link or a mention such
 * as `<!channel>`.
 * @param text {string} the untrusted text
 * @return {string} the text with `&amp;`, `&lt;` and `&gt;` in place
 */
export func escape(text as string) {
    def out as string init strings.replace($text, "&", "&amp;");
    $out = strings.replace($out, "<", "&lt;");
    return strings.replace($out, ">", "&gt;");
}

# --- rich-message builder (exported) ----------------------------------------

/**
 * Start an empty rich message (no fallback text, no blocks).
 * @return {Message} a fresh message
 */
export func message() {
    def blocks as list of string init [];
    return Message{text: "", blocks: $blocks};
}

/**
 * Set the top-level fallback text (shown in notifications and by clients that
 * do not render blocks). Returns a fresh message.
 * @param m {Message} the message
 * @param text {string} the fallback text
 * @return {Message} a message with the fallback text set
 */
export func text(m as Message, text as string) {
    def out as Message init $m;
    $out.text = $text;
    return $out;
}

/**
 * Add a section block (Slack mrkdwn). Returns a fresh message.
 * @param m {Message} the message
 * @param markdown {string} the section body (mrkdwn)
 * @return {Message} a message with the section appended
 */
export func section(m as Message, markdown as string) {
    def out as Message init $m;
    def block as string init '{"type":"section","text":{"type":"mrkdwn","text":' +
        json.encode($markdown) + '}}';
    $out.blocks[] = $block;
    return $out;
}

/**
 * Add a header block (plain text, bold and large). Returns a fresh message.
 * @param m {Message} the message
 * @param heading {string} the header text (plain text)
 * @return {Message} a message with the header appended
 */
export func header(m as Message, heading as string) {
    def out as Message init $m;
    def block as string init '{"type":"header","text":{"type":"plain_text","text":' +
        json.encode($heading) + '}}';
    $out.blocks[] = $block;
    return $out;
}

/**
 * Add a context block (small, muted helper text in mrkdwn). Returns a fresh
 * message.
 * @param m {Message} the message
 * @param text {string} the context text (mrkdwn)
 * @return {Message} a message with the context block appended
 */
export func contextBlock(m as Message, text as string) {
    def out as Message init $m;
    def block as string init '{"type":"context","elements":[{"type":"mrkdwn","text":' +
        json.encode($text) + '}]}';
    $out.blocks[] = $block;
    return $out;
}

/**
 * Add a section block laid out as two-column fields (each entry rendered as
 * mrkdwn). Slack packs the fields into a two-column grid. Returns a fresh
 * message.
 * @param m {Message} the message
 * @param fields {list of string} the field texts (mrkdwn), in order
 * @return {Message} a message with the fields section appended
 */
export func fieldsSection(m as Message, fields as list of string) {
    def out as Message init $m;
    def parts as list of string init [];
    for (def f in $fields) {
        $parts[] = '{"type":"mrkdwn","text":' + json.encode($f) + '}';
    }
    def block as string init '{"type":"section","fields":[' + strings.join($parts, ",") + ']}';
    $out.blocks[] = $block;
    return $out;
}

/**
 * Build a single URL button element for an actions block. Returns the
 * pre-rendered button JSON fragment; pass a list of these to `actionsBlock`.
 * @param text {string} the button label (plain text)
 * @param url {string} the URL the button opens
 * @return {string} the button JSON fragment
 */
export func button(text as string, url as string) {
    return '{"type":"button","text":{"type":"plain_text","text":' + json.encode($text) +
        '},"url":' + json.encode($url) + '}';
}

/**
 * Add an actions block from one or more buttons (built with `button`). Returns
 * a fresh message.
 * @param m {Message} the message
 * @param buttons {list of string} pre-rendered button fragments (see `button`)
 * @return {Message} a message with the actions block appended
 */
export func actionsBlock(m as Message, buttons as list of string) {
    def out as Message init $m;
    def block as string init '{"type":"actions","elements":[' + strings.join($buttons, ",") +
        ']}';
    $out.blocks[] = $block;
    return $out;
}

/**
 * Add a divider block (a horizontal rule). Returns a fresh message.
 * @param m {Message} the message
 * @return {Message} a message with the divider appended
 */
export func divider(m as Message) {
    def out as Message init $m;
    $out.blocks[] = '{"type":"divider"}';
    return $out;
}

/**
 * Render a message to its JSON payload string.
 * @param m {Message} the message
 * @return {string} the JSON payload Slack expects
 */
export func render(m as Message) {
    def parts as list of string init [];
    if (len($m.text) > 0) {
        $parts[] = "\"text\":" + json.encode($m.text);
    }
    if (len($m.blocks) > 0) {
        $parts[] = "\"blocks\":[" + strings.join($m.blocks, ",") + "]";
    }
    return '{' + strings.join($parts, ",") + '}';
}

/**
 * Post a built rich message to a Slack Incoming Webhook.
 * @param webhookUrl {string} the Incoming Webhook URL
 * @param m {Message} the message to send
 * @return {http.Response} Slack answers 200 with body "ok" on success
 */
export func sendMessage(webhookUrl as string, m as Message) {
    return post($webhookUrl, render($m));
}
