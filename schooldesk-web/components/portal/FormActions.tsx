"use client";

import { LoadingIndicator } from "@/components/loading-skeletons";

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
          <LoadingIndicator label="Saving…" compact announce={false} />
        ) : (
          label
        )}
      </button>
    </div>
  );
}
