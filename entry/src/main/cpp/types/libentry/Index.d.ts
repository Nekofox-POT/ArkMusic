export const encodeImageToBase64: (buffer: ArrayBuffer) => string
export const getImageAverageColor: (buffer: ArrayBuffer, width: number, height: number) => number
export const extractFilename: (path: string) => string
export const getAudioMetadata: (filePath: string) => AudioMetadata
export const base64urlCode: (input: string, isEncode: boolean) => string
export const sortStringArray: (arr: string[]) => string[]

export interface AudioMetadata {
  channels: number
  sampleRate: number
  bitDepth: number
  bitrate: number
  duration: number
  filename: string
  title: string
  artist: string
  composer: string
  album: string
  albumArtist: string
  genre: string
}