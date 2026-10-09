import {isHttpsUrl, isPlainObject} from "../core/validation";
import {
  InvalidUrlReason,
  parseVideoUrl,
  VideoPlatform,
  VIMEO_OEMBED,
  YOUTUBE_OEMBED,
} from "./videoUrl";

export type VideoMetadataResult =
  | {
      status: "ok";
      platform: VideoPlatform;
      domain: string;
      externalVideoId: string | null;
      title: string | null;
      thumbnailUrl: string | null;
      authorName: string | null;
      canonicalUrl: string;
      metadataAvailable: boolean;
    }
  | {status: "invalidUrl"; reason: InvalidUrlReason};

export type OEmbedFetcher = (url: string) => Promise<unknown>;

const MAX_OEMBED_BYTES = 256 * 1024;

/**
 * GET a un endpoint oEmbed permitido (timeout 5 s, sin redirecciones).
 * @param {string} url URL oEmbed generada por parseVideoUrl.
 * @return {Promise<unknown>} JSON de la respuesta.
 */
export async function fetchOEmbedJson(url: string): Promise<unknown> {
  if (
    !url.startsWith(`${YOUTUBE_OEMBED}?`) &&
    !url.startsWith(`${VIMEO_OEMBED}?`)
  ) {
    throw new Error("Endpoint oEmbed no permitido");
  }
  const response = await fetch(url, {
    method: "GET",
    headers: {accept: "application/json"},
    redirect: "error",
    signal: AbortSignal.timeout(5000),
  });
  if (!response.ok) throw new Error(`oEmbed HTTP ${response.status}`);
  const text = await response.text();
  if (text.length > MAX_OEMBED_BYTES) throw new Error("oEmbed muy grande");
  return JSON.parse(text);
}

/**
 * @param {unknown} value Valor.
 * @param {number} max Longitud máxima.
 * @return {string | null} Texto recortado o null.
 */
function text(value: unknown, max: number): string | null {
  if (typeof value !== "string") return null;
  const clean = value.trim();
  return clean.length > 0 ? Array.from(clean).slice(0, max).join("") : null;
}

/**
 * Resuelve plataforma, URL canónica y metadatos. Un fallo de oEmbed no es
 * error: se devuelve ok con metadataAvailable false.
 * @param {string} rawUrl URL ingresada.
 * @param {OEmbedFetcher} fetcher Cliente oEmbed (inyectable en pruebas).
 * @return {Promise<VideoMetadataResult>} Resultado del contrato.
 */
export async function resolveVideoMetadata(
  rawUrl: string,
  fetcher: OEmbedFetcher = fetchOEmbedJson,
): Promise<VideoMetadataResult> {
  const parsed = parseVideoUrl(rawUrl);
  if (!parsed.ok) return {status: "invalidUrl", reason: parsed.reason};

  let title: string | null = null;
  let authorName: string | null = null;
  let thumbnailUrl: string | null = null;
  if (parsed.oembedUrl) {
    try {
      const json = await fetcher(parsed.oembedUrl);
      if (isPlainObject(json)) {
        title = text(json.title, 200);
        authorName = text(json.author_name, 200);
        const thumb = text(json.thumbnail_url, 2048);
        thumbnailUrl = thumb && isHttpsUrl(thumb) ? thumb : null;
      }
    } catch {
      title = null;
    }
  }
  return {
    status: "ok",
    platform: parsed.platform,
    domain: parsed.domain,
    externalVideoId: parsed.externalVideoId,
    title,
    thumbnailUrl: thumbnailUrl ?? parsed.fallbackThumbnailUrl,
    authorName,
    canonicalUrl: parsed.canonicalUrl,
    metadataAvailable: title !== null,
  };
}
