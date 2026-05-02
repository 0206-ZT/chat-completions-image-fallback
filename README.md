# Chat Completions Image Fallback

Generate images through OpenAI-compatible `chat/completions` relay APIs when native image generation is unavailable or when a provider exposes image models through a chat endpoint instead of `/v1/images/generations`.

当原生图片生成不可用，或者第三方中转/代理把图片模型暴露在 `chat/completions` 而不是 `/v1/images/generations` 时，这个 skill 提供一个可复用的回退方案。

## What This Skill Does

- Wraps a reusable PowerShell client for relay/proxy image generation.
- Accepts a prompt, model name, base URL, and endpoint.
- Saves the raw response JSON, extracted content text, and the first parseable image.
- Uses a single evolving runtime script: `scripts/invoke-chat-image-fallback.ps1`.

## Recent Updates

- The repo now follows a strict single-script model: `scripts/invoke-chat-image-fallback.ps1` is the only supported runtime entrypoint.
- If a new relay/API needs script changes, generate a temporary candidate first and promote it only after a PowerShell parse check and a minimal live probe succeed.
- The script now prefers `OPENAI_IMAGE_API_KEY` before `OPENAI_API_KEY`, so image-specific credentials can override text-channel defaults.
- Relay errors such as `model_not_found` under `vip_2` are now documented as likely key/channel mismatches rather than simple model-name mistakes.

## 这个 Skill 能做什么

- 提供一个可复用的 PowerShell 调用脚本，用于中转/代理图片生成。
- 接收 prompt、模型名、Base URL 和 endpoint。
- 自动保存原始 JSON 响应、提取出的文本内容，以及第一个可解析图片结果。

## When To Use It

Use this skill when:

- native Codex/OpenAI image tooling is unavailable
- you explicitly want a relay or proxy workflow
- the provider exposes image generation through `chat/completions`
- when this skill is explicitly chosen for image generation, prefer going straight to the fallback script instead of first trying other local generation paths

## 适用场景

适合以下情况：

- 当前环境没有原生图片生成能力
- 你明确要走 relay/proxy 工作流
- 服务商把图片生成挂在 `chat/completions` 接口下

## Repository Contents

```text
.
|-- SKILL.md
|-- README.md
|-- LICENSE
|-- .gitignore
|-- agents/
|   `-- openai.yaml
`-- scripts/
    `-- invoke-chat-image-fallback.ps1
```

## Single-Script Policy

This repository uses a single evolving runtime script: `scripts/invoke-chat-image-fallback.ps1`.

When a new relay/API needs a script update:

- generate a temporary candidate script first
- validate it with a PowerShell parse check
- validate it with a minimal live probe against the target relay/API
- only then replace `scripts/invoke-chat-image-fallback.ps1`
- remove the temporary candidate after promotion

Old runtime variants are not kept as sibling scripts in the working tree. Git history is the rollback path.

## Script Interface

The bundled script preserves this runtime interface:

- `-ApiKey`
- `-BaseUrl`
- `-Model`
- `-Endpoint`
- `-Prompt`
- `-Out`
- `-TimeoutSec`

## Required Inputs

- API key: prefers `OPENAI_IMAGE_API_KEY`, then falls back to `OPENAI_API_KEY`
- Base URL: defaults to `OPENAI_BASE_URL`
- Model: for example `gpt-image-2`
- Endpoint: usually `chat/completions`
- Prompt: the image generation prompt

## 所需输入

- API Key：默认读取 `OPENAI_API_KEY`
- Base URL：默认读取 `OPENAI_BASE_URL`
- Model：例如 `gpt-image-2`
- Endpoint：通常是 `chat/completions`
- Prompt：图片生成提示词

## Example Usage

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\chat-completions-image-fallback\scripts\invoke-chat-image-fallback.ps1" `
  -BaseUrl "https://www.openclaudecode.cn/v1" `
  -Model "gpt-image-2" `
  -Endpoint "chat/completions" `
  -Prompt "Create a photorealistic portrait of a beautiful adult Asian woman, clean neutral background, soft studio lighting, no text, no watermark, no logo." `
  -Out "C:\path\to\output.png"
```

If your environment variables are already set:

```powershell
$env:OPENAI_API_KEY = "relay-key"
$env:OPENAI_BASE_URL = "https://relay.example.com/v1"

powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\chat-completions-image-fallback\scripts\invoke-chat-image-fallback.ps1" `
  -Model "gpt-image-2" `
  -Prompt "Create a simple studio product image." `
  -Out ".\output\imagegen\image.png"
```

## Outputs

For an output path like `image.png`, the script also saves:

- `image-response.json`
- `image-content.txt`

The script tries to parse:

- `data:image/...;base64,...`
- `b64_json`
- direct image URLs ending in `.png`, `.jpg`, `.jpeg`, or `.webp`

## Troubleshooting

- If you explicitly use this skill for image generation, default directly to `scripts/invoke-chat-image-fallback.ps1` instead of first trying other local generation paths.
- Some relays require a separate image key or image channel for image models. Do not assume the current `OPENAI_API_KEY` is automatically the correct key for image generation.
- If the relay returns `model_not_found` and mentions `under group vip_2`, first suspect the wrong key or channel rather than a wrong model name.
- If you adapt the script for a new relay/API, only promote the new version after it passes both a parse check and a minimal live probe. Until then, keep using the current canonical script path.

## 输出结果

如果输出文件是 `image.png`，脚本还会额外保存：

- `image-response.json`
- `image-content.txt`

脚本会尝试解析：

- `data:image/...;base64,...`
- `b64_json`
- 直接图片 URL（`.png`、`.jpg`、`.jpeg`、`.webp`）

## Install In Codex

Clone or copy this repository into your Codex skills directory:

```powershell
git clone git@github.com:0206-ZT/chat-completions-image-fallback.git "$env:USERPROFILE\.codex\skills\chat-completions-image-fallback"
```

Or copy the files manually so the final layout looks like:

```text
%USERPROFILE%\.codex\skills\chat-completions-image-fallback\
```

## 在 Codex 中安装

可以直接 clone 到 Codex skills 目录：

```powershell
git clone git@github.com:0206-ZT/chat-completions-image-fallback.git "$env:USERPROFILE\.codex\skills\chat-completions-image-fallback"
```

或者手动复制到：

```text
%USERPROFILE%\.codex\skills\chat-completions-image-fallback\
```

## Privacy And Safety

- Never expose your API key in chat logs or screenshots.
- Prefer environment variables over passing `-ApiKey` on the command line.
- Third-party relays receive your prompt and may store request content.
- Billing, moderation, retention, and output quality may differ from native OpenAI or Codex image generation.

## 隐私与安全

- 不要在聊天记录或截图中暴露 API Key。
- 优先使用环境变量，而不是命令行直接传 `-ApiKey`。
- 第三方 relay 会接收你的 prompt，也可能保留请求内容。
- 计费、审核、保留策略和输出质量可能与原生 OpenAI/Codex 图片生成不同。

## License

MIT
