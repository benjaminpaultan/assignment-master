import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final supabase = Supabase.instance.client;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();

  DateTime? _dob;
  String _gender = 'Male';

  bool _loading = false;

  Future<void> _register() async {
    if (_passwordCtrl.text != _confirmCtrl.text) {
      _error('Passwords do not match');
      return;
    }

    if (_usernameCtrl.text.trim().isEmpty) {
      _error('Username is required');
      return;
    }

    if (_dob == null) {
      _error('Please select date of birth');
      return;
    }

    setState(() => _loading = true);

    try {
      // 🔐 CREATE AUTH USER
      final res = await supabase.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      final user = res.user;
      if (user == null) {
        throw 'User creation failed';
      }

      // 👤 CREATE / UPDATE PROFILE (id is primary key → avoid duplicate key error)
      await supabase.from('profiles').upsert(
        {
          'id': user.id,
          'email': _emailCtrl.text.trim(),
          'username': _usernameCtrl.text.trim(),
          'date_of_birth': _dob!
              .toIso8601String()
              .split('T')[0], // YYYY-MM-DD
          'gender': _gender,
          'role': 'member',
        },
        onConflict: 'id',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Check your email to verify your account'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      _error(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 📧 EMAIL
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),

            // 👤 USERNAME
            TextField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 16),

            // 🔑 PASSWORD
            TextField(
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),

            // 🔑 CONFIRM
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
            ),
            const SizedBox(height: 16),

            // 🎂 DATE OF BIRTH
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _dob == null
                    ? 'Select Date of Birth'
                    : _dob!.toIso8601String().split('T')[0],
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(1900),
                  lastDate: DateTime.now(),
                  initialDate: DateTime(2000),
                );
                if (picked != null) {
                  setState(() => _dob = picked);
                }
              },
            ),

            const SizedBox(height: 16),

            // 🚻 GENDER
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
              ],
              onChanged: (v) => setState(() => _gender = v!),
            ),

            const SizedBox(height: 30),

            // ✅ REGISTER BUTTON
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _register,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Register'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
