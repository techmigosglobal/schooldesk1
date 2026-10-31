"use client";

import { usePortalRefresh } from "./use-portal-refresh";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { CircleAlert, Eye, EyeOff, Pencil, Plus, Trash2 } from "@/lib/lucide-react";
import { LoadingIndicator, PortalModuleSkeleton } from "@/components/loading-skeletons";
import type { Row } from "./types";
import { api, rowsFrom, stringValue } from "./utils";
import { Dialog } from "./Dialog";
import { TickerManager } from "./TickerManager";
import { confirmFormClose, usePortalGuard, usePortalState, usePortalTab } from "./PortalStateProvider";

type MediaFilter = "all" | "image" | "video" | "visible" | "hidden";

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
  const [tab, setTab] = usePortalTab<"gallery" | "copy" | "ticker">("website", "gallery");
  const [content, setContent] = useState<Row>({});
  const [gallery, setGallery] = useState<Row[]>([]);
  const [notice, setNotice] = useState("");
  const [loading, setLoading] = useState(true);
  const [loadPending, setLoadPending] = useState(false);
  const [loaded, setLoaded] = useState({ gallery: false, copy: false });
  const [uploading, setUploading] = useState(false);
  const [operation, setOperation] = useState("");
  const [search, setSearch] = usePortalState("website.search", "");
  const [page, setPage] = usePortalState("website.page", 1);
  const [filter, setFilter] = usePortalState<MediaFilter>("website.filter", "all");
  const [uploadOpen, setUploadOpen] = useState(false);
  const [copyDirty, setCopyDirty] = useState(false);
  const [copyVersion, setCopyVersion] = useState(0);
  usePortalGuard(copyDirty, uploading || !!operation);
  const [preview, setPreview] = useState<Row | null>(null);
  const [editing, setEditing] = useState<Row | null>(null);
  const [previewFileUrl, setPreviewFileUrl] = useState("");
  const [previewFileType, setPreviewFileType] = useState("");
  const loadVersion = useRef(0);

  const load = useCallback(async (manual = false) => {
    const version = ++loadVersion.current;
    setLoadPending(true);
    if (!manual) setLoading(true);
    try {
      if (tab === "ticker") return;
      if (tab === "copy") {
        const website = await api("website/content");
        if (version !== loadVersion.current) return;
        setContent((website as Row) || {});
        setCopyDirty(false);
        setCopyVersion((value) => value + 1);
      } else {
        const media = await api("website/gallery");
        if (version !== loadVersion.current) return;
        setGallery(rowsFrom(media));
      }
      setLoaded((value) => ({ ...value, [tab]: true }));
      setNotice("");
    } catch (event) {
      if (version === loadVersion.current) setNotice(event instanceof Error ? event.message : "Unable to load website content");
    } finally {
      if (version === loadVersion.current) { setLoading(false); setLoadPending(false); }
    }
  }, [tab]);

  usePortalRefresh(load, tab !== "ticker");

  useEffect(() => {
    setUploadOpen(false);
    setEditing(null);
    setPreview(null);
    setPreviewFileUrl("");
    setPreviewFileType("");
    if (tab !== "copy") setCopyDirty(false);
    if (tab !== "ticker") void load();
    return () => { loadVersion.current += 1; };
  }, [load, tab]);
  useEffect(() => () => { if (previewFileUrl) URL.revokeObjectURL(previewFileUrl); }, [previewFileUrl]);

  const visibleGallery = useMemo(() => {
    const query = search.trim().toLowerCase();
    return gallery.filter((item) => {
      const video = isVideo(item);
      const published = item.is_published !== false && !video;
      const matchesFilter = filter === "all" || (filter === "image" && !video) || (filter === "video" && video) || (filter === "visible" && published) || (filter === "hidden" && !published);
      const matchesSearch = !query || [item.title, item.caption, item.alt_text].some((value) => stringValue(value).toLowerCase().includes(query));
      return matchesFilter && matchesSearch;
    });
  }, [filter, gallery, search]);

  const pageSize = 24;
  const totalPages = Math.max(1, Math.ceil(visibleGallery.length / pageSize));
  const pagedGallery = visibleGallery.slice((page - 1) * pageSize, page * pageSize);
  useEffect(() => {
    if (tab === "gallery" && loaded.gallery && !loading) setPage((value) => Math.min(Math.max(1, value), totalPages));
  }, [loaded.gallery, loading, setPage, tab, totalPages]);

  const mediaCounts = useMemo(() => {
    const image = gallery.filter((item) => !isVideo(item)).length;
    const visible = gallery.filter((item) => item.is_published !== false && !isVideo(item)).length;
    return { all: gallery.length, image, video: gallery.length - image, visible, hidden: gallery.length - visible };
  }, [gallery]);

  const mediaFilterOptions: Array<{ key: MediaFilter; label: string; count: number }> = [
    { key: "all", label: "All media", count: mediaCounts.all },
    { key: "image", label: "Images", count: mediaCounts.image },
    { key: "video", label: "Videos", count: mediaCounts.video },
    { key: "visible", label: "Displayed on website", count: mediaCounts.visible },
    { key: "hidden", label: "Hidden from website", count: mediaCounts.hidden },
  ];

  async function saveContent(form: FormData, source: HTMLFormElement) {
    setOperation("copy");
    try {
      await api("website/content", { method: "PUT", body: JSON.stringify(Object.fromEntries(form)) });
      setCopyDirty(false);
      source.removeAttribute("data-portal-dirty");
      onNotify("Public website copy published. Visitors will see the update shortly.");
      await load(true);
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Unable to save homepage copy");
    } finally {
      setOperation("");
    }
  }

  async function upload(form: FormData, source: HTMLFormElement) {
    const file = form.get("file");
    if (!(file instanceof File)) { setNotice("Choose a media file before uploading."); return; }
    const invalid = fileValidationMessage(file);
    if (invalid) { setNotice(invalid); return; }
    if (videoTypes.has(file.type)) form.set("is_published", "false");
    setUploading(true);
    setNotice("");
    try {
      await api("website/gallery/upload", { method: "POST", body: form });
      source.removeAttribute("data-portal-dirty");
      onNotify(`${videoTypes.has(file.type) ? "Video" : "Image"} uploaded to the gallery.`);
      setPreviewFileUrl("");
      setPreviewFileType("");
      setUploadOpen(false);
      await load(true);
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Media upload failed");
    } finally {
      setUploading(false);
    }
  }

  async function updateMedia(item: Row, form: FormData, source: HTMLFormElement) {
    setOperation(`edit:${item.id}`);
    try {
      await api(`website/gallery/${item.id}`, { method: "PUT", body: JSON.stringify({ title: form.get("title"), alt_text: form.get("alt_text"), caption: form.get("caption"), sort_order: Number(form.get("sort_order") || 0), is_published: !isVideo(item) && form.get("is_published") === "true" }) });
      source.removeAttribute("data-portal-dirty");
      setEditing(null);
      onNotify("Media details updated.");
      await load(true);
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Unable to update media details");
    } finally {
      setOperation("");
    }
  }

  async function toggle(item: Row) {
    const itemId = stringValue(item.id);
    const eventPost = stringValue(item.source) === "event_post";
    const nextVisible = item.is_published === false;
    setOperation(`toggle:${itemId}`);
    setNotice("");
    // Update the card immediately so the control feels responsive while the
    // server persists the selection. The previous value is restored on error.
    setGallery((current) => current.map((row) => stringValue(row.id) === itemId ? { ...row, is_published: nextVisible } : row));
    try {
      if (eventPost) {
        await api(`event-posts/${stringValue(item.event_post_id)}`, {
          method: "PUT",
          body: JSON.stringify({ public_gallery_visible: nextVisible }),
        });
      } else {
        await api(`website/gallery/${itemId}`, {
          method: "PUT",
          body: JSON.stringify({
            title: item.title,
            alt_text: item.alt_text,
            caption: item.caption,
            sort_order: Number(item.sort_order || 0),
            is_published: nextVisible,
          }),
        });
      }
      onNotify(nextVisible ? "Media displayed on the public website." : "Media hidden from the public website.");
      await load(true);
    } catch (event) {
      setGallery((current) => current.map((row) => stringValue(row.id) === itemId ? { ...row, is_published: item.is_published } : row));
      setNotice(event instanceof Error ? event.message : "Unable to update media status");
    }
    finally { setOperation(""); }
  }

  async function deleteMedia(item: Row) {
    if (!confirm(`Delete "${stringValue(item.title || "Untitled media")}"? This also removes its stored file.`)) return;
    setOperation(`delete:${item.id}`);
    try {
      await api(`website/gallery/${item.id}`, { method: "DELETE" });
      onNotify("Media removed from the gallery.");
      if (preview?.id === item.id) setPreview(null);
      await load(true);
    } catch (event) { setNotice(event instanceof Error ? event.message : "Unable to delete media"); }
    finally { setOperation(""); }
  }

  function closeUpload() {
    const dialog = document.querySelector<HTMLElement>(".media-upload-panel")?.closest<HTMLElement>('[role="dialog"]') ?? null;
    if (uploading || !confirmFormClose(dialog)) return;
    setUploadOpen(false);
    setPreviewFileUrl("");
    setPreviewFileType("");
    setNotice("");
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
    {notice && !uploadOpen && <div className="ops-inline-error"><CircleAlert size={16} />{notice}</div>}
    <div className="media-tabs" role="tablist"><button role="tab" aria-selected={tab === "gallery"} className={tab === "gallery" ? "active" : ""} onClick={() => setTab("gallery")}>Media library</button><button role="tab" aria-selected={tab === "copy"} className={tab === "copy" ? "active" : ""} onClick={() => setTab("copy")}>Homepage copy</button><button role="tab" aria-selected={tab === "ticker"} className={tab === "ticker" ? "active" : ""} onClick={() => setTab("ticker")}>News ticker</button></div>
    {loading && tab !== "ticker" ? <PortalModuleSkeleton variant="split" label="Loading website and media settings" /> : tab !== "ticker" && !loaded[tab] ? <p className="ops-empty">Website content is unavailable. Use Refresh to try again.</p> : tab === "gallery" ? <div className="media-library-layout">
      <section className="surface media-library-panel">
        <div className="media-library-toolbar"><div><h2>Media library</h2><p className="media-scope-note">Photos can appear on the public website; videos stay in this library. These controls do not change in-app visibility.</p></div><div className="media-library-tools"><label className="media-search"><span className="sr-only">Search media</span><input value={search} onChange={(event) => { setSearch(event.target.value); setPage(1); }} placeholder="Search media" /></label><button className="primary-button" type="button" onClick={() => { setNotice(""); setUploadOpen(true); }}><Plus size={16} />Upload media</button></div></div>
        <div className="media-filter-row" aria-label="Filter media">
          {mediaFilterOptions.map(({ key, label, count }) => <button key={key} type="button" className={filter === key ? "active" : ""} aria-pressed={filter === key} onClick={() => { setFilter(key); setPage(1); }}><span>{label}</span><span className="media-filter-count">{count}</span></button>)}
        </div>
        {visibleGallery.length ? <div className="media-library-grid">{pagedGallery.map((item) => {
          const video = isVideo(item);
          const eventPost = stringValue(item.source) === "event_post";
          const published = item.is_published !== false && !video;
          const url = mediaUrl(item);
          const title = stringValue(item.title || "Untitled media");
          const itemId = stringValue(item.id);
          const updating = operation === `toggle:${itemId}`;
          const visibilityLabel = video ? "Library video" : published ? "Displayed on website" : "Hidden from website";
          return <article key={itemId} className={published ? "is-visible" : "is-hidden"}>
            <div className="media-library-cover">
              {video ? <video src={url} controls preload="none" /> : <img src={url} alt={stringValue(item.alt_text) || title} loading="lazy" decoding="async" />}
              <span className={`media-visibility-badge ${published ? "visible" : "hidden"}`}>{published ? <Eye size={12} /> : <EyeOff size={12} />}{visibilityLabel}</span>
              {eventPost && <i className="media-source-badge">Event post</i>}
            </div>
            <div className="media-library-copy">
              <b>{title}</b>
              {Boolean(item.caption) && <small>{stringValue(item.caption)}</small>}
              <div className="media-card-actions">
                {!video && <button className="media-toggle" type="button" disabled={updating} aria-busy={updating} aria-pressed={published} aria-label={`${published ? "Hide" : "Display"} ${title} ${published ? "from" : "on"} the public website`} title={published ? "Hide from public website" : "Display on public website"} onClick={() => void toggle(item)}>{updating ? <LoadingIndicator label="Updating…" compact announce={false} /> : published ? "Hide" : "Display"}</button>}
                <button type="button" aria-label={`Preview ${title}`} title="Preview media" onClick={() => setPreview(item)}><Eye size={15} /></button>
                {!eventPost && <><button type="button" aria-label={`Edit ${title}`} title="Edit media details" onClick={() => setEditing(item)}><Pencil size={15} /></button><button type="button" className="danger" aria-label={operation === `delete:${itemId}` ? `Deleting ${title}` : `Delete ${title}`} title="Delete media" disabled={operation === `delete:${itemId}`} onClick={() => void deleteMedia(item)}>{operation === `delete:${itemId}` ? <span className="activity-spinner" aria-hidden="true" /> : <Trash2 size={15} />}</button></>}
              </div>
            </div>
          </article>;
        })}</div> : <p className="ops-empty">No media matches the current search and filter.</p>}
        {visibleGallery.length > pageSize && <div className="ops-pagination"><button className="secondary-button" type="button" disabled={page === 1} onClick={() => setPage((value) => value - 1)}>Previous</button><span>Page {page} of {totalPages} · {visibleGallery.length} matching items</span><button className="secondary-button" type="button" disabled={page >= totalPages} onClick={() => setPage((value) => value + 1)}>Next</button></div>}
      </section>
    </div> : tab === "copy" ? <section className="surface media-copy-panel"><h2>Homepage copy</h2><p>These changes are validated by the backend and revalidated for public visitors.</p><form key={copyVersion} onSubmit={(event) => { event.preventDefault(); void saveContent(new FormData(event.currentTarget), event.currentTarget); }} className="ops-detail-form" aria-busy={operation === "copy"} onChange={() => setCopyDirty(true)}><fieldset disabled={operation === "copy" || loadPending} className="ops-detail-form" style={{ border: 0, padding: 0, margin: 0, minWidth: 0 }}><label className="field">Hero title<input name="hero_title" required defaultValue={stringValue(content.hero_title)} /></label><label className="field">Hero description<textarea name="hero_body" rows={3} required defaultValue={stringValue(content.hero_body)} /></label><label className="field">Mission title<input name="mission_title" required defaultValue={stringValue(content.mission_title)} /></label><label className="field">Mission statement<textarea name="mission_body" rows={3} required defaultValue={stringValue(content.mission_body)} /></label><button className="primary-button" type="submit" disabled={operation === "copy"} aria-busy={operation === "copy"}>{operation === "copy" ? <LoadingIndicator label="Publishing…" compact announce={false} /> : "Publish website copy"}</button></fieldset></form></section> : <TickerManager onNotify={onNotify} compact />}
    {uploadOpen && <Dialog kicker="Media library" title="Upload approved media" onClose={closeUpload}>
      <div className="media-upload-panel">{notice && <div className="ops-inline-error"><CircleAlert size={16} />{notice}</div>}<p>Images: JPG, PNG, WebP up to 10 MB. Videos: MP4, WebM, MOV up to 50 MB.</p><form onSubmit={(event) => { event.preventDefault(); void upload(new FormData(event.currentTarget), event.currentTarget); }} aria-busy={uploading}><fieldset disabled={uploading} className="ops-detail-form" style={{ border: 0, padding: 0, margin: 0, minWidth: 0 }}><label className="field">Image or video<input name="file" type="file" accept="image/jpeg,image/png,image/webp,video/mp4,video/webm,video/quicktime" onChange={handleFileSelect} required /></label>{previewFileUrl && <div className="media-file-preview">{previewFileType.startsWith("video/") ? <video src={previewFileUrl} controls preload="none" /> : <img src={previewFileUrl} alt="Selected upload preview" />}</div>}<label className="field">Title<input name="title" placeholder="e.g. Nature exploration" /></label><label className="field">Accessible description<input name="alt_text" required placeholder="Describe the children and activity shown" /></label><label className="field">Caption <small>(optional)</small><input name="caption" placeholder="Short public caption" /></label><label className="field">Display order <small>(lower appears first)</small><input name="sort_order" type="number" min="0" defaultValue="0" /></label><label className="check-field"><input name="is_published" type="checkbox" value="true" defaultChecked disabled={previewFileType.startsWith("video/")} />Display on the public website (photos only)</label><div className="dialog-footer"><button className="secondary-button" type="button" disabled={uploading} onClick={closeUpload}>Cancel</button><button className="primary-button" disabled={uploading} aria-busy={uploading} type="submit">{uploading ? <LoadingIndicator label="Uploading…" compact announce={false} /> : <><Plus size={16} />Upload to gallery</>}</button></div></fieldset></form></div>
    </Dialog>}
    {preview && <Dialog kicker="Media preview" title={stringValue(preview.title || "Gallery media")} onClose={() => setPreview(null)}>
      <div className="media-dialog-preview">
        {isVideo(preview)
          ? <video src={mediaUrl(preview)} controls autoPlay playsInline preload="none" />
          : <img src={mediaUrl(preview)} alt={stringValue(preview.alt_text) || "Gallery media"} />}
        {Boolean(preview.caption) && <p>{stringValue(preview.caption)}</p>}
      </div>
      <div className="dialog-footer"><button className="secondary-button" type="button" onClick={() => setPreview(null)}>Close preview</button></div>
    </Dialog>}
    {editing && <Dialog kicker="Media details" title={stringValue(editing.title || "Edit media")} onClose={() => setEditing(null)}><form onSubmit={(event) => { event.preventDefault(); void updateMedia(editing, new FormData(event.currentTarget), event.currentTarget); }} className="ops-detail-form" aria-busy={operation === `edit:${editing.id}`}><fieldset disabled={operation === `edit:${editing.id}`} className="ops-detail-form" style={{ border: 0, padding: 0, margin: 0, minWidth: 0 }}><label className="field">Title<input name="title" required defaultValue={stringValue(editing.title)} /></label><label className="field">Accessible description<input name="alt_text" required defaultValue={stringValue(editing.alt_text)} /></label><label className="field">Caption<input name="caption" defaultValue={stringValue(editing.caption)} /></label><label className="field">Display order<input name="sort_order" type="number" min="0" defaultValue={stringValue(editing.sort_order || 0)} /></label><label className="check-field"><input name="is_published" type="checkbox" value="true" defaultChecked={!isVideo(editing) && editing.is_published !== false} disabled={isVideo(editing)} />Published on the public website (photos only)</label><div className="dialog-footer"><button className="secondary-button" type="button" disabled={!!operation} onClick={(event) => { if (confirmFormClose(event.currentTarget.closest<HTMLElement>('[role="dialog"]'))) setEditing(null); }}>Cancel</button><button className="primary-button" type="submit" disabled={operation === `edit:${editing.id}`} aria-busy={operation === `edit:${editing.id}`}>{operation === `edit:${editing.id}` ? <LoadingIndicator label="Saving…" compact announce={false} /> : "Save media details"}</button></div></fieldset></form></Dialog>}
  </section>;
}
