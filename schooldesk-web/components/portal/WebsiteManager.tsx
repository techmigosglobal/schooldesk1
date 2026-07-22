"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  CircleAlert,
  Eye,
  Images,
  Plus,
  RefreshCw,
  Trash2,
} from "@/lib/lucide-react";
import type { Row } from "./types";
import { api, rowsFrom, stringValue } from "./utils";
import { Dialog } from "./Dialog";

export function WebsiteManager({
  onNotify,
}: {
  onNotify: (message: string) => void;
}) {
  const [tab, setTab] = useState<"gallery" | "copy">("gallery");
  const [content, setContent] = useState<Row>({});
  const [gallery, setGallery] = useState<Row[]>([]);
  const [notice, setNotice] = useState("");
  const [loading, setLoading] = useState(true);
  const [refreshing, setRefreshing] = useState(false);
  const [search, setSearch] = useState("");
  const [previewImage, setPreviewImage] = useState<Row | null>(null);
  const [previewFileUrl, setPreviewFileUrl] = useState<string>("");
  const [uploading, setUploading] = useState(false);

  const load = useCallback(async (manual = false) => {
    if (manual) setRefreshing(true);
    else setLoading(true);
    try {
      const [website, images] = await Promise.all([
        api("website/content").catch(() => ({})),
        api("website/gallery").catch(() => []),
      ]);
      setContent((website as Row) || {});
      setGallery(rowsFrom(images));
      setNotice("");
    } catch (event) {
      setNotice(
        event instanceof Error ? event.message : "Unable to load gallery content"
      );
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const filteredGallery = useMemo(() => {
    const query = search.trim().toLowerCase();
    return gallery.filter((item) => {
      const title = stringValue(item.title);
      const caption = stringValue(item.caption);
      const alt = stringValue(item.alt_text);
      return !query || [title, caption, alt].some((val) => val.toLowerCase().includes(query));
    });
  }, [gallery, search]);

  async function saveContent(form: FormData) {
    try {
      await api("website/content", {
        method: "PUT",
        body: JSON.stringify(Object.fromEntries(form)),
      });
      onNotify("Public website copy published. Visitors will see the update shortly.");
      void load(true);
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Unable to save homepage copy");
    }
  }

  async function upload(form: FormData) {
    setUploading(true);
    setNotice("");
    try {
      await api("website/gallery/upload", {
        method: "POST",
        body: form,
      });
      onNotify("Gallery photo uploaded successfully.");
      setPreviewFileUrl("");
      void load(true);
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Image upload failed");
    } finally {
      setUploading(false);
    }
  }

  async function toggle(row: Row) {
    try {
      await api(`website/gallery/${row.id}`, {
        method: "PUT",
        body: JSON.stringify({ ...row, is_published: !row.is_published }),
      });
      onNotify(
        row.is_published ? "Gallery photo unpublished." : "Gallery photo published to website."
      );
      void load(true);
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Unable to update gallery photo");
    }
  }

  async function deletePhoto(row: Row) {
    if (!confirm(`Delete photo "${stringValue(row.title || "Untitled")}"?`)) return;
    try {
      await api(`website/gallery/${row.id}`, { method: "DELETE" });
      onNotify("Photo removed from gallery.");
      void load(true);
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Unable to delete photo");
    }
  }

  function handleFileSelect(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (file) {
      setPreviewFileUrl(URL.createObjectURL(file));
    } else {
      setPreviewFileUrl("");
    }
  }

  return (
    <section className="ops-module gallery-workspace">
      <div className="ops-module-heading">
        <div>
          <div className="ops-module-icon green" style={{ background: "#eef8f1", color: "#1d632f" }}>
            <Images size={20} />
          </div>
          <div>
            <p className="ops-kicker">Public publishing</p>
            <h2>Gallery &amp; Media Assets</h2>
            <p>Curate public website photos, manage publication status, and update homepage story copy.</p>
          </div>
        </div>

        <div className="ops-actions">
          <button className="secondary-button" onClick={() => void load(true)} disabled={refreshing}>
            <RefreshCw size={16} className={refreshing ? "spin" : ""} /> Refresh
          </button>
        </div>
      </div>

      {notice && (
        <div className="ops-inline-error">
          <CircleAlert size={16} />
          {notice}
        </div>
      )}

      <div className="finance-tabs" style={{ marginBottom: "1.2rem" }}>
        <button
          type="button"
          className={tab === "gallery" ? "active" : ""}
          onClick={() => setTab("gallery")}
        >
          Media Gallery ({gallery.length})
        </button>
        <button
          type="button"
          className={tab === "copy" ? "active" : ""}
          onClick={() => setTab("copy")}
        >
          Public Homepage Copy
        </button>
      </div>

      {tab === "gallery" ? (
        <div className="website-grid ops-website-grid">
          <section className="surface ops-form-surface">
            <h3>Upload New Gallery Photo</h3>
            <p>Select a cleared photo for the public website. Uploaded photos default to published status.</p>

            <form action={upload}>
              <label className="field">
                Photo file
                <input
                  name="file"
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  onChange={handleFileSelect}
                  required
                />
              </label>

              {previewFileUrl && (
                <div style={{ margin: "0.5rem 0", borderRadius: "10px", overflow: "hidden", border: "1px solid #d0e2e9", maxHeight: "160px", background: "#f5fafc" }}>
                  <img src={previewFileUrl} alt="Upload preview" style={{ width: "100%", height: "160px", objectFit: "cover" }} />
                </div>
              )}

              <label className="field">
                Title
                <input name="title" placeholder="e.g. Science Fair 2026" />
              </label>
              <label className="field">
                Accessible description (Alt text)
                <input name="alt_text" required placeholder="Describe what is shown in the image" />
              </label>
              <label className="field">
                Caption <small>(optional)</small>
                <input name="caption" placeholder="Short caption text" />
              </label>
              <button className="primary-button" disabled={uploading} style={{ marginTop: "0.5rem" }}>
                <Plus size={16} /> {uploading ? "Uploading…" : "Upload to gallery"}
              </button>
            </form>
          </section>

          <section className="surface ops-form-surface">
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "0.8rem", flexWrap: "wrap", gap: "0.5rem" }}>
              <div>
                <h3 style={{ margin: 0 }}>Public Gallery Photos</h3>
                <small style={{ color: "#617785" }}>Curated photos displayed on the school website.</small>
              </div>
              <input
                className="search-input"
                placeholder="Search photos…"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                style={{ maxWidth: "220px", padding: "0.4rem 0.60rem", fontSize: "0.82rem" }}
              />
            </div>

            {loading ? (
              <div className="skeleton-container">
                <div className="skeleton skeleton-row" />
                <div className="skeleton skeleton-row" />
              </div>
            ) : filteredGallery.length ? (
              <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(220px, 1fr))", gap: "1rem", marginTop: "1rem" }}>
                {filteredGallery.map((item) => {
                  const id = stringValue(item.id);
                  const isPub = item.is_published !== false;
                  const imgUrl = stringValue(item.media_url || item.url);
                  const title = stringValue(item.title || "Untitled image");

                  return (
                    <article
                      key={id}
                      style={{
                        background: "#fff",
                        border: "1px solid #dbe6ed",
                        borderRadius: "12px",
                        overflow: "hidden",
                        display: "flex",
                        flexDirection: "column",
                        transition: "box-shadow 0.2s ease",
                      }}
                    >
                      <div style={{ position: "relative", height: "140px", background: "#f0f4f7" }}>
                        <img
                          src={imgUrl}
                          alt={stringValue(item.alt_text) || title}
                          loading="lazy"
                          style={{ width: "100%", height: "100%", objectFit: "cover" }}
                        />
                        <span
                          className={`student-status ${isPub ? "active" : "inactive"}`}
                          style={{ position: "absolute", top: "8px", right: "8px", boxShadow: "0 2px 6px rgba(0,0,0,0.15)" }}
                        >
                          {isPub ? "Published" : "Draft"}
                        </span>
                      </div>
                      <div style={{ padding: "0.75rem", flex: 1, display: "flex", flexDirection: "column" }}>
                        <b style={{ fontSize: "0.86rem", color: "#193c59" }}>{title}</b>
                        {Boolean(item.caption) && (
                          <small style={{ color: "#617785", marginTop: "0.2rem", display: "block", fontSize: "0.76rem" }}>
                            {stringValue(item.caption)}
                          </small>
                        )}
                        <div style={{ display: "flex", gap: "0.4rem", marginTop: "auto", paddingTop: "0.75rem" }}>
                          <button
                            className="secondary-button"
                            style={{ flex: 1, padding: "0.3rem 0.5rem", fontSize: "0.76rem" }}
                            onClick={() => void toggle(item)}
                          >
                            {isPub ? "Unpublish" : "Publish"}
                          </button>
                          <button
                            className="icon-button"
                            title="Preview image"
                            onClick={() => setPreviewImage(item)}
                          >
                            <Eye size={14} />
                          </button>
                          <button
                            className="icon-button danger"
                            title="Delete photo"
                            onClick={() => void deletePhoto(item)}
                          >
                            <Trash2 size={14} />
                          </button>
                        </div>
                      </div>
                    </article>
                  );
                })}
              </div>
            ) : (
              <p className="ops-empty">No gallery photos match your search.</p>
            )}
          </section>
        </div>
      ) : (
        <section className="surface ops-form-surface" style={{ maxWidth: "680px" }}>
          <h3>Public Homepage Copy &amp; Story</h3>
          <p>These details revalidate the live public school website upon publishing.</p>

          <form action={saveContent} className="ops-detail-form">
            <div className="form-grid">
              <label className="field">
                Hero Title
                <input
                  name="hero_title"
                  required
                  defaultValue={stringValue(content.hero_title || "Welcome to SchoolDesk Academy")}
                />
              </label>
              <label className="field" style={{ gridColumn: "1 / -1" }}>
                Hero Description
                <textarea
                  name="hero_body"
                  rows={3}
                  required
                  defaultValue={stringValue(content.hero_body || "Empowering young minds through excellence in education, leadership, and personal growth.")}
                />
              </label>
              <label className="field">
                Mission Title
                <input
                  name="mission_title"
                  required
                  defaultValue={stringValue(content.mission_title || "Our Mission & Core Values")}
                />
              </label>
              <label className="field" style={{ gridColumn: "1 / -1" }}>
                Mission Statement
                <textarea
                  name="mission_body"
                  rows={3}
                  required
                  defaultValue={stringValue(content.mission_body || "To nurture inquisitive, compassionate, and resilient learners equipped to thrive in a global community.")}
                />
              </label>
            </div>
            <button className="primary-button" style={{ marginTop: "1rem" }}>
              Publish website copy
            </button>
          </form>
        </section>
      )}

      {previewImage && (
        <Dialog
          kicker="Media preview"
          title={stringValue(previewImage.title || "Gallery photo")}
          onClose={() => setPreviewImage(null)}
        >
          <div style={{ textAlign: "center" }}>
            <img
              src={stringValue(previewImage.media_url || previewImage.url)}
              alt={stringValue(previewImage.alt_text) || "Gallery image"}
              style={{ maxWidth: "100%", maxHeight: "450px", borderRadius: "10px", border: "1px solid #d0e0ec" }}
            />
            {Boolean(previewImage.caption) && (
              <p style={{ marginTop: "0.75rem", color: "#4f6575", fontSize: "0.86rem" }}>
                {stringValue(previewImage.caption)}
              </p>
            )}
          </div>
          <div className="dialog-footer" style={{ marginTop: "1rem" }}>
            <button className="secondary-button" type="button" onClick={() => setPreviewImage(null)}>
              Close preview
            </button>
          </div>
        </Dialog>
      )}
    </section>
  );
}
