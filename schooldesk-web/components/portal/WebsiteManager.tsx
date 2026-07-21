"use client";

import { useCallback, useEffect, useState } from "react";
import { CircleAlert, Globe2, RefreshCw } from "lucide-react";
import type { Row } from "./types";
import { api, rowsFrom, stringValue } from "./utils";

export function WebsiteManager({
  onNotify,
}: {
  onNotify: (message: string) => void;
}) {
  const [content, setContent] = useState<Row>({});
  const [gallery, setGallery] = useState<Row[]>([]);
  const [notice, setNotice] = useState("");
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [website, images] = await Promise.all([
        api("website/content"),
        api("website/gallery"),
      ]);
      setContent((website as Row) || {});
      setGallery(rowsFrom(images));
      setNotice("");
    } catch (event) {
      setNotice(
        event instanceof Error ? event.message : "Unable to load website content"
      );
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  async function saveContent(form: FormData) {
    try {
      await api("website/content", {
        method: "PUT",
        body: JSON.stringify(Object.fromEntries(form)),
      });
      onNotify("Public website copy published. Visitors will see the update shortly.");
      void load();
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Unable to save");
    }
  }

  async function upload(form: FormData) {
    try {
      await api("website/gallery/upload", {
        method: "POST",
        body: form,
      });
      onNotify("Gallery image uploaded as a draft.");
      void load();
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Upload failed");
    }
  }

  async function toggle(row: Row) {
    try {
      await api(`website/gallery/${row.id}`, {
        method: "PUT",
        body: JSON.stringify({ ...row, is_published: !row.is_published }),
      });
      onNotify(
        row.is_published ? "Gallery item unpublished." : "Gallery item is now public."
      );
      void load();
    } catch (event) {
      setNotice(event instanceof Error ? event.message : "Unable to update gallery");
    }
  }

  return (
    <section className="ops-module">
      <div className="ops-module-heading">
        <div>
          <div className="ops-module-icon green">
            <Globe2 size={20} />
          </div>
          <div>
            <p className="ops-kicker">Principal-only publishing</p>
            <h2>Public Website</h2>
            <p>
              Update the ArishVille story and curate photos without exposing operational school media.
            </p>
          </div>
        </div>

        <div className="ops-actions">
          <button className="secondary-button" onClick={() => void load()}>
            <RefreshCw size={16} /> Refresh
          </button>
        </div>
      </div>

      {notice && (
        <div className="ops-inline-error">
          <CircleAlert size={16} />
          {notice}
        </div>
      )}

      <div className="website-grid ops-website-grid">
        <section className="surface ops-form-surface">
          <h3>Homepage copy</h3>
          <p>These changes revalidate the public website after a successful save.</p>

          <form action={saveContent}>
            <label className="field">
              Hero title
              <input
                name="hero_title"
                required
                defaultValue={stringValue(content.hero_title)}
              />
            </label>
            <label className="field">
              Hero description
              <textarea
                name="hero_body"
                required
                defaultValue={stringValue(content.hero_body)}
              />
            </label>
            <label className="field">
              Mission title
              <input
                name="mission_title"
                required
                defaultValue={stringValue(content.mission_title)}
              />
            </label>
            <label className="field">
              Mission statement
              <textarea
                name="mission_body"
                required
                defaultValue={stringValue(content.mission_body)}
              />
            </label>
            <button className="primary-button">Publish website copy</button>
          </form>
        </section>

        <section className="surface ops-form-surface">
          <h3>Curated gallery</h3>
          <p>Upload only photos cleared for the public ArishVille website.</p>

          <form action={upload}>
            <label className="field">
              Photo
              <input
                name="file"
                type="file"
                accept="image/jpeg,image/png,image/webp"
                required
              />
            </label>
            <label className="field">
              Title
              <input name="title" />
            </label>
            <label className="field">
              Accessible description
              <input name="alt_text" required />
            </label>
            <label className="field">
              Caption
              <input name="caption" />
            </label>
            <button className="secondary-button">Upload as draft</button>
          </form>

          <div className="ops-gallery-list">
            {loading ? (
              <p className="loading">Loading gallery…</p>
            ) : gallery.length ? (
              gallery.map((row) => (
                <div className="gallery-admin-item" key={stringValue(row.id)}>
                  <img
                    className="gallery-thumb"
                    src={stringValue(row.media_url)}
                    alt={stringValue(row.alt_text) || "Gallery image"}
                    loading="lazy"
                    decoding="async"
                  />
                  <div>
                    <b>{stringValue(row.title) || "Untitled image"}</b>
                    <small>{row.is_published ? "Published" : "Draft"}</small>
                  </div>
                  <button
                    className="outline-button"
                    onClick={() => void toggle(row)}
                  >
                    {row.is_published ? "Unpublish" : "Publish"}
                  </button>
                </div>
              ))
            ) : (
              <p className="ops-empty-small">No public gallery images yet.</p>
            )}
          </div>
        </section>
      </div>
    </section>
  );
}
