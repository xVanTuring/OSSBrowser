
## 参考文档
@docs/project-architecture.md
@docs/aliyun-oss-doc/basic.md
@docs/macos-sandbox-notes.md
@docs/aliyun-oss-doc/multi-part-upload.md
## 需求
- 每次修改代码后都需要检测是否有编译错误
- 子组件放单独的文件中
- 重构设计时删除不需要的旧代码
- 方案不确定时，或者方案执行错误时，要停下来问我
- 当我提出需求时，你可以向我提问来细化需求点。

## BUG
1. 目前的分片下载是假的(暂不处理)，Ailyun Sdk 的 getObjectToFile 没有任何分片下载处理

## TODO
1. 文件上传不支持取消