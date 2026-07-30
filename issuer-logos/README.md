# 发行方 Logo 维护

此目录是 OpenAuthenticator 的远程 Logo 保底源。应用仍会优先使用内置 Logo 和 Simple Icons；只有现有逻辑无法获取 Logo 时，才读取这里的清单。

## 新增品牌

1. 将 SVG 放入 `issuer-logos/logos/`。
2. 在 `manifest.json` 的 `logos` 数组中新增一项。
3. 提交并推送到 GitCode 的 `main` 分支。

```json
{
  "slug": "example",
  "aliases": ["example", "示例品牌", "example.com"],
  "brand": "logos/example.svg",
  "light": "logos/example-light.svg",
  "dark": "logos/example-dark.svg",
  "revision": "1"
}
```

- `slug`：品牌唯一标识，仅使用小写字母、数字、下划线或短横线。
- `aliases`：发行方或令牌名称中可能出现的关键词，不区分大小写。
- `brand`：品牌色 SVG，必填。
- `light`：浅色主题 SVG，可选；未填写时使用 `brand`。
- `dark`：深色主题 SVG，可选；未填写时使用 `brand`。
- `revision`：图片版本。替换任一 SVG 后必须递增，应用才会切换到新的缓存文件。

文件路径必须相对于 `issuer-logos/`，只能包含英文字母、数字、`_`、`-`、`.` 和 `/`。单个清单或 SVG 文件应小于 1 MB。

远程清单会在内存中缓存 10 分钟，并保存到应用私有目录供离线使用。首次新增一个此前无法识别的品牌后，应用会在下次 Logo 补全时自动获取；重新打开应用可立即触发补全。
