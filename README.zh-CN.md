<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/banner-dark.gif">
    <img src="assets/banner-light.gif" width="864" alt="All nine ThinkingOrbs designs animating side by side">
  </picture>
</p>

<h1 align="center">ThinkingOrbs for Flutter</h1>

<p align="center">
  专为 AI 与 Agent 智能体交互打造的纯 3D 点阵微动加载动效库。<br />
  九款手调设计，两款物理优化尺寸，一行代码即可无缝接入。
</p>

<p align="center">
  <a href="README.md">English</a> · <b>简体中文</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Dart-3.12+-0175C2?logo=dart&logoColor=white" alt="Dart 3" />
  <img src="https://img.shields.io/badge/Flutter-3.27+-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/iOS%20·%20Android%20·%20macOS%20·%20Web%20·%20Windows%20·%20Linux-supported-000000" alt="Platforms" />
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="MIT License" />
</p>

---

```dart
ThinkingOrb(design: OrbDesign.searching)
```

这就是全部接入代码。九款设计中有八款为真正的 3D 几何空间体（经空间旋转、深度着色与基于 Z 轴景深排序绘制），第九款为连续等距多边形平滑插值形变。全系采用纯粹单色灰阶点阵渲染，在浅色与深色界面下均沉稳克制、毫不喧宾夺主。全屏所有 Orb 均由统一的全局时钟驱动并保持相位同步，应用切到后台时自动暂停，并严格适配系统 Reduce Motion（减弱动态效果）。

## 安装方式

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  thinking_orbs_kit: ^0.0.1
```

导入包：

```dart
import 'package:thinking_orbs_kit/thinking_orbs_kit.dart';
```

## 快速上手

```dart
import 'package:flutter/material.dart';
import 'package:thinking_orbs_kit/thinking_orbs_kit.dart';

class AssistantStatus extends StatelessWidget {
  const AssistantStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return const ThinkingOrbLabel(
      '正在全网搜索…',
      design: OrbDesign.searching,
    );
  }
}
```

## 九款专属设计

每种动效均为 `OrbDesign` 的枚举值。根据智能体当前的实际任务状态选择最贴切的形态：

| Regular (常规) | Small (微型) | 设计形态 | 代码枚举 | 推荐应用场景 |
|:---:|:---:|---|---|---|
| <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/working-regular-dark.gif"><img src="assets/designs/working-regular-light.gif" width="96" alt="Working, regular"></picture> | <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/working-small-dark.gif"><img src="assets/designs/working-small-light.gif" width="30" alt="Working, small"></picture> | **Working (运作)**<br><sub>倾斜轨道上的循环粒子</sub> | `OrbDesign.working` | 通用繁忙、后台处理、基础运转 |
| <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/searching-regular-dark.gif"><img src="assets/designs/searching-regular-light.gif" width="96" alt="Searching, regular"></picture> | <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/searching-small-dark.gif"><img src="assets/designs/searching-small-light.gif" width="30" alt="Searching, small"></picture> | **Searching (检索)**<br><sub>子午线扫描光带席卷点阵球</sub> | `OrbDesign.searching` | 网络检索、知识库召回、向量查询 |
| <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/solving-regular-dark.gif"><img src="assets/designs/solving-regular-light.gif" width="96" alt="Solving, regular"></picture> | <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/solving-small-dark.gif"><img src="assets/designs/solving-small-light.gif" width="30" alt="Solving, small"></picture> | **Solving (求解)**<br><sub>环带切片快速扰动后清脆复位</sub> | `OrbDesign.solving` | 逻辑推理、代码生成、数学计算 |
| <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/listening-regular-dark.gif"><img src="assets/designs/listening-regular-light.gif" width="96" alt="Listening, regular"></picture> | <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/listening-small-dark.gif"><img src="assets/designs/listening-small-light.gif" width="30" alt="Listening, small"></picture> | **Listening (聆听)**<br><sub>声学波形沿纬度环涌动</sub> | `OrbDesign.listening` | 语音输入、实时转录、声学检测 |
| <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/connecting-regular-dark.gif"><img src="assets/designs/connecting-regular-light.gif" width="96" alt="Connecting, regular"></picture> | <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/connecting-small-dark.gif"><img src="assets/designs/connecting-small-light.gif" width="30" alt="Connecting, small"></picture> | **Connecting (互联)**<br><sub>星座网络自组织布线与脉冲传输</sub> | `OrbDesign.connecting` | 工具调用、外部 API、多节点同步 |
| <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/weaving-regular-dark.gif"><img src="assets/designs/weaving-regular-light.gif" width="96" alt="Weaving, regular"></picture> | <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/weaving-small-dark.gif"><img src="assets/designs/weaving-small-light.gif" width="30" alt="Weaving, small"></picture> | **Weaving (编织)**<br><sub>三股发辫沿球面自旋穿梭交织</sub> | `OrbDesign.weaving` | 规划拆解、多步骤调度、工作流编排 |
| <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/composing-regular-dark.gif"><img src="assets/designs/composing-regular-light.gif" width="96" alt="Composing, regular"></picture> | <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/composing-small-dark.gif"><img src="assets/designs/composing-small-light.gif" width="30" alt="Composing, small"></picture> | **Composing (撰写)**<br><sub>起伏微动的三维多轨飘带</sub> | `OrbDesign.composing` | 流式输出、正文起草、回复润色 |
| <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/breathing-regular-dark.gif"><img src="assets/designs/breathing-regular-light.gif" width="96" alt="Breathing, regular"></picture> | <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/breathing-small-dark.gif"><img src="assets/designs/breathing-small-light.gif" width="30" alt="Breathing, small"></picture> | **Breathing (呼吸)**<br><sub>正向环带轻缓舒张起伏</sub> | `OrbDesign.breathing` | 待机思考、等待上游回复、闲置就绪 |
| <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/shaping-regular-dark.gif"><img src="assets/designs/shaping-regular-light.gif" width="96" alt="Shaping, regular"></picture> | <picture><source media="(prefers-color-scheme: dark)" srcset="assets/designs/shaping-small-dark.gif"><img src="assets/designs/shaping-small-light.gif" width="30" alt="Shaping, small"></picture> | **Shaping (塑形)**<br><sub>圆 → 三角 → 方形轮廓平滑过渡</sub> | `OrbDesign.shaping` | 图像生成、布局排版、UI 构型 |

## 双微调物理尺寸

提供了两款专门微调的尺寸，并非粗暴的线性缩放：微型尺寸采用更少但更大的点、匹配更紧凑的步频，以确保在文本行间依然清晰可辨。

```dart
ThinkingOrb(design: OrbDesign.working)                          // .regular: 64 pt，适合头像、空白态、核心高光
ThinkingOrb(design: OrbDesign.working, size: OrbSize.small)    // .small: 20 pt，适合行内文本、工具栏、列表项
ThinkingOrb(design: OrbDesign.solving, diameter: 56)           // 以 56 pt 尺寸绘制 regular 预设
```

## 状态标签与扫光

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/labels-dark.gif">
    <img src="assets/labels-light.gif" width="400" alt="A Thinking pill and four status chips, their text shimmering">
  </picture>
</p>

`ThinkingOrbLabel` 将 Orb 与带有柔和扫光动效的状态文字组合在一起：

```dart
ThinkingOrbLabel('正在全网搜索…', design: OrbDesign.searching);

Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  decoration: BoxDecoration(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(999),
  ),
  child: const ThinkingOrbLabel(
    '深度思考中…',
    design: OrbDesign.breathing,
    size: OrbSize.regular,
    diameter: 44,
  ),
);
```

扫光效果同时提供 Widget 扩展方法，可直接为任意文本或组件赋予微光生命力：

```dart
const Text('正在综合生成最终回复…').thinkingShimmer();
```

## 确定性测试 (Golden Tests)

在编写 Widget 测试或截图比对时，可使用 `OrbClockOverride` 将全局时钟锁定在任意指定秒数：

```dart
OrbClockOverride(
  seconds: 1.25,
  child: ThinkingOrb(design: OrbDesign.composing),
);
```

## 无障碍与系统无动画 (Reduce Motion)

- **VoiceOver / TalkBack**：自动为每个 Orb 分配精准的无障碍语义标签（如 “正在检索…”）。
- **减弱动态效果 (Reduce Motion)**：检测到 `MediaQuery.disableAnimations` 为 true 时，自动停泊在具有代表性的静态静止帧（`t = 0.6`），零 Ticker 损耗。
- **高对比度适配**：在开启高对比度模式时，状态标语的底色透明度自动拉升至 100%，确保弱视用户清晰阅读。

## 致谢与参考来源 (Credits & References)

本项目为 1:1 精确移植自以下优秀开源项目：
- **[haplollc/ThinkingOrbs](https://github.com/haplollc/ThinkingOrbs)**：Haplo LLC 的 Swift / SwiftUI 实现，提供了原生架构设计、Golden 向量集与优雅的 API 规范。
- **[Jakubantalik/thinking-orbs](https://github.com/Jakubantalik/thinking-orbs)**：由 [Jakub Antalik](https://github.com/Jakubantalik) 设计开发的原版 3D 几何数学引擎与动效设计（亦见于 [libraries.dev/orbs](https://libraries.dev/orbs)）。

本项目 100% 忠实保留了全部 9 种数学几何模式、2 组微调比例预设、256 级灰阶着色查找表与 72 组向量黄金测试集。

## 规格参考文档

仓库内包含详尽的技术规范与映射文档：
- `ref/spec.md`：数学规格书、参数微调公式与各形态几何定义。
- `ref/mapping.md`：SwiftUI 至 Flutter 架构映射表与 API 对齐指南。
- `ref/verification.md`：黄金测试集数据规范（72 组 Stride 6/7 向量容差判定）。
- `ref/upstream/`：完整归档上游 Swift 源码供横向比对。

## 开源协议

MIT License。详见 [LICENSE](LICENSE)。
- 原始动效与数学引擎：Jakub Antalik (MIT)。
- Swift ThinkingOrbs：Haplo LLC (MIT)。
- Flutter 移植：Chencheng Xie (MIT)。
