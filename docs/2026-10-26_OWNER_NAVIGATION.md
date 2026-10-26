# Owner 页面分工与导航整理

日期：2026-10-26；版本 0.1.4+5。保留五个底栏入口、原有主题、顶部返回与真实 Staging。

| 页面 | 当前职责 |
| --- | --- |
| Home | 一个明显的 Request cleaning；可点击状态统计；Pending requests 与 Upcoming bookings 分组、原地展开；不再重复排列功能菜单 |
| Properties | 出租单位列表、详情、新增和编辑；顶部 Add 保留 |
| Providers | 已批准服务商的展示资料；按名称、地区或服务搜索，分页浏览，查看资料后返回目录 |
| Bookings | 全部预约、跨完整记录搜索、状态筛选、History、时间排序与分页；不再复制首页概览 |
| Profile | 账号与偏好、Appearance、Schedule／Spending、About & help、Sign out；移除 Manage properties 重复入口 |

Home 顶部保留 Messages 与 Notifications 工具入口，删除 More 菜单、Quick actions 和主页面侧边导航。
服务商目录不会打开预约表单；创建预约由 Home 的 Request cleaning 启动。
Property 详情保留针对该单位的预约操作。没有服务商被默认选中、自动派单或假装通过时间可用性检查。
目录价格是资料展示；实际报价与资格仍在创建请求时按单位、服务和时间验证。

## 后端读取

- 新增迁移 029，仅提供 `page_owner_booking_search` 与 `page_approved_provider_directory` 两个读取接口。
- 预约搜索在数据库按当前 Owner、状态组和查询字词筛选后分页；Ongoing 包含 Accepted／In Progress，History 包含 Completed／Cancelled／Declined。
- 查询按字面匹配，`%` 不会变成匹配全部资料的通配符。每页客户端最多 20 条，时间戳及 UUID 作为稳定游标；支持新到旧与旧到新。
- 目录仅显示 approved Provider 的展示姓名、介绍、地区、服务、价格及统计；不返回账号邮箱、电话、私人出发地址或原始时间表。
- 仅 Owner 可调用这些模块的读取接口；Provider 与匿名调用拒绝。未扩大原始表授权，没有改变预约写操作。
- 页面使用账号隔离的内存缓存、安静刷新、下拉刷新；离开时关闭预约订阅，修改搜索会废弃旧请求结果。
- 迁移 029 已应用到 Staging `gqtetdavmrautoojaqrk`；原项目未改动，没有新建用户或更改业务记录／密码。

## 验证

- 850 项完整 Flutter 回归通过，包括新增 13 项导航读取、旧请求隔离、Unicode 输入、错误重试、服务商资料返回及双主题／大字体检查。
- 本地 PostgreSQL 在 legacy／disabled 默认授权两种模式下通过 001–029 迁移、ACL／RLS、跨账号拒绝、分页与并发检查。
- 27 张预约、26 个批准服务商及一个待批准账号的本地夹具，确认第一页以外的搜索、无重复游标与历史筛选。
- 原固定账号的 Staging 只读复核通过：目录字段白名单、Owner 搜索／历史、Provider／匿名拒绝；无新增测试用户或业务记录。
- 静态分析无 error／warning；现有风格提示仍在。源码 159 文件、最终包 756 文件敏感资料模式扫描 PASS。
- 已查看 Home、Providers、Bookings 的页面图像；保留原有底栏和品牌色。
- Profile APK 构建成功，版本 0.1.4／build 5，最低 Android 6.0／API 23，包含 ARM／x86。
  签名与 v0.1.3 一致，分发副本 SHA-256 与构建文件一致。

## 手机复验

1. 双方覆盖安装同一新版；原固定 Owner／Provider 账号继续使用。
2. 确认 Home 没有 Quick actions 或 More 主菜单，只有一个 Request cleaning 主按钮；三个统计卡片仍可打开正确状态列表。
3. Providers 搜索、加载更多、打开资料、返回原目录；底栏仍选中 Providers。
4. Bookings 搜索旧预约，切换 History／Ongoing／其他状态和时间排序，打开详情后返回；不会丢进创建预约表单。
5. 从 Profile 打开 Schedule、Spending、Appearance 与 About & help；Properties 仅通过底栏管理。
6. 继续原双手机预约／聊天／照片流程；记录 Android 返回、键盘、权限和实际更新延迟。

人工手机 UAT／P2-4 尚未标记完成。支付、正式客服／法律发布与密码恢复回调的既有未完成项没有改为已完成。
本次是内部 Staging Profile 包，保留正式发布保护。
