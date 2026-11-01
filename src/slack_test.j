# SPDX-License-Identifier: LGPL-3.0-only
# SPDX-FileCopyrightText: Copyright (C) 2026 mplx <mplx@jennifer-lang.dev>
# pragma-jennifer-version: >=0.25.0

/**
 * White-box tests for slack: jennifer test src/slack_test.j
 *
 * The Block Kit payloads are rendered directly. The posts go to an `httpd`
 * server on a loopback port, which answers one request like an Incoming
 * Webhook does and hands back what it received.
 */
use convert;
use httpd;
use task;
use testing;

/** One request as the fake webhook saw it. */
def struct Seen {
    method as string,
    path as string,
    contentType as string,
    body as string
};

/**
 * Answer one request: 200 `ok` on `/webhook`, else 404 `no_service`, as Slack
 * answers an unknown webhook.
 *
 * @param srv {httpd.Server} the listening server
 * @return {Seen} the request
 */
func answerOne(srv as httpd.Server) {
    def req as httpd.Request init httpd.accept($srv);
    def seen as Seen init Seen{
        method: httpd.method($req),
        path: httpd.path($req),
        contentType: httpd.header($req, "Content-Type"),
        body: convert.stringFromBytes(httpd.body($req), "utf-8")
    };
    if ($seen.path == "/webhook") {
        httpd.respond($req, 200, "ok");
    } else {
        httpd.respond($req, 404, "no_service");
    }
    return $seen;
}

func testRenderTextOnly() {
    def m as Message init text(message(), "deploy done");
    testing.assertEqual(render($m), '{"text":"deploy done"}');
}

func testRenderEmpty() {
    testing.assertEqual(render(message()), '{}');
}

func testRenderBlocks() {
    def m as Message init message();
    $m = header($m, "Deploy");
    $m = section($m, "*build* live");
    $m = divider($m);
    testing.assertEqual(
        render($m),
        '{"blocks":[' +
            '{"type":"header","text":{"type":"plain_text","text":"Deploy"}},' +
            '{"type":"section","text":{"type":"mrkdwn","text":"*build* live"}},' +
            '{"type":"divider"}]}');
}

func testTextAndBlocks() {
    def m as Message init section(text(message(), "fallback"), "body");
    testing.assertEqual(
        render($m),
        '{"text":"fallback","blocks":[{"type":"section","text":{"type":"mrkdwn","text":"body"}}]}');
}

func testContextBlock() {
    def m as Message init contextBlock(message(), "posted by ci");
    testing.assertEqual(
        render($m),
        '{"blocks":[{"type":"context","elements":[' +
            '{"type":"mrkdwn","text":"posted by ci"}]}]}');
}

func testFieldsSection() {
    def fields as list of string init ["*Env:*\nprod", "*Build:*\n1234"];
    def m as Message init fieldsSection(message(), $fields);
    testing.assertEqual(
        render($m),
        '{"blocks":[{"type":"section","fields":[' +
            '{"type":"mrkdwn","text":"*Env:*\nprod"},' +
            '{"type":"mrkdwn","text":"*Build:*\n1234"}]}]}');
}

func testActionsBlock() {
    def buttons as list of string init [
        button("View build", "https://example.com/build"),
        button("Logs", "https://example.com/logs")
    ];
    def m as Message init actionsBlock(message(), $buttons);
    testing.assertEqual(
        render($m),
        '{"blocks":[{"type":"actions","elements":[' +
            '{"type":"button","text":{"type":"plain_text","text":"View build"},' +
            '"url":"https://example.com/build"},' +
            '{"type":"button","text":{"type":"plain_text","text":"Logs"},' +
            '"url":"https://example.com/logs"}]}]}');
}

func testSectionEscaping() {
    def m as Message init section(message(), "a \"quote\" & <tag>\nnl");
    # json.encode is HTML-safe: `&` `<` `>` become \u0026 \u003c \u003e (still
    # valid JSON, decodes identically), so the Slack payload stays intact.
    testing.assertEqual(
        render($m),
        '{"blocks":[{"type":"section","text":{"type":"mrkdwn",' +
            '"text":"a \"quote\" \u0026 \u003ctag\u003e\nnl"}}]}');
}

func testSendPostsThePlainText() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    defer httpd.shutdown($srv);
    def t as task of Seen init spawn {
        return answerOne($srv);
    };
    def r as http.Response init send("http://" + httpd.address($srv) + "/webhook", "hello");
    def seen as Seen init task.wait($t);
    testing.assertEqual($r.status, 200);
    testing.assertEqual($r.body, "ok");
    testing.assertEqual($seen.method, "POST");
    testing.assertEqual($seen.contentType, "application/json");
    testing.assertEqual($seen.body, '{"text":"hello"}');
}

func testSendMessagePostsTheBlocks() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    defer httpd.shutdown($srv);
    def t as task of Seen init spawn {
        return answerOne($srv);
    };
    def m as Message init divider(section(header(message(), "Deploy"), "body"));
    def r as http.Response init sendMessage("http://" + httpd.address($srv) + "/webhook", $m);
    def seen as Seen init task.wait($t);
    testing.assertEqual($r.status, 200);
    testing.assertEqual($seen.contentType, "application/json");
    testing.assertEqual(
        $seen.body,
        '{"blocks":[{"type":"header","text":{"type":"plain_text","text":"Deploy"}},' +
            '{"type":"section","text":{"type":"mrkdwn","text":"body"}},{"type":"divider"}]}');
}

func testUnknownWebhookIsAResponse() {
    def srv as httpd.Server init httpd.listen("127.0.0.1:0");
    defer httpd.shutdown($srv);
    def t as task of Seen init spawn {
        return answerOne($srv);
    };
    def r as http.Response init send("http://" + httpd.address($srv) + "/gone", "x");
    task.wait($t);
    testing.assertEqual($r.status, 404);
    testing.assertEqual($r.body, "no_service");
}

func testEscape() {
    testing.assertEqual(
        escape("<!channel> a & b <https://x|y>"),
        "&lt;!channel&gt; a &amp; b &lt;https://x|y&gt;");
    testing.assertEqual(escape("plain"), "plain");
}

func testWebhookMustBeHttps() {
    for (def url in [
        "hooks.slack.com/services/T/B/x",
        "http://hooks.slack.com/services/T/B/x",
        "htps://hooks.slack.com/services/T/B/x",
        "http://127.0.0.1.example.com/x",
        "http://localhost@evil.example/x",
        ""
    ]) {
        testing.assertThrowsWith("checkWebhook", [$url], "slack");
    }
}

func testWebhookAcceptsHttpsAndLoopback() {
    for (def url in [
        "https://hooks.slack.com/services/T/B/x",
        "HTTPS://hooks.slack.com/x",
        "http://127.0.0.1:8080/webhook",
        "http://localhost/webhook",
        "http://[::1]:9/webhook",
        "http://evil.example@127.0.0.1:9/webhook"
    ]) {
        checkWebhook($url);
    }
}

func testSendRefusesPlainHttpBeforeSending() {
    testing.assertThrowsWith("send", ["http://hooks.slack.com/services/T/B/x", "x"], "slack");
}
