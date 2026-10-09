export type VideoPlatform = "youtube" | "vimeo" | "facebook" | "other";

export type InvalidUrlReason =
  | "empty"
  | "tooLong"
  | "unparseable"
  | "notHttps"
  | "credentials"
  | "noHost"
  | "invalidVideoId";

export interface ParsedVideoUrl {
  ok: true;
  platform: VideoPlatform;
  domain: string;
  externalVideoId: string | null;
  canonicalUrl: string;
  /** Endpoint oEmbed fijo (solo YouTube o Vimeo); null = no consultar. */
  oembedUrl: string | null;
  fallbackThumbnailUrl: string | null;
}

export type ParseVideoUrlResult =
  | ParsedVideoUrl
  | {ok: false; reason: InvalidUrlReason};

export const MAX_VIDEO_URL_LENGTH = 2048;
export const YOUTUBE_OEMBED = "https://www.youtube.com/oembed";
export const VIMEO_OEMBED = "https://vimeo.com/api/oembed.json";

const YOUTUBE_HOSTS = new Set([
  "youtube.com",
  "www.youtube.com",
  "m.youtube.com",
  "music.youtube.com",
  "youtu.be",
  "www.youtube-nocookie.com",
]);
const VIMEO_HOSTS = new Set(["vimeo.com", "www.vimeo.com", "player.vimeo.com"]);
const FACEBOOK_HOSTS = new Set([
  "facebook.com",
  "www.facebook.com",
  "m.facebook.com",
  "fb.watch",
]);

const YOUTUBE_ID = /^[A-Za-z0-9_-]{11}$/;
const VIMEO_ID = /^\d{1,15}$/;
const VIMEO_HASH = /^[0-9a-f]{6,32}$/;

/**
 * @param {URL} url URL de YouTube.
 * @return {string | null} Id de 11 caracteres o null.
 */
function youtubeId(url: URL): string | null {
  const segments = url.pathname.split("/").filter((s) => s.length > 0);
  let candidate: string | null = null;
  if (url.hostname === "youtu.be") {
    candidate = segments[0] ?? null;
  } else if (url.pathname === "/watch" || url.pathname === "/watch/") {
    candidate = url.searchParams.get("v");
  } else if (["shorts", "live", "embed"].includes(segments[0] ?? "")) {
    candidate = segments[1] ?? null;
  }
  return candidate !== null && YOUTUBE_ID.test(candidate) ? candidate : null;
}

/**
 * @param {URL} url URL de Vimeo.
 * @return {object | null} Id numérico y hash (videos no listados).
 */
function vimeoId(url: URL): {id: string; hash: string | null} | null {
  const segments = url.pathname.split("/").filter((s) => s.length > 0);
  if (url.hostname === "player.vimeo.com") {
    if (segments[0] !== "video" || !VIMEO_ID.test(segments[1] ?? "")) {
      return null;
    }
    const h = url.searchParams.get("h");
    return {id: segments[1], hash: h && VIMEO_HASH.test(h) ? h : null};
  }
  const index = segments.findIndex((s) => VIMEO_ID.test(s));
  if (index < 0) return null;
  const next = segments[index + 1] ?? "";
  return {id: segments[index], hash: VIMEO_HASH.test(next) ? next : null};
}

/**
 * Valida y clasifica la URL de una prédica. Solo genera URLs oEmbed hacia
 * los dos endpoints fijos (sin SSRF).
 * @param {string} raw URL ingresada por el admin.
 * @return {ParseVideoUrlResult} Datos derivados o motivo de rechazo.
 */
export function parseVideoUrl(raw: string): ParseVideoUrlResult {
  const text = raw.trim();
  if (text.length === 0) return {ok: false, reason: "empty"};
  if (text.length > MAX_VIDEO_URL_LENGTH) return {ok: false, reason: "tooLong"};
  let url: URL;
  try {
    url = new URL(text);
  } catch {
    return {ok: false, reason: "unparseable"};
  }
  if (url.protocol !== "https:") return {ok: false, reason: "notHttps"};
  if (url.username !== "" || url.password !== "") {
    return {ok: false, reason: "credentials"};
  }
  const host = url.hostname.toLowerCase();
  if (host.length === 0) return {ok: false, reason: "noHost"};

  if (YOUTUBE_HOSTS.has(host)) {
    const id = youtubeId(url);
    if (!id) return {ok: false, reason: "invalidVideoId"};
    const canonicalUrl = `https://www.youtube.com/watch?v=${id}`;
    return {
      ok: true,
      platform: "youtube",
      domain: host,
      externalVideoId: id,
      canonicalUrl,
      oembedUrl: `${YOUTUBE_OEMBED}?format=json&url=` +
        encodeURIComponent(canonicalUrl),
      fallbackThumbnailUrl: `https://i.ytimg.com/vi/${id}/hqdefault.jpg`,
    };
  }

  if (VIMEO_HOSTS.has(host)) {
    const parsed = vimeoId(url);
    if (!parsed) return {ok: false, reason: "invalidVideoId"};
    const canonicalUrl = `https://vimeo.com/${parsed.id}` +
      (parsed.hash ? `/${parsed.hash}` : "");
    return {
      ok: true,
      platform: "vimeo",
      domain: host,
      externalVideoId: parsed.id,
      canonicalUrl,
      oembedUrl: `${VIMEO_OEMBED}?url=${encodeURIComponent(canonicalUrl)}`,
      fallbackThumbnailUrl: null,
    };
  }

  return {
    ok: true,
    platform: FACEBOOK_HOSTS.has(host) ? "facebook" : "other",
    domain: host,
    externalVideoId: null,
    canonicalUrl: url.href,
    oembedUrl: null,
    fallbackThumbnailUrl: null,
  };
}
