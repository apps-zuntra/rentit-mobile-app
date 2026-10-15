// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';
// import 'ApartmentVerify.dart';

// class PostPropertyContactScreen extends StatefulWidget {
//   const PostPropertyContactScreen({super.key});

//   @override
//   State<PostPropertyContactScreen> createState() =>
//       _PostPropertyContactScreenState();
// }

// class _PostPropertyContactScreenState extends State<PostPropertyContactScreen> {
//   final String baseUrl = "https://rentit-backend-yti9.onrender.com";

//   bool loading = false;

//   final TextEditingController contactNameController = TextEditingController();
//   final TextEditingController mobileController = TextEditingController();

//   String repliesWithin = "";
//   bool whatsapp = false;

//   /// SAVE CONTACT DETAILS
//   Future<void> handleVerify() async {
//     final prefs = await SharedPreferences.getInstance();
//     final propertyId = prefs.getInt("propertyId");
//     final token = prefs.getString("token");

//     if (propertyId == null) {
//       _showMsg("Property ID missing");
//       return;
//     }

//     if (contactNameController.text.trim().isEmpty) {
//       _showMsg("Contact Name is required");
//       return;
//     }

//     if (!RegExp(r'^[0-9]{10}$').hasMatch(mobileController.text)) {
//       _showMsg("Enter valid 10 digit mobile number");
//       return;
//     }

//     try {
//       setState(() => loading = true);

//       final response = await http.put(
//         Uri.parse("$baseUrl/property/$propertyId/contact"),
//         headers: {
//           "Content-Type": "application/json",
//           "Authorization": "Bearer $token",
//         },
//         body: jsonEncode({
//           "contactName": contactNameController.text.trim(),
//           "mobileNo": mobileController.text,
//           "repliesWithin": repliesWithin.isNotEmpty ? repliesWithin : null,
//           "whatsapp": whatsapp,
//         }),
//       );

//       if (response.statusCode == 200 || response.statusCode == 201) {
//         Navigator.push(
//           context,
//           MaterialPageRoute(builder: (_) => const PostPropertyVerifyScreen()),
//         );
//       } else {
//         final data = jsonDecode(response.body);
//         _showMsg(data["message"] ?? "Failed to save contact details");
//       }
//     } catch (e) {
//       _showMsg("Something went wrong");
//     } finally {
//       setState(() => loading = false);
//     }
//   }

//   void _showMsg(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Contact Details"),
//         backgroundColor: const Color(0xFF0F766E),
//       ),

//       body: Padding(
//         padding: const EdgeInsets.all(20),

//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             /// CONTACT NAME
//             const Text("Contact Name *"),

//             const SizedBox(height: 5),

//             TextField(
//               controller: contactNameController,
//               decoration: const InputDecoration(
//                 hintText: "Enter your name",
//                 border: OutlineInputBorder(),
//               ),
//             ),

//             const SizedBox(height: 20),

//             /// MOBILE NUMBER
//             const Text("Mobile No *"),

//             const SizedBox(height: 5),

//             TextField(
//               controller: mobileController,
//               keyboardType: TextInputType.number,
//               maxLength: 10,
//               decoration: const InputDecoration(
//                 hintText: "Enter your number",
//                 border: OutlineInputBorder(),
//                 counterText: "",
//               ),
//             ),

//             const SizedBox(height: 20),

//             /// REPLIES WITHIN
//             const Text("Replies within"),

//             const SizedBox(height: 5),

//             DropdownButtonFormField<String>(
//               value: repliesWithin.isEmpty ? null : repliesWithin,
//               items: const [
//                 DropdownMenuItem(
//                   value: "Within 1 hour",
//                   child: Text("Within 1 hour"),
//                 ),
//                 DropdownMenuItem(
//                   value: "Within 3 hours",
//                   child: Text("Within 3 hours"),
//                 ),
//                 DropdownMenuItem(
//                   value: "Within 24 hours",
//                   child: Text("Within 24 hours"),
//                 ),
//               ],
//               onChanged: (value) {
//                 setState(() {
//                   repliesWithin = value ?? "";
//                 });
//               },
//               decoration: const InputDecoration(
//                 border: OutlineInputBorder(),
//                 hintText: "Select",
//               ),
//             ),

//             const SizedBox(height: 20),

//             /// WHATSAPP CHECKBOX
//             Row(
//               children: [
//                 Checkbox(
//                   value: whatsapp,
//                   onChanged: (value) {
//                     setState(() {
//                       whatsapp = value ?? false;
//                     });
//                   },
//                 ),
//                 const Text("Get Updates on WhatsApp"),
//               ],
//             ),

//             const SizedBox(height: 30),

//             /// VERIFY BUTTON
//             SizedBox(
//               width: double.infinity,
//               height: 50,
//               child: ElevatedButton(
//                 onPressed: loading ? null : handleVerify,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF0F766E),
//                 ),
//                 child: Text(
//                   loading ? "Saving..." : "Verify",
//                   style: const TextStyle(fontSize: 16),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
