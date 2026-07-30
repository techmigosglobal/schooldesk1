import { ImageResponse } from "next/og";

export const alt = "Arish Ville Preschool — Learn Today, Lead Tomorrow.";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function OpenGraphImage() {
  return new ImageResponse(<div style={{ width: "100%", height: "100%", display: "flex", flexDirection: "column", justifyContent: "center", padding: "72px", color: "#ffffff", background: "linear-gradient(130deg, #0b2f5b, #0e5ea8 58%, #2e7fc1)" }}><div style={{ display: "flex", fontSize: 30, letterSpacing: 5, color: "#ffe27a", fontWeight: 700 }}>ARISH VILLE PRESCHOOL</div><div style={{ display: "flex", maxWidth: 900, marginTop: 24, fontSize: 82, lineHeight: 1.05, fontFamily: "serif", fontWeight: 700 }}>Learn Today, Lead Tomorrow.</div><div style={{ display: "flex", marginTop: 35, fontSize: 30, color: "#eef7ff" }}>A joyful first home for curiosity, confidence, and friendship.</div></div>, size);
}
