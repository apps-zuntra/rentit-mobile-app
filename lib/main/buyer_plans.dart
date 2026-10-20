// buyer_plans.dart
// Design: Clean, minimal, typographically precise.
// Primary brand: #2F4253 (navy slate), New Brand UI colors applied.

import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:rentit/screen/nav/mainnavigationscreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'order_review.dart';
import 'dart:async';
import 'package:rentit/main/Help&Support.dart';

// ── Tokens ────────────────────────────────────────────────────────────────────
const Color kPrimary = Color(0xFF2F4253); // brand navy
const Color kPrimaryMid = Color(0xFF3D5166); // slightly lighter navy
const Color kAccent = Color(0xFF1EB6A8); // teal highlight
const Color kAccentTint = Color(0xFFE8F9F7); // teal wash
const Color kBg = Color(0xFFF7F8FA); // off-white page
const Color kCard = Color(0xFFFFFFFF); // card surface
const Color kBorder = Color(0xFFEAECF0); // dividers
const Color kText = Color(0xFF1C2B3A); // primary text
const Color kTextSub = Color(0xFF5A6A7A); // secondary text
const Color kTextMuted = Color(0xFF9BAAB8); // muted / placeholder
const Color kGreen = Color(0xFF16A34A);
const Color kGreenTint = Color(0xFFDCFCE7);
const Color kBlue = Color(0xFF2563EB);
const Color kBlueTint = Color(0xFFEFF6FF);
const Color kPurple = Color(0xFF7C3AED);
const Color kPurpleTint = Color(0xFFF5F3FF);
const Color kOrange = Color(0xFFEA580C);
const Color kOrangeTint = Color(0xFFFFF7ED);
const Color kRed = Color(0xFFDC2626);

const String _kBase = "https://rentit-backend-omega.vercel.app";

// ── Plan data ─────────────────────────────────────────────────────────────────
class _PlanFeature {
  final String text;
  final bool included;
  const _PlanFeature(this.text, this.included);
}

class _Plan {
  final String key;
  final String name;
  final String subtitle;
  final String price;
  final int amount;
  final String period;
  final String? tag;
  final Color color;
  final Color colorTint;
  final IconData icon;
  final List<_PlanFeature> features;
  final String planType;
  final String propType;

  const _Plan({
    required this.key,
    required this.name,
    required this.subtitle,
    required this.price,
    required this.amount,
    required this.period,
    this.tag,
    required this.color,
    required this.colorTint,
    required this.icon,
    required this.features,
    required this.planType,
    required this.propType,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────
class BuyerPlansScreen extends StatefulWidget {
  const BuyerPlansScreen({super.key});
  @override
  State<BuyerPlansScreen> createState() => _BuyerPlansScreenState();
}

class _BuyerPlansScreenState extends State<BuyerPlansScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  late final Razorpay _rp;

  int _ci = 1; // commercial selected index
  int _ai = 1; // apartment selected index
  int _pi = 0; // pg selected index
  bool _paying = false;
  Map<String, dynamic>? _meta;

  String? _activePlanName;
  String? _activePlanProp;
  DateTime? _activePlanExpiry;

  Timer? _timer;
  int _timeLeft = 300;

  // ── Commercial plans ──────────────────────────────────────────────────────
  static const _commercial = <_Plan>[
    _Plan(
      key: 'bc0',
      name: 'Basic',
      subtitle: '90 Days · 25 Contacts',
      price: '₹1,099',
      amount: 1099,
      period: '90 Days',
      color: kBlue,
      colorTint: kBlueTint,
      icon: CupertinoIcons.bolt,
      features: [
        _PlanFeature('25 owner contacts', true),
        _PlanFeature('Advanced filters', true),
        _PlanFeature('Interior design consultation', false),
        _PlanFeature('Property info on WhatsApp', false),
        _PlanFeature('Property posted date info', false),
      ],
      planType: 'basic',
      propType: 'commercial',
    ),
    _Plan(
      key: 'bc1',
      name: 'Premium',
      subtitle: '45 Days · 50 Contacts',
      price: '₹2,599',
      amount: 2599,
      period: '45 Days',
      color: kAccent,
      colorTint: kAccentTint,
      icon: CupertinoIcons.star,
      features: [
        _PlanFeature('50 owner contacts', true),
        _PlanFeature('Advanced filters', true),
        _PlanFeature('Interior design consultation', true),
        _PlanFeature('Property info on WhatsApp', false),
        _PlanFeature('Property posted date info', false),
      ],
      planType: 'premium',
      propType: 'commercial',
    ),
    _Plan(
      key: 'bc2',
      name: 'Premium+',
      subtitle: '45 Days · VIP Access',
      price: '₹4,599',
      amount: 4599,
      period: '45 Days',
      tag: 'MOST POPULAR',
      color: kPurple,
      colorTint: kPurpleTint,
      icon: CupertinoIcons.rocket,
      features: [
        _PlanFeature('50 owner contacts', true),
        _PlanFeature('Advanced filters', true),
        _PlanFeature('Interior design consultation', true),
        _PlanFeature('Property info on WhatsApp', true),
        _PlanFeature('Property posted date info', true),
      ],
      planType: 'premium+',
      propType: 'commercial',
    ),
  ];

  // ── Apartment plans ────────────────────────────────────────────────────────
  static const _apartment = <_Plan>[
    _Plan(
      key: 'ba0',
      name: 'Basic',
      subtitle: '45 Days · 20 Contacts',
      price: '₹1,449',
      amount: 1449,
      period: '45 Days',
      color: kBlue,
      colorTint: kBlueTint,
      icon: CupertinoIcons.bolt,
      features: [
        _PlanFeature('20 owner contacts', true),
        _PlanFeature('Advanced filters', true),
        _PlanFeature('Interior design consultation', false),
        _PlanFeature('Property info on WhatsApp', false),
        _PlanFeature('Property posted date info', false),
      ],
      planType: 'basic',
      propType: 'Housing',
    ),
    _Plan(
      key: 'ba1',
      name: 'Premium',
      subtitle: '60 Days · 50 Contacts',
      price: '₹3,499',
      amount: 3499,
      period: '60 Days',
      color: kAccent,
      colorTint: kAccentTint,
      icon: CupertinoIcons.star,
      features: [
        _PlanFeature('50 owner contacts', true),
        _PlanFeature('Advanced filters', true),
        _PlanFeature('Interior design consultation', true),
        _PlanFeature('Property info on WhatsApp', false),
        _PlanFeature('Property posted date info', false),
      ],
      planType: 'premium',
      propType: 'Housing',
    ),
    _Plan(
      key: 'ba2',
      name: 'Premium+',
      subtitle: '60 Days · VIP Access',
      price: '₹4,499',
      amount: 4499,
      period: '60 Days',
      tag: 'MOST POPULAR',
      color: kPurple,
      colorTint: kPurpleTint,
      icon: CupertinoIcons.rocket,
      features: [
        _PlanFeature('50 owner contacts', true),
        _PlanFeature('Advanced filters', true),
        _PlanFeature('Interior design consultation', true),
        _PlanFeature('Property info on WhatsApp', true),
        _PlanFeature('Property posted date info', true),
      ],
      planType: 'premium+',
      propType: 'Housing',
    ),
  ];

  // ── PG plans ─────────────────────────────────────────────────────────────
  static const _pg = <_Plan>[
    _Plan(
      key: 'bp0',
      name: 'Basic',
      subtitle: '15 Days Validity',
      price: '₹799',
      amount: 799,
      period: '15 Days',
      color: kBlue,
      colorTint: kBlueTint,
      icon: CupertinoIcons.bolt,
      features: [
        _PlanFeature('10 owner contacts', true),
        _PlanFeature('Advanced filters', true),
        _PlanFeature('Property info on WhatsApp', false),
        _PlanFeature('Property posted date info', false),
      ],
      planType: 'basic',
      propType: 'PG',
    ),
    _Plan(
      key: 'bp1',
      name: 'Premium',
      subtitle: '30 Days Validity',
      price: '₹899',
      amount: 899,
      period: '30 Days',
      tag: 'MOST POPULAR',
      color: kPurple,
      colorTint: kPurpleTint,
      icon: CupertinoIcons.rocket,
      features: [
        _PlanFeature('25 owner contacts', true),
        _PlanFeature('Advanced filters', true),
        _PlanFeature('Property info on WhatsApp', true),
        _PlanFeature('Property posted date info', true),
      ],
      planType: 'premium',
      propType: 'PG',
    ),
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _rp = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onOk)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onErr)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);

    _loadActivePlan();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          _timeLeft = 300;
        }
      });
    });
  }

  Future<void> _loadActivePlan() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryStr = prefs.getString('active_buyer_plan_expiry');
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && expiry.isAfter(DateTime.now())) {
        setState(() {
          _activePlanName = prefs.getString('active_buyer_plan_name');
          _activePlanProp = prefs.getString('active_buyer_plan_prop');
          _activePlanExpiry = expiry;
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tab.dispose();
    _rp.clear();
    super.dispose();
  }

  // ── Payment ───────────────────────────────────────────────────────────────
  Future<String?> _tok() async =>
      (await SharedPreferences.getInstance()).getString('token');

  Future<Map<String, String>> _getUserPrefill() async {
    final prefs = await SharedPreferences.getInstance();
    final phone =
        prefs.getString('phone') ??
        prefs.getString('mobile') ??
        prefs.getString('contact') ??
        '';
    final email = prefs.getString('email') ?? '';
    return {'contact': phone, 'email': email};
  }

  Future<void> _buy(_Plan p) async {
    if (_paying) return;
    setState(() => _paying = true);
    try {
      final tok = await _tok();
      if (tok == null) {
        _toast('Please log in to continue.', err: true);
        return;
      }
      final res = await http.post(
        Uri.parse('$_kBase/payment/create-order'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tok',
        },
        body: jsonEncode({'amount': p.amount}),
      );
      if (res.statusCode != 200 && res.statusCode != 201) {
        _toast(
          'Could not create order (${res.statusCode}). Please try again.',
          err: true,
        );
        return;
      }
      final d = jsonDecode(res.body) as Map<String, dynamic>;
      final orderId = d['id'] as String?;
      final orderAmount = d['amount'];
      if (orderId == null || orderAmount == null) {
        _toast('Invalid order response from server.', err: true);
        return;
      }
      _meta = {
        'planType': p.planType,
        'amount': p.amount,
        'propertyType': _tab.index == 0
            ? 'commercial'
            : (_tab.index == 1 ? 'apartment' : 'pg'),
      };
      final prefill = await _getUserPrefill();
      _rp.open({
        'key': 'rzp_live_SRoJY9zxg1WtPH',
        'amount': orderAmount,
        'order_id': orderId,
        'name': 'Rentit',
        'description': '${p.name} Plan · ${p.period}',
        'prefill': prefill,
        'theme': {'color': '#281A45'},
        'retry': {'enabled': true, 'max_count': 3},
      });
    } catch (e) {
      _toast('Something went wrong: ${e.toString()}', err: true);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _onOk(PaymentSuccessResponse r) async {
    _toast('Verifying payment…');
    try {
      final tok = await _tok();
      final verifyRes = await http.post(
        Uri.parse('$_kBase/payment/verify'),
        headers: {
          'Content-Type': 'application/json',
          if (tok != null) 'Authorization': 'Bearer $tok',
        },
        body: jsonEncode({
          'razorpay_order_id': r.orderId,
          'razorpay_payment_id': r.paymentId,
          'razorpay_signature': r.signature,
          ...?_meta,
        }),
      );
      if (verifyRes.statusCode == 200 || verifyRes.statusCode == 201) {
        _toast('Payment successful Plan activated!');
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const MainNavigationScreen(),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        }
      } else {
        final body = jsonDecode(verifyRes.body);
        _toast(
          'Verification failed: ${body['message'] ?? verifyRes.statusCode}',
          err: true,
        );
      }
    } catch (e) {
      _toast('Verification error: ${e.toString()}', err: true);
    }
  }

  void _onErr(PaymentFailureResponse r) {
    final msg = r.message ?? 'Payment failed';
    final code = r.code ?? 0;
    _toast('Payment failed (code $code): $msg', err: true);
  }

  void _onWallet(ExternalWalletResponse r) {
    _toast('External wallet selected: ${r.walletName}');
  }

  void _toast(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
        ),
        backgroundColor: err ? kRed : kPrimary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleBack() {
    if (!mounted) return;
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainNavigationScreen(),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final activeList = _tab.index == 0
        ? _commercial
        : (_tab.index == 1 ? _apartment : _pg);
    final activeIndex = _tab.index == 0 ? _ci : (_tab.index == 1 ? _ai : _pi);
    final activePlan = activeList[activeIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Stack(
        children: [
          Column(
            children: [
              _header(),
              _tabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _sheet(
                      _commercial,
                      _ci,
                      (i) => setState(() => _ci = i),
                      'Rental ',
                      'Find your ideal commercial space with verified owner contacts',
                    ),
                    _sheet(
                      _apartment,
                      _ai,
                      (i) => setState(() => _ai = i),
                      'Rental ',
                      'Get Premium to unlock more owner contacts and interior design consultation',
                    ),
                    _sheet(
                      _pg,
                      _pi,
                      (i) => setState(() => _pi = i),
                      'Rental ',
                      'Find the perfect PG and connect with owners instantly',
                    ),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _stickyBottomBar(activeList, activeIndex, (i) {
              setState(() {
                if (_tab.index == 0)
                  _ci = i;
                else if (_tab.index == 1)
                  _ai = i;
                else
                  _pi = i;
              });
            }),
          ),
        ],
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────
  Widget _header() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _handleBack,
                child: Container(
                  height: 38,
                  width: 38,
                  decoration: const BoxDecoration(
                    color: kBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: Colors.black,
                  ),
                ),
              ),
              const Text(
                'Rental Pricing Plans',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HelpAndSupportScreen(),
                    ),
                  );
                },
                child: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: kBorder),
                  ),
                  child: const Icon(
                    CupertinoIcons.question,
                    size: 18,
                    color: Color(0xFF635BFF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── TAB BAR ───────────────────────────────────────────────────────────────
  Widget _tabBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kBorder, width: 0.5),
        ),
        child: TabBar(
          controller: _tab,
          onTap: (index) {
            setState(() {});
          },
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(4),
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          tabs: const [
            Tab(text: 'Commercial'),
            Tab(text: 'Apartment'),
            Tab(text: 'PG'),
          ],
        ),
      ),
    );
  }

  // ── SCROLLABLE SHEET ──────────────────────────────────────────────────────
  Widget _sheet(
    List<_Plan> plans,
    int idx,
    ValueChanged<int> onSel,
    String prefix,
    String subtitle,
  ) {
    final activePlan = plans[idx];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 220),
      children: [
        RichText(
          text: TextSpan(
            text: prefix,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF635BFF),
              letterSpacing: -0.5,
            ),
            children: const [
              TextSpan(
                text: 'Pricing Plans',
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: kTextSub, height: 1.4),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF281A45),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Flash Sale! Save 45% extra',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(_timeLeft ~/ 60).toString().padLeft(2, '0')}:${(_timeLeft % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: Color(0xFF281A45),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'CHOOSE YOUR PLAN',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: kTextMuted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(
          plans.length,
          (i) => _planSelectionCard(plans[i], i == idx, () => onSel(i)),
        ),
        const SizedBox(height: 24),
        _featuresCard(activePlan),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── PLAN SELECTION CARD ───────────────────────────────────────────────────
  Widget _planSelectionCard(_Plan p, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sel ? const Color(0xFF281A45) : kBorder,
            width: sel ? 2.0 : 1.0,
          ),
          boxShadow: sel
              ? [
                  BoxShadow(
                    color: const Color(0xFF281A45).withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              height: 20,
              width: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: sel
                      ? const Color(0xFF281A45)
                      : kBorder.withOpacity(0.8),
                  width: sel ? 6.0 : 1.5,
                ),
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.subtitle,
                    style: const TextStyle(fontSize: 11, color: kTextSub),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (p.tag != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF635BFF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      p.tag!.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
                Text(
                  p.price,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── FEATURES CARD ─────────────────────────────────────────────────────────
  Widget _featuresCard(_Plan p) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF281A45),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Text(
              'Rentit ${p.name}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: p.features
                  .map((f) => _featureCheckRow(f.text, f.included))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureCheckRow(String text, bool included) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            height: 16,
            width: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: included ? kGreenTint : kBg,
            ),
            child: Icon(
              included ? CupertinoIcons.checkmark_alt : CupertinoIcons.xmark,
              size: 10,
              color: included ? kGreen : kTextMuted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                color: included ? Colors.black87 : kTextMuted,
                fontWeight: included ? FontWeight.w500 : FontWeight.w400,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BOTTOM PLAN SELECTOR ──────────────────────────────────────────────────
  Widget _bottomPlanSelector(
    List<_Plan> plans,
    int activeIdx,
    ValueChanged<int> onSel,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(plans.length, (i) {
          final p = plans[i];
          final sel = i == activeIdx;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSel(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.black : kTextMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.price}/${p.period}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: sel ? const Color(0xFF635BFF) : kTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── STICKY BOTTOM BAR ─────────────────────────────────────────────────────
  Widget _stickyBottomBar(
    List<_Plan> plans,
    int activeIdx,
    ValueChanged<int> onSel,
  ) {
    final p = plans[activeIdx];
    final isActive = _activePlanName == p.name && _activePlanProp == p.propType;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorder.withOpacity(0.5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _bottomPlanSelector(plans, activeIdx, onSel),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isActive
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderReviewPage(
                            planName: p.name,
                            planPrice: p.price,
                            planAmount: p.amount,
                            planPeriod: p.period,
                            planType: p.planType,
                            propType: p.propType,
                            isBuyer: true,
                            features: p.features
                                .map(
                                  (e) => {
                                    'text': e.text,
                                    'included': e.included,
                                  },
                                )
                                .toList(),
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF281A45),
                disabledBackgroundColor: isActive
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF281A45).withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: _paying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isActive
                          ? 'Current Plan (Active)'
                          : '${p.name == 'Premium+' ? 'Start Premium+' : p.name} · ${p.price} / ${p.period}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Cancel anytime · No hidden fees',
            style: TextStyle(
              fontSize: 12,
              color: kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
