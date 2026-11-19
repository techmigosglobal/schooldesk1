"use client";

import Image, { type ImageProps } from "next/image";
import { useState, type SyntheticEvent } from "react";

const fallbackImage = "/preschool/gallery/classroom-learning.jpeg";

export function PublicImage({ src, alt, onError, ...props }: ImageProps) {
  const [failed, setFailed] = useState(false);
  const resolvedSrc = failed ? fallbackImage : src;
  return (
    <Image
      {...props}
      src={resolvedSrc}
      alt={alt}
      onError={(event: SyntheticEvent<HTMLImageElement, Event>) => {
        if (!failed && src !== fallbackImage) setFailed(true);
        onError?.(event);
      }}
    />
  );
}
