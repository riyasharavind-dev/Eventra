import 'package:flutter/material.dart';

class ServiceActionBar extends StatelessWidget {
  final VoidCallback onAddToPlan;
  final VoidCallback onBookService;

  const ServiceActionBar({
    super.key,
    required this.onAddToPlan,
    required this.onBookService,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          12,
          10,
          12,
          10,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: 0.10,
              ),
              blurRadius: 12,
              offset: const Offset(
                0,
                -3,
              ),
            ),
          ],
        ),
        child: Row(
          children: [
            // ==================================================
            // ADD TO PLAN
            // ==================================================

            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton(
                  onPressed: onAddToPlan,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: Colors.grey.shade400,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Add to Plan',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // ==================================================
            // BOOK SERVICE
            // ==================================================

            Expanded(
              child: SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: onBookService,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xFFFFD600),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Book Service',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}