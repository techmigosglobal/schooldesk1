"use client";

import { useEffect, useRef, useState } from "react";
import { Dialog } from "./Dialog";
import { RotateCw, ZoomIn, ZoomOut } from "@/lib/lucide-react";

export function ImageCropperModal({
  imageSrc,
  onCancel,
  onCropComplete,
}: {
  imageSrc: string;
  onCancel: () => void;
  onCropComplete: (file: File) => void;
}) {
  const [zoom, setZoom] = useState(1);
  const [rotation, setRotation] = useState(0);
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const [isDragging, setIsDragging] = useState(false);
  const [dragStart, setDragStart] = useState({ x: 0, y: 0 });
  const [dimensions, setDimensions] = useState<{
    naturalWidth: number;
    naturalHeight: number;
    dispWidth: number;
    dispHeight: number;
  } | null>(null);
  const imgRef = useRef<HTMLImageElement | null>(null);

  const VIEWPORT_SIZE = 280;

  useEffect(() => {
    const img = new Image();
    img.src = imageSrc;
    img.onload = () => {
      imgRef.current = img;
      const W = img.naturalWidth;
      const H = img.naturalHeight;
      const fitScale = Math.max(VIEWPORT_SIZE / W, VIEWPORT_SIZE / H);
      setDimensions({
        naturalWidth: W,
        naturalHeight: H,
        dispWidth: W * fitScale,
        dispHeight: H * fitScale,
      });
    };
  }, [imageSrc]);

  function handleMouseDown(e: React.MouseEvent | React.TouchEvent) {
    setIsDragging(true);
    const clientX = "touches" in e ? e.touches[0].clientX : e.clientX;
    const clientY = "touches" in e ? e.touches[0].clientY : e.clientY;
    setDragStart({ x: clientX - offset.x, y: clientY - offset.y });
  }

  function handleMouseMove(e: React.MouseEvent | React.TouchEvent) {
    if (!isDragging) return;
    const clientX = "touches" in e ? e.touches[0].clientX : e.clientX;
    const clientY = "touches" in e ? e.touches[0].clientY : e.clientY;
    setOffset({
      x: clientX - dragStart.x,
      y: clientY - dragStart.y,
    });
  }

  function handleMouseUp() {
    setIsDragging(false);
  }

  function handleCrop() {
    if (!imgRef.current || !dimensions) return;
    const img = imgRef.current;
    const canvas = document.createElement("canvas");
    const OUTPUT_SIZE = 500;
    canvas.width = OUTPUT_SIZE;
    canvas.height = OUTPUT_SIZE;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    ctx.fillStyle = "#ffffff";
    ctx.fillRect(0, 0, OUTPUT_SIZE, OUTPUT_SIZE);

    ctx.save();
    ctx.translate(OUTPUT_SIZE / 2, OUTPUT_SIZE / 2);
    ctx.rotate((rotation * Math.PI) / 180);

    const scaleFactor = OUTPUT_SIZE / VIEWPORT_SIZE;
    const canvasImgWidth = dimensions.dispWidth * scaleFactor * zoom;
    const canvasImgHeight = dimensions.dispHeight * scaleFactor * zoom;
    const centerX = offset.x * scaleFactor;
    const centerY = offset.y * scaleFactor;

    ctx.drawImage(
      img,
      centerX - canvasImgWidth / 2,
      centerY - canvasImgHeight / 2,
      canvasImgWidth,
      canvasImgHeight
    );

    ctx.restore();

    canvas.toBlob(
      (blob) => {
        if (!blob) return;
        const croppedFile = new File([blob], "student_photo_cropped.jpg", {
          type: "image/jpeg",
        });
        onCropComplete(croppedFile);
      },
      "image/jpeg",
      0.92
    );
  }

  return (
    <Dialog kicker="Adjust photo" title="Crop & position photo" onClose={onCancel}>
      <div className="cropper-wrapper">
        <p className="cropper-instruction">
          Drag photo to position face inside circle, then click Apply crop.
        </p>

        <div
          className="cropper-viewport"
          onMouseDown={handleMouseDown}
          onMouseMove={handleMouseMove}
          onMouseUp={handleMouseUp}
          onMouseLeave={handleMouseUp}
          onTouchStart={handleMouseDown}
          onTouchMove={handleMouseMove}
          onTouchEnd={handleMouseUp}
        >
          {dimensions && (
            <img
              src={imageSrc}
              alt="Crop preview"
              style={{
                width: `${dimensions.dispWidth}px`,
                height: `${dimensions.dispHeight}px`,
                position: "absolute",
                top: "50%",
                left: "50%",
                transform: `translate(-50%, -50%) translate(${offset.x}px, ${offset.y}px) scale(${zoom}) rotate(${rotation}deg)`,
                transformOrigin: "center center",
              }}
              draggable={false}
            />
          )}
          <div className="cropper-mask" />
        </div>

        <div className="cropper-controls">
          <div className="cropper-zoom">
            <ZoomOut size={16} />
            <input
              type="range"
              min="1"
              max="3"
              step="0.05"
              value={zoom}
              onChange={(e) => setZoom(parseFloat(e.target.value))}
              aria-label="Zoom level"
            />
            <ZoomIn size={16} />
          </div>

          <div className="cropper-actions">
            <button
              type="button"
              className="secondary-button icon-button-text"
              onClick={() => setRotation((r) => (r + 90) % 360)}
            >
              <RotateCw size={15} /> Rotate
            </button>
            <button
              type="button"
              className="secondary-button icon-button-text"
              onClick={() => {
                setZoom(1);
                setRotation(0);
                setOffset({ x: 0, y: 0 });
              }}
            >
              Reset
            </button>
          </div>
        </div>

        <div className="dialog-footer">
          <button type="button" className="secondary-button" onClick={onCancel}>
            Cancel
          </button>
          <button type="button" className="primary-button" onClick={handleCrop}>
            Apply crop
          </button>
        </div>
      </div>
    </Dialog>
  );
}
