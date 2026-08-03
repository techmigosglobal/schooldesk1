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
    <>
      {saving && (
        <div className="dialog-save-progress" role="status" aria-live="polite">
          <LoadingIndicator label="Saving changes…" announce={false} />
        </div>
      )}
      <div className="dialog-footer">
        <button className="secondary-button" type="button" onClick={onClose} disabled={saving}>
          Cancel
        </button>
        <button className="primary-button" type="submit" disabled={saving} aria-busy={saving}>
          {saving ? (
            <LoadingIndicator label="Saving…" compact announce={false} />
          ) : (
            label
          )}
        </button>
      </div>
    </>
  );
}
