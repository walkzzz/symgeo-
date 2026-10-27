# symgeo 形式化证明（moon prove）方案与进展

> 依据：MoonBit 官方 moon prove 文档（实验性特性）。工具链：moon 0.1.20261020。
> 本文档记录：证明目标、可信边界、运行方法、已知限制。

## 1. 证明环境

| 组件 | 状态 | 说明 |
|---|---|---|
| moon prove | ✅ 可用 | moon 自带证明流水线（`moonc-prove` 转 Why3 WhyML，派发证明义务） |
| SMT 求解器 | 🔧 z3 **4.12.2** | **版本红线：why3 检测数据只认 Z3 ≤ 4.12.x**（4.13.x 报 "no prover available"）。二进制位于 `workspace/tools/z3-4.12.2-x64-win/bin/`，用 `Z3PATH` 环境变量接入（指到 z3.exe 或其目录） |
| Why3 | ✅ 内置 | moon 工具链自带完整 Why3 运行时（`~/.moon/share/why3`，含 z3.drv 与 provers-detection-data.conf），无需单独安装 opam why3 |
| 证明模型 | ⚠️ | **数学整数**（无界），不建模机器整数溢出——见可信边界 |

## 2. 支持子集（实测探明）

- ✅ `FixedArray[Int32]`：`.length()`、索引 `xs[i]`、for 计数循环（`for i = 0; i < xs.length(); { ... continue i + 1 }`）、循环不变量、`proof_ensure` 后置条件。
- ❌ `Array`（可变）：`.length()`/索引/遍历在 contracted 函数体内报 `[4207] unsupported primitive operator`。`FixedArray` 逃逸式使用同样不受官方支持。
- **策略：证明模型层（proof model）**。真实函数（Array 表示）不挂契约；为每个要证的性质写一个结构镜像的模型函数（`FixedArray[Int32]` 表示）并证明之。模型与实现的对应关系以命名和注释固化（如 `sum_degrees` ↔ `Monomial::total_degree`）。moon prove 子集扩展后，契约可迁回真实函数。

## 3. 运行方法

```bash
# bash（当前会话）
export Z3PATH="C:/Users/Administrator/WorkBuddy/2026-10-27-12-01-25/tools/z3-4.12.2-x64-win/bin/z3.exe"
moon prove            # 证明模块内全部启用证明的包
moon prove poly       # 只证明 poly 包（依赖作为假设）
moon check            # 常规类型检查（证明语法也在此解析）
moon test             # 运行时测试（与证明互补，互不替代）
```

证明报告：`_build/verif/<pkg>/<pkg>.proof.json`（含每个 VC 的 goal、headline、solver attempts）。

## 4. 已证明目标（第一批：证明模型层）

| 模型函数（poly/proof_model.mbt） | 性质 | 镜像的真实函数 | 手段 |
|---|---|---|---|
| `sum_degrees(xs)` | `result >= 0`（度和非负） | `Monomial::total_degree` | 循环不变量 `0 <= d` |
| `max_exponent(xs)` | `result >= -1`（空数组=零多项式约定） | `Polynomial::degree` | 循环不变量 `-1 <= m` |

逻辑侧谓词在 `poly/monomial.mbtp`：`nonneg`、`exponent_list`、`degree_bound`。
最小流水线探针：`prooflab/probe_fixed_i32`（FixedArray[Int32] 循环不变量端到端样例）。

## 5. 可信边界（明确声明）

1. **证明模型 = 数学整数**：`Int` 上不建模溢出。运行时超界仍需运行时防护（MoonBit 运行时自身有边界检查）。
2. **BigInt 不透明**：`arithmetic` 包的 Rational/gcd 基于 core `@bigint`（外部类型），其内部性质**不可证也不证明**——由 golden test + FLINT/Singular oracle 数值对拍覆盖（已在方案中定位为 oracle）。
3. **模型 ↔ 实现的镜像关系是人工保证**：证明模型证明的是模型函数的性质，与真实函数的对应靠命名/注释/评审维持（这是 proof-model 策略的固有代价，子集扩展后消除）。
4. **未证明 ≠ 未验证**：运行时测试（17 个）继续作为第一道防线；证明是叠加保证，不是替代。

## 6. 后续证明路线（按迭代排入）

| 目标 | 性质 | 难度 | 计划 |
|---|---|---|---|
| 模型 `mul_degrees` | 度可加性 `sum(a++b) == sum(a)+sum(b)` | 中 | I1.5 |
| `Monomial::mul` 模型 | 结构有效（升序保持） | 中（双指针 merge 循环不变量） | I1.5 |
| `Polynomial::add` 模型 | 保持规范存储序 | 高（需要序列量化推理） | I2 |
| Buchberger 引擎 | 度界保护必然返回 + 终止 | 高（well-founded 度量 proof_decrease） | I2-I3 |
| Wu 伪除 | 伪除次数有界 | 高 | I3 |
| 证书 `verify(cert)` | **证书验证正确性**——最值得证明的目标：验证器小而纯，证明它=证明所有"Proved"结论可信 | 中高 | I3（与证书格式定稿同步） |

> 原则：优先证明"验证器"而非"生成器"（验证器小且纯，证明收益最大——与 Narboux 证书化思想的验证侧一致）。

## 7. 实验性声明

moon prove 为 MoonBit 实验特性（官方文档明示），语法与工具链可能变化。证明代码与运行时测试解耦：`moon test`/`moon build` 不依赖证明成立，证明失败不影响构建。
