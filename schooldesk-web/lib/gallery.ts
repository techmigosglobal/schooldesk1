/** Client-safe gallery data and helpers shared by public website components. */
export type GalleryItem = {
  id: string;
  title: string;
  alt_text: string;
  caption: string;
  media_url: string;
  media_type?: string;
};

/** The public-school website is intentionally a photo showcase. */
export function isPublicGalleryImage(item: GalleryItem): boolean {
  return item.media_type?.startsWith("image/") === true
    || /\.(avif|gif|jpe?g|png|webp)(\?|$)/i.test(item.media_url);
}
