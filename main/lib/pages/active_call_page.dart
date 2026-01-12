import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import '../helpers/funciones.dart';
import '../helpers/style.dart';
import '../providers/call_provider.dart';

class ActiveCallPage extends StatefulWidget {
  final bool isVideoCall;

  const ActiveCallPage({Key? key, required this.isVideoCall}) : super(key: key);

  @override
  _ActiveCallPageState createState() => _ActiveCallPageState();
}

class _ActiveCallPageState extends State<ActiveCallPage> {
  RTCVideoRenderer? _localRenderer;
  RTCVideoRenderer? _remoteRenderer;
  bool _isInitialized = false;
  CallProvider?
      _callProvider; // Store reference to avoid accessing context in dispose

  @override
  void initState() {
    super.initState();
    _initializeRenderers();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Store provider reference safely before dispose
    _callProvider = Provider.of<CallProvider>(context, listen: false);
    
    // Listen for call state changes to handle call ended
    _callProvider?.addListener(_onCallStateChanged);
  }

  Future<void> _initializeRenderers() async {
    _localRenderer = RTCVideoRenderer();
    _remoteRenderer = RTCVideoRenderer();

    await _localRenderer!.initialize();
    await _remoteRenderer!.initialize();

    // Use stored reference or get it from context
    _callProvider ??= Provider.of<CallProvider>(context, listen: false);

    // Attach streams to renderers
    if (_callProvider!.localStream != null) {
      _localRenderer!.srcObject = _callProvider!.localStream;
    }

    if (_callProvider!.remoteStream != null) {
      _remoteRenderer!.srcObject = _callProvider!.remoteStream;
    }

    // Listen for stream changes
    _callProvider!.addListener(_onStreamChanged);

    setState(() {
      _isInitialized = true;
    });
  }

  void _onStreamChanged() {
    if (_callProvider == null) return;

    if (_localRenderer != null && _callProvider!.localStream != null) {
      _localRenderer!.srcObject = _callProvider!.localStream;
    }

    if (_remoteRenderer != null && _callProvider!.remoteStream != null) {
      _remoteRenderer!.srcObject = _callProvider!.remoteStream;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _onCallStateChanged() {
    if (_callProvider == null || !mounted) return;

    // When call state becomes ended, show ended screen and navigate back after delay
    if (_callProvider!.callState == CallState.ended) {
      setState(() {});
      
      // Navigate back after showing "Call Ended" screen for 2 seconds
      // This matches the delay in CallProvider before state resets to idle
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  String _getCallStatusText(CallState state, bool isCaller) {
    switch (state) {
      case CallState.calling:
        return isCaller ? 'Calling...' : 'Incoming call...';
      case CallState.ringing:
        return isCaller ? 'Ringing...' : 'Ringing...';
      case CallState.connected:
        // Show "Connecting..." briefly when just connected, then duration
        return 'Connected';
      case CallState.ended:
        return 'Call ended';
      case CallState.idle:
        return '';
    }
  }

  /// Build connection quality indicator (signal bars)
  Widget _buildConnectionQualityIndicator() {
    // Simple indicator - can be enhanced with actual WebRTC stats
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.signal_cellular_alt,
            color: Colors.green,
            size: 16,
          ),
          SizedBox(width: 4),
          Text(
            'HD',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Use stored reference instead of accessing context (which is unsafe in dispose)
    _callProvider?.removeListener(_onStreamChanged);
    _callProvider?.removeListener(_onCallStateChanged);

    _localRenderer?.dispose();
    _remoteRenderer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use stored reference if available, otherwise get from context
    final callProvider = _callProvider ?? Provider.of<CallProvider>(context);

    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        _callProvider?.endCall();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Video/Audio Display
              if (widget.isVideoCall && callProvider.remoteStream != null)
                // Remote video (full screen)
                RTCVideoView(
                  _remoteRenderer!,
                  mirror: false,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                // Audio call - show avatar
                Container(
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
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 80,
                          backgroundImage: callProvider.otherPartyAvatar != null
                              ? AssetImage(getAvatar(
                                  callProvider.otherPartyAvatar!, 'user_'))
                              : null,
                          child: callProvider.otherPartyAvatar == null
                              ? const Icon(
                                  Icons.person,
                                  size: 80,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          capitalize(callProvider.otherPartyName ?? 'Unknown'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Show call status or duration
                        Text(
                          callProvider.callState == CallState.connected
                              ? _formatDuration(callProvider.callDuration)
                              : _getCallStatusText(callProvider.callState,
                                  callProvider.isCaller),
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 18,
                            fontWeight: callProvider.callState == CallState.ringing 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                        // Show "Connecting..." when transitioning from ringing to connected
                        if (callProvider.callState == CallState.connected && callProvider.callDuration.inSeconds < 2)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'Connecting...',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // Local video (picture-in-picture for video calls)
              if (widget.isVideoCall && callProvider.localStream != null)
                Positioned(
                  top: 40,
                  right: 20,
                  child: Container(
                    width: 120,
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: RTCVideoView(
                        _localRenderer!,
                        mirror: true,
                        objectFit:
                            RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),

              // Call status/duration and connection quality (for video calls)
              if (widget.isVideoCall)
                Positioned(
                  top: 40,
                  left: 20,
                  child: Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              callProvider.callState == CallState.connected
                                  ? _formatDuration(callProvider.callDuration)
                                  : _getCallStatusText(callProvider.callState,
                                      callProvider.isCaller),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            // Show "Connecting..." when just connected
                            if (callProvider.callState == CallState.connected && callProvider.callDuration.inSeconds < 2)
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  'Connecting...',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Connection quality indicator
                      if (callProvider.callState == CallState.connected)
                        Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: _buildConnectionQualityIndicator(),
                        ),
                    ],
                  ),
                ),

              // Control buttons (bottom) - only show if call is not ended
              if (callProvider.callState != CallState.ended)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Control buttons row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mute button
                        _buildControlButton(
                          icon:
                              callProvider.isMuted ? Icons.mic_off : Icons.mic,
                          color: callProvider.isMuted
                              ? Colors.red
                              : Colors.white70,
                          onTap: () => callProvider.toggleMute(),
                        ),

                        // Video toggle (only for video calls)
                        if (widget.isVideoCall)
                          _buildControlButton(
                            icon: callProvider.isVideoEnabled
                                ? Icons.videocam
                                : Icons.videocam_off,
                            color: callProvider.isVideoEnabled
                                ? Colors.white70
                                : Colors.red,
                            onTap: () => callProvider.toggleVideo(),
                          ),

                        // Speaker button
                        _buildControlButton(
                          icon: callProvider.isSpeakerEnabled
                              ? Icons.volume_up
                              : Icons.volume_down,
                          color: callProvider.isSpeakerEnabled
                              ? primary
                              : Colors.white70,
                          onTap: () => callProvider.toggleSpeaker(),
                        ),

                        // End call button
                        _buildControlButton(
                          icon: Icons.call_end,
                          color: Colors.red,
                          size: 60,
                          onTap: () {
                            callProvider.endCall();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Call Ended overlay
              if (callProvider.callState == CallState.ended)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.9),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.call_end,
                            color: Colors.white,
                            size: 80,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Call Ended',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (callProvider.callDuration.inSeconds > 0)
                            Text(
                              'Duration: ${_formatDuration(callProvider.callDuration)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 18,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 50,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.3),
          border: Border.all(
            color: color,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.5,
        ),
      ),
    );
  }
}
