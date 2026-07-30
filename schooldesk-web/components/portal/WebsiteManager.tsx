"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { CircleAlert, Eye, Images, Pencil, Plus, RefreshCw, Trash2 } from "@/lib/lucide-react";
import { LoadingIndicator, PortalModuleSkeleton } from "@/components/loading-skeletons";
import type { Row } from "./types";
import { api, rowsFrom, stringValue } from "./utils";
import { Dialog } from "./Dialog";
import { TickerManager } from "./TickerManager";

type MediaFilter = "all" | "image" | "video" | "published" | "draft";

const imageTypes = new Set(["image/jpeg", "image/png", "image/webp"]);
const videoTypes = new Set(["video/mp4", "video/webm", "video/quicktime"]);

function mediaUrl(item: Row) { return stringValue(item.media_url || item.url); }
function isVideo(item: Row) {
  const type = stringValue(item.media_type).toLowerCase();
  return type.startsWith("video/") || /\.(m4v|mov|mp4|webm)(\?|$)/i.test(mediaUrl(item));
}
function fileValidationMessage(file: File) {
  const supported = imageTypes.has(file.type) || videoTypes.has(file.type);
  if (!supported) return "Choose a JPG, PNG, WebP, MP4, WebM, or MOV file.";
  const maxSize = videoTypes.has(file.type) ? 50 : 10;
  if (file.size > maxSize * 1024 * 1024) return `${isVideo({ media_type: file.type }) ? "Videos" : "Images"} must be ${maxSize} MB or smaller.`;
  return "";
}

export function WebsiteManager({ onNotify }: { onNotify: (message: string) => void }) {
  const [tab, setTab] = useState<"gallery" | "copy" | "ticker">("gallery");
  const [content, setContent] = useState<Row>({});
  const [gallery, setGallery] = useState<Row[]>([]);
  const [notice, setNotice] = useState("");
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [uploading, setUploading] = useState(false);
  const [operation, setOperation] = useState("");
  const [search, setSearch] = useState("");
  const [filter, setFilter] = useState<MediaFilter>("all");
  const [preview, setPreview] = useState<Row | null>(null);
  const [editing, setEditing] = useState<Row | null>(null);
  const [previewFileUrl, setPreviewFileUrl] = useState("");
  const [previewFileType, setPreviewFileType] = useState("");

  const load = useCallback(async (manual = false) => {
    manual ? setRefreshing(true) : setLoading(true);
    try {
      const [website, media] = await Promise.all([api("website/content"), api("website/gallery")]);
      setContent((website as Row) || {});
      setGallery(rowsFrom(media));
      setNotice("");
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Unable to load gallery content");
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => { void load(); }, [load]);
  useEffect(() => () => { if (previewFileUrl) URL.revokeObjectURL(previewFileUrl); }, [previewFileUrl]);

  const visibleGallery = useMemo(() => {
    const query = search.trim().toLowerCase();
    return gallery.filter((item) => {
      const video = isVideo(item);
      const published = item.is_published !== false;
      const matchesFilter = filter === "all" || (filter === "image" && !video) || (filter === "video" && video) || (filter === "published" && published) || (filter === "draft" && !published);
      const matchesSearch = !query || [item.title, item.caption, item.alt_text].some((value) => stringValue(value).toLowerCase().includes(query));
      return matchesFilter && matchesSearch;
    });
  }, [filter, gallery, search]);

  async function saveContent(form: FormData) {
    setOperation("copy");
    try {
      await api("website/content", { method: "PUT", body: JSON.stringify(Object.fromEntries(form)) });
      onNotify("Public website copy published. Visitors will see the update shortly.");
      void load(true);
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Unable to save homepage copy");
    } finally {
      setOperation("");
    }
  }

  async function upload(form: FormData) {
    const file = form.get("file");
    if (!(file instanceof File)) { setNotice("Choose a media file before uploading."); return; }
    const invalid = fileValidationMessage(file);
    if (invalid) { setNotice(invalid); return; }
    setUploading(true);
    setNotice("");
    try {
      await api("website/gallery/upload", { method: "POST", body: form });
      onNotify(`${videoTypes.has(file.type) ? "Video" : "Image"} uploaded to the gallery.`);
      setPreviewFileUrl("");
      setPreviewFileType("");
      void load(true);
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Media upload failed");
    } finally {
      setUploading(false);
    }
  }

  async function updateMedia(item: Row, form: FormData) {
    setOperation(`edit:${item.id}`);
    try {
      await api(`website/gallery/${item.id}`, { method: "PUT", body: JSON.stringify({ title: form.get("title"), alt_text: form.get("alt_text"), caption: form.get("caption"), sort_order: Number(form.get("sort_order") || 0), is_published: form.get("is_published") === "true" }) });
      setEditing(null);
      onNotify("Media details updated.");
      void load(true);
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Unable to update media details");
    } finally {
      setOperation("");
    }
  }

  async function toggle(item: Row) {
    setOperation(`toggle:${item.id}`);
    try {
      await api(`website/gallery/${item.id}`, { method: "PUT", body: JSON.stringify({ title: item.title, alt_text: item.alt_text, caption: item.caption, sort_order: Number(item.sort_order || 0), is_published: item.is_published === false }) });
      onNotify(item.is_published === false ? "Media published to the website." : "Media moved to draft.");
      void load(true);
    } catch (event) { setNotice(event instanceof Error ? event.message : "Unable to update media status"); }
    finally { setOperation(""); }
  }

  async function deleteMedia(item: Row) {
    if (!confirm(`Delete "${stringValue(item.title || "Untitled media")}"? This also removes its stored file.`)) return;
    setOperation(`delete:${item.id}`);
    try {
      await api(`website/gallery/${item.id}`, { method: "DELETE" });
      onNotify("Media removed from the gallery.");
      if (preview?.id === item.id) setPreview(null);
      void load(true);
    } catch (event) { setNotice(event instanceof Error ? event.message : "Unable to delete media"); }
    finally { setOperation(""); }
  }

  function handleFileSelect(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) { setPreviewFileUrl(""); setPreviewFileType(""); return; }
    const invalid = fileValidationMessage(file);
    setNotice(invalid);
    if (invalid) { event.target.value = ""; setPreviewFileUrl(""); setPreviewFileType(""); return; }
    setPreviewFileUrl(URL.createObjectURL(file));
    setPreviewFileType(file.type);
  }

  return <section className="ops-module gallery-workspace">
    <div className="ops-module-heading"><div><div className="ops-module-icon green"><Images size={20} /></div><div><p className="ops-kicker">Public publishing</p><h2>Gallery &amp; Media Assets</h2><p>Curate approved public images and videos with publication controls, accessible descriptions, and a live media library.</p></div></div><div className="ops-actions"><button className="secondary-button" type="button" onClick={() => void load(true)} disabled={refreshing}><RefreshCw size={16} className={refreshing ? "spin" : ""} /> Refresh</button></div></div>
    {notice && <div className="ops-inline-error"><CircleAlert size={16} />{notice}</div>}
    <div className="media-tabs" role="tablist"><button role="tab" aria-selected={tab === "gallery"} className={tab === "gallery" ? "active" : ""} onClick={() => setTab("gallery")}>Media library ({gallery.length})</button><button role="tab" aria-selected={tab === "copy"} className={tab === "copy" ? "active" : ""} onClick={() => setTab("copy")}>Homepage copy</button><button role="tab" aria-selected={tab === "ticker"} className={tab === "ticker" ? "active" : ""} onClick={() => setTab("ticker")}>Breaking news</button></div>
    {loading && tab !== "ticker" ? <PortalModuleSkeleton variant="split" label="Loading website and media settings" /> : tab === "gallery" ? <div className="media-library-layout">
      <section className="surface media-upload-panel"><h3>Upload approved media</h3><p>Images: JPG, PNG, WebP up to 10 MB. Videos: MP4, WebM, MOV up to 50 MB.</p><form action={upload}><label className="field">Image or video<input name="file" type="file" accept="image/jpeg,image/png,image/webp,video/mp4,video/webm,video/quicktime" onChange={handleFileSelect} required /></label>{previewFileUrl && <div className="media-file-preview">{previewFileType.startsWith("video/") ? <video src={previewFileUrl} controls preload="metadata" /> : <img src={previewFileUrl} alt="Selected upload preview" />}</div>}<label className="field">Title<input name="title" placeholder="e.g. Nature exploration" /></label><label className="field">Accessible description<input name="alt_text" required placeholder="Describe the children and activity shown" /></label><label className="field">Caption <small>(optional)</small><input name="caption" placeholder="Short public caption" /></label><label className="field">Display order <small>(lower appears first)</small><input name="sort_order" type="number" min="0" defaultValue="0" /></label><button className="primary-button" disabled={uploading} aria-busy={uploading} type="submit">{uploading ? <LoadingIndicator label="Uploading…" compact announce={false} /> : <><Plus size={16} />Upload to gallery</>}</button></form></section>
      <section className="surface media-library-panel"><div className="media-library-toolbar"><div><h3>Public media library</h3><small>{visibleGallery.length} item{visibleGallery.length === 1 ? "" : "s"} shown</small></div><label className="media-search"><span className="sr-only">Search media</span><input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search media" /></label></div><div className="media-filter-row" aria-label="Filter media">{(["all", "image", "video", "published", "draft"] as MediaFilter[]).map((item) => <button key={item} type="button" className={filter === item ? "active" : ""} onClick={() => setFilter(item)}>{item === "all" ? "All" : item[0].toUpperCase() + item.slice(1)}</button>)}</div>{visibleGallery.length ? <div className="media-library-grid">{visibleGallery.map((item) => { const video = isVideo(item); const published = item.is_published !== false; const url = mediaUrl(item); const title = stringValue(item.title || "Untitled media"); const itemId = stringValue(item.id); return <article key={itemId}><div className="media-library-cover">{video ? <video src={url} controls preload="metadata" /> : <img src={url} alt={stringValue(item.alt_text) || title} loading="lazy" decoding="async" />}<span className={published ? "published" : "draft"}>{published ? "Published" : "Draft"}</span><i>{video ? "Video" : "Image"}</i></div><div className="media-library-copy"><b>{title}</b><small>{stringValue(item.caption) || "No caption"}</small><div><button type="button" disabled={operation === `toggle:${itemId}`} aria-busy={operation === `toggle:${itemId}`} onClick={() => void toggle(item)}>{operation === `toggle:${itemId}` ? <LoadingIndicator label="Updating…" compact announce={false} /> : published ? "Unpublish" : "Publish"}</button><button type="button" aria-label={`Preview ${title}`} onClick={() => setPreview(item)}><Eye size={15} /></button><button type="button" aria-label={`Edit ${title}`} onClick={() => setEditing(item)}><Pencil size={15} /></button><button type="button" className="danger" aria-label={operation === `delete:${itemId}` ? `Deleting ${title}` : `Delete ${title}`} disabled={operation === `delete:${itemId}`} onClick={() => void deleteMedia(item)}>{operation === `delete:${itemId}` ? <span className="activity-spinner" aria-hidden="true" /> : <Trash2 size={15} />}</button></div></div></article>; })}</div> : <p className="ops-empty">No media matches the current search and filter.</p>}</section>
    </div> : tab === "copy" ? <section className="surface media-copy-panel"><h3>Public homepage copy</h3><p>These changes are validated by the backend and revalidated for public visitors.</p><form action={saveContent} className="ops-detail-form"><label className="field">Hero title<input name="hero_title" required defaultValue={stringValue(content.hero_title)} /></label><label className="field">Hero description<textarea name="hero_body" rows={3} required defaultValue={stringValue(content.hero_body)} /></label><label className="field">Mission title<input name="mission_title" required defaultValue={stringValue(content.mission_title)} /></label><label className="field">Mission statement<textarea name="mission_body" rows={3} required defaultValue={stringValue(content.mission_body)} /></label><button className="primary-button" type="submit" disabled={operation === "copy"} aria-busy={operation === "copy"}>{operation === "copy" ? <LoadingIndicator label="Publishing…" compact announce={false} /> : "Publish website copy"}</button></form></section> : <TickerManager onNotify={onNotify} compact />}
    {preview && <Dialog kicker="Media preview" title={stringValue(preview.title || "Gallery media")} onClose={() => setPreview(null)}>
      <div className="media-dialog-preview">
        {isVideo(preview)
          ? <video src={mediaUrl(preview)} controls autoPlay playsInline />
          : <img src={mediaUrl(preview)} alt={stringValue(preview.alt_text) || "Gallery media"} />}
        {Boolean(preview.caption) && <p>{stringValue(preview.caption)}</p>}
      </div>
      <div className="dialog-footer"><button className="secondary-button" type="button" onClick={() => setPreview(null)}>Close preview</button></div>
    </Dialog>}
    {editing && <Dialog kicker="Media details" title={stringValue(editing.title || "Edit media")} onClose={() => setEditing(null)}><form action={(form) => updateMedia(editing, form)} className="ops-detail-form"><label className="field">Title<input name="title" required defaultValue={stringValue(editing.title)} /></label><label className="field">Accessible description<input name="alt_text" required defaultValue={stringValue(editing.alt_text)} /></label><label className="field">Caption<input name="caption" defaultValue={stringValue(editing.caption)} /></label><label className="field">Display order<input name="sort_order" type="number" min="0" defaultValue={stringValue(editing.sort_order || 0)} /></label><label className="check-field"><input name="is_published" type="checkbox" value="true" defaultChecked={editing.is_published !== false} />Published on the public website</label><div className="dialog-footer"><button className="secondary-button" type="button" onClick={() => setEditing(null)}>Cancel</button><button className="primary-button" type="submit" disabled={operation === `edit:${editing.id}`} aria-busy={operation === `edit:${editing.id}`}>{operation === `edit:${editing.id}` ? <LoadingIndicator label="Saving…" compact announce={false} /> : "Save media details"}</button></div></form></Dialog>}
  </section>;
}
