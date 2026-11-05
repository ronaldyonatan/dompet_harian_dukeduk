// import 'package:flutter/material.dart';
// import '../helpers/localization_helper.dart';
// import 'login_screen.dart';

// class SettingsScreen extends StatelessWidget {
//   final String currentLanguage;
//   final Function(String) onLanguageChanged;

//   const SettingsScreen({
//     super.key,
//     required this.currentLanguage,
//     required this.onLanguageChanged,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final t = AppLocalizations(currentLanguage);

//     return Scaffold(
//       backgroundColor: const Color(0xFFF8FAFC),
//       appBar: AppBar(
//         title: Text(t.translate('settings'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//         backgroundColor: const Color(0xFF1A237E),
//         foregroundColor: Colors.white,
//         elevation: 0,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(20.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Container(
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(20),
//                 border: Border.all(color: Colors.grey.shade200),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(t.translate('language'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
//                   const SizedBox(height: 12),
//                   Row(
//                     children: [
//                       Expanded(
//                         child: RadioListTile<String>(
//                           title: const Text('Bahasa Indonesia', style: TextStyle(fontSize: 13)),
//                           value: 'id',
//                           groupValue: currentLanguage,
//                           onChanged: (val) {
//                             if (val != null) onLanguageChanged(val);
//                           },
//                         ),
//                       ),
//                       Expanded(
//                         child: RadioListTile<String>(
//                           title: const Text('English', style: TextStyle(fontSize: 13)),
//                           value: 'en',
//                           groupValue: currentLanguage,
//                           onChanged: (val) {
//                             if (val != null) onLanguageChanged(val);
//                           },
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//             const Spacer(),
//             ElevatedButton.icon(
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.red.shade50,
//                 foregroundColor: Colors.red.shade700,
//                 elevation: 0,
//                 padding: const EdgeInsets.symmetric(vertical: 14),
//                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//               ),
//               onPressed: () {
//                 Navigator.pushReplacement(
//                   context,
//                   MaterialPageRoute(builder: (context) => const LoginScreen()),
//                 );
//               },
//               icon: const Icon(Icons.logout_rounded),
//               label: Text(t.translate('logout'), style: const TextStyle(fontWeight: FontWeight.bold)),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
