//
// 储存 / 读取
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import { fileIo as fs, ListFileOptions } from '@kit.CoreFileKit'

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

// string[][]转json储存 //
export function array_to_json_save(data: string[][], path: string): boolean {

  // 转换
  if (!data || data.length === 0) {
    console.log('#1')
    return false
  }
  console.log('#2')
  const packData = JSON.stringify(data)
  console.log('#3')
  console.log(`${packData}`)

  // 保存
  try {
    console.log('#4')
    console.log(getContext().filesDir + path)
    const file = fs.openSync(getContext().filesDir + '/' + path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    fs.writeSync(file.fd, packData)
    fs.closeSync(file)
  } catch (e) {
    console.log('#0')
    console.log(e)
    return false
  }

  return true

}

// json读取转string[][] //
export function read_json_to_array(path: string): string[][] {

  // 读取
  let json: string = ''
  try {
    // 使用 readTextSync：自动打开、读取全部文本、关闭，直接返回 string
    json = fs.readTextSync(getContext().filesDir + '/' + path)
  } catch (error) {
    console.error("读取文件失败: ", JSON.stringify(error))
    return []   // 文件不存在或读取失败，返回空数组
  }

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

  return result;
}