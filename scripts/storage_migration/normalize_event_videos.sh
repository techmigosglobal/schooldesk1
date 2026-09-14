#!/usr/bin/env bash
set -euo pipefail

# Re-encodes legacy event-post videos into an Android-compatible private R2
# object, then replaces only the database reference. Source objects are never
# deleted; source_url/source_storage_ref are retained for rollback/audit.
#
# Required environment:
#   API_BASE_URL              Supabase Edge API base, ending in /api
#   TEACHER_ACCESS_TOKEN      access token for a user who can view the feed
#   SUPABASE_SERVICE_KEY      service_role/secret key for the PostgREST patch
#   SCHOOL_ID                 school whose event-post media is being repaired
#
# Optional:
#   DRY_RUN=1                 list candidates without downloading or mutating
#   VIDEO_WORK_DIR            explicit temporary working directory

required() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "$name is required" >&2
    exit 2
  fi
}

required API_BASE_URL
required TEACHER_ACCESS_TOKEN
required SUPABASE_SERVICE_KEY
required SCHOOL_ID

readonly API_BASE_URL="${API_BASE_URL%/}"
readonly SUPABASE_URL="${API_BASE_URL%/functions/v1/api}"
readonly DRY_RUN="${DRY_RUN:-0}"
readonly WORK_DIR="${VIDEO_WORK_DIR:-$(mktemp -d /tmp/schooldesk-video-normalize.XXXXXX)}"
readonly SHARD_INDEX="${SHARD_INDEX:-0}"
readonly SHARD_COUNT="${SHARD_COUNT:-1}"
mkdir -p "$WORK_DIR"

if ! [[ "$SHARD_INDEX" =~ ^[0-9]+$ && "$SHARD_COUNT" =~ ^[1-9][0-9]*$ &&
  "$SHARD_INDEX" -lt "$SHARD_COUNT" ]]; then
  echo "SHARD_INDEX must be a non-negative integer smaller than SHARD_COUNT" >&2
  exit 2
fi

feed_file="$WORK_DIR/feed.json"
# Use the service-scoped event-post inventory rather than the teacher feed so
# parent-home, gallery, staff-home, and approval-visible records all share the
# same repair pass. The media URL itself is still resolved through the normal
# authenticated API path below.
curl -fsSL --retry 2 \
  "$SUPABASE_URL/rest/v1/event_posts?school_id=eq.$SCHOOL_ID&select=id,media_urls" \
  -H "apikey: $SUPABASE_SERVICE_KEY" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" > "$feed_file"

all_candidates_file="$WORK_DIR/candidates.all.tsv"
candidates_file="$WORK_DIR/candidates.tsv"
jq -r '.[] as $post | ($post.media_urls // []) | to_entries[] |
  select((.value.kind == "video" or (.value.mime_type // "" | startswith("video/")) or ((.value.name // .value.url // "") | test("\\.(mov|mp4|m4v|webm)(\\?|$)"; "i"))) and (((.value.storage_ref // .value.url // "") | contains("/event-post-compat/")) | not)) |
  [$post.id, .key, (.value.name // "event-video"), (.value.mime_type // ""), (.value.storage_ref // "")] | @tsv' "$feed_file" > "$all_candidates_file"
awk -v shard="$SHARD_INDEX" -v shards="$SHARD_COUNT" \
  '((NR - 1) % shards) == shard' "$all_candidates_file" > "$candidates_file"
candidate_count=$(wc -l < "$candidates_file" | tr -d ' ')
echo "video_candidates=$candidate_count"

if [[ "$DRY_RUN" == "1" ]]; then
  cat "$candidates_file"
  exit 0
fi

processed=0
failed=0

while IFS=$'\t' read -r post_id media_index display_name old_ref; do
  [[ -n "$post_id" ]] || continue
  processed=$((processed + 1))
  echo "[$processed/$candidate_count] post=$post_id media_index=$media_index name=${display_name:0:80}"

  post_json="$WORK_DIR/post.json"
  if ! curl -fsSL --retry 2 \
    -H "Authorization: Bearer $TEACHER_ACCESS_TOKEN" \
    "$API_BASE_URL/event-posts/$post_id" > "$post_json"; then
    echo "could not read event post $post_id" >&2
    failed=$((failed + 1))
    continue
  fi
  source_url=$(jq -r --argjson index "$media_index" '.data.media_urls[$index].url // empty' "$post_json")
  if [[ -z "$source_url" ]]; then
    echo "missing source URL for $post_id[$media_index]" >&2
    failed=$((failed + 1))
    continue
  fi

  src="$WORK_DIR/source.bin"
  out="$WORK_DIR/compat.mp4"
  if ! curl -fsSL --retry 2 -o "$src" "$source_url"; then
    echo "could not download source for $post_id[$media_index]" >&2
    failed=$((failed + 1))
    continue
  fi

  transfer=$(ffprobe -v error -select_streams v:0 -show_entries stream=color_transfer -of csv=p=0 "$src" 2>/dev/null || true)
  pix_fmt=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of csv=p=0 "$src" 2>/dev/null || true)
  if [[ "$transfer" == *smpte2084* || "$transfer" == *arib-std-b67* || "$pix_fmt" == *10* ]]; then
    video_filter="zscale=t=linear:npl=100,format=gbrpf32le,tonemap=tonemap=hable:desat=0,zscale=t=bt709:m=bt709:p=bt709:r=tv,format=yuv420p,scale='min(720,iw)':-2"
  else
    video_filter="scale='min(720,iw)':-2,format=yuv420p"
  fi

  if ! ffmpeg -hide_banner -loglevel error -y -i "$src" \
    -map 0:v:0 -map 0:a:0? -sn -dn \
    -vf "$video_filter" \
    -c:v libx264 -preset veryfast -profile:v baseline -level 4.1 -crf 29 \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
    -c:a aac -b:a 96k -movflags +faststart "$out" < /dev/null; then
    echo "could not normalize source for $post_id[$media_index]" >&2
    failed=$((failed + 1))
    continue
  fi

  upload_json="$WORK_DIR/upload.json"
  if ! curl -sS --fail-with-body --retry 2 -X POST "$API_BASE_URL/uploads" \
    -H "Authorization: Bearer $TEACHER_ACCESS_TOKEN" \
    -F "file=@$out;type=video/mp4" \
    -F 'folder=event-post-compat' \
    -F 'entity_type=event_post_media' \
    -F "entity_id=$post_id" > "$upload_json"; then
    echo "upload failed for $post_id[$media_index]: $(tr '\n' ' ' < "$upload_json" | cut -c1-300)" >&2
    failed=$((failed + 1))
    continue
  fi
  r2_ref=$(jq -r '.data.path // empty' "$upload_json")
  [[ "$r2_ref" == r2://private/* ]] || {
    echo "upload did not return a private R2 reference for $post_id[$media_index]" >&2
    failed=$((failed + 1))
    continue
  }

  current_json="$WORK_DIR/current.json"
  if ! curl -fsSL \
    "$SUPABASE_URL/rest/v1/event_posts?id=eq.$post_id&select=media_urls" \
    -H "apikey: $SUPABASE_SERVICE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" > "$current_json"; then
    echo "could not reread event post $post_id for patch" >&2
    failed=$((failed + 1))
    continue
  fi
  patch_json=$(jq --argjson index "$media_index" --arg r2 "$r2_ref" \
    '. [0].media_urls as $media |
      ($media[$index]) as $item |
      {media_urls: ($media | .[$index] = ($item + {
        url: $r2,
        storage_ref: $r2,
        name: ((($item.name // "event-video") | sub("\\.[^.]+$"; "")) + ".mp4"),
        file_name: ((($item.file_name // $item.name // "event-video") | sub("\\.[^.]+$"; "")) + ".mp4"),
        mime_type: "video/mp4",
        source_url: ($item.source_url // $item.url),
        source_storage_ref: ($item.source_storage_ref // $item.storage_ref)
      })), updated_at: (now | todateiso8601)}' "$current_json")
  if ! curl -fsSL --retry 2 -X PATCH \
    "$SUPABASE_URL/rest/v1/event_posts?id=eq.$post_id" \
    -H "apikey: $SUPABASE_SERVICE_KEY" \
    -H "Authorization: Bearer $SUPABASE_SERVICE_KEY" \
    -H 'Content-Type: application/json' \
    -H 'Prefer: return=minimal' \
    --data-binary "$patch_json" > /dev/null; then
    echo "could not patch event post $post_id[$media_index]" >&2
    failed=$((failed + 1))
    continue
  fi

  echo "  updated private R2 reference"
done < "$candidates_file"

echo "processed=$processed failed=$failed"
[[ "$failed" == "0" ]]
