from __future__ import annotations

import uuid
from pathlib import Path

CONTENT_TYPE_EXTENSION_MAP = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
    "image/heic": "heic",
    "image/heif": "heif",
    "image/gif": "gif",
    "image/bmp": "bmp",
    "image/tiff": "tiff",
    "application/pdf": "pdf",
}


def _clean_segment(value) -> str:
    segment = str(value or "").strip().strip("/")
    if not segment:
        raise ValueError("Storage path segment is required.")
    return segment


def resolve_upload_extension(upload, default: str = "bin") -> str:
    suffix = Path(str(getattr(upload, "name", "") or "")).suffix.lower().lstrip(".")
    if suffix:
        return suffix[:12]

    content_type = str(getattr(upload, "content_type", "") or "").lower().strip()
    mapped = CONTENT_TYPE_EXTENSION_MAP.get(content_type, "")
    if mapped:
        return mapped

    if "/" in content_type:
        return content_type.rsplit("/", 1)[-1][:12] or default
    return default


def build_storage_path(*segments, upload=None, filename: str | None = None) -> str:
    path_segments = [_clean_segment(segment) for segment in segments]
    if not path_segments:
        raise ValueError("At least one storage path segment is required.")

    if filename:
        resolved_filename = Path(filename).name
    else:
        extension = resolve_upload_extension(upload)
        resolved_filename = f"{uuid.uuid4().hex}.{extension}"

    return "/".join([*path_segments, resolved_filename])
