// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:shared_preferences/shared_preferences.dart';

// class PGProvideInformation extends StatefulWidget {
//   const PGProvideInformation({super.key});

//   @override
//   State<PGProvideInformation> createState() => _PGProvideInformationState();
// }

// class _PGProvideInformationState extends State<PGProvideInformation> {
//   final String API_BASE = "https://rentit-backend-omega.vercel.app";

//   String placeFor = "";
//   String preferredGuest = "";
//   String availableFrom = "";
//   String foodIncluded = "";
//   List<String> foodOptions = [];

//   String gateClosing = "";
//   String description = "";

//   late TextEditingController availableFromController;
//   late TextEditingController gateClosingController;

//   Map<String, bool> rules = {
//     "noSmoking": false,
//     "noGuardians": false,
//     "noDrinking": false,
//     "noNonVeg": false,
//     "noGirlsEntry": false,
//   };

//   bool loading = false;

//   @override
//   void initState() {
//     super.initState();
//     availableFromController = TextEditingController();
//     gateClosingController = TextEditingController();
//   }

//   @override
//   void dispose() {
//     availableFromController.dispose();
//     gateClosingController.dispose();
//     super.dispose();
//   }

//   Future<void> handleSubmit() async {
//     final prefs = await SharedPreferences.getInstance();
//     final propertyId = prefs.getInt("propertyId")?.toString();
//     final token = prefs.getString("token");

//     if (propertyId == null) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Property ID missing")));
//       return;
//     }

//     if (availableFrom.isEmpty) {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(const SnackBar(content: Text("Select Available From")));
//       return;
//     }

//     setState(() => loading = true);

//     final payload = {
//       "placeisavailablefor": placeFor.isNotEmpty ? [placeFor] : [],
//       "preferredTenant": preferredGuest.isNotEmpty ? [preferredGuest] : [],
//       "availableFrom": availableFrom, // YYYY-MM-DD
//       "foodIncluded": foodIncluded == "Yes",
//       "gateClosingTime": gateClosing, // HH:mm
//       "rulesAndRegulation": rules.entries
//           .where((e) => e.value == true) // Only selected rules
//           .map((e) => e.key) // Take key names
//           .join(", "), // Convert to string      "description": description,
//       "foodType": foodOptions,
//     };

//     print("=== FINAL PAYLOAD ===");
//     print(jsonEncode(payload));

//     final res = await http.put(
//       Uri.parse("$API_BASE/property/$propertyId/amenities"),
//       headers: {
//         "Content-Type": "application/json",
//         "Authorization": "Bearer $token",
//       },
//       body: jsonEncode(payload),
//     );

//     setState(() => loading = false);

//     if (res.statusCode == 200) {
//       Navigator.pushNamed(context, "/pgAdditionalDetails");
//     } else {
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Error: ${res.body}")));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("PG Details � Provide Info")),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             _sectionTitle("Place is available for *"),
//             _radioGroup(
//               ["Male", "Female", "Anyone"],
//               placeFor,
//               (val) => setState(() => placeFor = val),
//             ),

//             _sectionTitle("Preferred Guests *"),
//             DropdownButtonFormField(
//               value: preferredGuest.isNotEmpty ? preferredGuest : null,
//               items: [
//                 "Students",
//                 "Working Professionals",
//                 "Anyone",
//               ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
//               onChanged: (val) => setState(() => preferredGuest = val!),
//             ),

//             _sectionTitle("Available From *"),
//             TextFormField(
//               readOnly: true,
//               decoration: const InputDecoration(hintText: "Select Date"),
//               controller: availableFromController,
//               onTap: () async {
//                 final picked = await showDatePicker(
//                   context: context,
//                   firstDate: DateTime(2020),
//                   lastDate: DateTime(2035),
//                   initialDate: DateTime.now(),
//                 );

//                 if (picked != null) {
//                   final date =
//                       "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";

//                   setState(() {
//                     availableFrom = date;
//                     availableFromController.text = date;
//                   });
//                 }
//               },
//             ),

//             _sectionTitle("Food Included *"),
//             _radioGroup(
//               ["Yes", "No"],
//               foodIncluded,
//               (val) => setState(() => foodIncluded = val),
//             ),

//             if (foodIncluded == "Yes")
//               Column(
//                 children: [
//                   _sectionTitle("Food Options"),
//                   _checkbox("Breakfast"),
//                   _checkbox("Lunch"),
//                   _checkbox("Dinner"),
//                 ],
//               ),

//             _sectionTitle("Gate Closing Time"),
//             TextFormField(
//               readOnly: true,
//               decoration: const InputDecoration(hintText: "Select Time"),
//               controller: gateClosingController,
//               onTap: () async {
//                 final time = await showTimePicker(
//                   context: context,
//                   initialTime: TimeOfDay.now(),
//                 );

//                 if (time != null) {
//                   final formatted =
//                       "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

//                   setState(() {
//                     gateClosing = formatted;
//                     gateClosingController.text = formatted;
//                   });
//                 }
//               },
//             ),

//             _sectionTitle("PG Rules"),
//             ...rules.entries.map(
//               (e) => CheckboxListTile(
//                 title: Text(e.key),
//                 value: e.value,
//                 onChanged: (val) => setState(() => rules[e.key] = val ?? false),
//               ),
//             ),

//             _sectionTitle("Description"),
//             TextFormField(
//               maxLines: 4,
//               decoration: const InputDecoration(hintText: "Write details..."),
//               onChanged: (v) => description = v,
//             ),

//             const SizedBox(height: 20),

//             ElevatedButton(
//               onPressed: loading ? null : handleSubmit,
//               child: Text(loading ? "Saving..." : "Save & Continue ?"),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _sectionTitle(String text) => Padding(
//     padding: const EdgeInsets.only(top: 18, bottom: 8),
//     child: Text(text),
//   );

//   Widget _radioGroup(
//     List<String> items,
//     String groupValue,
//     Function(String) onChange,
//   ) {
//     return Column(
//       children: items
//           .map(
//             (e) => RadioListTile(
//               title: Text(e),
//               value: e,
//               groupValue: groupValue,
//               onChanged: (val) => onChange(val!),
//             ),
//           )
//           .toList(),
//     );
//   }

//   Widget _checkbox(String label) {
//     final selected = foodOptions.contains(label);
//     return CheckboxListTile(
//       title: Text(label),
//       value: selected,
//       onChanged: (val) {
//         setState(() {
//           if (selected) {
//             foodOptions.remove(label);
//           } else {
//             foodOptions.add(label);
//           }
//         });
//       },
//     );
//   }
// }
