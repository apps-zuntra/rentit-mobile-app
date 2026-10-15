import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────
// CONSTANTS & HELPERS
// ─────────────────────────────────────────────

const String kSupportPhone = '+91 98765 43210';
const String kSupportPhoneRaw = '+919876543210';
const String kSupportEmail = 'support@rentit.com';

Future<void> launchSupportCall({
  BuildContext? context,
  String phoneNumber = kSupportPhoneRaw,
}) async {
  final Uri uri = Uri.parse('tel:$phoneNumber');
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri);
    }
  } catch (e) {
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calling $kSupportPhone...'),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

Future<void> launchSupportEmail({
  BuildContext? context,
  String email = kSupportEmail,
  String subject = 'Rentit Support Request',
  String body = '',
}) async {
  final Uri uri = Uri(
    scheme: 'mailto',
    path: email,
    queryParameters: {
      'subject': subject,
      if (body.isNotEmpty) 'body': body,
    },
  );
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(uri);
    }
  } catch (e) {
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening email to $kSupportEmail...'),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────
// POPUP 1: TALK TO AN EXPERT BOTTOM SHEET
// ─────────────────────────────────────────────

void showTalkToExpertSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _TalkToExpertSheetContent(),
  );
}

class _TalkToExpertSheetContent extends StatelessWidget {
  const _TalkToExpertSheetContent();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle & Close button row
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      size: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Green Circle Avatar
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFD1FAF0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: Color(0xFF10B981),
              size: 30,
            ),
          ),

          const SizedBox(height: 14),

          // Title
          const Text(
            'Talk to an Expert',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              'Need help finding the right property or have questions about Rentit? Our experts are happy to help.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Working Hours Pill Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFEEF2F6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  CupertinoIcons.time,
                  size: 13.5,
                  color: Color(0xFF334155),
                ),
                SizedBox(width: 6),
                Text(
                  'Mon–Sat, 9:00 AM–7:00 PM',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Call Us Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.phone,
                    color: Color(0xFF16A34A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Call us',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        kSupportPhone,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      launchSupportCall(context: context);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    child: const Text(
                      'Call',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Email Us Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.mail,
                    color: Color(0xFF16A34A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Email us',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        kSupportEmail,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 36,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      launchSupportEmail(
                        context: context,
                        subject: 'Expert Assistance Request',
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: const Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // "Call an Expert" Main Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                launchSupportCall(context: context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Call an Expert',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // "Email instead" Button
          SizedBox(
            width: double.infinity,
            height: 40,
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                launchSupportEmail(
                  context: context,
                  subject: 'Expert Assistance Request',
                );
              },
              child: const Text(
                'Email instead',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// POPUP 2: CALL RENTIT SUPPORT BOTTOM SHEET
// ─────────────────────────────────────────────

void showCallSupportSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _CallSupportSheetContent(),
  );
}

class _CallSupportSheetContent extends StatefulWidget {
  const _CallSupportSheetContent();

  @override
  State<_CallSupportSheetContent> createState() =>
      _CallSupportSheetContentState();
}

class _CallSupportSheetContentState extends State<_CallSupportSheetContent> {
  String _selectedTopic = 'Property & Listings';

  final List<String> _topics = [
    'Property & Listings',
    'Booking & Visits',
    'Premium Plan',
    'Account & Payments',
    'Safety & Reporting',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle & Close button row
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      size: 13,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Blue Circle Phone Avatar
          Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFDBEAFE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                CupertinoIcons.phone_fill,
                color: Color(0xFF2563EB),
                size: 26,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Title
          const Center(
            child: Text(
              'Call Rentit Support',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Have an issue with your account, property, booking, or Premium plan? Our support team is ready to help.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Support Hours Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEEF2F6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Support hours',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Monday–Saturday · 9:00 AM–7:00 PM',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Typical response time: within a few minutes',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Customer Support Card
          InkWell(
            onTap: () {
              Navigator.pop(context);
              launchSupportCall(context: context);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDBEAFE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.phone,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Customer Support',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          kSupportPhone,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Email Support Card
          InkWell(
            onTap: () {
              Navigator.pop(context);
              launchSupportEmail(
                context: context,
                subject: 'Rentit Support Request: $_selectedTopic',
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDBEAFE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.mail,
                      color: Color(0xFF2563EB),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Email Support',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          kSupportEmail,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // How Can We Help? Label
          const Text(
            'How can we help?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),

          const SizedBox(height: 10),

          // Topic Chips Wrap
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _topics.map((topic) {
              final isSelected = _selectedTopic == topic;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedTopic = topic;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    topic,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // "Call Support" Main Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                launchSupportCall(context: context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text(
                'Call Support',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // "Email Support" Button
          SizedBox(
            width: double.infinity,
            height: 40,
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                launchSupportEmail(
                  context: context,
                  subject: 'Rentit Support Request: $_selectedTopic',
                );
              },
              child: const Text(
                'Email Support',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DATA MODELS FOR FAQ
// ─────────────────────────────────────────────

class FaqSection {
  final String category;
  final List<FaqItem> items;

  const FaqSection({
    required this.category,
    required this.items,
  });
}

class FaqItem {
  final String id;
  final String question;
  final String answer;

  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
  });
}

// ─────────────────────────────────────────────
// STATIC FAQ DATA (MATCHING FIGMA/UI DESIGN)
// ─────────────────────────────────────────────

const List<FaqSection> kFaqSections = [
  FaqSection(
    category: 'General',
    items: [
      FaqItem(
        id: 'gen_1',
        question: 'What is Rentit?',
        answer:
            'Rentit is a rental discovery platform that helps you find verified apartments, homes, PGs and commercial spaces, and connect directly with property owners — with no brokerage fees.',
      ),
      FaqItem(
        id: 'gen_2',
        question: 'How does Rentit help me find a property?',
        answer:
            'Rentit provides verified property listings with high-resolution photos, detailed amenities, interactive maps, and transparent pricing. You can filter by locality, budget, property type, and BHK configuration to find your ideal home easily.',
      ),
      FaqItem(
        id: 'gen_3',
        question: 'Do I need an account to browse properties?',
        answer:
            'No, you can freely browse and explore all property listings on Rentit without creating an account. However, creating an account is required to contact property owners, schedule visits, save favorite listings, and complete bookings.',
      ),
    ],
  ),
  FaqSection(
    category: 'Properties',
    items: [
      FaqItem(
        id: 'prop_1',
        question: 'How do I search for a property?',
        answer:
            'Use the search bar on the home screen to search by city, locality, or landmark. You can also use our comprehensive filters to narrow down by price range, property type (Apartment, House, PG, Commercial), BHK, and amenities.',
      ),
      FaqItem(
        id: 'prop_2',
        question: 'How can I contact a property owner?',
        answer:
            'On any property details page, tap the "Contact Owner" or "Chat" button. You can send a direct message or call the owner directly without any broker intervention.',
      ),
      FaqItem(
        id: 'prop_3',
        question: 'How do I schedule a property visit?',
        answer:
            'Open the property listing, tap "Schedule Visit", select your preferred date and time slot, and submit. The owner will be notified to confirm your visit appointment.',
      ),
    ],
  ),
  FaqSection(
    category: 'Booking',
    items: [
      FaqItem(
        id: 'book_1',
        question: 'How do I schedule a visit?',
        answer:
            'Select your desired property, click "Schedule Visit", pick an available date and time slot from the calendar, and tap confirm. You will receive instant confirmation and visit reminders.',
      ),
      FaqItem(
        id: 'book_2',
        question: 'Can I cancel a scheduled visit?',
        answer:
            'Yes, you can cancel or reschedule any upcoming visit anytime from your "Activity" tab up to 2 hours before the scheduled time without any penalty.',
      ),
      FaqItem(
        id: 'book_3',
        question: 'How do I know if a property is available?',
        answer:
            'All active listings on Rentit are continuously verified. Listings clearly indicate their availability status (Available, Booking in Progress, or Rented Out). You can also message the owner directly to reconfirm.',
      ),
    ],
  ),
  FaqSection(
    category: 'Payments',
    items: [
      FaqItem(
        id: 'pay_1',
        question: 'Does Rentit charge brokerage fees?',
        answer:
            'Zero brokerage! Rentit connects tenants and buyers directly with genuine owners, eliminating all middleman commissions and brokerage charges.',
      ),
      FaqItem(
        id: 'pay_2',
        question: 'How does the Premium plan work?',
        answer:
            'Rentit Premium gives you instant access to direct owner contact numbers, priority customer support, unlimited visit scheduling, verified property alerts, and assisted rental guidance.',
      ),
      FaqItem(
        id: 'pay_3',
        question: 'How can I manage my Premium subscription?',
        answer:
            'Go to Account → Premium Plans or Subscriptions to view your active plan, renew, upgrade, or manage billing settings at any time.',
      ),
    ],
  ),
  FaqSection(
    category: 'Account',
    items: [
      FaqItem(
        id: 'acc_1',
        question: 'How do I update my profile?',
        answer:
            'Navigate to the Account tab from the bottom navigation bar and tap "Edit Profile". Here you can update your name, profile photo, email address, phone number, and preferences.',
      ),
      FaqItem(
        id: 'acc_2',
        question: 'How do I change my contact information?',
        answer:
            'In the Account section, select "Profile" and tap on phone number or email to edit. You will be prompted to verify the change via OTP for security.',
      ),
      FaqItem(
        id: 'acc_3',
        question: 'How can I delete my account?',
        answer:
            'Go to Account → Settings → Privacy & Security → Delete Account. Please note that deleting your account permanently removes your profile, saved listings, and chat history.',
      ),
    ],
  ),
  FaqSection(
    category: 'Safety',
    items: [
      FaqItem(
        id: 'safe_1',
        question: 'How does Rentit verify listings?',
        answer:
            'Our verification team conducts on-ground checks and document validation for listings. Verified listings receive a "Verified" badge, ensuring authentic owners and accurate photos.',
      ),
      FaqItem(
        id: 'safe_2',
        question: 'How can I report a suspicious listing?',
        answer:
            'If you encounter inaccurate information, fake listings, or fraudulent behavior, tap the 3 dots menu on the property page and select "Report Listing" or contact our support team immediately.',
      ),
      FaqItem(
        id: 'safe_3',
        question: 'What should I do if I encounter a problem?',
        answer:
            'You can reach our dedicated support team via "Talk to an Expert" or "Call Support" in the Help Center. We are available 24/7 to assist you with any concerns.',
      ),
    ],
  ),
];

// ─────────────────────────────────────────────
// HELP CENTER & FAQ SCREEN
// ─────────────────────────────────────────────

class HelpAndSupportScreen extends StatefulWidget {
  final String? initialCategory;

  const HelpAndSupportScreen({super.key, this.initialCategory});

  @override
  State<HelpAndSupportScreen> createState() => _HelpAndSupportScreenState();
}

// Alias for explicit naming
typedef FaqHelpCenterScreen = HelpAndSupportScreen;

class _HelpAndSupportScreenState extends State<HelpAndSupportScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _expandedIds = {'gen_1'}; // First FAQ expanded by default
  String _selectedCategory = 'General';
  String _searchQuery = '';

  final List<String> _categories = [
    'General',
    'Properties',
    'Booking',
    'Payments',
    'Account',
    'Safety',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null &&
        _categories.contains(widget.initialCategory)) {
      _selectedCategory = widget.initialCategory!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleExpand(String id) {
    setState(() {
      if (_expandedIds.contains(id)) {
        _expandedIds.remove(id);
      } else {
        _expandedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<FaqSection> visibleSections = [];

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      for (final sec in kFaqSections) {
        final filteredItems = sec.items.where((item) {
          return item.question.toLowerCase().contains(q) ||
              item.answer.toLowerCase().contains(q);
        }).toList();

        if (filteredItems.isNotEmpty) {
          visibleSections.add(
            FaqSection(
              category: sec.category,
              items: filteredItems,
            ),
          );
        }
      }
    } else {
      visibleSections = kFaqSections;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
            child: GestureDetector(
              onTap: () => Navigator.maybePop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Icon(
                  CupertinoIcons.chevron_back,
                  size: 18,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          'Help Center',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HERO TITLE & SUBTITLE ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'How can we help?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Find quick answers to common questions about renting, properties, bookings, payments, and your Rentit account.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            // ── SEARCH INPUT ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 14),
                    const Icon(
                      CupertinoIcons.search,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search FAQs',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            CupertinoIcons.clear_circled_solid,
                            size: 18,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── TOP "NEED MORE HELP?" CARD ────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: _buildHelpCard(
                title: 'Need more help?',
                subtitle: 'Our experts are here to help you find the right answer.',
              ),
            ),

            // ── CATEGORY FILTER CHIPS ────────────────────────────────
            const SizedBox(height: 18),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedCategory = cat;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 16),

            // ── SECTIONS & FAQ ACCORDIONS ─────────────────────────────
            if (visibleSections.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 40,
                ),
                child: Center(
                  child: Column(
                    children: const [
                      Icon(
                        CupertinoIcons.search,
                        size: 40,
                        color: Color(0xFF94A3B8),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No questions found',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Try searching with different keywords',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...visibleSections.map((section) {
                if (_searchQuery.isEmpty &&
                    _selectedCategory != 'General' &&
                    section.category != _selectedCategory) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // Section Header
                      Text(
                        section.category.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Section Items
                      ...section.items.map((item) {
                        final isExpanded = _expandedIds.contains(item.id);
                        return Column(
                          children: [
                            InkWell(
                              onTap: () => _toggleExpand(item.id),
                              splashColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item.question,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0F172A),
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        AnimatedRotation(
                                          turns: isExpanded ? 0.5 : 0.0,
                                          duration:
                                              const Duration(milliseconds: 200),
                                          child: const Icon(
                                            CupertinoIcons.chevron_down,
                                            size: 16,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    AnimatedCrossFade(
                                      firstChild: const SizedBox.shrink(),
                                      secondChild: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 10,
                                          bottom: 4,
                                          right: 8,
                                        ),
                                        child: Text(
                                          item.answer,
                                          style: const TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF475569),
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                      crossFadeState: isExpanded
                                          ? CrossFadeState.showSecond
                                          : CrossFadeState.showFirst,
                                      duration:
                                          const Duration(milliseconds: 200),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(
                              height: 1,
                              thickness: 1,
                              color: Color(0xFFF1F5F9),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                );
              }),

            // ── BOTTOM "STILL CAN'T FIND WHAT YOU'RE LOOKING FOR?" CARD ───
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
              child: _buildHelpCard(
                title: "Still can't find what you're looking for?",
                subtitle: 'Talk to our support team and we\'ll help you out.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HELP CARD WIDGET (TALK TO EXPERT / CALL SUPPORT)
  // ─────────────────────────────────────────────

  Widget _buildHelpCard({
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: () => showTalkToExpertSheet(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Talk to an Expert',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: OutlinedButton(
                    onPressed: () => showCallSupportSheet(context),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E293B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      'Call Support',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
