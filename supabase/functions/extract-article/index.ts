// @ts-nocheck
// deno-lint-ignore-file no-explicit-any prefer-const
/**
 * extract-article Edge Function
 *
 * 接收 URL，使用 Mozilla Readability 算法提取网页正文。
 *
 * POST /functions/v1/extract-article
 * Body: { "url": "https://example.com/article" }
 *
 * Response:
 *   { ok: true, title: "...", textContent: "...", content: "<html>..." }
 *   { ok: false, error: "...", message: "..." }
 */

import { parseHTML } from "npm:linkedom@0.18.5";
import { corsHeaders } from "../_shared/cors.ts";

// ══════════════════════════════════════════════
//  Readability 核心算法（精简移植版）
//  基于 Mozilla Readability.js，适配 linkedom
// ══════════════════════════════════════════════

const REGEXPS = {
  unlikelyCandidates:
    /-ad-|ai2html|banner|breadcrumbs|combx|comment|community|cover-wrap|disqus|extra|footer|gdpr|header|legends|menu|related|remark|replies|rss|shoutbox|sidebar|skyscraper|social|sponsor|supplemental|ad-break|agegate|pagination|pager|popup|yom-remote/i,
  okMaybeItsACandidate:
    /and|article|body|column|content|main|shadow/i,
  positive:
    /article|body|content|entry|hentry|h-entry|main|page|pagination|post|text|blog|story/i,
  negative:
    /-ad-|hidden|^hid$| hid$| hid |^hid |banner|combx|comment|com-|contact|foot|footer|footnote|gdpr|masthead|media|meta|outbrain|promo|related|scroll|share|shoutbox|sidebar|skyscraper|sponsor|shopping|tags|tool|widget/i,
  extraneous:
    /print|archive|comment|discuss|e[\-]?mail|share|reply|all|login|sign|single|utility/i,
  byline: /byline|author|dateline|writtenby|p-author/i,
  replaceFonts: /<(\/?)font[^>]*>/gi,
  normalize: /\s{2,}/g,
  videos: /\/\/(www\.)?((dailymotion|youtube|youtube-nocookie|player\.vimeo|v\.qq)\.com|(archive|upload\.wikimedia)\.org|player\.twitch\.tv)/i,
  shareElements: /(\b|_)(share|sharedaddy)(\b|_)/i,
  hasContent: /\S$/,
  sentences: /\S[.?!。！？](?:\s|$)/,
};

const DEFAULT_TAGS_TO_SCORE = "section,h2,h3,h4,h5,h6,p,td,pre,div".toUpperCase().split(",");
const DEFAULT_TAGS_TO_IGNORE = "script,style,noscript,br,hr,svg,math,header,footer,nav,aside,form,button,textarea,select,option,iframe,embed,object,canvas,video,audio".toUpperCase().split(",");

const DIV_TO_P_ELEMS = new Set(["BLOCKQUOTE", "DL", "DIV", "IMG", "OL", "P", "PRE", "TABLE", "UL"]);

interface ArticleMetadata {
  byline: string;
  title: string;
  excerpt: string;
  siteName: string;
}

interface RArticle {
  title: string;
  content: string;
  textContent: string;
  length: number;
  excerpt: string;
  byline: string;
  dir: string;
  siteName: string;
}

function getInnerText(node: any, normalizeSpaces: boolean): string {
  const textContent = node.textContent.trim();
  return normalizeSpaces ? textContent.replace(REGEXPS.normalize, " ") : textContent;
}

function getCharCount(node: any, s: string | RegExp): number {
  return (getInnerText(node, false).match(new RegExp(s, "g")) || []).length;
}

function getLinkDensity(node: any): number {
  const textLength = getInnerText(node, true).length;
  if (textLength === 0) return 0;
  let linkLength = 0;
  const links = node.querySelectorAll("a");
  for (const link of links) {
    const linkText = getInnerText(link, true);
    linkLength += linkText.length;
  }
  return linkLength / textLength;
}

function getClassWeight(node: any): number {
  let weight = 0;
  const className = (node.className || "").toString();
  const id = (node.id || "").toString();

  if (className || id) {
    if (REGEXPS.negative.test(className)) weight -= 25;
    if (REGEXPS.negative.test(id)) weight -= 25;
    if (REGEXPS.positive.test(className)) weight += 25;
    if (REGEXPS.positive.test(id)) weight += 25;
  }
  return weight;
}

function nodeIsSufficientContent(node: any): boolean {
  return getInnerText(node, true).length >= 100;
}

class Readability {
  private doc: any;
  private articleTitle: string = "";
  private articleByline: string = "";
  private articleDir: string = "";
  private articleSiteName: string = "";
  private attempts: any[] = [];

  constructor(doc: any) {
    this.doc = doc;
  }

  parse(): RArticle | null {
    // 1. 预处理
    this.prepDocument();
    const metadata = this.getArticleMetadata();

    // 2. 找候选节点
    let candidates = this.getCandidates();

    // 3. 如果没有高分候选，放宽条件
    if (candidates.length === 0) {
      candidates = this.getCandidates(true);
    }

    if (candidates.length === 0) {
      return null;
    }

    // 4. 对候选节点打分并选最佳
    const topCandidate = this.selectTopCandidate(candidates);

    if (!topCandidate) {
      return null;
    }

    // 5. 构建输出内容
    const articleContent = this.postProcessContent(topCandidate);

    if (!articleContent || getInnerText(articleContent, true).length < 140) {
      return null;
    }

    // 6. 清理
    this.clean(articleContent, "style");
    this.clean(articleContent, "script");
    this.clean(articleContent, "noscript");
    this.clean(articleContent, "iframe");

    // 移除链接密度过高的段落
    const paragraphs = articleContent.querySelectorAll("p");
    for (const p of paragraphs) {
      if (getLinkDensity(p) > 0.5) {
        p.parentNode?.removeChild(p);
      }
    }

    const textContent = getInnerText(articleContent, true);
    const excerpt = metadata.excerpt || textContent.substring(0, 200).trim();

    return {
      title: this.articleTitle || metadata.title,
      content: articleContent.innerHTML || articleContent.toString(),
      textContent,
      length: textContent.length,
      excerpt,
      byline: this.articleByline || metadata.byline,
      dir: this.articleDir,
      siteName: this.articleSiteName || metadata.siteName,
    };
  }

  private prepDocument(): void {
    // 移除不需要的标签
    for (const tag of DEFAULT_TAGS_TO_IGNORE) {
      const elems = this.doc.querySelectorAll(tag);
      for (const el of elems) {
        el.parentNode?.removeChild(el);
      }
    }

    // 把 div/p/pre 等转换为 <p> 便于打分
    this.replaceBrs(this.doc.body);
    this.improveParagraphs(this.doc.body);
  }

  private replaceBrs(node: any): void {
    const brs = node.querySelectorAll ? node.querySelectorAll("br") : [];
    let sibling = node.firstChild;
    while (sibling) {
      const next = sibling.nextSibling;
      if (sibling.nodeName === "BR") {
        const parent = sibling.parentNode;
        if (parent) {
          parent.replaceChild(this.doc.createTextNode("\n\n"), sibling);
        }
      }
      sibling = next;
    }
    if (node.querySelectorAll) {
      for (const child of node.querySelectorAll("*")) {
        this.replaceBrs(child);
      }
    }
  }

  private improveParagraphs(node: any): void {
    // 简单实现：把看起来像正文的 div 内容标记出来
    const divs = node.querySelectorAll ? node.querySelectorAll("div") : [];
    for (const div of divs) {
      if (div.querySelectorAll("p, pre, blockquote").length > 0) continue;
      const text = getInnerText(div, true);
      if (text.length > 200 && getLinkDensity(div) < 0.3) {
        // 这是一个像段落的 div
        div.setAttribute("data-readability", "true");
      }
    }
  }

  private getArticleMetadata(): ArticleMetadata {
    const meta: ArticleMetadata = {
      byline: "",
      title: "",
      excerpt: "",
      siteName: "",
    };

    // title
    meta.title =
      this.getMetaContent("og:title") ||
      this.getMetaContent("twitter:title") ||
      this.doc.title ||
      "";

    // description
    meta.excerpt =
      this.getMetaContent("og:description") ||
      this.getMetaContent("twitter:description") ||
      this.getMetaContent("description");

    // author
    meta.byline =
      this.getMetaContent("author") ||
      this.getMetaContent("article:author");

    // site name
    meta.siteName =
      this.getMetaContent("og:site_name") ||
      "";

    // 如果没有 og:title，尝试 h1
    if (!meta.title) {
      const h1 = this.doc.querySelector("h1");
      if (h1) meta.title = getInnerText(h1, true);
    }

    return meta;
  }

  private getMetaContent(name: string): string {
    const meta = this.doc.querySelector(`meta[name="${name}"], meta[property="${name}"]`);
    return meta?.getAttribute("content")?.trim() || "";
  }

  private getCandidates(relaxed = false): any[] {
    const candidates: any[] = [];
    const tags = DEFAULT_TAGS_TO_SCORE;

    for (const tag of tags) {
      const elems = this.doc.querySelectorAll(tag);
      for (const elem of elems) {
        const textLen = getInnerText(elem, true).length;
        if (textLen < (relaxed ? 50 : 100)) continue;

        const linkDensity = getLinkDensity(elem);
        const className = (elem.className || "").toString();
        const id = (elem.id || "").toString();

        // 过滤明显非正文的节点
        if (!relaxed && REGEXPS.unlikelyCandidates.test(className + id) &&
            !REGEXPS.okMaybeItsACandidate.test(className + id)) {
          continue;
        }

        // 评分
        let score = 0;
        score += Math.floor(textLen / 100);  // 文本量
        score += getCharCount(elem, ",");     // 逗号密度（英文）
        score += getCharCount(elem, "，");    // 逗号密度（中文）
        score += getCharCount(elem, "。") * 2; // 句号密度（中文）
        score += getCharCount(elem, ".") * 2;  // 句号密度（英文）
        score -= Math.floor(linkDensity * 100); // 链接密度惩罚
        score += getClassWeight(elem);

        candidates.push({ node: elem, score });
      }
    }

    // 向上累加分数
    for (const candidate of candidates) {
      let parent = candidate.node.parentNode;
      while (parent && parent !== this.doc.body) {
        let existing = candidates.find((c: any) => c.node === parent);
        if (existing) {
          existing.score += candidate.score * 0.5;
        } else {
          candidates.push({ node: parent, score: candidate.score * 0.5 });
        }
        parent = parent.parentNode;
      }
    }

    return candidates.sort((a, b) => b.score - a.score);
  }

  private selectTopCandidate(candidates: any[]): any | null {
    if (candidates.length === 0) return null;

    // 首选 article/main 标签
    const articleTag = this.doc.querySelector("article, main, [role='main']");
    if (articleTag && getInnerText(articleTag, true).length >= 200) {
      return articleTag;
    }

    // 取前 3 个候选，选文本量最大的
    const top3 = candidates.slice(0, 3);
    let best = top3[0].node;
    let bestText = getInnerText(best, true).length;

    for (let i = 1; i < top3.length; i++) {
      const text = getInnerText(top3[i].node, true).length;
      if (text > bestText) {
        best = top3[i].node;
        bestText = text;
      }
    }

    return best;
  }

  private postProcessContent(node: any): any {
    // 克隆节点
    const clone = node.cloneNode(true);

    // 移除链接密度过高的子节点
    const walk = (n: any) => {
      if (!n || !n.childNodes) return;
      const children = Array.from(n.childNodes);
      for (const child of children) {
        if (child.nodeName === "A") {
          // 保留链接，但不进一步处理
        } else if (child.nodeType === 1) {
          const textLen = getInnerText(child, true).length;
          const linkDensity = getLinkDensity(child);
          if (linkDensity > 0.8 || (textLen < 20 && linkDensity > 0.5)) {
            child.parentNode?.removeChild(child);
            continue;
          }
          walk(child);
        }
      }
    };
    walk(clone);

    return clone;
  }

  private clean(node: any, tag: string): void {
    const elems = node.querySelectorAll ? node.querySelectorAll(tag) : [];
    for (const el of elems) {
      el.parentNode?.removeChild(el);
    }
  }
}

// ══════════════════════════════════════════════
//  URL 验证工具
// ══════════════════════════════════════════════

function isValidUrl(str: string): boolean {
  try {
    const url = new URL(str);
    return url.protocol === "http:" || url.protocol === "https:";
  } catch {
    return false;
  }
}

function json(data: any, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// ══════════════════════════════════════════════
//  主入口
// ══════════════════════════════════════════════

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }

  try {
    const body = (await req.json()) as any;
    const url = (body.url || "").trim();

    // URL 验证
    if (!url) {
      return json({
        ok: false,
        error: "missing_url",
        message: "请输入文章链接",
      }, 400);
    }

    if (!isValidUrl(url)) {
      return json({
        ok: false,
        error: "invalid_url",
        message: "请输入有效的网址（以 http:// 或 https:// 开头）",
      }, 400);
    }

    // 只允许 HTTP/HTTPS
    if (!url.startsWith("http://") && !url.startsWith("https://")) {
      return json({
        ok: false,
        error: "invalid_protocol",
        message: "仅支持 http:// 或 https:// 链接",
      }, 400);
    }

    // Fetch 网页内容
    const fetchStart = Date.now();
    let html: string;
    try {
      const resp = await fetch(url, {
        headers: {
          "User-Agent":
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
          Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
          "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        },
        redirect: "follow",
      });

      if (!resp.ok) {
        return json({
          ok: false,
          error: "fetch_failed",
          message: `无法访问该网页（HTTP ${resp.status}）`,
        }, 502);
      }

      // 检查 Content-Type 是否为 HTML
      const contentType = resp.headers.get("content-type") || "";
      if (!contentType.includes("text/html") && !contentType.includes("application/xhtml")) {
        return json({
          ok: false,
          error: "not_html",
          message: "该链接不是网页，仅支持提取 HTML 文章",
        }, 400);
      }

      html = await resp.text();
    } catch (e: any) {
      return json({
        ok: false,
        error: "fetch_error",
        message: `网络请求失败: ${e.message || "未知错误"}`,
      }, 502);
    }

    console.log(`[extract-article] fetched ${url} (${html.length} bytes, ${Date.now() - fetchStart}ms)`);

    // Readability 提取
    const parseStart = Date.now();
    const { document: doc } = parseHTML(html);

    if (!doc || !doc.body) {
      return json({
        ok: false,
        error: "parse_failed",
        message: "无法解析网页结构",
      }, 500);
    }

    const reader = new Readability(doc);
    const article = reader.parse();

    if (!article) {
      return json({
        ok: false,
        error: "extraction_failed",
        message: "未能从该网页提取到正文内容，请尝试手动复制粘贴",
      }, 422);
    }

    console.log(
      `[extract-article] extracted "${article.title}" (${article.textContent.length} chars, ${Date.now() - parseStart}ms)`
    );

    return json({
      ok: true,
      title: article.title,
      textContent: article.textContent,
      content: article.content,
      excerpt: article.excerpt,
      length: article.length,
      byline: article.byline,
      siteName: article.siteName,
    });
  } catch (e: any) {
    console.error("[extract-article] unhandled error:", e.message || e);
    return json({
      ok: false,
      error: "internal_error",
      message: `服务器内部错误: ${e.message || String(e)}`,
    }, 500);
  }
});
