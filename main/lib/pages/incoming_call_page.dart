import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../helpers/funciones.dart';
import '../helpers/style.dart';
import '../providers/call_provider.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../main.dart';

class IncomingCallPage extends StatefulWidget {
  final String callerName;
  final String? callerAvatar;
  final bool isVideoCall;

  const IncomingCallPage({
    Key? key,
    required this.callerName,
    this.callerAvatar,
    required this.isVideoCall,
  }) : super(key: key);

  @override
  _IncomingCallPageState createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends State<IncomingCallPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Haptic feedback on incoming call
    HapticFeedback.mediumImpact();

    // Pulsing animation for avatar
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Check if this call came from FCM notification or should auto-accept
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final autoAccept = args?['autoAccept'] == true;
      final fromFCM = args?['fromFCM'] == true;
      
      if (args != null && (fromFCM || autoAccept)) {
        // Initialize CallProvider with FCM data
        final callProvider = Provider.of<CallProvider>(context, listen: false);
        final socketService = Provider.of<SocketService>(context, listen: false);
        final authService = Provider.of<AuthService>(context, listen: false);
        
        // Initialize if not already
        if (!callProvider.isInitialized) {
          callProvider.initialize(socketService, authService, navigatorKey);
          // Wait a bit for initialization
          await Future.delayed(const Duration(milliseconds: 200));
        }
        
        // Ensure socket is connected
        if (socketService.socket == null || !socketService.socket!.connected) {
          debugPrint('[IncomingCallPage] Socket not connected, attempting to connect...');
          socketService.connect();
          // Wait for connection
          int attempts = 0;
          while (attempts < 20 && (socketService.socket == null || !socketService.socket!.connected)) {
            await Future.delayed(const Duration(milliseconds: 250));
            attempts++;
          }
        }
        
        // Handle the incoming call from FCM
        callProvider.handleIncomingCallFromFCM({
          'callerId': args['callerId'],
          'callerName': args['callerName'] ?? widget.callerName,
          'callerAvatar': args['callerAvatar'] ?? widget.callerAvatar,
          'isVideoCall': args['isVideoCall'] ?? widget.isVideoCall,
          'sdp': args['sdp'],
          'rtcType': args['rtcType'],
        });
        
        // If autoAccept is true, automatically accept the call
        if (autoAccept) {
          debugPrint('[IncomingCallPage] Auto-accepting call...');
          try {
            // Accept the call
            await callProvider.acceptCall();
            
            // Wait for call to connect
            int attempts = 0;
            while (attempts < 30 && callProvider.callState != CallState.connected) {
              await Future.delayed(const Duration(milliseconds: 500));
              attempts++;
            }
            
            // Navigate to active call page
            if (mounted) {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                'activeCall',
                arguments: {
                  'isVideoCall': widget.isVideoCall,
                },
              );
            }
          } catch (e) {
            debugPrint('[IncomingCallPage] Error auto-accepting call: $e');
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final callProvider = Provider.of<CallProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black,
                Colors.grey[900]!,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 100),
              // Caller Avatar with pulsing animation
              AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: primary,
                          width: 4,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 100,
                        backgroundImage: widget.callerAvatar != null
                            ? AssetImage(
                                getAvatar(widget.callerAvatar!, 'user_'))
                            : null,
                        child: widget.callerAvatar == null
                            ? const Icon(
                                Icons.person,
                                size: 100,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              // Caller Name
              Text(
                capitalize(widget.callerName),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              // Call Type
              Text(
                widget.isVideoCall ? 'Video Call' : 'Audio Call',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 100),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject Button
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      callProvider.rejectCall();
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      child: const Icon(
                        Icons.call_end,
                        color: Colors.white,
                        size: 35,
                      ),
                    ),
                  ),
                  // Accept Button
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await callProvider.acceptCall();
                      Navigator.pop(context);
                      Navigator.pushNamed(
                        context,
                        'activeCall',
                        arguments: {
                          'isVideoCall': widget.isVideoCall,
                        },
                      );
                    },
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green,
                      ),
                      child: const Icon(
                        Icons.call,
                        color: Colors.white,
                        size: 35,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
