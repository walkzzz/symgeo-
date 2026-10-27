# symgeo 形式化证明（moon prove）方案与进展

> 依据：MoonBit 官方 moon prove 文档（实验性特性）。工具链：moon 0.1.20261020。
> 本文档记录：证明目标、可信边界、运行方法、已知限制。

## 1. 证明环境

| 组件 | 状态 | 说明 |
|---|---|---|
| moon prove | ✅ 可用 | moon 自带证明流水线（转 Why3 消解证明义务） |
| SMT 求解器 | 🔧 z3 4.13.4 | 官方 Windows 二进制解压于 `workspace/tools/z3-4.13.4-x64-win/bin/`，通过 `Z3PATH` 环境变量接入 |
| Why3 | — | moon prove 未单独报缺 why3（推测 moon 内置/封装了 why3 转换层），以实际运行为准 |
| 证明模型 | ⚠️ | **数学整数**（无界），不建模机器整数溢出——见可信边界 |

## 2. 运行方法

```bash
# PowerShell（当前会话）
$env:Z3PATH = "C:\Users\Administrator\WorkBuddy\2026-10-27-12-01-25\tools\z3-4.13.4-x64-win\bin"
moon prove            # 证明模块内全部启用证明的包
moon prove poly       # 只证明 poly 包（依赖作为假设）
moon check            # 常规类型检查（证明语法也在此解析）
moon test             # 运行时测试（与证明互补，互不替代）
```

## 3. 已证明目标（第一批）

| 函数 | 性质 | 手段 |
|---|---|---|
| `poly/monomial.mbt :: Monomial::num_vars` | `result == m_vars.length()`（计数正确性） | 后置条件直证（无循环） |
| `poly/monomial.mbt :: Monomial::total_degree` | `result >= 0`（度非负） | for 循环不变量 `0 <= d` |
| `poly/poly.mbt :: Polynomial::degree` | `result >= -1`（零多项式约定 -1） | 循环不变量 + **链式复用** total_degree 的已证契约（callee contract） |

逻辑侧谓词在 `poly/monomial.mbtp`：`monomial_valid_vars`（升序+正指数结构不变式）、`nonneg`、`num_vars_ok`、`total_degree_ok`。

## 4. 可信边界（明确声明）

1. **证明模型 = 数学整数**：`Int` 上不建模溢出。指数运算 `exp > 0` 等在模型中成立，运行时超界仍需运行时防护（MoonBit 运行时自身有边界检查）。
2. **BigInt 不透明**：`arithmetic` 包的 Rational/gcd 基于 core `@bigint`（外部类型），其内部性质**不可证也不证明**——由 golden test + FLINT/Singular oracle 数值对拍覆盖（已在方案中定位为 oracle）。
3. **未证明 ≠ 未验证**：运行时测试（17 个）继续作为第一道防线；证明是叠加保证，不是替代。

## 5. 后续证明路线（按迭代排入）

| 目标 | 性质 | 难度 | 计划 |
|---|---|---|---|
| `Monomial::mul` | 保持 `monomial_valid_vars`（结构有效）+ 度可加性 | 中（双指针 merge 循环不变量） | I1.5 |
| `Monomial::divide/divides` | mul/divide 互逆 | 中高 | I2 前 |
| `Polynomial::add` | 保持规范存储序（sorted、无零项、无重复） | 高（需要序列量化推理） | I2 |
| Buchberger 引擎 | 度界保护必然返回（不挂死）+ 终止 | 高（well-founded 度量 proof_decrease） | I2-I3 |
| Wu 伪除 | 伪除次数有界 | 高 | I3 |
| 证书 `verify(cert)` | **证书验证正确性**——最值得证明的目标：验证器小而纯，证明它=证明所有"Proved"结论可信 | 中高 | I3（与证书格式定稿同步） |

> 原则：优先证明"验证器"而非"生成器"（验证器小且纯，证明收益最大——与 Narboux 证书化思想的验证侧一致）。

## 6. 实验性声明

moon prove 为 MoonBit 实验特性（官方文档明示），语法与工具链可能变化。证明代码与运行时测试解耦：`moon test`/`moon build` 不依赖证明成立，证明失败不影响构建。
