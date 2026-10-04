# 움성 추출기

영상 파일을 끌어다 놓거나 `파일 추가`로 고른 다음 `음성 추출`을 누르면 됩니다. 결과물은 원본 영상과 같은 폴더에 저장됩니다.

## 추출 형식

- 전사용 MP3: 16kHz, 모노, 32kbps. Whisper 음성 전사에 적합
- 고음질 MP3: libmp3lame `-q:a 0`
- WAV: 무손실 PCM 오디오
- 원본 복사: 재인코딩 없이 오디오 스트림을 M4A에 복사

같은 이름의 파일이 이미 있으면 `파일명 2.mp3`처럼 새 이름으로 저장하며 원본을 덮어쓰지 않습니다.

## 다시 빌드

```bash
./build.sh
```

빌드하면 `/Users/kwon/Applications/AudioExtractor.app`에 설치됩니다. Finder와 앱 제목에서는 `움성 추출기`로 표시됩니다.

이 앱은 `/opt/homebrew/bin/ffmpeg` 또는 `/usr/local/bin/ffmpeg`가 설치되어 있어야 합니다.
