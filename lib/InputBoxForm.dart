import 'package:flutter/material.dart';

class InputBoxForForm extends StatelessWidget {
  const InputBoxForForm({
    super.key,
    required this.w,
    required this.h,
    required this.obscure,
    required TextEditingController passController,
    required this.message,
  }) : _passController = passController;

  final double w;
  final double h;
  final bool obscure;
  final TextEditingController _passController;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 0.7 * w,
      height: 0.07 * h,
      child: TextFormField(
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontFamily: 'Montserrat',
          fontWeight: FontWeight.w600,
        ),
        obscureText: obscure,
        controller: _passController,
        // The validator receives the text that the user has entered.
        decoration: InputDecoration(
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(32.0),
            borderSide: const BorderSide(
                color: Colors.black, width: 1.3),
          ),
          labelText: message,
          labelStyle: const TextStyle(
            color: Colors.black,
            fontSize: 14,
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w600,
          ),
          contentPadding: EdgeInsets.symmetric(
             // Adjust this value to increase/decrease height
            horizontal: 16.0,
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter some text';
          }
          return null;
        },
      ),
    );
  }
}
