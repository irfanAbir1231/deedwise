part of '../main.dart';

String cloudError(Object error) {
  if (error is CloudFailure) return error.message;
  if (error is PostgrestException) {
    if (error.code == 'PGRST202' ||
        error.code == 'PGRST205' ||
        error.code == '42P01') {
      return 'Cloud setup is not ready yet. Please try later.';
    }
    if (error.code == '42501') {
      return 'You do not have permission for this action. Sign in and try again.';
    }
    if (error.code == 'P0001' || error.code == '22023') return error.message;
  }
  if (error is AuthException) {
    return 'Sign-in could not be completed. Please try again.';
  }
  return 'Could not connect. Check your internet connection and try again.';
}

class BackendSession extends ChangeNotifier {
  SupabaseClient? client;
  StreamSubscription<AuthState>? _subscription;
  Future<void> _queue = Future<void>.value();
  bool ready = false, changingAccount = false;
  String? userId, error, identityError;
  bool get configured => BackendConfig.environment.configured;
  bool get signedIn =>
      ready && userId != null && !changingAccount && identityError == null;
  GroupRepository get groups => SupabaseGroupRepository(client!);
  ProfileRepository get profiles => SupabaseProfileRepository(client!);
  Future<void> initialize() async {
    if (!configured || ready) return;
    BackendConfig.environment.validate();
    if (client == null) {
      await Supabase.initialize(
        url: BackendConfig.environment.url,
        publishableKey: BackendConfig.environment.publishableKey,
        debug: false,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      client = Supabase.instance.client;
    }
    await _changeUser(client!.auth.currentUser?.id);
    _subscription ??= client!.auth.onAuthStateChange.listen(
      (state) {
        final next = state.session?.user.id;
        if (next == userId && !changingAccount) return;
        changingAccount = true;
        notifyListeners();
        _queue = _queue.then((_) => _changeUser(next)).catchError((Object e) {
          error = cloudError(e);
          identityError = error;
          changingAccount = false;
          notifyListeners();
        });
      },
      onError: (Object e) {
        error = cloudError(e);
        notifyListeners();
      },
    );
    ready = true;
    notifyListeners();
  }

  Future<void> _changeUser(String? next) async {
    changingAccount = true;
    identityError = null;
    notifyListeners();
    try {
      await localData.switchAccount(next);
      userId = next;
      error = null;
      if (next != null) {
        try {
          final profile = await profiles.ensure();
          store.name = profile.name;
          await localData.flush();
        } catch (e) {
          error = cloudError(e);
        }
      }
      store.changed();
      if (ready) rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    } catch (e) {
      identityError = cloudError(e);
      rethrow;
    } finally {
      changingAccount = false;
      notifyListeners();
    }
  }

  Future<void> retryIdentity() async {
    try {
      await _changeUser(client?.auth.currentUser?.id);
    } catch (_) {
      /* The blocking startup screen retains the error and retry. */
    }
  }

  Future<void> signIn() async {
    if (!ready) {
      throw const CloudFailure(
        'Cloud connection is not available in this build.',
      );
    }
    final launched = await client!.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'deedwise://login-callback/',
    );
    if (!launched) {
      throw const CloudFailure(
        'Could not open Google sign-in. Please try again.',
      );
    }
  }

  Future<void> signOut() async {
    if (client == null) return;
    // Clear the local session even if a network outage prevents global revocation.
    await client!.auth.signOut(scope: SignOutScope.local);
    await _queue;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class BackendAccountGate extends StatelessWidget {
  const BackendAccountGate({super.key});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: backend,
    builder: (context, _) =>
        backend.signedIn ? AppShell(key: appShellKey) : const CloudLoginPage(),
  );
}

class CloudLoginPage extends StatefulWidget {
  const CloudLoginPage({super.key});
  @override
  State<CloudLoginPage> createState() => _CloudLoginPageState();
}

class _CloudLoginPageState extends State<CloudLoginPage> {
  bool busy = false;
  String? error;
  Future<void> signIn() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await backend.signIn();
    } catch (e) {
      if (mounted) setState(() => error = cloudError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: brandCream,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Brand(),
                  const SizedBox(height: 48),
                  const BrandMark(size: 88),
                  const SizedBox(height: 30),
                  Text('Your good starts here.', style: editorial(35)),
                  const SizedBox(height: 16),
                  const Text(
                    'Sign in to your DeedWise account to record your day and connect with your circles.',
                    style: TextStyle(color: muted, fontSize: 15, height: 1.6),
                  ),
                  const SizedBox(height: 30),
                  FilledButton.icon(
                    onPressed: busy || !backend.ready ? null : signIn,
                    icon: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login_rounded),
                    label: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Center(
                          child: Text(
                            busy ? 'Opening Google…' : 'Continue with Google',
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (error != null || backend.error != null) ...[
                    const SizedBox(height: 16),
                    NoteBox(error ?? backend.error!),
                  ],
                  const SizedBox(height: 22),
                  const Text(
                    'Your private deeds and photos stay on this device for now. Group sharing is always your choice.',
                    style: TextStyle(color: muted, fontSize: 12, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class CloudAccountPanel extends StatefulWidget {
  const CloudAccountPanel({super.key});
  @override
  State<CloudAccountPanel> createState() => _CloudAccountPanelState();
}

class _CloudAccountPanelState extends State<CloudAccountPanel> {
  bool busy = false;
  String? message;
  Future<void> act(Future<void> Function() action) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) setState(() => message = cloudError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: backend,
    builder: (context, _) => Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            backend.signedIn ? 'Your account' : 'Keep your circle connected',
            style: editorial(23),
          ),
          const SizedBox(height: 10),
          Text(
            backend.signedIn
                ? 'Signed in. Your groups are connected.'
                : backend.configured
                ? 'Sign in with Google to create or join a real group.'
                : 'Cloud connection is not available in this build. Your private device records are still available.',
            style: const TextStyle(color: muted, height: 1.5),
          ),
          if (backend.configured || backend.signedIn) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: busy || backend.changingAccount
                  ? null
                  : () => act(
                      backend.signedIn ? backend.signOut : backend.signIn,
                    ),
              icon: Icon(backend.signedIn ? Icons.logout : Icons.login),
              label: Text(
                busy
                    ? 'Please wait…'
                    : backend.signedIn
                    ? 'Log out'
                    : 'Continue with Google',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Private deeds and photos stay on this device for now. They are kept separately for each account.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
          if (message != null || backend.error != null) ...[
            const SizedBox(height: 10),
            Text(
              message ?? backend.error!,
              style: const TextStyle(color: Color(0xFF9B413C)),
            ),
          ],
        ],
      ),
    ),
  );
}
