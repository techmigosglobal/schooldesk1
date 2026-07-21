"use client";

import { LoaderCircle } from "@/lib/lucide-react";

export function FormActions({
  saving,
  onClose,
  label = "Save changes",
}: {
  saving: boolean;
  onClose: () => void;
  label?: string;
}) {
  return (
    <div className="dialog-footer">
      <button className="secondary-button" type="button" onClick={onClose}>
        Cancel
      </button>
      <button className="primary-button" disabled={saving}>
        {saving ? (
          <>
            <LoaderCircle className="spin" size={16} /> Saving
          </>
        ) : (
          label
        )}
      </button>
    </div>
  );
}
