import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'pin_service.dart';

/// Écran de déverrouillage par code PIN (4 chiffres).
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({
    super.key,
    required this.onUnlocked,
    required this.pinService,
  });

  final VoidCallback onUnlocked;
  final PinService pinService;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _entered = '';
  String? _error;

  Future<void> _push(String digit) async {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit;
      _error = null;
    });

    if (_entered.length == 4) {
      final bool ok = await widget.pinService.verify(_entered);
      if (ok) {
        widget.onUnlocked();
      } else {
        setState(() {
          _error = 'Code incorrect.';
          _entered = '';
        });
      }
    }
  }

  void _backspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('💰', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 12),
              const Text(
                'Entre ton code',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (int i = 0; i < 4; i++)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _entered.length
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        border: Border.all(color: context.borderColor),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 24,
                child: Text(
                  _error ?? '',
                  style: TextStyle(color: context.dangerColor, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                childAspectRatio: 1.5,
                children: <Widget>[
                  for (int i = 1; i <= 9; i++)
                    _Key(label: '$i', onTap: () => _push('$i')),
                  const SizedBox.shrink(),
                  _Key(label: '0', onTap: () => _push('0')),
                  _Key(
                    icon: Icons.backspace_outlined,
                    onTap: _backspace,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: context.borderColor),
            borderRadius: BorderRadius.circular(16),
          ),
          child: icon != null
              ? Icon(icon, size: 20)
              : Text(
                  label!,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}
