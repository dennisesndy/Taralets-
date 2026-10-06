class NotificationItem {
  final String id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime timestamp;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    this.isRead = false,
    required this.timestamp,
  });
}