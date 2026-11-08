import 'package:flutter/material.dart';
import '../models/file_item.dart';

class FileTile extends StatelessWidget {
  final FileItem item;
  final VoidCallback onTap;

  const FileTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData icon;
    Color iconColor;

    switch (item.type) {
      case ItemType.folder:
        icon = Icons.folder_rounded;
        iconColor = Colors.amber.shade700;
        break;
      case ItemType.video:
        icon = Icons.play_circle_fill_rounded;
        iconColor = theme.colorScheme.primary;
        break;
      case ItemType.text:
        icon = Icons.description_rounded;
        iconColor = Colors.blueGrey;
        break;
      case ItemType.image:
        icon = Icons.image_rounded;
        iconColor = Colors.teal;
        break;
      default:
        icon = Icons.insert_drive_file_rounded;
        iconColor = Colors.grey;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.4)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: (item.date.isNotEmpty || item.size.isNotEmpty && item.size != '-')
            ? Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    if (item.date.isNotEmpty)
                      Text(
                        item.date,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    if (item.date.isNotEmpty && item.size.isNotEmpty && item.size != '-')
                      const SizedBox(width: 12),
                    if (item.size.isNotEmpty && item.size != '-')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.size,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              )
            : null,
        trailing: Icon(
          item.isFolder ? Icons.chevron_right_rounded : (item.isVideo ? Icons.play_arrow_rounded : Icons.open_in_new_rounded),
          color: theme.colorScheme.outline,
        ),
        onTap: onTap,
      ),
    );
  }
}
