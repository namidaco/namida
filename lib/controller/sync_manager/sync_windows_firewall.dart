part of 'sync_manager.dart';

// by claude
class _SyncWindowsFirewall {
  _SyncWindowsFirewall._();

  static const _kRulesStateScript = r'''
$rules = @(Get-NetFirewallApplicationFilter -Program '{exe}' -ErrorAction SilentlyContinue | Get-NetFirewallRule | Where-Object { $_.Direction -eq 'Inbound' -and $_.Enabled -eq 'True' })
$isAllowed = ($rules | Where-Object Action -eq 'Allow') -and -not ($rules | Where-Object Action -eq 'Block')
if ($isAllowed) { 'allowed' } else { 'blocked' }
''';

  // -- same rule name as the installer, so uninstalling removes it too
  static const _kAllowScript = r'''
$exe = '{exe}'
Get-NetFirewallApplicationFilter -Program $exe -ErrorAction SilentlyContinue | Get-NetFirewallRule | Where-Object Direction -eq 'Inbound' | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName 'Namida' -Direction Inbound -Program $exe -Action Allow -Profile Any | Out-Null
''';

  static const _kElevateScript = r'''
try { Start-Process powershell -Verb RunAs -WindowStyle Hidden -Wait -ArgumentList '-NoProfile', '-NonInteractive', '-EncodedCommand', '{script}' } catch {}
''';

  static final _exePath = Platform.resolvedExecutable.replaceAll("'", "''");

  /// blocked when no enabled inbound rule allows namida, or one blocks it. null when it couldn't be checked.
  static Future<bool?> isBlocking() async {
    final script = _kRulesStateScript.replaceFirst('{exe}', _exePath);
    try {
      final state = await SyncUtils._runPowershell(script);
      return switch (state) {
        'allowed' => false,
        'blocked' => true,
        _ => null,
      };
    } catch (_) {
      return null;
    }
  }

  /// replaces namida's inbound rules with one allowing it, behind a uac prompt.
  static Future<void> allow() async {
    final allowScript = _kAllowScript.replaceFirst('{exe}', _exePath);
    final encodedAllowScript = SyncUtils._encodePowershell(allowScript);
    final elevateScript = _kElevateScript.replaceFirst('{script}', encodedAllowScript);
    await SyncUtils._runPowershell(elevateScript, timeout: const Duration(minutes: 2));
  }
}
