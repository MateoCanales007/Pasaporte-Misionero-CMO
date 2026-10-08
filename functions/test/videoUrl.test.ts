import assert from "node:assert/strict";
import {describe, test} from "node:test";
import {
  fetchOEmbedJson,
  resolveVideoMetadata,
} from "../src/sermons/videoMetadata";
import {parseVideoUrl} from "../src/sermons/videoUrl";

const ID = "dQw4w9WgXcQ";
const CANONICAL = `https://www.youtube.com/watch?v=${ID}`;

describe("parseVideoUrl – YouTube", () => {
  const forms = [
    `https://www.youtube.com/watch?v=${ID}`,
    `https://youtube.com/watch?v=${ID}&t=42s&list=PL123`,
    `https://m.youtube.com/watch?feature=share&v=${ID}`,
    `https://music.youtube.com/watch?v=${ID}&si=abc`,
    `https://youtu.be/${ID}?si=XyZ&t=10`,
    `https://www.youtube.com/shorts/${ID}`,
    `https://www.youtube.com/live/${ID}?feature=shared`,
    `https://www.youtube.com/embed/${ID}?start=10`,
    `https://www.youtube-nocookie.com/embed/${ID}`,
    `https://WWW.YouTube.com/watch?v=${ID}`,
    `   https://www.youtube.com/watch?v=${ID}   `,
  ];
  for (const url of forms) {
    test(`reconoce ${url.trim()}`, () => {
      const result = parseVideoUrl(url);
      assert.equal(result.ok, true);
      if (!result.ok) return;
      assert.equal(result.platform, "youtube");
      assert.equal(result.externalVideoId, ID);
      assert.equal(result.canonicalUrl, CANONICAL);
      assert.equal(
        result.oembedUrl,
        "https://www.youtube.com/oembed?format=json&url=" +
          encodeURIComponent(CANONICAL),
      );
      assert.equal(
        result.fallbackThumbnailUrl,
        `https://i.ytimg.com/vi/${ID}/hqdefault.jpg`,
      );
    });
  }

  test("id inválido o URL que no es de video → invalidVideoId", () => {
    for (const url of [
      "https://www.youtube.com/watch?v=corto",
      "https://www.youtube.com/watch?v=dQw4w9WgXcQ1",
      "https://www.youtube.com/@canal",
      "https://youtu.be/",
      "https://www.youtube.com/shorts/",
      "https://www.youtube.com/watch?v=dQw4w9W%3CXcQ",
    ]) {
      assert.deepEqual(parseVideoUrl(url), {
        ok: false,
        reason: "invalidVideoId",
      }, url);
    }
  });
});

describe("parseVideoUrl – Vimeo, Facebook y otros", () => {
  test("vimeo.com/ID", () => {
    const result = parseVideoUrl("https://vimeo.com/76979871");
    assert.ok(result.ok);
    assert.equal(result.platform, "vimeo");
    assert.equal(result.externalVideoId, "76979871");
    assert.equal(result.canonicalUrl, "https://vimeo.com/76979871");
    assert.equal(
      result.oembedUrl,
      "https://vimeo.com/api/oembed.json?url=" +
        encodeURIComponent("https://vimeo.com/76979871"),
    );
    assert.equal(result.fallbackThumbnailUrl, null);
  });

  test("player.vimeo.com/video/ID con hash y canales", () => {
    const player = parseVideoUrl(
      "https://player.vimeo.com/video/76979871?h=abcdef1234&autoplay=1",
    );
    assert.ok(player.ok);
    assert.equal(player.canonicalUrl, "https://vimeo.com/76979871/abcdef1234");
    const channel = parseVideoUrl(
      "https://www.vimeo.com/channels/staffpicks/76979871",
    );
    assert.ok(channel.ok);
    assert.equal(channel.externalVideoId, "76979871");
    assert.deepEqual(parseVideoUrl("https://vimeo.com/about"), {
      ok: false,
      reason: "invalidVideoId",
    });
  });

  test("Facebook: sin consulta oEmbed", () => {
    for (const url of [
      "https://www.facebook.com/watch/?v=1234567890",
      "https://m.facebook.com/iglesia/videos/1234567890/",
      "https://fb.watch/abcDEF123/",
    ]) {
      const result = parseVideoUrl(url);
      assert.ok(result.ok);
      assert.equal(result.platform, "facebook");
      assert.equal(result.oembedUrl, null);
      assert.equal(result.externalVideoId, null);
      assert.equal(result.canonicalUrl, new URL(url).href);
    }
  });

  test("otros dominios: platform other y domain = hostname", () => {
    const result = parseVideoUrl("https://media.example.org/predica.mp4?x=1");
    assert.ok(result.ok);
    assert.equal(result.platform, "other");
    assert.equal(result.domain, "media.example.org");
    assert.equal(result.oembedUrl, null);
  });
});

describe("parseVideoUrl – rechazos", () => {
  const cases: [string, string][] = [
    [`http://www.youtube.com/watch?v=${ID}`, "notHttps"],
    ["javascript:alert(1)", "notHttps"],
    ["JavaScript:alert(document.cookie)", "notHttps"],
    ["file:///etc/passwd", "notHttps"],
    ["data:text/html,<script>alert(1)</script>", "notHttps"],
    ["ftp://example.com/video", "notHttps"],
    [`https://user:pass@www.youtube.com/watch?v=${ID}`, "credentials"],
    ["https://user@example.com/video", "credentials"],
    ["esto no es una url", "unparseable"],
    ["//youtube.com/watch", "unparseable"],
    ["", "empty"],
    ["    ", "empty"],
    [`https://example.com/${"a".repeat(2048)}`, "tooLong"],
  ];
  for (const [url, reason] of cases) {
    test(`${url.slice(0, 50)} → ${reason}`, () => {
      assert.deepEqual(parseVideoUrl(url), {ok: false, reason});
    });
  }
});

describe("resolveVideoMetadata", () => {
  test("oEmbed correcto llena título, autor y miniatura", async () => {
    const calls: string[] = [];
    const result = await resolveVideoMetadata(
      `https://youtu.be/${ID}`,
      async (url) => {
        calls.push(url);
        return {
          title: "  Prédica dominical  ",
          author_name: "CMO",
          thumbnail_url: "https://i.ytimg.com/vi/x/maxres.jpg",
        };
      },
    );
    assert.deepEqual(calls, [
      `https://www.youtube.com/oembed?format=json&url=${
        encodeURIComponent(CANONICAL)}`,
    ]);
    assert.deepEqual(result, {
      status: "ok",
      platform: "youtube",
      domain: "youtu.be",
      externalVideoId: ID,
      title: "Prédica dominical",
      thumbnailUrl: "https://i.ytimg.com/vi/x/maxres.jpg",
      authorName: "CMO",
      canonicalUrl: CANONICAL,
      metadataAvailable: true,
    });
  });

  test("fallo o timeout de oEmbed → ok sin metadatos", async () => {
    const result = await resolveVideoMetadata(CANONICAL, async () => {
      throw new Error("timeout");
    });
    assert.equal(result.status, "ok");
    if (result.status !== "ok") return;
    assert.equal(result.title, null);
    assert.equal(result.authorName, null);
    assert.equal(result.metadataAvailable, false);
    assert.equal(
      result.thumbnailUrl,
      `https://i.ytimg.com/vi/${ID}/hqdefault.jpg`,
    );
  });

  test("miniatura no https se ignora", async () => {
    const result = await resolveVideoMetadata(
      "https://vimeo.com/76979871",
      async () => ({title: "T", thumbnail_url: "http://inseguro/x.jpg"}),
    );
    assert.equal(result.status === "ok" && result.thumbnailUrl, null);
  });

  test("Facebook y otros no consultan la red", async () => {
    const fetcher = async () => {
      throw new Error("no debe llamarse");
    };
    const fb = await resolveVideoMetadata(
      "https://fb.watch/abc/",
      fetcher,
    );
    assert.equal(fb.status === "ok" && fb.platform, "facebook");
    assert.equal(fb.status === "ok" && fb.metadataAvailable, false);
  });

  test("URL inválida → invalidUrl con motivo", async () => {
    assert.deepEqual(await resolveVideoMetadata("javascript:alert(1)"), {
      status: "invalidUrl",
      reason: "notHttps",
    });
  });

  test("fetchOEmbedJson solo acepta los dos endpoints fijos", async () => {
    await assert.rejects(fetchOEmbedJson("https://evil.example/oembed?x=1"));
    await assert.rejects(
      fetchOEmbedJson("https://www.youtube.com.evil.example/oembed?x"),
    );
    await assert.rejects(fetchOEmbedJson("http://169.254.169.254/latest"));
  });
});
