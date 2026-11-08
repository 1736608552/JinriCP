import 'package:flutter/material.dart';
import '../services/proxy_route_service.dart';

class RouteSelectionModal {
  /// 显示线路智能调度与测速弹窗
  static void show(
    BuildContext context, {
    String? testStreamUrl,
    VoidCallback? onRouteChanged,
    Function(String message)? onShowMessage,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF191C28),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedId = ProxyRouteService.selectedRouteId;
            final currentFastest = ProxyRouteService.currentFastestRoute;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.alt_route_rounded, color: Color(0xFFFF2E63), size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '直播线路调度与测速',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () async {
                            setModalState(() {});
                            await ProxyRouteService.benchmarkAndSelectFastest(
                              customTestUrl: testStreamUrl,
                              force: true,
                            );
                            setModalState(() {});
                          },
                          icon: const Icon(Icons.speed_rounded, color: Colors.amberAccent, size: 16),
                          label: const Text('重新测速', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 💡 卡顿自救指南 (折叠/常驻提示)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262B3F),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.tips_and_updates_rounded, color: Color(0xFFFFD54F), size: 16),
                              SizedBox(width: 6),
                              Text(
                                '💡 直播卡顿秒开秘籍',
                                style: TextStyle(color: Color(0xFFFFD54F), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.45),
                              children: [
                                TextSpan(text: '1. '),
                                TextSpan(
                                  text: '已开梯子/代理：',
                                  style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: '请手动选中下方【官方原画直连】，并在梯子中开启【全局代理】选【韩国/香港/日本】节点，立享千兆秒开！\n'),
                                TextSpan(text: '2. '),
                                TextSpan(
                                  text: '国内无梯子：',
                                  style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: '请选【Cloudflare CDN】或带绿色高速标签的线路，避开拥堵机房。'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 📶 本地网络体检状态栏
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF222638),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            ProxyRouteService.localNetworkMode == LocalNetworkMode.vpnConnected
                                ? Icons.vpn_lock_rounded
                                : Icons.cell_tower_rounded,
                            color: ProxyRouteService.localNetworkMode == LocalNetworkMode.vpnConnected
                                ? Colors.greenAccent
                                : Colors.cyanAccent,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '手机本地网络: ${ProxyRouteService.localNetworkDesc}',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ProxyRouteService.localNetworkMode == LocalNetworkMode.vpnConnected
                                      ? '已智能解锁【官方原画直连】最高优先级'
                                      : '国内网络直连环境，已自动适配反代中继节点',
                                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 1. 自动智能优选推荐项
                    Container(
                      decoration: BoxDecoration(
                        color: selectedId == 'auto'
                            ? const Color(0xFFFF2E63).withOpacity(0.12)
                            : const Color(0xFF222638),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selectedId == 'auto'
                              ? const Color(0xFFFF2E63)
                              : Colors.white10,
                          width: selectedId == 'auto' ? 1.5 : 1,
                        ),
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFF2E63),
                          radius: 16,
                          child: Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                        ),
                        title: const Text(
                          '⚡ 自动智能优选 (按真实下载速率推荐)',
                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          currentFastest != null
                              ? '当前最优: ${currentFastest.name} (${currentFastest.downloadSpeedKBps > 0 ? "实测 " + currentFastest.speedText + " · " : ""}${currentFastest.latencyText})'
                              : '实时选择当前网络实际下载速率最高、延迟最低的线路',
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        trailing: selectedId == 'auto'
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFF2E63))
                            : null,
                        onTap: () {
                          ProxyRouteService.setSelectedRouteId('auto');
                          Navigator.pop(modalContext);
                          onRouteChanged?.call();
                          onShowMessage?.call('已切回【自动智能优选】线路');
                        },
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 2. 全部独立线路列表
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.38,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: ProxyRouteService.allRoutes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final route = ProxyRouteService.allRoutes[index];
                          final isSelected = selectedId == route.id;

                          Color latencyColor = Colors.grey;
                          if (route.isAvailable && route.latencyMs < 9000) {
                            if (route.latencyMs < 120) {
                              latencyColor = const Color(0xFF00E676);
                            } else if (route.latencyMs < 280) {
                              latencyColor = Colors.amberAccent;
                            } else {
                              latencyColor = Colors.orangeAccent;
                            }
                          }

                          Color speedColor = Colors.grey;
                          if (route.isAvailable && route.downloadSpeedKBps > 0) {
                            if (route.downloadSpeedKBps >= 500) {
                              speedColor = const Color(0xFF00E676); // > 500KB/s 极速
                            } else if (route.downloadSpeedKBps >= 150) {
                              speedColor = Colors.amberAccent; // > 150KB/s 良好
                            } else {
                              speedColor = Colors.orangeAccent; // 缓慢
                            }
                          }

                          return Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFF2E63).withOpacity(0.12)
                                  : const Color(0xFF222638),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFFF2E63) : Colors.white10,
                              ),
                            ),
                            child: ListTile(
                              dense: true,
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      route.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white70,
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (route.downloadSpeedKBps > 0) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: speedColor.withOpacity(0.18),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: speedColor.withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.download_rounded, color: speedColor, size: 10),
                                          const SizedBox(width: 2),
                                          Text(
                                            route.speedText,
                                            style: TextStyle(color: speedColor, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: latencyColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      route.latencyText,
                                      style: TextStyle(color: latencyColor, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                !route.isAvailable && route.unavailableReason != null
                                    ? '${route.region} · ⚠️ ${route.unavailableReason}'
                                    : '${route.region}${route.downloadSpeedKBps > 0 ? " · 实测下载: " + route.speedText : ""}',
                                style: TextStyle(
                                  color: !route.isAvailable ? Colors.amberAccent.withOpacity(0.9) : Colors.white38,
                                  fontSize: 10,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFF2E63), size: 20)
                                  : null,
                              onTap: () async {
                                if (!route.isAvailable) {
                                  if (route.isDirect) {
                                    onShowMessage?.call('⚠️ 已锁定【${route.name}】(该线路需开启科学上网/梯子)');
                                  } else {
                                    onShowMessage?.call('已锁定【${route.name}】(当前测速稍慢，正尝试强连)');
                                  }
                                } else {
                                  onShowMessage?.call('已锁定使用【${route.name}】');
                                }
                                await ProxyRouteService.setSelectedRouteId(route.id);
                                Navigator.pop(modalContext);
                                onRouteChanged?.call();
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
