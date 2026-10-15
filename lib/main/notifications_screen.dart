// // notifications_screen.dart
// //
// // Reads from NotificationService (SharedPreferences).
// // Automatically refreshes when the screen comes into focus (RouteObserver not
// // required – uses WidgetsBindingObserver / didChangeDependencies pattern).
// //
// // Features
// // -----------------------------------------------------------------------------
// // • Three filter tabs: All · Bookings · Messages
// // • Unread dot + count badge
// // • Swipe-to-delete with confirmation
// // • "Mark all read" button
// // • Pull-to-refresh
// // • Empty state per category
// // • Human-readable relative timestamps
// // • Tapping a tile marks it as read immediately

// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:rentit/feature/notification/notification_service.dart';

// // -----------------------------------------------------------------------------
// //  PALETTE  (matches rest of app)
// // -----------------------------------------------------------------------------

// const Color _primary   = Color(0xFF1A2B40);
// const Color _accent    = Color(0xFF0A7C66);
// const Color _orange    = Color(0xFFF59E0B);
// const Color _purple    = Color(0xFF7C5CE4);
// const Color _bg        = Color(0xFFF5F6F8);
// const Color _text      = Color(0xFF111827);
// const Color _text2     = Color(0xFF6B7280);
// const Color _border    = Color(0xFFE5E7EB);
// const Color _unreadDot = Color(0xFF1E2B45);

// // -----------------------------------------------------------------------------
// //  FILTER ENUM
// // -----------------------------------------------------------------------------

// enum _Filter { all, bookings, messages }

// // -----------------------------------------------------------------------------
// //  SCREEN
// // -----------------------------------------------------------------------------

// class NotificationsScreen extends StatefulWidget {
//   const NotificationsScreen({super.key});

//   @override
//   State<NotificationsScreen> createState() => _NotificationsScreenState();
// }

// class _NotificationsScreenState extends State<NotificationsScreen>
//     with WidgetsBindingObserver {

//   List<AppNotification> _all = [];
//   bool                  _loading = true;
//   _Filter               _filter  = _Filter.all;

//   // -- Lifecycle --------------------------------------------------------------

//   @override
//   void initState() {
//     super.initState();
//     WidgetsBinding.instance.addObserver(this);
//     _load();
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }

//   /// Re-fetch whenever the app comes back to foreground.
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     if (state == AppLifecycleState.resumed) _load();
//   }

//   /// Re-fetch whenever this route is pushed on top again.
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     _load();
//   }

//   // -- Data -------------------------------------------------------------------

//   Future<void> _load() async {
//     if (!mounted) return;
//     setState(() => _loading = true);

//     final list = await NotificationService.getAll();

//     if (!mounted) return;
//     setState(() {
//       _all     = list;
//       _loading = false;
//     });
//   }

//   Future<void> _markAllRead() async {
//     HapticFeedback.lightImpact();
//     await NotificationService.markAllAsRead();
//     await _load();
//   }

//   Future<void> _markRead(AppNotification n) async {
//     if (n.isRead) return;
//     await NotificationService.markAsRead(n.id);
//     await _load();
//   }

//   Future<void> _delete(AppNotification n) async {
//     await NotificationService.delete(n.id);
//     await _load();
//   }

//   // -- Filtered list ----------------------------------------------------------

//   List<AppNotification> get _filtered {
//     switch (_filter) {
//       case _Filter.all:
//         return _all;
//       case _Filter.bookings:
//         return _all
//             .where((n) => n.category == NotificationCategory.booking)
//             .toList();
//       case _Filter.messages:
//         return _all
//             .where((n) => n.category == NotificationCategory.message)
//             .toList();
//     }
//   }

//   int _countFor(_Filter f) {
//     switch (f) {
//       case _Filter.all:
//         return _all.where((n) => !n.isRead).length;
//       case _Filter.bookings:
//         return _all
//             .where((n) =>
//                 n.category == NotificationCategory.booking && !n.isRead)
//             .length;
//       case _Filter.messages:
//         return _all
//             .where((n) =>
//                 n.category == NotificationCategory.message && !n.isRead)
//             .length;
//     }
//   }

//   // -- Build ------------------------------------------------------------------

//   @override
//   Widget build(BuildContext context) {
//     final unreadAll = _all.where((n) => !n.isRead).length;

//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: SafeArea(
//         child: Column(
//           children: [
//             _buildHeader(unreadAll),
//             const SizedBox(height: 16),
//             _buildTabRow(),
//             const SizedBox(height: 2),
//             // Thin separator below tabs
//             Container(height: 1.5, color: _border),
//             Expanded(
//               child: _loading
//                   ? const Center(
//                       child: CircularProgressIndicator(color: _primary),
//                     )
//                   : RefreshIndicator(
//                       onRefresh:  _load,
//                       color:      _primary,
//                       child:      _buildList(),
//                     ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // -- Header -----------------------------------------------------------------

//   Widget _buildHeader(int unreadAll) {
//     return Padding(
//       padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           // Back button
//           GestureDetector(
//             onTap: () {
//               if (Navigator.canPop(context)) Navigator.pop(context);
//             },
//             child: Container(
//               height: 46,
//               width:  46,
//               decoration: BoxDecoration(
//                 border:      Border.all(color: _border),
//                 shape:       BoxShape.circle,
//               ),
//               child: const Icon(
//                 Icons.arrow_back_ios_new,
//                 size:  18,
//                 color: _text,
//               ),
//             ),
//           ),

//           const SizedBox(width: 14),

//           // Title + subtitle
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'Notifications',
//                   style: TextStyle(
//                     fontSize:   26,
//                     fontWeight: FontWeight.w800,
//                     color:      _text,
//                     letterSpacing: -0.5,
//                   ),
//                 ),
//                 const SizedBox(height: 1),
//                 Text(
//                   unreadAll == 0
//                       ? 'All caught up!'
//                       : '$unreadAll unread',
//                   style: const TextStyle(
//                     fontSize: 14,
//                     color:    Color(0xFF9CA3AF),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Mark all read (only show if there are unread)
//           if (unreadAll > 0)
//             GestureDetector(
//               onTap: _markAllRead,
//               child: Container(
//                 padding: const EdgeInsets.symmetric(
//                     horizontal: 16, vertical: 10),
//                 decoration: BoxDecoration(
//                   border:       Border.all(color: _text),
//                   borderRadius: BorderRadius.circular(30),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: const [
//                     Icon(Icons.done_all_rounded,
//                         size: 16, color: _text),
//                     SizedBox(width: 6),
//                     Text(
//                       'Mark all read',
//                       style: TextStyle(
//                         fontSize:   13,
//                         fontWeight: FontWeight.w600,
//                         color:      _text,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   // -- Tab row ----------------------------------------------------------------

//   Widget _buildTabRow() {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 20),
//       child: Row(
//         children: [
//           _Tab(
//             label:    'All',
//             count:    _countFor(_Filter.all),
//             active:   _filter == _Filter.all,
//             onTap:    () => setState(() => _filter = _Filter.all),
//           ),
//           const SizedBox(width: 28),
//           _Tab(
//             label:    'Bookings',
//             count:    _countFor(_Filter.bookings),
//             active:   _filter == _Filter.bookings,
//             onTap:    () => setState(() => _filter = _Filter.bookings),
//           ),
//           const SizedBox(width: 28),
//           _Tab(
//             label:    'Messages',
//             count:    _countFor(_Filter.messages),
//             active:   _filter == _Filter.messages,
//             onTap:    () => setState(() => _filter = _Filter.messages),
//           ),
//         ],
//       ),
//     );
//   }

//   // -- List -------------------------------------------------------------------

//   Widget _buildList() {
//     final items = _filtered;

//     if (items.isEmpty) return _buildEmpty();

//     return ListView.builder(
//       physics:   const AlwaysScrollableScrollPhysics(),
//       padding:   EdgeInsets.zero,
//       itemCount: items.length,
//       itemBuilder: (_, i) {
//         final n = items[i];
//         return _SwipableNotificationTile(
//           notification: n,
//           onTap:        () => _markRead(n),
//           onDelete:     () => _delete(n),
//         );
//       },
//     );
//   }

//   // -- Empty state ------------------------------------------------------------

//   Widget _buildEmpty() {
//     final String label;
//     final IconData icon;

//     switch (_filter) {
//       case _Filter.bookings:
//         label = 'No booking notifications yet.\nBook a visit to see them here.';
//         icon  = Icons.event_available_outlined;
//         break;
//       case _Filter.messages:
//         label = 'No message notifications yet.';
//         icon  = Icons.chat_bubble_outline_rounded;
//         break;
//       case _Filter.all:
//         label = "You're all caught up!\nNo notifications right now.";
//         icon  = Icons.notifications_none_rounded;
//         break;
//     }

//     return ListView(
//       physics: const AlwaysScrollableScrollPhysics(),
//       children: [
//         SizedBox(
//           height: MediaQuery.of(context).size.height * 0.5,
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Container(
//                 width:  80,
//                 height: 80,
//                 decoration: BoxDecoration(
//                   color:  const Color(0xFFF0FAF4),
//                   shape:  BoxShape.circle,
//                 ),
//                 child: Icon(icon, size: 36, color: _primary),
//               ),
//               const SizedBox(height: 20),
//               Text(
//                 label,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   fontSize: 15,
//                   color:    Color(0xFF9CA3AF),
//                   height:   1.6,
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }
// }

// // -----------------------------------------------------------------------------
// //  TAB WIDGET
// // -----------------------------------------------------------------------------

// class _Tab extends StatelessWidget {
//   final String    label;
//   final int       count;
//   final bool      active;
//   final VoidCallback onTap;

//   const _Tab({
//     required this.label,
//     required this.count,
//     required this.active,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap:     onTap,
//       behavior:  HitTestBehavior.opaque,
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Row(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 label,
//                 style: TextStyle(
//                   fontSize:   16,
//                   fontWeight: active ? FontWeight.w700 : FontWeight.w500,
//                   color:      active ? _text : const Color(0xFF94A3B8),
//                 ),
//               ),
//               if (count > 0) ...[
//                 const SizedBox(width: 6),
//                 Container(
//                   height: 22,
//                   width:  22,
//                   decoration: BoxDecoration(
//                     color: active ? _unreadDot : Colors.grey.shade300,
//                     shape: BoxShape.circle,
//                   ),
//                   alignment: Alignment.center,
//                   child: Text(
//                     '$count',
//                     style: TextStyle(
//                       color:      active ? Colors.white : Colors.grey.shade600,
//                       fontSize:   11,
//                       fontWeight: FontWeight.w700,
//                     ),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//           const SizedBox(height: 8),
//           AnimatedContainer(
//             duration: const Duration(milliseconds: 200),
//             height: 3,
//             width:  active ? 80 : 0,
//             decoration: BoxDecoration(
//               color:        _unreadDot,
//               borderRadius: BorderRadius.circular(2),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // -----------------------------------------------------------------------------
// //  SWIPABLE TILE
// // -----------------------------------------------------------------------------

// class _SwipableNotificationTile extends StatelessWidget {
//   final AppNotification notification;
//   final VoidCallback    onTap;
//   final VoidCallback    onDelete;

//   const _SwipableNotificationTile({
//     required this.notification,
//     required this.onTap,
//     required this.onDelete,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Dismissible(
//       key:       ValueKey(notification.id),
//       direction: DismissDirection.endToStart,
//       background: Container(
//         alignment: Alignment.centerRight,
//         padding:   const EdgeInsets.only(right: 24),
//         color:     const Color(0xFFFFEBEE),
//         child: const Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(Icons.delete_outline_rounded,
//                 color: Color(0xFFE53935), size: 26),
//             SizedBox(height: 4),
//             Text('Delete',
//                 style: TextStyle(
//                     color: Color(0xFFE53935),
//                     fontSize: 11,
//                     fontWeight: FontWeight.w600)),
//           ],
//         ),
//       ),
//       confirmDismiss: (_) async {
//         HapticFeedback.mediumImpact();
//         return true;
//       },
//       onDismissed: (_) => onDelete(),
//       child: _NotificationTile(
//         notification: notification,
//         onTap:        onTap,
//       ),
//     );
//   }
// }

// // -----------------------------------------------------------------------------
// //  NOTIFICATION TILE
// // -----------------------------------------------------------------------------

// class _NotificationTile extends StatelessWidget {
//   final AppNotification notification;
//   final VoidCallback    onTap;

//   const _NotificationTile({
//     required this.notification,
//     required this.onTap,
//   });

//   // -- Category ? visual config -----------------------------------------------

//   static const Map<NotificationCategory, _TileStyle> _styles = {
//     NotificationCategory.booking: _TileStyle(
//       iconBg:    Color(0xFFEAF5EF),
//       iconColor: Color(0xFF1A2B40),
//       icon:      Icons.event_note_outlined,
//     ),
//     NotificationCategory.message: _TileStyle(
//       iconBg:    Color(0xFFF2ECFA),
//       iconColor: Color(0xFF7C5CE4),
//       icon:      Icons.chat_bubble_outline_rounded,
//     ),
//     NotificationCategory.offer: _TileStyle(
//       iconBg:    Color(0xFFFBEFE8),
//       iconColor: Color(0xFFF08A3E),
//       icon:      Icons.local_offer_outlined,
//     ),
//     NotificationCategory.system: _TileStyle(
//       iconBg:    Color(0xFFEAF1F9),
//       iconColor: Color(0xFF4B8BE5),
//       icon:      Icons.info_outline_rounded,
//     ),
//   };

//   // -- Relative time ----------------------------------------------------------

//   String _relativeTime(DateTime dt) {
//     final diff = DateTime.now().difference(dt);
//     if (diff.isNegative) return 'Just now';
//     if (diff.inSeconds < 60)  return 'Just now';
//     if (diff.inMinutes < 60)  return '${diff.inMinutes} min ago';
//     if (diff.inHours   < 24)  {
//       final h = diff.inHours;
//       return '$h hr${h > 1 ? 's' : ''} ago';
//     }
//     if (diff.inDays    < 2)   return 'Yesterday';
//     if (diff.inDays    < 7)   return '${diff.inDays} days ago';
//     // Older ? show date
//     const months = [
//       'Jan','Feb','Mar','Apr','May','Jun',
//       'Jul','Aug','Sep','Oct','Nov','Dec'
//     ];
//     return '${dt.day} ${months[dt.month - 1]}';
//   }

//   @override
//   Widget build(BuildContext context) {
//     final style = _styles[notification.category] ??
//         _styles[NotificationCategory.system]!;
//     final isUnread = !notification.isRead;

//     return GestureDetector(
//       onTap:     onTap,
//       behavior:  HitTestBehavior.opaque,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 250),
//         color: isUnread
//             ? const Color(0xFFF8FAFF)
//             : Colors.white,
//         child: Container(
//           decoration: const BoxDecoration(
//             border: Border(
//               bottom: BorderSide(color: Color(0xFFEEF2F7)),
//             ),
//           ),
//           padding: const EdgeInsets.symmetric(
//               horizontal: 18, vertical: 16),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Unread dot
//               if (isUnread)
//                 Padding(
//                   padding: const EdgeInsets.only(top: 8, right: 12),
//                   child: Container(
//                     height: 9,
//                     width:  9,
//                     decoration: const BoxDecoration(
//                       color: _unreadDot,
//                       shape: BoxShape.circle,
//                     ),
//                   ),
//                 )
//               else
//                 const SizedBox(width: 21), // same width as dot + gap

//               // Icon
//               Container(
//                 height: 52,
//                 width:  52,
//                 decoration: BoxDecoration(
//                   color:        style.iconBg,
//                   borderRadius: BorderRadius.circular(16),
//                 ),
//                 child: Icon(style.icon,
//                     color: style.iconColor, size: 26),
//               ),

//               const SizedBox(width: 14),

//               // Text content
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     // Title + time
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Expanded(
//                           child: Text(
//                             notification.title,
//                             style: TextStyle(
//                               fontSize:   15,
//                               fontWeight: isUnread
//                                   ? FontWeight.w700
//                                   : FontWeight.w600,
//                               color: _text,
//                             ),
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Text(
//                           _relativeTime(notification.createdAt),
//                           style: const TextStyle(
//                             fontSize: 12,
//                             color:    Color(0xFFB6BDC9),
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 5),
//                     // Body
//                     Text(
//                       notification.body,
//                       style: TextStyle(
//                         fontSize: 13,
//                         height:   1.5,
//                         color:    isUnread ? _text2 : const Color(0xFF9CA3AF),
//                       ),
//                     ),
//                     // Category chip
//                     const SizedBox(height: 8),
//                     _CategoryChip(category: notification.category),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// // -----------------------------------------------------------------------------
// //  CATEGORY CHIP
// // -----------------------------------------------------------------------------

// class _CategoryChip extends StatelessWidget {
//   final NotificationCategory category;
//   const _CategoryChip({required this.category});

//   @override
//   Widget build(BuildContext context) {
//     final Color bg;
//     final Color fg;
//     final String label;

//     switch (category) {
//       case NotificationCategory.booking:
//         bg    = const Color(0xFFEAF5EF);
//         fg    = _accent;
//         label = 'Booking';
//         break;
//       case NotificationCategory.message:
//         bg    = const Color(0xFFF2ECFA);
//         fg    = _purple;
//         label = 'Message';
//         break;
//       case NotificationCategory.offer:
//         bg    = const Color(0xFFFFF3E0);
//         fg    = _orange;
//         label = 'Offer';
//         break;
//       case NotificationCategory.system:
//         bg    = const Color(0xFFEAF1F9);
//         fg    = const Color(0xFF4B8BE5);
//         label = 'System';
//         break;
//     }

//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//       decoration: BoxDecoration(
//         color:        bg,
//         borderRadius: BorderRadius.circular(6),
//       ),
//       child: Text(
//         label,
//         style: TextStyle(
//           fontSize:   10,
//           fontWeight: FontWeight.w700,
//           color:      fg,
//           letterSpacing: 0.3,
//         ),
//       ),
//     );
//   }
// }

// // -----------------------------------------------------------------------------
// //  STYLE VALUE OBJECT
// // -----------------------------------------------------------------------------

// class _TileStyle {
//   final Color    iconBg;
//   final Color    iconColor;
//   final IconData icon;

//   const _TileStyle({
//     required this.iconBg,
//     required this.iconColor,
//     required this.icon,
//   });
// }
