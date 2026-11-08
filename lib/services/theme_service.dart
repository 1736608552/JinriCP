import 'package:flutter/material.dart';

/// 🌟 极光影音视界 - 全局高定电影级设计系统与主题规范
class AppTheme {
  /// 判断当前上下文是否处于夜间深色模式
  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // ================= 核心色彩规范 =================
  /// 品牌主色调：极光赤霞紫粉 (Neon Rose)
  static const Color primaryPink = Color(0xFFFF2D55);
  static const Color accentPink = Color(0xFFFF5277);
  static const Color neonPurple = Color(0xFF8A2BE2);
  static const Color electricCyan = Color(0xFF00E5FF);
  static const Color amberGold = Color(0xFFFFB300);
  static const Color successGreen = Color(0xFF00E676);
  static const Color warningAmber = Color(0xFFFF9100);

  /// 顶级流媒体流光渐变（主视觉焦点）
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF2D55), Color(0xFF9D34DA)],
  );

  /// 电影级琥珀高分渐变
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB300), Color(0xFFFF6D00)],
  );

  /// 极速超清青蓝渐变
  static const LinearGradient cyanGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00E5FF), Color(0xFF0072FF)],
  );

  /// 实时直播呼吸红渐变
  static const LinearGradient liveGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF1744), Color(0xFFFF5252)],
  );

  // ================= 背景与表面分层 =================
  /// 页面主背景色（夜间：黑曜石深渊 0xFF090A10 / 白天：纯净陶瓷轻奢 0xFFF5F7FB）
  static Color scaffoldBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF090A10) : const Color(0xFFF5F7FB);

  /// 顶栏 AppBar 背景色（半透或高级磨砂感）
  static Color appBarBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF0E101A) : Colors.white;

  /// 一级卡片容器背景色（夜间深钛晶 0xFF121522）
  static Color cardBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF121522) : Colors.white;

  /// 二级卡片容器 / 高光悬浮区背景色
  static Color cardSecondaryBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF1A1F33) : const Color(0xFFECEFF6);

  /// 搜索框 / 输入框背景色
  static Color inputBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF151828) : const Color(0xFFEBEEF5);

  /// 底部导航栏背景色
  static Color bottomNavBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF0F111D).withOpacity(0.94) : Colors.white.withOpacity(0.96);

  // ================= 文字阶梯规范 =================
  /// 主标题文字颜色
  static Color textPrimary(BuildContext context) =>
      isDark(context) ? Colors.white : const Color(0xFF111420);

  /// 次级文字颜色
  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFFA2A9B8) : const Color(0xFF5D6577);

  /// 弱化/占位/时间文字颜色
  static Color textMuted(BuildContext context) =>
      isDark(context) ? const Color(0xFF6B7386) : const Color(0xFF98A1B2);

  /// 统一微晶细边框颜色（带有微弱高光反光感）
  static Color borderColor(BuildContext context) =>
      isDark(context) ? Colors.white.withOpacity(0.08) : const Color(0xFFE5E9F2);

  /// 未选 Chip / 胶囊标签背景色
  static Color chipUnselectedBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF16192A) : const Color(0xFFEEF1F6);

  /// 激活标签胶囊浅色底
  static Color pillActiveBg(BuildContext context) =>
      isDark(context) ? const Color(0xFFFF2D55).withOpacity(0.18) : const Color(0xFFFFF0F3);

  // ================= 电影级弥散光晕与阴影 =================
  /// 悬浮卡片柔和弥散阴影
  static List<BoxShadow> cardShadow(BuildContext context) {
    if (isDark(context)) {
      return [
        BoxShadow(
          color: Colors.black.withOpacity(0.45),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
    } else {
      return [
        BoxShadow(
          color: const Color(0xFF1C274C).withOpacity(0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
    }
  }

  /// 霓虹微发光光晕
  static List<BoxShadow> neonGlow({Color color = primaryPink, double opacity = 0.38, double blur = 14}) {
    return [
      BoxShadow(
        color: color.withOpacity(opacity),
        blurRadius: blur,
        offset: const Offset(0, 3),
      ),
    ];
  }

  /// 现代高定玻璃感卡片修饰
  static BoxDecoration glassCard(
    BuildContext context, {
    double radius = 16,
    Color? customBg,
    Color? customBorderColor,
  }) {
    final dark = isDark(context);
    return BoxDecoration(
      color: customBg ?? cardBg(context),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: customBorderColor ?? borderColor(context),
        width: 0.8,
      ),
      boxShadow: cardShadow(context),
    );
  }
}
