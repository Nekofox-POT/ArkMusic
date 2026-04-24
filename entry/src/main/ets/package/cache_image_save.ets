//
// 图片缓存
// 这是一个多线程操作
//

////////////////
// 导入第三方库 //
///////////////
import { image } from '@kit.ImageKit'
import { fileIo as fs } from '@kit.CoreFileKit'

///////////
// 变量池 //
//////////
const root_path = getContext().filesDir   // 工作目录

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 主程序 //
//////////
export async function img_save(pixelMap: image.PixelMap, path: string) {

  // 创建图片打包器
  const imagePackerApi = image.createImagePacker()

  // 设置打包参数
  const packOpts: image.PackingOption = {
    format: 'image/png',
    quality: 100
  }

  // 打包 PixelMap 为 PNG 数据
  const packData = await imagePackerApi.packing(pixelMap, packOpts)

  // 写入文件
  console.log(`正在保存 ${path}`)
  const file = fs.openSync(root_path + `/` + path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY)
  fs.writeSync(file.fd, packData)
  fs.closeSync(file)

  // 释放打包器
  imagePackerApi.release()

}