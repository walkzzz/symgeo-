# symgeo 项目对话历史总结

> 会话日期：2026-10-27 ｜ 模式：WorkBuddy 软件交付专家团（马斯克五步法立项 → 生命周期编排）
> 本文由 AI 助手根据本次完整对话自动总结，供项目追溯与新成员 onboarding。

## 一、立项阶段（马斯克五步法）

**输入**：`E:\codebuddy-work\初稿.md` —— MoonBit 符号几何库「symgeo」七层架构设计（L0 精确算术 → L7 DSL/CLI/导出）。

**五步法结论（有条件立项）**：
- **质疑**：初稿 3200 行没有一个字回答"谁用、解决什么真实问题"；定位修正为"学习/算法储备 + MoonBit 生态补空"。
- **删除**：八层砍到核心链路，删约 60% 工作量（L3/L5 砍半、L7 延后）。
- **简化**：去 LRU 缓存；保留"确定性排序/规范化"（数学库可测试性核心资产）。
- **加速**：MVP 路径 + 里程碑门禁。
- **自动化**：golden/property test 优先。
- 顺带发现初稿 2 个技术 bug（`int_mul_overflow` 在 b==0 时误判；`mul` 无穷规则分支覆盖冲突）。

## 二、市场与竞品调研

1. **市场调研**：七层功能全部有成熟竞品（SymPy/Singular/GeoGebra/OpenGeoProver/JGEX 等）；MoonBit 生态已出现 `CAIMEOX/symbit`（SymPy 移植，473 测试）与 `Luna-Flow/luna-poly`（规范型多项式库）。
2. **源码级评估**（克隆到 `competitor-src/`）：symbit 38 子包/19MB，sympolys 6.5 万行；结论：不自研 L0-L2，生态空缺在"约束翻译 + 自动判定"层。
3. **多语言扫描**：Rust `sdiehl/groebner`（MIT，F4+Buchberger，自带黄金测试集）为并列主源；Go 弱；C/C++ 大库（FLINT/NTL/Singular）因 copyleft+指针密集+Wasm 不可链接，定位为对拍 oracle。

## 三、路线拍板（用户决策）

1. 从 **OCaml 生态移植**（后改为"只吸收思想"）。
2. **L0-L2 自持底座**（仅依赖 MoonBit core `@bigint`），symbit 复用方案作废（降级为对拍参照）。
3. **不搬任何代码，只吸收算法思想**——许可证风险归零。
4. **保留扩展能力**为硬约束：6 条扩展性红线（Ring trait 域参数化、MonomialOrder 策略参数、Shape enum 留位、谓词注册表、Prover 接口可插拔、模块物理隔离）+ 五层→八层回扩路线图。
5. 批准**完整方案与迭代路线**（I0-I5，串行门禁驱动）。

## 四、关键交付物（工作区根目录）

| 文档 | 内容 |
|---|---|
| symgeo-立项评估-马斯克五步法.md | 五步法立项漏斗 |
| symgeo-竞品开源库市场调研.md | 分层竞品矩阵 + MoonBit 生态细查 |
| symgeo-竞品源码级评估.md | symbit/luna-poly 源码细读 |
| symgeo-OCaml移植源映射.md | 七层 × OCaml 源映射 |
| symgeo-多语言移植源补充调研.md | Rust/Go/C/C++ 扫描 |
| symgeo-实现方案-思想吸收版.md | 五层架构 + 扩展性红线 |
| symgeo-完整方案与迭代路线.md | **定稿 v1.0：I0-I5 迭代路线** |

## 五、开发执行（symgeo/ 仓库）

### I0 工具链冒烟 ✅
- moon 0.1.20261020 / moonc v0.10.16 已就位；`@bigint` 大数四则精确。
- 五包骨架：`arithmetic / poly / translate / prover/{wu,groebner} / cmd/main`，依赖方向自下而上。

### I1 精确内核 ✅（commit f3532e7）
- `Rational`（BigInt 底座，构造即规范化）+ `Ring` trait（红线 #1）。
- `Monomial`（稀疏指数向量、lex/grevlex 双序）+ 稀疏 `Polynomial`（四则/幂/单项式除/leading term/content/单变量欧几里得 GCD）。
- **17/17 测试全绿**。
- MoonBit 新版踩坑：`var` 是关键字；可选参数须标签传参（`c=`）；`derive(Show)`→`derive(Debug)`；错误枚举需手写 Show impl。

### 形式化证明（用户追加要求，moon prove）
- `poly` 包启用 `proof_enabled`；`.mbtp` 逻辑谓词；证明模型层 `proof_model.mbt`（`sum_degrees`/`max_exponent`，FixedArray[Int32] 循环不变量）。
- **支持子集（实测）**：`FixedArray[Int32]` 循环+契约 ✅；`Array` 的 length/索引在 contracted 体内报 `[4207]` ❌ → 采用"证明模型镜像真实函数"策略。
- **z3 版本红线**：moon 内置 why3 检测数据只认 Z3 ≤ 4.12.x（4.13.x 报 no prover available）；z3 4.12.2 Windows 二进制经断点续传下载至 `tools/`，`Z3PATH` 接入。
- **遗留问题**：why3server → z3 调用链瞬间失败（time=0.000001，highfailure），z3 本体直跑正常（sat）；已排除版本/缓存/沙箱/显式 command，待继续排查 why3server 进程派生机制。详见 `symgeo/PROOF.md`。

## 六、当前状态与下一步

- **代码**：`workspace/symgeo/`（本仓库），17/17 测试绿，4 个 commit。
- **任务看板**：I2（Buchberger + 8 谓词注册表 + 黄金语料）待开工；#7（30 题定理清单→验收标准）I1 结束前由产品角色完成。
- **moon prove**：代码与文档就绪，等 why3server/z3 调用链打通后第一批义务（度和非负、度 ≥ -1）即可消解。
