/** Client-safe gallery data and helpers shared by public website components. */
export type GalleryItem = {
  id: string;
  title: string;
  alt_text: string;
  caption: string;
  media_url: string;
  media_type?: string;
};

/**
 * School-approved photography that ships with the public preschool website.
 * These images remain visible alongside any photos published through the
 * portal-managed gallery.
 */
export const preschoolPhotography: GalleryItem[] = [
  {
    id: "preschool-classroom-literacy",
    title: "Learning together",
    alt_text: "Children taking part in a classroom literacy lesson with their teacher",
    caption: "A bright classroom moment filled with early learning and participation.",
    media_url: "/preschool/gallery/classroom-literacy.jpeg",
    media_type: "image/jpeg",
  },
  {
    id: "preschool-garden-planting",
    title: "Growing curiosity",
    alt_text: "Children planting a sapling with their teacher in the preschool garden",
    caption: "Little hands caring for the natural world together.",
    media_url: "/preschool/gallery/garden-planting.jpeg",
    media_type: "image/jpeg",
  },
  {
    id: "preschool-sensory-discovery",
    title: "Sensory discovery",
    alt_text: "Children exploring tactile materials and learning panels with their teacher",
    caption: "Hands-on experiences make discovery feel meaningful.",
    media_url: "/preschool/gallery/sensory-discovery.jpeg",
    media_type: "image/jpeg",
  },
  {
    id: "preschool-creative-blocks",
    title: "Creating together",
    alt_text: "Children building with colourful blocks alongside their teacher",
    caption: "Play, collaboration, and imagination in action.",
    media_url: "/preschool/gallery/creative-blocks.jpeg",
    media_type: "image/jpeg",
  },
  {
    id: "preschool-sense-of-touch",
    title: "Exploring touch",
    alt_text: "Children exploring a brick wall during a sensory lesson about touch",
    caption: "A sensory lesson on texture, temperature, and the sense of touch.",
    media_url: "/preschool/gallery/sense-of-touch.jpeg",
    media_type: "image/jpeg",
  },
  {
    id: "preschool-classroom-learning",
    title: "Joyful classroom learning",
    alt_text: "Children learning in a colourful classroom with their teacher",
    caption: "Everyday classroom learning made joyful and engaging.",
    media_url: "/preschool/gallery/classroom-learning.jpeg",
    media_type: "image/jpeg",
  },
];

/** The public-school website is intentionally a photo showcase. */
export function isPublicGalleryImage(item: GalleryItem): boolean {
  return item.media_type?.startsWith("image/") === true
    || /\.(avif|gif|jpe?g|png|webp)(\?|$)/i.test(item.media_url);
}

export function isPublicGalleryVideo(item: GalleryItem): boolean {
  return item.media_type?.startsWith("video/") === true
    || /\.(m4v|mov|mp4|webm)(\?|$)/i.test(item.media_url);
}

export function isPublicGalleryMedia(item: GalleryItem): boolean {
  return isPublicGalleryImage(item) || isPublicGalleryVideo(item);
}

export function uniqueGalleryItems(items: GalleryItem[]): GalleryItem[] {
  const seen = new Set<string>();
  return items.filter((item) => {
    const key = `${item.id || ""}:${item.media_url}`;
    if (!item.media_url || seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}
