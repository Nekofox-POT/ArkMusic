import { fileIo as fs } from '@kit.CoreFileKit'
import { log } from './system_function'

// string[]储存（覆盖） //
export async function save_array(data: string[], path: string): Promise<boolean> {

  try {await fs.rmdir(path)} catch {}

  // 转换
  const packData = JSON.stringify(data)

  // 保存
  try {
    const file = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    await fs.write(file.fd, packData)
    await fs.close(file)
  } catch (e) {
    log(`保存${path}失败: ${e}`, 'error')
    return false
  }

  return true

}
// 读取string[] //
export function load_array(path: string): string[] {

  try {
    let json: string = fs.readTextSync(path)

    const parsed = JSON.parse(json) as string[]

    // 校验：必须是数组
    if (!Array.isArray(parsed)) {
      throw new Error("JSON 格式错误：期望数组")
    }

    const result: string[] = []

    // 遍历每个元素，确保是字符串
    for (let i = 0; i < parsed.length; i++) {
      const element = parsed[i]
      if (typeof element !== 'string') {
        throw new Error("JSON 格式错误：数组元素必须是字符串")
      }
      result.push(element)
    }

    return result

  } catch (e) {
    log(`读取${path}失败: ${e}`, 'error')
    return []
  }
}

// （a定制）map_string[][]储存（覆盖） //
export async function save_map_cust_a(data: Map<string, string[][]>, path: string): Promise<boolean> {

  try {await fs.rmdir(path)} catch {}

  // Map → 条目数组 → JSON
  const entries: [string, string[][]][] = []
  data.forEach((value: string[][], key: string) => {
    entries.push([key, value])
  })
  const packData = JSON.stringify(entries)

  try {
    const file = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    await fs.write(file.fd, packData)
    await fs.close(file)
  } catch (e) {
    log(`保存${path}失败: ${e}`, 'error')
    return false
  }

  return true

}
// （a定制）读取map_string[][] //
export function load_map_cust_a(path: string): Map<string, string[][]> {

  try {
    let json: string = fs.readTextSync(path)
    const parsed = JSON.parse(json) as [string, string[][]][]

    // 校验：必须是数组
    if (!Array.isArray(parsed)) {
      throw new Error("JSON 格式错误：期望数组")
    }

    const result = new Map<string, string[][]>()
    for (const entry of parsed) {
      // 校验：每个条目必须是 [key: string, val: string[][]]
      if (!Array.isArray(entry) || entry.length < 2 ||
          typeof entry[0] !== 'string' || !Array.isArray(entry[1])) {
        throw new Error("JSON 格式错误：条目格式不正确")
      }
      result.set(entry[0], entry[1] as string[][])
    }

    return result

  } catch (e) {
    log(`读取${path}失败: ${e}`, 'error')
    return new Map<string, string[][]>()
  }

}

// （b定制）map_string[]储存（覆盖） //
export async function save_map_cust_b(data: Map<string, string[]>, path: string): Promise<boolean> {

  try {await fs.rmdir(path)} catch {}

  // Map → 条目数组 → JSON
  const entries: [string, string[]][] = []
  data.forEach((value: string[], key: string) => {
    entries.push([key, value])
  })
  const packData = JSON.stringify(entries)

  try {
    const file = await fs.open(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    await fs.write(file.fd, packData)
    await fs.close(file)
  } catch (e) {
    log(`保存${path}失败: ${e}`, 'error')
    return false
  }

  return true

}

// （b定制）读取map_string[] //
export function load_map_cust_b(path: string): Map<string, string[]> {

  try {
    let json: string = fs.readTextSync(path)
    const parsed = JSON.parse(json) as [string, string[]][]

    // 校验：必须是数组
    if (!Array.isArray(parsed)) {
      throw new Error("JSON 格式错误：期望数组")
    }

    const result = new Map<string, string[]>()
    for (const entry of parsed) {
      // 校验：每个条目必须是 [key: string, val: string[]]
      if (!Array.isArray(entry) || entry.length < 2 ||
          typeof entry[0] !== 'string' || !Array.isArray(entry[1])) {
        throw new Error("JSON 格式错误：条目格式不正确")
      }
      result.set(entry[0], entry[1] as string[])
    }

    return result

  } catch (e) {
    log(`读取${path}失败: ${e}`, 'error')
    return new Map<string, string[]>()
  }

}