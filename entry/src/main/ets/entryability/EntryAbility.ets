import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });

    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        console.error('加载失败: ' + JSON.stringify(err));
        return;
      }

      let windowClass: window.Window = windowStage.getMainWindowSync();

      // 1. 设置全屏布局
      windowClass.setWindowLayoutFullScreen(true)
        .then(() => {
          console.info('沉浸式布局已开启');
          // 2. 设置状态栏透明 + 文字颜色
          let sysBarProps: window.SystemBarProperties = {
            statusBarColor: '#00000000',       // 状态栏背景透明
            statusBarContentColor: '#FFFFFF',  // 文字白色（适合深色背景）
            // 如果背景是浅色（如白色），这里改为 '#000000'
          };
          return windowClass.setWindowSystemBarProperties(sysBarProps);
        })
        .then(() => {
          console.info('状态栏颜色已设置');
        })
        .catch((err: BusinessError) => {
          console.error('设置失败: ' + JSON.stringify(err));
        });
    });

  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}