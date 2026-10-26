# Supabase Database Security Review — 2026-10-23

项目：`dvakrwalnqpcmgirmlct`，页面标示 `main / PRODUCTION`。

## 审查范围与证据

已通过用户当前登录的 Dashboard SQL Editor 执行只读元数据查询，并完整读取结果；不是根据本地代码推测线上状态。统一快照返回 19 个检查类别，原始导出见同目录 `2026-10-23_database_metadata_snapshot.csv`。

读取范围：表/列、约束、RLS、授权、触发器及函数源码、枚举、视图、存储桶配置、角色属性/继承、默认权限、schema 权限、有效表权限、索引、Realtime 发布和迁移登记表是否存在。

没有读取用户/预约/聊天/照片记录，没有下载照片，没有读取密钥、密码、Auth 会话或用户清单；没有调用业务 RPC、插入测试记录、执行迁移、修改权限或创建项目。SQL Editor 的查询草稿/执行日志可能正常留在平台内，但业务结构与记录没有因本次审查被改变。

**结论：本轮静态数据库配置审查完成；真实用户权限验收、线上并发/Storage/JWT 测试和上线批准尚未完成。** 配置判断通过不等于实际行为已经测试通过。

## 逐项结果、逻辑评价与建议

| 编号 | 检查与线上证据 | 判断 / 业务逻辑 | 建议与后续验证 |
| --- | --- | --- | --- |
| DB01 | public 有 10 张业务表；58 个列定义；40 个约束；10 个自定义触发器 | 有完整的早期结构，不是空数据库 | 保留已有结构；先建立 Staging 再确定升级路径，不能从 001 在当前项目重复建表 |
| DB02 | 10 张 public 表全部启用 RLS；force_rls=false | RLS 基础正确；不强制表所有者遵守 RLS 不等于普通客户端能绕过 | 保留；使用普通用户验证，不用 postgres 的查看结果当作权限验收 |
| DB03 | anon/authenticated 对全部 10 表都有 SELECT/INSERT/UPDATE/DELETE/REFERENCES/TRIGGER/TRUNCATE；有效权限查询亦确认 | 过度授权不是只有 booking 一张表的问题。RLS 会限制常规行操作，但不能替代最小权限；这些结果不等于存在可直接调用的清表 API | 高优先级：明确各表和客户端实际需要的操作，撤销多余授权，保留必要 RPC；不要删除 anon 角色或关闭 RLS |
| DB04 | postgres、supabase_admin 在 public 的表/函数/序列默认 ACL 较宽 | 只修现有表不够，未来创建对象仍可能继承宽授权 | 按实际创建对象的 owner 审查默认权限及 PUBLIC EXECUTE；不要随意撤销数据库 CONNECT 或整个 public schema USAGE |
| DB05 | anon/authenticated 非超级用户、无 BYPASSRLS、无 CREATEROLE；无直接角色继承记录；public USAGE=true、CREATE=false | 客户端角色边界的静态配置合理；service_role 有 BYPASSRLS 属服务器高权限角色 | 保留；service_role 必须留在可信服务器。此次未读取任何真实密钥，也没有重新完成全量客户端密钥审计 |
| DB06 | booking SELECT 限 owner_id 或 provider_id 等于 auth.uid() | 符合预约参与者读取原则 | 保留；仍需 Owner A/Owner B/Provider A/Provider B/未登录的真实账号隔离测试 |
| DB07 | booking UPDATE RLS 限 Owner；更新触发器禁止改身份、Provider、房产、类型、时间、状态、created_at，且只允许原状态 Pending | 并非任意 UPDATE。当前 10 个字段中，instructions 是未被该触发器禁止的可编辑字段；当前根本没有价格列，不应误报为已证实价格篡改漏洞 | 保留关键字段保护；评估 instructions 的列级授权、长度限制及受控操作。后续添加报价/重试 ID 必须同步增加保护 |
| DB08 | booking INSERT 允许当前 Owner 为自己的房产创建 Pending；未经过统一创建 RPC；无 client_request_id | 创建规则不足：没有完整统一的未来时间、审批、服务支持、时长及报价校验；网络重试无稳定去重 ID | 高优先级：对齐本地 006/009 的受控创建入口及稳定 token；所有新请求必须走同一服务器校验，Pending 仍不占容量 |
| DB09 | accept_pending_booking：仅分配 Provider 可执行；锁 Provider 和 Booking；检查未来时间、租赁清洁窗口、可用时段、服务类型和冲突 | 原子接受和参与者检查已有设计；但当前函数未检查 approval_status，也没有新版时长/报价规则 | 保留事务/锁/冲突检查，补审批和最终定价/时长规则。静态源码不代替真实并发测试 |
| DB10 | exclusion constraint 只阻止同 Provider 的 Accepted/In Progress 半开区间重叠；Pending 不参与 | 与权威业务规则一致；相邻结束/开始时间可以接续，不代表已验证路程可行 | 保留；在 Staging 实测两次并发接受，只能有一个成功 |
| DB11 | 状态枚举只有 Pending、Accepted、In Progress、Completed、Declined、Cancelled | 符合单一生命周期；没有旧 Scheduled/Delayed/Rescheduled | 保留，不新增重复状态来表达预约日期或备注 |
| DB12 | transition_booking 校验参与者/前后状态并在同一次调用记录 history；只有 Pending 可 Cancelled | 有效的基础 FSM；但与本地 003 已同意的 Accepted 开始前双方取消规则不一致，未要求取消原因 | 应与现有取消业务规则统一部署，不是再设计一套；测试拒绝进行中/已完成取消，以及状态与历史原子一致 |
| DB13 | Completed 需要两条照片路径、remarks 和 Storage 对象存在；证据可直接 INSERT/UPDATE，Accepted 也能写 | 只证明路径/对象存在，不证明照片已解码验证；没有新版受控上传与 completion attestation | 高优先级：协调 014/018 与验证函数一起部署；不能只替换客户端或只关闭上传。保留旧证据前先定历史资料方案 |
| DB14 | cleaning-evidence public=false、5 MiB、JPEG/PNG；Storage policy 检查 booking 文件夹和参与者 | 私有桶/大小限制正确；当前读取范围是整个参与预约文件夹，不仅当前附加照片，且文件名/MIME 不是真实内容验证 | 保留私有配置；缩小为当前已验证附加对象，关闭客户端直接发布，服务器实际解码/去元数据/重编码后才附加 |
| DB15 | user_account SELECT/UPDATE 限本人；触发器禁止客户端改 user_id、role、email | 更新时有防角色篡改保护，并非可自行把账号改成管理员；角色枚举仅 Owner/Provider | 保留；自助注册可选择角色是产品规则，不能据此断言有任意管理员提升；未来新增角色须重新审查注册入口 |
| DB16 | provider_profile SELECT 对所有 authenticated 为 true；原表含 service_origin_address | 明确的资料最小化问题：当前规则允许任意已登录角色读取原始 Provider 行，含精确起点与未筛选审批状态；此次未实际下载用户资料 | 高优先级：对齐 005，原表本人可读，目录用明确安全字段和 approved 过滤；匹配内部可使用起点但不返回原始地址 |
| DB17 | Provider 的 approval_status/rating_average/completed_job_count 有 INSERT/UPDATE 触发器保护 | Provider 不能通过普通写入自批、改平均分或完成数；这是正确的服务器侧保护 | 保留；评分应来自已完成预约的 Owner 评价并由服务器重算，当前 booking_review 表/RPC 尚不存在 |
| DB18 | capability/weekly_slot/unavailable_date 全部已登录用户可 SELECT；Provider 本人可直接改能力；时段只有顺序/唯一约束 | 完整计划/不可用日期暴露过多；目前无两小时最短时段或时段不重叠校验；能力直接删除也未阻止影响已确认工作 | 对齐 004/005：本人管理、受控能力替换、最短两小时/时段重叠校验、保留已确认任务所需服务能力 |
| DB19 | availability 变更有 Provider 锁和确认预约检查；property window 也有锁/检查触发器，但该函数当前为 invoker | 保护未来确认任务的意图正确。后续收紧 Provider 可见性时，invoker 的锁可能因 RLS 而失效/受限 | 数据最小化变更必须与 007 锁可见性修复配套；不要只改 SELECT policy 却漏掉并发保护 |
| DB20 | 11 个非扩展 public 函数；只有 accept/revise/transition 对 authenticated 可执行，anon 均不可执行；内部触发器函数不对客户端开放；search_path 均为空 | 当前显式函数执行授权、固定路径和角色校验有良好基础；SECURITY DEFINER 不自动安全也不自动有漏洞 | 保留当前 allow-list 原则；新 RPC 逐一核对所有者、auth.uid、参数、状态及 EXECUTE，不依赖 RLS 代替 definer 内检查 |
| DB21 | public 无视图；17 个索引，包括参与者索引、history 索引和排他 GiST | 当前无 public definer view 绕过面；有基础索引，但未做真实负载/查询计划评估 | 不凭索引数量宣称性能合格；新聊天/分页/上传结构按实际迁移补索引与测试 |
| DB22 | Realtime 当前只发布 booking 与 booking_status_history | 与早期实时状态设计相符；新聊天不存在，也未验证实时订阅权限 | 升级后按需要发布并验证消息可见性、断线重连、离开页面取消订阅；不因订阅开放就放宽原始表权限 |
| DB23 | supabase_migrations.schema_migrations 不存在；无部署环境登记表；无聊天、评价、上传票据等新表；仅 3 个业务 RPC | 明确的 Schema Drift。本地 18 份迁移不代表线上已执行；不能依据这次快照证明历史上究竟执行了哪份脚本 | 先备份/新 Staging/建立可信 baseline，再升级及验证。禁止伪造“已应用全部版本”的登记或在原项目重跑 001 |
| DB24 | 当前函数的取消逻辑/缺失价格列与本地新设计不同 | 是部署版本差异，不是应回改最新 App 以迎合旧库；原有正确保护也不应丢弃 | 用“业务规则 → 表/约束 → RPC → App → 测试”逐项对齐，部署期间明确兼容/维护策略 |
| DB25 | 本地 shim 默认对 authenticated 授全部表权限，未重现当前 hosted anon 的全部默认授权 | 本地测试通过不能证明线上 least-privilege 已完成；仅部署既有 18 迁移也未形成覆盖所有旧表的全面默认 ACL 整改 | 需独立补最小权限迁移及镜像 hosted 默认 ACL 的回归测试；本次只审查，不自动实现或应用 |
| DB26 | 6 个扩展位于 extensions / vault / pg_catalog，没有扩展安装在 public | 当前扩展命名空间没有发现 public 扩展暴露问题；btree_gist 支持预约排他约束 | 保留；本轮未检查扩展版本漏洞、升级兼容性或 Vault 内部秘密内容，不能据此宣布依赖安全审计完成 |

## 需要修改的优先顺序

1. 建立独立 Staging；识别并备份现有环境/迁移 baseline，不能把当前 production 简单重命名为安全测试环境。
2. 整理所有 10 张表和新 RPC 的权限矩阵，补齐显式 grants/revokes 与新对象默认权限。注意环境身份探测等少数 anon RPC 可以是有意允许的，不做一刀切全函数撤权。
3. 受控预约创建、防重试重复、Provider approved、最短时长、报价快照与取消规则共同对齐。
4. Provider 原始资料和完整日程最小化，配套 property-window 的锁权限修复，不能牺牲并发保护。
5. 照片票据、服务器验证、附加和完成门禁、旧证据访问计划一起部署。
6. 再上线聊天/评价/分页/限流等缺失结构与对应客户端；这些是待部署功能，不是假定已经工作的线上能力。
7. 用不同真实测试身份做允许/拒绝矩阵，再做并发接受、丢失响应、照片替换/删除、实时订阅检查。

不是现在就让用户逐条在 Production 手动 REVOKE 或手动删除 Policy。整改需要可复现迁移、版本记录和 Staging 验收；涉及真实删除/历史资料变更需另行确认。

## 值得亲手学习的暂停点

### 暂停点 1：确认“我是谁”，避免管理员视角假通过

让用户亲手在 SQL Editor 执行：

```sql
SELECT current_user AS database_role, auth.uid() AS app_user_id;
```

此查询是只读。通常 Dashboard 的 database_role 是 postgres、app_user_id 为 NULL；以实际结果为准。NULL 不是登录损坏，Dashboard 管理会话不等于 App 的某个 Owner/Provider JWT 会话。此练习不测试行访问，只用于识别身份。

### 暂停点 2：权限矩阵与 RLS 的真实体验（Staging 已准备后）

用户亲手用 Owner A、Owner B、Provider A、Provider B 的预建测试账号切换，分别查看自己的与别人的预约/照片。先演示一个允许和一个拒绝；剩余重复用例由助手完成。禁止使用 service_role 或 postgres 来证明普通账号隔离。

### 暂停点 3：执行一份已审核迁移（另行确认后）

先看清 Project Reference 和 Staging 身份，再由用户执行已测试的权限迁移，随后重新读取有效授权，理解“变更前 → 迁移 → 变更后验证”。没有用户方向前不进行本轮以外的线上修改。

### 暂停点 4：并发与事务

在 Staging 中用两个真实请求竞争同 Provider 的相同时段，观察只有一个 Accepted，另一个保持 Pending/收到冲突。理解 transaction/locking/exclusion constraint 是不同层的保护；不能只看日历上没有重叠就宣布并发正确。

## 尚未验收的项目（不能标为通过）

- Auth 设置：匿名 Auth 登录开关、邮箱确认、密码/会话策略、恢复链接、SMTP 与邮件送达；本轮没有读取这些管理设置。
- Data API exposed schemas/实际 HTTP 可达性、所有 Auth/Storage/Realtime 跨账号行为；目录 SQL 权限不直接证明 API exploit 或隔离通过。
- Staging 存在与隔离、备份可恢复性、平台 advisor 完整输出、运行时负载、日志敏感资料、完整恢复演练。
- 数据保存期限、真实账号删除、备份保存与照片/聊天保留策略；需产品决定，不自动发明或执行删除期限。
- 本轮不在 Production 插入/修改记录，也没有执行真实并发写入来“验证”源码判断。

## 参考依据

业务结论来自本次项目实际 SQL 元数据/函数源码及本地 migration 对照。以下仅支持权限语义，不作为项目已经通过的证据：

- [Supabase：Grants、RLS 与默认权限](https://supabase.com/docs/guides/api/securing-your-api)
- [Supabase：RLS 和高权限绕过](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase：数据库函数、SECURITY DEFINER 与执行授权](https://supabase.com/docs/guides/database/functions)
- [Supabase：Storage 权限](https://supabase.com/docs/guides/storage/security/access-control)
