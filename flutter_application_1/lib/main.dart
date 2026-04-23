import 'package:flutter/material.dart';
import 'package:nfc_manager/nfc_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NFC Attendance',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const NfcScreen(),
    );
  }
}

class NfcScreen extends StatefulWidget {
  const NfcScreen({super.key});

  @override
  State<NfcScreen> createState() => _NfcScreenState();
}

class _NfcScreenState extends State<NfcScreen> {
  String nfcStatus = "NFC STATUS: WAITING";
  final TextEditingController nameController = TextEditingController();
  List<String> attendanceList = [];

  void _registerTag() async {
    if (nameController.text.isEmpty) {
      setState(() => nfcStatus = "Sila masukkan nama dahulu!");
      return;
    }

    setState(() => nfcStatus = "NFC IS IN WRITE MODE\n(Sila tap tag anda)");

    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      setState(() => nfcStatus = "NFC tidak disokong pada peranti ini.");
      return;
    }

    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      var ndef = Ndef.from(tag);
      if (ndef == null || !ndef.isWritable) {
        NfcManager.instance.stopSession(errorMessage: 'Tag tidak boleh ditulis');
        setState(() => nfcStatus = "Tag dikunci / bukan NDEF");
        return;
      }

      try {
        NdefMessage message = NdefMessage([
          NdefRecord.createText(nameController.text),
        ]);
        await ndef.write(message);
        NfcManager.instance.stopSession();
        setState(() {
          nfcStatus = "Registered: ${nameController.text}";
          nameController.clear();
        });
      } catch (e) {
        NfcManager.instance.stopSession(errorMessage: 'Ralat penulisan');
        setState(() => nfcStatus = "Ralat: Gagal menulis ke tag");
      }
    });
  }

  void _takeAttendance() async {
    setState(() => nfcStatus = "READ MODE\n(Sila tap tag anda)");

    bool isAvailable = await NfcManager.instance.isAvailable();
    if (!isAvailable) {
      setState(() => nfcStatus = "NFC tidak disokong.");
      return;
    }

    NfcManager.instance.startSession(onDiscovered: (NfcTag tag) async {
      var ndef = Ndef.from(tag);
      if (ndef == null) {
        NfcManager.instance.stopSession(errorMessage: 'Bukan tag NDEF');
        setState(() => nfcStatus = "Bukan tag berformat NDEF");
        return;
      }

      final record = ndef.cachedMessage?.records.first;
      if (record != null) {
        // Buang 3 aksara pertama (prefix bahasa kod NDEF)
        String studentName = String.fromCharCodes(record.payload).substring(3); 
        
        NfcManager.instance.stopSession();
        
        setState(() {
          nfcStatus = "Berjaya baca tag!";
          if (!attendanceList.contains(studentName)) {
            attendanceList.add(studentName);
          }
        });
      } else {
        NfcManager.instance.stopSession();
        setState(() => nfcStatus = "Tag kosong. Sila daftar dahulu.");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sistem Kehadiran NFC")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(nfcStatus, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 30),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Nama Pelajar Untuk Didaftar',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: _registerTag, child: const Text("Register Tag")),
                ElevatedButton(onPressed: _takeAttendance, child: const Text("Take Attendance")),
              ],
            ),
            const Divider(height: 40, thickness: 2),
            const Text("Senarai Kehadiran:", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: attendanceList.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.check_circle, color: Colors.green),
                    title: Text(attendanceList[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}