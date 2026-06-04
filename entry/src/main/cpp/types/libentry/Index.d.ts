export const encodeImageToBase64: (buffer: ArrayBuffer) => string
export const pixel_light_count: (buffer: ArrayBuffer, width: number, height: number) => number
export const extractFilename: (path: string) => string
export const getAudioMetadata: (filePath: string | string[]) => Promise<AudioMetadata | BatchAudioMetadata[]>
export const base64urlCode: (input: string, isEncode: boolean) => string
export const sortStringArray: (arr: string[]) => string[]
export const dsdToWav: (inputPath: string, outputPath: string) => Promise<void>

// 播放器控制
export const set_audio: (path: string, auto_start?: boolean, time?: number) => Promise<boolean>
export const playing: () => void
export const pause: () => void
export const seek: (time_ms: number) => void
export const get_current_time: () => number
export const register_time_callback: (callback: (time_ms: number) => void) => void
export const register_ready_callback: (callback: () => void) => void
export const register_status_callback: (callback: (status: string) => void) => void
export const get_status: () => string

// EQ/PEQ
export const switch_eq: (mode: number) => void
export const get_eq_mode: () => number
export const set_eq: (gains: number[]) => void
export const set_peq: (params: [boolean, number, number, number, number][]) => void
export const get_eq: () => number[]
export const get_peq: () => [boolean, number, number, number, number][]

export interface AudioMetadata {
  channels: number
  sampleRate: number
  bitDepth: number
  bitrate: number
  duration: number
  durationFormat: string
  filename: string
  title: string
  artist: string
  composer: string
  album: string
  albumArtist: string
  genre: string
}

export interface BatchAudioMetadata {
  filePath: string
  success: boolean
  filename: string
  channels: number
  sampleRate: number
  bitDepth: number
  bitrate: number
  duration: number
  durationFormat: string
  title: string
  artist: string
  composer: string
  album: string
  albumArtist: string
  genre: string
  error?: string
}
