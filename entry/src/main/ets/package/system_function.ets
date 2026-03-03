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

//////////////////
// 导入自创建模块 //
/////////////////

///////////
// 变量池 //
//////////

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