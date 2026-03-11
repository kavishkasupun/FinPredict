import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hintText;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final bool obscureText;
  final String? Function(String?)? validator;
  final int maxLines;
  final Function(String)? onChanged;
  final Function(bool)? onFocusChange;
  final FocusNode? focusNode;
  final Function(String)? onSubmitted; // ADD THIS LINE

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hintText,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.obscureText = false,
    this.validator,
    this.maxLines = 1,
    this.onChanged,
    this.onFocusChange,
    this.focusNode,
    this.onSubmitted, // ADD THIS LINE
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Only show label if it's not empty
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Focus(
          onFocusChange: onFocusChange,
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            obscureText: obscureText,
            maxLines: maxLines,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.send, // Better UX for chat
            onFieldSubmitted:
                onSubmitted, // ADD THIS LINE - Connect to TextFormField
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: const Color(0xFF94A3B8))
                  : null,
              suffixIcon: suffixIcon != null
                  ? IconButton(
                      icon: Icon(suffixIcon, color: const Color(0xFF94A3B8)),
                      onPressed: onSuffixIconPressed,
                    )
                  : null,
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFFFBA002), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFEF4444)),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: onChanged,
            validator: validator,
          ),
        ),
      ],
    );
  }
}
