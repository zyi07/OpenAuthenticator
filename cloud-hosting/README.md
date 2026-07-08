# Tool_2FA 云托管页面

`public/user-agreement.html` 是可直接部署到 AppGallery Connect 云托管的用户协议页面，也已在应用内作为独立用户协议链接使用。

当前仓库独立链接：

https://gitcode.com/mroble/Tool_2FA/raw/main/cloud-hosting/public/user-agreement.html

1. 在 AppGallery Connect 为当前项目开通“云托管”。
2. 创建站点并将 `public` 目录作为静态网站根目录上传或部署。
3. 确认生成的 HTTPS 地址可以公开访问，例如 `https://<站点域名>/user-agreement.html`。
4. 在 AppGallery Connect 的标准化隐私声明服务中，将该地址配置为“用户协议”链接并发布。
5. 将隐私声明配置为“隐私声明”链接并发布。

应用通过 `privacyManager.getAppPrivacyMgmtInfo()` 获取已发布链接，因此站点域名变化时无需重新打包应用。
