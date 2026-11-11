/**
 * Files on a task: the same limits as the private "task-files" bucket (see the tasks
 * migration), checked in the browser first so a teacher hears about a problem before
 * waiting for an upload.
 */

export const TASK_FILES_BUCKET = 'task-files';

/** 300 MB each. */
export const MAX_FILE_BYTES = 300 * 1024 * 1024;

/** The file types schools use, by extension, as the bucket accepts them. */
const TYPES_BY_EXTENSION: Record<string, string> = {
  pdf: 'application/pdf',
  doc: 'application/msword',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  ppt: 'application/vnd.ms-powerpoint',
  pptx: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  xls: 'application/vnd.ms-excel',
  xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  odt: 'application/vnd.oasis.opendocument.text',
  odp: 'application/vnd.oasis.opendocument.presentation',
  ods: 'application/vnd.oasis.opendocument.spreadsheet',
  rtf: 'application/rtf',
  txt: 'text/plain',
  csv: 'text/csv',
  zip: 'application/zip',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  png: 'image/png',
  gif: 'image/gif',
  webp: 'image/webp',
  heic: 'image/heic',
  mp3: 'audio/mpeg',
  m4a: 'audio/mp4',
  wav: 'audio/wav',
  mp4: 'video/mp4',
  mov: 'video/quicktime',
  webm: 'video/webm',
};

const ALLOWED = new Set(Object.values(TYPES_BY_EXTENSION));

/** What the <input type="file"> offers. */
export const ACCEPT = Object.keys(TYPES_BY_EXTENSION)
  .map((ext) => `.${ext}`)
  .join(',');

function extensionOf(name: string): string {
  const dot = name.lastIndexOf('.');
  return dot === -1 ? '' : name.slice(dot + 1).toLowerCase();
}

/**
 * The type to store a file as: the browser's, if the bucket takes it (any image, audio
 * or video counts); otherwise the one its extension implies. Null if neither works.
 */
export function contentTypeFor(file: { name: string; type: string }): string | null {
  const type = file.type.toLowerCase();
  if (
    ALLOWED.has(type) ||
    /^(image|audio|video)\//.test(type) ||
    type === 'application/x-zip-compressed'
  ) {
    return type;
  }
  return TYPES_BY_EXTENSION[extensionOf(file.name)] ?? null;
}

/** Why a file can't be attached, in words a teacher reads; null if it can. */
export function fileProblem(file: { name: string; type: string; size: number }): string | null {
  if (file.size === 0) return `${file.name} is empty.`;
  if (file.size > MAX_FILE_BYTES) return `${file.name} is over 300 MB.`;
  if (!contentTypeFor(file)) return `${file.name} isn’t a file type Chom takes.`;
  return null;
}

export function isVideo(file: { name: string; type: string }): boolean {
  return (contentTypeFor(file) ?? '').startsWith('video/');
}

/**
 * Where a file goes: <school>/<task>/<random>-<tidy name>. The random part keeps two
 * files of the same name apart; the name stays readable in the bucket.
 */
export function storagePath(
  schoolId: string,
  taskId: string,
  fileName: string,
  id: string,
): string {
  const tidy =
    fileName
      .normalize('NFKD')
      .replace(/[^\w.-]+/g, '-')
      .replace(/-+/g, '-')
      .replace(/-\./g, '.')
      .replace(/^-|-$/g, '')
      .slice(-80) || 'file';
  return `${schoolId}/${taskId}/${id}-${tidy}`;
}

export function formatBytes(bytes: number): string {
  if (bytes >= 1024 * 1024) return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  return `${Math.max(1, Math.round(bytes / 1024))} KB`;
}
