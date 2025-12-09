# macOS App Sandbox 权限配置

## 问题背景
在开发 OSS Browser 应用时遇到网络请求失败的问题：
- 错误信息：`ResponseError: send request failed`
- 根本原因：macOS App Sandbox 默认禁止网络连接

## 解决方案

### 1. 网络连接权限
在 Xcode 项目设置中：
1. 选择 Target -> Signing & Capabilities
2. 确保 App Sandbox 已开启
3. 在 App Sandbox 中勾选：
   - **Outgoing Connections (Client)** - 允许应用发起网络连接

### 2. 文件访问权限（后续需要）
当实现文件上传下载功能时，需要添加：
- **Downloads Folder** - 访问下载文件夹
- **Downloads** - 允许下载文件到指定位置
- **Selected Files** - 通过文件选择器访问用户指定的文件

### 3. 其他可能需要的权限
- **Incoming Connections (Server)** - 如果需要本地服务器功能
- **Hardware** - 如果需要访问 USB 设备等

## 开发建议
1. **开发阶段调试**：遇到网络或文件访问问题时，首先检查沙盒权限
2. **最小权限原则**：只开启必要的权限，提高安全性
3. **错误处理**：在代码中添加权限相关的错误提示，引导用户检查设置
4. **测试清单**：
   - 网络连接测试
   - 文件读取测试
   - 文件写入测试

## 相关文档
- [Apple App Sandbox Documentation](https://developer.apple.com/documentation/security/app_sandbox)
- [App Sandbox Design Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/AppSandboxDesignGuide/AboutAppSandbox/AboutAppSandbox.html)