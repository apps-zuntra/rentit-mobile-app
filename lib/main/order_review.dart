import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'payment_success_screen.dart';

const String _kBase = "https://rentit-backend-yti9.onrender.com";
const Color kTextSub = Color(0xFF5A6A7A);
const Color kTextMuted = Color(0xFF9BAAB8);

class OrderReviewPage extends StatefulWidget {
  final String planName;
  final String planPrice;
  final int planAmount;
  final String planPeriod;
  final String planType; // basic, premium, premium+
  final String propType;
  final bool isBuyer;
  final List<Map<String, dynamic>> features;

  const OrderReviewPage({
    super.key,
    required this.planName,
    required this.planPrice,
    required this.planAmount,
    required this.planPeriod,
    required this.planType,
    required this.propType,
    this.isBuyer = false,
    required this.features,
  });

  @override
  State<OrderReviewPage> createState() => _OrderReviewPageState();
}

class _OrderReviewPageState extends State<OrderReviewPage> {
  late Razorpay _rp;
  bool _paying = false;
  Map<String, dynamic>? _meta;

  bool _boostListing = false;
  bool _aiVideo = false;
  String _selectedCity = 'Chennai';

  @override
  void initState() {
    super.initState();
    _rp = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _onOk)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _onErr)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
  }

  @override
  void dispose() {
    _rp.clear();
    super.dispose();
  }

  int get _boostListingPrice {
    if (widget.propType == 'Housing' && widget.planType == 'basic') return 1500;
    return 750;
  }

  int get _totalAmount {
    int total = widget.planAmount;
    if (widget.isBuyer) {
      if (_boostListing) total += 75; // Extra 2 contacts addon
    } else {
      if (_boostListing) total += _boostListingPrice;
      if (_aiVideo) total += 2000;
    }
    return total;
  }

  // ── Payment Logic ────────────────────────────────────────────────────────
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

  Future<void> _buy() async {
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
        body: jsonEncode({'amount': _totalAmount}),
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
        'planType': widget.planType,
        'amount': _totalAmount,
        'propertyType': widget.propType,
      };
      final prefill = await _getUserPrefill();
      _rp.open({
        'key': 'rzp_live_SRoJY9zxg1WtPH',
        'amount': orderAmount,
        'order_id': orderId,
        'name': 'Rentit',
        'description': '${widget.planName} Plan + Add-ons',
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
        final prefs = await SharedPreferences.getInstance();
        int days = 30;
        final match = RegExp(r'(\d+)').firstMatch(widget.planPeriod);
        if (match != null) {
          days = int.parse(match.group(1)!);
        }
        final expiry = DateTime.now().add(Duration(days: days));
        if (widget.isBuyer) {
          await prefs.setString('active_buyer_plan_name', widget.planName);
          await prefs.setString('active_buyer_plan_prop', widget.propType);
          await prefs.setString(
            'active_buyer_plan_expiry',
            expiry.toIso8601String(),
          );
        } else {
          await prefs.setString('active_plan_name', widget.planName);
          await prefs.setString('active_plan_type', widget.planType);
          await prefs.setString('active_plan_prop', widget.propType);
          await prefs.setString('active_plan_expiry', expiry.toIso8601String());
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PaymentSuccessScreen(isBuyer: widget.isBuyer),
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
        backgroundColor: err
            ? const Color(0xFFDC2626)
            : const Color(0xFF2F4253),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── UI ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    Color borderColor;
    Color tagColor;
    String tagText;

    if (widget.planType == 'basic') {
      borderColor = const Color(0xFF10B981); // green
      tagColor = const Color(0xFF10B981);
      tagText = 'BASIC';
    } else if (widget.planType == 'premium') {
      borderColor = const Color(0xFF8B5CF6); // purple
      tagColor = const Color(0xFF8B5CF6);
      tagText = 'PREMIUM';
    } else {
      borderColor = const Color(0xFFF59E0B); // gold/orange
      tagColor = const Color(0xFFF59E0B);
      tagText = 'PREMIUM+';
    }

    final includedFeatures = widget.features
        .where((f) => f['included'] == true)
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text(
          'Order Review',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
            children: [
              // Info Alert
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      CupertinoIcons.info_circle,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 13.5,
                            color: Color(0xFF1E293B),
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            TextSpan(
                              text:
                                  'You have no active buy listing currently!\n',
                            ),
                            TextSpan(
                              text: 'Upload Listing Now',
                              style: TextStyle(color: Color(0xFF3B82F6)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Selected Plan Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor, width: 1.5),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: tagColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tagText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              widget.planPrice,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'Best Value',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: tagColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${widget.propType[0].toUpperCase()}${widget.propType.substring(1)} – ${widget.planName}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      runSpacing: 10,
                      children: includedFeatures.map((f) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              CupertinoIcons.checkmark_alt,
                              color: Color(0xFF10B981),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              f['text'],
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (widget.isBuyer) ...[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Optional Add-ons',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildAddonCard(
                  title: 'Extra 2 contacts',
                  subtitle: 'Owner Contacts',
                  price: '₹75',
                  icon: CupertinoIcons.person_2_fill,
                  iconColor: const Color(0xFF6366F1), // Indigo
                  iconBg: const Color(0xFFE0E7FF),
                  selected:
                      _boostListing, // reusing variable for Extra Contacts
                  onToggle: () =>
                      setState(() => _boostListing = !_boostListing),
                ),
                const SizedBox(height: 20),
              ] else ...[
                // Boost Your Response Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Boost Your Response',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Text(
                      'Optional Add-ons',
                      style: TextStyle(
                        fontSize: 12,
                        color: kTextMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Boost Listing Card
                _buildAddonCard(
                  title: 'Boost Listing',
                  subtitle: 'Photoshoot',
                  price: '₹$_boostListingPrice',
                  icon: CupertinoIcons.rocket_fill,
                  iconColor: const Color(0xFFF97316),
                  iconBg: const Color(0xFFFFEDD5),
                  selected: _boostListing,
                  onToggle: () =>
                      setState(() => _boostListing = !_boostListing),
                ),
                const SizedBox(height: 12),

                // AI Video Card
                _buildAddonCard(
                  title: 'AI video',
                  subtitle:
                      '• Social media ad campaign\n• Reusable video link\n• Opportunity to post property\n  on Rentit\'s official social media\n  channels',
                  price: '₹2,000',
                  icon: CupertinoIcons.play_rectangle_fill,
                  iconColor: const Color(0xFF3B82F6),
                  iconBg: const Color(0xFFDBEAFE),
                  selected: _aiVideo,
                  onToggle: () => setState(() => _aiVideo = !_aiVideo),
                ),
                const SizedBox(height: 20),
              ],

              // Billing City
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.location_solid,
                      color: kTextMuted,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Billing City',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Spacer(),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCity,
                        icon: const Icon(CupertinoIcons.chevron_down, size: 16),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        items: ['Chennai', 'Bangalore', 'Hyderabad', 'Mumbai']
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedCity = v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Sticky Bottom Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFFE2E8F0).withOpacity(0.5),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _paying ? null : _buy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF281A45),
                    disabledBackgroundColor: const Color(
                      0xFF281A45,
                    ).withOpacity(0.5),
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
                          'Confirm & Pay ₹${_totalAmount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddonCard({
    required String title,
    required String subtitle,
    required String price,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required bool selected,
    required VoidCallback onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? const Color(0xFF281A45) : const Color(0xFFE2E8F0),
          width: selected ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onToggle,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFF281A45) : Colors.white,
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF281A45)
                          : const Color(0xFFCBD5E1),
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    selected
                        ? CupertinoIcons.checkmark_alt
                        : CupertinoIcons.add,
                    size: 16,
                    color: selected ? Colors.white : const Color(0xFF64748B),
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
