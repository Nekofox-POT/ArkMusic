//
// array的 储存 / 读取
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import { fileIo as fs } from '@kit.CoreFileKit'
import { log } from './system_function'

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

// string[]转json储存（覆盖） //
export function array_to_json_save(data: string[], path: string): boolean {

  try {fs.rmdirSync(path)} catch {}

  // 转换
  const packData = JSON.stringify(data)

  // 保存
  try {
    const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    fs.writeSync(file.fd, packData)
    fs.closeSync(file)
  } catch (e) {
    log(`保存文件失败: ${e}`, 'error')
    return false
  }

  return true

}

// json读取转string[] //
export function read_json_to_array(path: string): string[] {
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
    log(`读取文件失败: ${e}`, 'error')
    return []
  }
}