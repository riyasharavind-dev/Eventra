import 'package:flutter/material.dart';

import '../../models/support_model.dart';
import 'support_ui.dart';

class SupportTicketTile extends StatelessWidget {
  const SupportTicketTile({
    super.key,
    required this.ticket,
    required this.onTap,
  });
  final SupportTicket ticket;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final done = ticket.status == 'resolved' || ticket.status == 'closed';
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.all(16),
      title: Text(
        ticket.subject,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF17171B),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          '${ticket.reference} · ${supportDate(ticket.createdAt)}\n${ticket.category}',
          style: const TextStyle(
            fontSize: 12,
            height: 1.6,
            color: Color(0xFF73737D),
          ),
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        constraints: const BoxConstraints(maxWidth: 100),
        decoration: BoxDecoration(
          color: done ? const Color(0xFFEAF5EE) : const Color(0xFFFFF4DF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          ticket.statusLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: done ? const Color(0xFF267349) : const Color(0xFF945C00),
          ),
        ),
      ),
    );
  }
}
