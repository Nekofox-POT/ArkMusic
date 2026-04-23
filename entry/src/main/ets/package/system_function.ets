//
// 系统功能调用
//
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////
// 导入第三方库 //
///////////////
import promptAction from '@ohos.promptAction';
import { vibrator } from '@kit.SensorServiceKit';
import { common } from '@kit.AbilityKit';
import { wantAgent } from '@kit.AbilityKit';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import hilog from '@ohos.hilog';

//////////////////
// 导入自创建模块 //
/////////////////

///////////
// 变量池 //
//////////
const DOMAIN = 0x0712; // 自定义域名
const TAG = '[ArkMusic]'; // 自定义标签

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 函数库 //
//////////

//////////
// 通知 //
/////////
export async function notice(msg: string) {
  try {
    promptAction.showToast({ message: msg, duration: 3000 });
  } catch (e) { console.log(`通知失效：${e}`) }
}

/////////////
// 日志记录 //
////////////
export function log(msg: string, level: string = 'info') {
  if (level == 'error') {
    hilog.error(DOMAIN, TAG, msg)
    notice(msg)
    console.error(msg)
  } else {
    hilog.info(DOMAIN, TAG, msg)
    console.info(msg)
  }
}

//////////
// 震动 //
/////////
export async function vib() {
  vibrator.startVibration({ type: 'preset', effectId: 'haptic.common.click', count: 1 }, { usage: 'touch' })
    .catch(() => {
      console.log(`马达震动失败.`)
    })
}

/////////////
// 后台注册 //
////////////
export async function reg_bg_run(context: common.UIAbilityContext) {
  console.log('注册后台任务')
  let wantAgentInfo: wantAgent.WantAgentInfo = {
    wants: [
      {
        bundleName: "com.nekofoxpot.arkmusic",
        abilityName: "EntryAbility"
      }
    ],
    actionType: wantAgent.OperationType.START_ABILITY,
    requestCode: 712,
    actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG],
  };

  try {
    let tmpWantAgent = await wantAgent.getWantAgent(wantAgentInfo);
    await backgroundTaskManager.startBackgroundRunning(context, backgroundTaskManager.BackgroundMode.AUDIO_PLAYBACK, tmpWantAgent);
  } catch (e) {
    console.error(`后台注册失败：${e.message}`);
  }
}