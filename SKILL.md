---
name: chat-completions-image-fallback
description: Build and run a fallback image-generation workflow for relay or proxy APIs that expose image models through OpenAI-compatible /v1/chat/completions instead of /v1/images/generations. Use when the user provides or wants to use a relay API key, BASE_URL, model name, endpoint, or an image model masquerading as a chat model to generate images through a chat-completions endpoint and save returned image URLs or base64 payloads locally.
---

# Chat Completions Image Fallback

## Overview

Use this skill when native `image_gen` is unavailable and a third-party relay exposes image generation through chat completions. The core resource is `scripts/invoke-chat-image-fallback.ps1`, a reusable PowerShell client that posts a prompt to a configurable endpoint and saves the first parseable image from the response.

When this skill is explicitly selected for an image-generation task, do not first try other local image-generation paths, native `/v1/images/generations`, or alternate built-in tooling. Go straight to `scripts/invoke-chat-image-fallback.ps1` unless the user explicitly asks to use a different path.

This skill follows a single-script evolution model. `scripts/invoke-chat-image-fallback.ps1` is the only supported runtime entrypoint. If a new relay/API requires script changes, generate a temporary candidate script first, validate it, then promote it by replacing `scripts/invoke-chat-image-fallback.ps1`. Do not keep multiple long-lived runtime variants in the directory.

## Workflow

1. If this skill is being used for image generation, default directly to the fallback script workflow. Do not first detour through native image tools, local generation helpers, or `/v1/images/generations` unless the user explicitly asks for another path.
2. Collect or infer these four settings:
   - API key: use `OPENAI_API_KEY` by default. Do not ask the user to paste secrets in chat.
   - Base URL: for example `https://www.openclaudecode.cn/v1`.
   - Model: for example `gpt-image-2`.
   - Endpoint: usually `chat/completions`; accept full paths such as `/v1/chat/completions` or full URLs.
   - Before assuming the key is correct, sanity-check whether the relay uses a separate image key or image channel for image models. Do not assume the current `OPENAI_API_KEY` is automatically the right key for image generation.
3. When adapting the script for a new relay/API, generate a temporary candidate script instead of introducing a second permanent runtime script.
4. Validate the candidate before promotion:
   - PowerShell parsing must succeed.
   - A minimal live probe against the target relay/API must succeed.
5. If validation succeeds, replace `scripts/invoke-chat-image-fallback.ps1` with the validated candidate and remove the temporary candidate file. If validation fails, keep the current canonical script unchanged.
6. Save both the raw JSON response and extracted message text next to the final image. If image parsing fails, inspect the raw response and add a parser for the relay's actual return shape.
7. Report the image path, raw response path, prompt, model, endpoint, and whether a URL or base64 payload was parsed.

## Running The Script

Always treat `scripts/invoke-chat-image-fallback.ps1` as the canonical runtime path. Consumers of this skill should call that path directly, even after the script has been adapted for a new relay/API.

Use the bundled script directly, copying it into the workspace only if the user wants a persistent project-local helper. Example:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\chat-completions-image-fallback\scripts\invoke-chat-image-fallback.ps1" `
  -BaseUrl "https://www.openclaudecode.cn/v1" `
  -Model "gpt-image-2" `
  -Endpoint "chat/completions" `
  -Prompt "Create a photorealistic portrait of a beautiful adult Asian woman, clean neutral background, soft studio lighting, no text, no watermark, no logo." `
  -Out "C:\path\to\output.png"
```

If the user has already set environment variables, omit `-ApiKey` and `-BaseUrl`:

```powershell
$env:OPENAI_API_KEY = "relay-key"
$env:OPENAI_BASE_URL = "https://relay.example.com/v1"
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\chat-completions-image-fallback\scripts\invoke-chat-image-fallback.ps1" `
  -Model "gpt-image-2" `
  -Prompt "Create a simple studio product image." `
  -Out ".\output\imagegen\image.png"
```

## Parsing Strategy

The script first serializes the entire response to JSON, then searches all JSON text for:

- `data:image/...;base64,...`
- direct image URLs ending in `.png`, `.jpg`, `.jpeg`, or `.webp`

It also saves:

- `<output-stem>-response.json`
- `<output-stem>-content.txt`

When parsing fails, inspect those files. Common new parser additions:

- `choices[0].message.content` contains Markdown with a nonstandard URL.
- the relay returns `data[0].b64_json`.
- the relay returns `image_url`, `images[0].url`, or a JSON string inside message content.

## Troubleshooting

- If the relay returns `model_not_found` and the error mentions `under group vip_2`, first suspect that the wrong key or channel is being used, not that the model name is wrong.
- Some relays split text and image access across different keys or groups. If an image model fails under a text-oriented group such as `vip_2`, explicitly tell the user that image generation may require a separate image key or image channel.
- If a candidate script for a new relay/API fails either parse validation or the minimal live probe, do not promote it. Keep using the current `scripts/invoke-chat-image-fallback.ps1` until a validated candidate succeeds.

## Safety And Secrets

- Never print the API key.
- Prefer environment variables over command-line `-ApiKey`, because shell history can store arguments.
- Third-party relays receive the prompt and may store content. Mention this when users ask about privacy or sensitive images.
- This fallback is not the same as native Codex image generation and may use separate billing, moderation, quality, and retention behavior.
