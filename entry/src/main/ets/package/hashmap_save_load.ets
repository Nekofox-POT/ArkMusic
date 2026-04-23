//
// 储存 / 读取
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

// string[][]转json储存 //
export function array_to_json_save(data: string[][], path: string): boolean {

  // 转换
  if (!data || data.length === 0) {
    return false
  }
  const packData = JSON.stringify(data)

  // 保存
  try {
    const file = fs.openSync(getContext().filesDir + '/' + path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    fs.writeSync(file.fd, packData)
    fs.closeSync(file)
  } catch (e) {
    log(`保存文件失败: ${e}`, 'error')
    return false
  }

  return true

}

// json读取转string[][] //
export function read_json_to_array(path: string): string[][] {

  // 读取
  try {

    // 读取文本
    let json: string = fs.readTextSync(getContext().filesDir + '/' + path)

    // 转换
    // 核心修改：使用 as 显式断言为 string[][]，不使用 unknown
    const parsed = JSON.parse(json) as string[][];

    // 防御性校验：确保解析出来的确实是二维数组
    if (!Array.isArray(parsed)) {
      throw new Error("JSON 格式错误：期望数组");
    }

    const result: string[][] = [];

    // 核心修改：使用传统 for 循环代替 for...of，在 ArkTS 中更安全且不会触发隐式 any 报错
    for (let i = 0; i < parsed.length; i++) {
      const row = parsed[i];
      if (!Array.isArray(row)) {
        throw new Error("JSON 格式错误：期望二维数组");
      }

      const stringRow: string[] = [];
      for (let j = 0; j < row.length; j++) {
        const element = row[j];
        if (typeof element !== 'string') {
          throw new Error("JSON 格式错误：数组元素必须是字符串");
        }
        stringRow.push(element);
      }
      result.push(stringRow);
    }

    // 返回
    return result

  } catch (e) {
    log(`读取文件失败: ${e}`, 'error')
    return []   // 文件不存在或读取失败，返回空数组
  }

}