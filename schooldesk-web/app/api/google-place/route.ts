import { NextResponse } from "next/server";

const fallbackGoogleUrl = "https://www.google.com/search?q=Arish+Ville+Miyapur";

type GoogleReview = {
  author: string;
  rating?: number;
  text: string;
  relativeTime: string;
  photoUrl?: string;
};

/**
 * Keeps the Google Places key on the server. Google Place Details returns a
 * maximum of five review records; the complete review history remains on the
 * Google property linked from the public site.
 */
export async function GET() {
  const apiKey = process.env.GOOGLE_PLACES_API_KEY;
  const placeId = process.env.GOOGLE_PLACE_ID;
  if (!apiKey || !placeId) {
    return NextResponse.json({ configured: false, googleMapsUri: process.env.GOOGLE_REVIEWS_URL || fallbackGoogleUrl });
  }

  try {
    const response = await fetch(`https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}`, {
      headers: {
        "X-Goog-Api-Key": apiKey,
        "X-Goog-FieldMask": "displayName,formattedAddress,location,rating,userRatingCount,googleMapsUri,reviews",
      },
      next: { revalidate: 3600 },
    });
    if (!response.ok) throw new Error(`Places returned ${response.status}`);
    const place = await response.json() as {
      displayName?: { text?: string }; formattedAddress?: string; rating?: number; userRatingCount?: number; googleMapsUri?: string;
      reviews?: Array<{ authorAttribution?: { displayName?: string; photoUri?: string }; rating?: number; text?: { text?: string }; relativePublishTimeDescription?: string }>;
    };
    const reviews: GoogleReview[] = (place.reviews ?? []).slice(0, 5).map((review) => ({
      author: review.authorAttribution?.displayName || "Google reviewer",
      rating: review.rating,
      text: review.text?.text || "",
      relativeTime: review.relativePublishTimeDescription || "",
      photoUrl: review.authorAttribution?.photoUri,
    })).filter((review) => Boolean(review.text));
    return NextResponse.json({
      configured: true,
      name: place.displayName?.text || "Arish Ville Miyapur",
      address: place.formattedAddress || "",
      rating: place.rating,
      userRatingCount: place.userRatingCount,
      googleMapsUri: place.googleMapsUri || process.env.GOOGLE_REVIEWS_URL || fallbackGoogleUrl,
      reviews,
    });
  } catch {
    return NextResponse.json({ configured: false, googleMapsUri: process.env.GOOGLE_REVIEWS_URL || fallbackGoogleUrl });
  }
}
