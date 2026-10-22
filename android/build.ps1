param(
  [string]$Jdk = $env:JAVA_HOME,
  [string]$Sdk = $env:ANDROID_HOME,
  [string]$Version = "1.0"
)

# 方块战场 安卓包构建脚本（不依赖 Gradle）
# 依赖：JDK 17、Android SDK（platforms;android-34、build-tools;34.0.0）
# 用法：pwsh -File build.ps1 -Jdk "C:\jdk-17" -Sdk "C:\android-sdk"

$ErrorActionPreference = "Stop"

if (-not $Jdk) { throw "缺少 JDK 路径，请用 -Jdk 指定，或设置 JAVA_HOME" }
if (-not $Sdk) { throw "缺少 Android SDK 路径，请用 -Sdk 指定，或设置 ANDROID_HOME" }

$root = $PSScriptRoot                # android/
$repo = Split-Path $root -Parent     # 仓库根目录
$BT = Join-Path $Sdk "build-tools\34.0.0"
$AJ = Join-Path $Sdk "platforms\android-34\android.jar"
$OUT = Join-Path $repo "build"
$ASSETS = Join-Path $root "assets"

$env:JAVA_HOME = $Jdk
$env:PATH = (Join-Path $Jdk "bin") + ";" + $env:PATH

Write-Host "[1/5] 准备资源"
if (-not (Test-Path (Join-Path $BT "aapt2.exe"))) { throw "找不到 aapt2，检查 -Sdk 与 build-tools 版本" }
if (-not (Test-Path $AJ)) { throw "找不到 android.jar，检查 platforms;android-34" }
New-Item -ItemType Directory -Force -Path $ASSETS | Out-Null
Copy-Item (Join-Path $repo "index.html") (Join-Path $ASSETS "index.html") -Force

Write-Host "[2/5] 更新版本号"
$enc = New-Object Text.UTF8Encoding($false)
$mfPath = Join-Path $root "AndroidManifest.xml"
$mf = [IO.File]::ReadAllText($mfPath, [Text.Encoding]::UTF8)
$mf = $mf -replace 'android:versionName="[^"]*"', "android:versionName=`"$Version`""
[IO.File]::WriteAllText($mfPath, $mf, $enc)

Remove-Item $OUT -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $OUT | Out-Null

Push-Location $root
try {
  Write-Host "[3/5] 编译资源"
  & (Join-Path $BT "aapt2.exe") compile --dir res -o (Join-Path $OUT "res.zip")
  if ($LASTEXITCODE -ne 0) { throw "aapt2 compile 失败" }

  & (Join-Path $BT "aapt2.exe") link -o (Join-Path $OUT "app.unsigned.apk") -I $AJ `
    --manifest AndroidManifest.xml -A assets --min-sdk-version 21 --target-sdk-version 34 `
    (Join-Path $OUT "res.zip")
  if ($LASTEXITCODE -ne 0) { throw "aapt2 link 失败" }

  Write-Host "[4/5] 编译 Java 并转 dex"
  New-Item -ItemType Directory -Force -Path (Join-Path $OUT "classes") | Out-Null
  & (Join-Path $Jdk "bin\javac.exe") -source 8 -target 8 -bootclasspath $AJ -encoding UTF-8 `
    -d (Join-Path $OUT "classes") "java\com\dsh\voxelarena\MainActivity.java"
  if ($LASTEXITCODE -ne 0) { throw "javac 失败" }

  New-Item -ItemType Directory -Force -Path (Join-Path $OUT "dex") | Out-Null
  $classes = Get-ChildItem (Join-Path $OUT "classes\com\dsh\voxelarena") -Filter *.class |
    ForEach-Object { $_.FullName }
  & (Join-Path $BT "d8.bat") --min-api 21 --lib $AJ --output (Join-Path $OUT "dex") $classes
  if ($LASTEXITCODE -ne 0) { throw "d8 失败" }
} finally {
  Pop-Location
}

Write-Host "[5/5] 打包并签名"
$py = (Get-Command python -ErrorAction SilentlyContinue)
$merge = @"
import zipfile, shutil, os
out = r'$OUT'
shutil.copyfile(os.path.join(out, 'app.unsigned.apk'), os.path.join(out, 'app.withdex.apk'))
with zipfile.ZipFile(os.path.join(out, 'app.withdex.apk'), 'a', zipfile.ZIP_DEFLATED) as z:
    z.write(os.path.join(out, 'dex', 'classes.dex'), 'classes.dex')
"@
$mergePath = Join-Path $OUT "merge.py"
Set-Content -Path $mergePath -Value $merge -Encoding UTF8
if ($py) { & $py.Source $mergePath }
else {
  # 没有 python 时用 jar 追加（需要 jar 在 PATH）
  Copy-Item (Join-Path $OUT "app.unsigned.apk") (Join-Path $OUT "app.withdex.apk") -Force
  Push-Location (Join-Path $OUT "dex")
  try { & (Join-Path $Jdk "bin\jar.exe") uf (Join-Path $OUT "app.withdex.apk") classes.dex } finally { Pop-Location }
}

& (Join-Path $BT "zipalign.exe") -f 4 (Join-Path $OUT "app.withdex.apk") (Join-Path $OUT "app.aligned.apk")

$ks = Join-Path $OUT "release.keystore"
if (-not (Test-Path $ks)) {
  & (Join-Path $Jdk "bin\keytool.exe") -genkeypair -keystore $ks -alias voxelarena `
    -keyalg RSA -keysize 2048 -validity 10000 -storepass voxelarena -keypass voxelarena `
    -dname "CN=Voxel Arena, OU=Game, O=DSH, L=NA, ST=NA, C=CN"
}

& (Join-Path $BT "apksigner.bat") sign --ks $ks --ks-key-alias voxelarena `
  --ks-pass pass:voxelarena --key-pass pass:voxelarena `
  --out (Join-Path $OUT "voxel-arena.apk") (Join-Path $OUT "app.aligned.apk")

New-Item -ItemType Directory -Force -Path (Join-Path $repo "dist") | Out-Null
Copy-Item (Join-Path $OUT "voxel-arena.apk") (Join-Path $repo "dist\voxel-arena.apk") -Force

$kb = [math]::Round((Get-Item (Join-Path $repo "dist\voxel-arena.apk")).Length / 1KB, 1)
Write-Host "完成：dist\voxel-arena.apk ($kb KB)"
