//
// 图片缓存
// 这是一个多线程操作
//

////////////////
// 导入第三方库 //
///////////////
import { image } from '@kit.ImageKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import taskpool from '@ohos.taskpool'

///////////
// 变量池 //
//////////
const root_path = getContext().filesDir   // 工作目录

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// TaskPool任务 //
////////////////

// 图片打包任务（在TaskPool线程中执行）
@Concurrent
async function pack_image_task(pixelMap: image.PixelMap): Promise<ArrayBuffer> {
  // 创建图片打包器
  const imagePackerApi = image.createImagePacker()

  // 设置打包参数
  const packOpts: image.PackingOption = {
    format: 'image/png',
    quality: 100
  }

  // 打包 PixelMap 为 PNG 数据
  const packData = await imagePackerApi.packing(pixelMap, packOpts)

  // 释放打包器
  imagePackerApi.release()

  return packData
}

// 文件写入任务（在TaskPool线程中执行）
@Concurrent
function write_file_task(rootPath: string, path: string, data: ArrayBuffer): void {
  console.log(`正在保存 ${path}`)
  try {
    const file = fs.openSync(rootPath + `/` + path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
    fs.writeSync(file.fd, data)
    fs.closeSync(file)
  } catch (e) {
    console.error(`文件保存失败：${e}`)
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主程序 //
//////////
export async function img_save(pixelMap: image.PixelMap, path: string) {

  try {
    // 创建并行任务
    const packTask = new taskpool.Task(pack_image_task, pixelMap)

    // 执行打包任务
    const packData = await taskpool.execute(packTask) as ArrayBuffer

    // 创建写入任务
    const writeTask = new taskpool.Task(write_file_task, root_path, path, packData)

    // 执行写入任务
    await taskpool.execute(writeTask)
  } catch (e) {
    console.error(`图片保存失败：${e}`)
  }

}