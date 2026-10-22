# 方块战场 · Voxel Arena

一个横屏手机小游戏：伪 3D 等距视角（Minecraft 风格的方块世界），虚拟摇杆 + 攻击键 + 冲刺键，近战/远程双武器切换，无尽刷怪刷分。

纯 HTML + Canvas 2D 实现，**零依赖、零网络请求**，单文件即可运行；安卓安装包用原生 WebView 外壳打包，离线可玩。

## 直接下载

- 安装包：`dist/方块战场.apk`（约 65 KB，安卓 5.0 以上）
- 网页版：`index.html`，手机浏览器直接打开即可玩

也可以在 Releases 页面下载。

## 玩法

| 操作 | 说明 |
|---|---|
| 左下摇杆 | 八方向移动（屏幕方向速度一致） |
| 右下大圆键 | 攻击（按住连发） |
| 右下小圆键 | 切换近战 / 远程武器 |
| 双箭头键 | 冲刺，消耗耐力条，满耐力可跑 7 秒，回满 14 秒 |
| 踩上箱子 | 自动开箱，出武器 / 血包 / 护甲 |
| 踩上掉落物 | 自动拾取 |

- 近战：贴脸扇形劈砍，高伤害、攻击范围随等级成长
- 远程：直线弹丸，低伤害、可风筝
- 护甲：抵挡一定比例伤害，可抵挡固定次数，用光即碎
- 升级：击杀累积到阈值自动升级，血量上限 ×1.3、射程 +0.15、攻速 +0.6 次/秒

## 目录结构

```
index.html          游戏本体（单文件，浏览器可直接运行）
dist/               已构建的安卓安装包
android/            安卓外壳工程（原生 WebView + 全屏横屏）
  AndroidManifest.xml
  java/com/dsh/voxelarena/MainActivity.java
  res/              图标与字符串
  build.ps1         无 Gradle 打包脚本（aapt2 + javac + d8 + apksigner）
```

## 重新构建安卓包

需要 JDK 17 与 Android SDK（platform 34 + build-tools 34.0.0）：

```powershell
pwsh -File android/build.ps1 -Jdk "C:\path\to\jdk-17" -Sdk "C:\path\to\android-sdk"
```

产物：`dist/方块战场.apk`

## 说明

- 自签名证书，仅用于自用与朋友间安装；上架应用商店需要正式签名与资质
- 游戏进度（最高分）保存在设备本地
