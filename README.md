# 움성 추출기

ffmpeg로 영상에서 오디오만 빠르게 뽑아내는 macOS 앱입니다.

영상 파일이나 폴더를 끌어다 놓거나 `파일 추가`(⌘O)로 고른 다음 `음성 추출`을 누르면 됩니다. 결과물은 원본 영상과 같은 폴더에 저장됩니다.

- 지원 형식: `mp4` `mov` `mkv` `avi` `webm` `m4v` `flv` `wmv` `mts` `m2ts`
- 폴더를 넣으면 그 폴더 바로 안에 있는 영상만 추가합니다. 하위 폴더는 포함하지 않습니다.
- 추출 중에는 버튼이 `취소`로 바뀌어 언제든 멈출 수 있고, 끝나면 Finder에서 결과 파일을 보여줍니다.

## 추출 형식

- 전사용 MP3: 16kHz, 모노, 32kbps. Whisper 음성 전사에 적합
- 고음질 MP3: libmp3lame `-q:a 0`
- WAV: 무손실 PCM 오디오
- 원본 복사: 재인코딩 없이 오디오 스트림을 M4A에 복사

같은 이름의 파일이 이미 있으면 `파일명 2.mp3`처럼 새 이름으로 저장하며 원본을 덮어쓰지 않습니다.

## 단축키

다른 맥 앱들처럼 macOS 기본 단축키를 사용할 수 있습니다.

## 요구 사항

- macOS 13 이상, Apple Silicon
- Xcode Command Line Tools (`xcode-select --install`)
- ffmpeg: `brew install ffmpeg`. 앱은 `/opt/homebrew/bin/ffmpeg`, `/usr/local/bin/ffmpeg`, `/usr/bin/ffmpeg` 순서로 찾습니다.

## 빌드

```bash
./build.sh
```

빌드하면 `/Users/kwon/Applications/AudioExtractor.app`에 설치됩니다. Finder와 앱 제목에서는 `움성 추출기`로 표시됩니다.

## 앱 아이콘

`Resources/AppIcon.png`(1024×1024)를 빌드할 때 `AppIcon.icns`로 변환해 앱에 넣습니다. 아이콘을 바꾸려면 이 PNG를 교체하고 다시 빌드하면 됩니다.

macOS 26부터는 가장자리가 투명한 아이콘에 회색 판이 덧씌워지므로, 둥근 모서리 없이 정사각형을 꽉 채운 이미지를 써야 합니다. 모서리는 시스템이 알아서 둥글게 잘라 줍니다.

Dock에 예전 아이콘이 남아 있으면 `killall Dock`으로 새로 고칠 수 있습니다.

## 구조

```
Sources/main.swift      앱 전체 코드 (AppKit)
Info.plist              번들 정보
Resources/AppIcon.png   앱 아이콘 원본
build.sh                컴파일 · 아이콘 생성 · 서명 · 설치
```
