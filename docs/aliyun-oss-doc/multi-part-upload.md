## 分片上传流程

分片上传（Multipart Upload）分为以下三个步骤：

1. 初始化一个分片上传事件。
调用client.initiateMultipartUpload方法返回OSS创建的全局唯一的uploadId。

2. 上传分片。
调用client.uploadPart方法上传分片数据。
> 说明
> 对于同一个uploadId，分片号（PartNumber）标识了该分片在整个文件内的相对位置。如果使用同一个分片号上传了新的数据，则OSS上该分片已有的数据将会被覆盖。
> OSS将收到的分片数据的MD5值放在ETag头内返回给用户。
> OSS计算上传数据的MD5值，并与SDK计算的MD5值比较，如果不一致则返回InvalidDigest错误码。

3. 完成分片上传。
所有分片上传完成后，调用client.completeMultipartUpload方法将所有分片合并成完整的文件。

## 示例代码

```swift
import AlibabaCloudOSS
import Foundation

@main
struct Main {
    static func main() async {
        do {
            // 填写Bucket所在地域。以华东1（杭州）为例，Region填写为cn-hangzhou。
            let region = "cn-hangzhou"
            // 填写Bucket名称。
            let bucket = "yourBucketName"
            // 填写对象名称（如：my-object.txt）。
            let key = "yourKey"
            // 填写本地文件路径（如：/path/to/file.txt）。
            let filePath = "/path/to/your/file.txt"
            // 设置分片大小（单位：字节）。例如：5MB = 5 * 1024 * 1024
            let partSize = 5 * 1024 * 1024
            // 可选项，指定访问OSS服务的域名。以华东1（杭州）为例，Endpoint填写为https://oss-cn-hangzhou.aliyuncs.com
            let endpoint: String? = nil

            // 从环境变量加载凭证（需提前设置 OSS_ACCESS_KEY_ID 和 OSS_ACCESS_KEY_SECRET）
            let credentialsProvider = EnvironmentCredentialsProvider()

            // 配置OSS客户端参数
            let config = Configuration.default()
                .withRegion(region) // 设置区域
                .withCredentialsProvider(credentialsProvider) // 设置凭证
                
            // 设置Endpoint
            if let endpoint = endpoint {
                config.withEndpoint(endpoint)
            }

            // 创建OSS客户端实例
            let client = Client(config)
            
            // 1. 初始化分片上传
            let initResult = try await client.initiateMultipartUpload(
                InitiateMultipartUploadRequest(
                    bucket: bucket,
                    key: key
                )
            )
            let uploadId = initResult.uploadId // 获取分片上传ID

            // 2. 获取文件属性并计算分片数量
            let attribute = try FileManager.default.attributesOfItem(atPath: filePath)
            guard let fileSize = attribute[FileAttributeKey.size] as? Int64 else {
                throw ClientError(code: "error", message: "Can't get file size")
            }

            var partCount = Int(fileSize / Int64(partSize))
            if fileSize % Int64(partSize) > 0 { partCount += 1 } // 处理不足整分片的情况

            // 3. 打开文件并逐片上传
            let fileHandle = FileHandle(forReadingAtPath: filePath)
            var parts: [UploadPart] = [] // 存储分片ETag和编号
            
            for partNumber in 1...partCount {
                // 定位到当前分片的起始位置
                fileHandle?.seek(toFileOffset: UInt64((partNumber - 1) * partSize))
                
                // 读取当前分片数据
                guard let partData = fileHandle?.readData(ofLength: partSize) else {
                    throw ClientError(code: "error", message: "Can't get file data")
                }
                
                // 执行分片上传
                let uploadPartResult = try await client.uploadPart(
                    UploadPartRequest(
                        bucket: bucket,
                        key: key,
                        partNumber: partNumber,
                        uploadId: uploadId,
                        body: .data(partData)
                    )
                )
                
                // 保存分片ETag和编号
                parts.append(
                    UploadPart(
                        etag: uploadPartResult.etag,
                        partNumber: partNumber
                    )
                )
            }

            // 4. 完成分片上传
            let _ = try await client.completeMultipartUpload(
                CompleteMultipartUploadRequest(
                    bucket: bucket,
                    key: key,
                    uploadId: uploadId,
                    completeMultipartUpload: CompleteMultipartUpload(parts: parts)
                )
            )
            print("分片上传完成！")

        } catch {
            // 捕获并处理异常
            print("error:\n\(error)")
        }
    }
}

```

## 取消分片上传事件
如果您需要取消分片上传事件的操作，您需要在调用InitiateMultipartUpload完成初始化分片之后获取uploadId，然后使用获取的uploadId调用abortMultipartUpload方法来取消分片上传事件。当一个分片上传事件被取消后，无法再使用该uploadId进行任何操作，已上传的分片数据会被删除。取消分片上传事件的示例代码如下。

```swift
import AlibabaCloudOSS
import Foundation

@main
struct Main {
    static func main() async {
        do {
            // 填写Bucket所在地域。以华东1（杭州）为例，Region填写为cn-hangzhou。
            let region = "cn-hangzhou"
            // 填写Bucket名称。
            let bucket = "yourBucketName"
            // 可选项，指定访问OSS服务的域名。以华东1（杭州）为例，Endpoint填写为https://oss-cn-hangzhou.aliyuncs.com
            let endpoint: String? = nil
            // 填写对象名称（如：my-object.txt）。
            let key = "yourKey"
            // 填写分块上传ID（从InitiateMultipartUpload响应中获取）。
            let uploadId = "yourUploadId"

            // 从环境变量加载凭证（需提前设置 OSS_ACCESS_KEY_ID 和 OSS_ACCESS_KEY_SECRET）
            let credentialsProvider = EnvironmentCredentialsProvider()

            // 配置OSS客户端参数
            let config = Configuration.default()
                .withRegion(region) // 设置区域
                .withCredentialsProvider(credentialsProvider) // 设置凭证
                
            // 设置Endpoint
            if let endpoint = endpoint {
                config.withEndpoint(endpoint)
            }

            // 创建OSS客户端实例
            let client = Client(config)

            // 执行终止分块上传操作
            let result = try await client.abortMultipartUpload(
                AbortMultipartUploadRequest(
                    bucket: bucket,
                    key: key,
                    uploadId: uploadId
                )
            )

            // 输出操作结果
            print("result:\n\(result)")

        } catch {
            // 捕获并处理异常
            print("error:\n\(error)")
        }
    }
}

```